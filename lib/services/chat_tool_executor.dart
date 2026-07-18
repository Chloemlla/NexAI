/// Executes builtin chat tools against local providers and remote endpoints.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_tool.dart';
import '../models/note.dart';
import '../models/chat_knowledge.dart';
import '../providers/artifacts_provider.dart';
import '../providers/image_generation_provider.dart';
import '../providers/knowledge_provider.dart';
import '../providers/notes_provider.dart';
import 'chat_tool_catalog.dart';
import 'remote_mcp_client.dart';
import '../utils/network_safety.dart';

class ChatToolRuntimeContext {
  final NotesProvider notesProvider;
  final ImageGenerationProvider imageGenerationProvider;
  final ArtifactsProvider artifactsProvider;
  final KnowledgeProvider knowledgeProvider;
  final List<McpServerConfig> mcpServers;
  final List<WebSearchProviderConfig> webSearchProviders;
  final String activeWebSearchProviderId;
  final String toolGatewayBaseUrl;
  final bool semanticKnowledgeSearch;
  final String baseUrl;
  final String apiKey;
  final String selectedModel;
  final String? accessToken;
  final String imageModel;

  const ChatToolRuntimeContext({
    required this.notesProvider,
    required this.imageGenerationProvider,
    required this.artifactsProvider,
    required this.knowledgeProvider,
    required this.mcpServers,
    this.webSearchProviders = const [],
    this.activeWebSearchProviderId = 'ddg',
    this.toolGatewayBaseUrl = '',
    this.semanticKnowledgeSearch = true,
    required this.baseUrl,
    required this.apiKey,
    required this.selectedModel,
    required this.accessToken,
    required this.imageModel,
  });
}

class ChatToolExecutor {
  ChatToolExecutor({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': 'NexAI-Android-ChatTools/1.0',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              },
            ),
          );

  final Dio _dio;
  final RemoteMcpClient _mcpClient = RemoteMcpClient();

  void _assertSafeEndpoint(String raw, {bool requireHttps = false}) {
    final err = NetworkSafety.validatePublicHttpUrl(raw, requireHttps: requireHttps);
    if (err != null) {
      throw StateError('blocked_url:$err');
    }
  }

  String _safeToolContent(String content) => NetworkSafety.redactSecrets(content);


  Future<ToolExecutionResult> execute({
    required String name,
    required Map<String, dynamic> arguments,
    required ChatToolRuntimeContext context,
  }) async {
    try {
      switch (name) {
        case ChatToolCatalog.webSearch:
          return await _webSearch(arguments, context);
        case ChatToolCatalog.notesSearch:
          return _notesSearch(arguments, context);
        case ChatToolCatalog.notesRead:
          return _notesRead(arguments, context);
        case ChatToolCatalog.generateImage:
          return await _generateImage(arguments, context);
        case ChatToolCatalog.reportArtifacts:
          return await _reportArtifacts(arguments, context);
        case ChatToolCatalog.fetchUrl:
          return await _fetchUrl(arguments);
        case ChatToolCatalog.createNote:
          return await _createNote(arguments, context);
        case ChatToolCatalog.knowledgeSearch:
          return _knowledgeSearch(arguments, context);
        case ChatToolCatalog.knowledgeRead:
          return _knowledgeRead(arguments, context);
        case ChatToolCatalog.knowledgeManage:
          return await _knowledgeManage(arguments, context);
        case ChatToolCatalog.getCurrentTime:
          return _getCurrentTime(arguments);
        default:
          if (ChatToolCatalog.isMcpTool(name)) {
            return await _mcpCall(name, arguments, context);
          }
          return ToolExecutionResult(
            content: jsonEncode({
              'error': 'unknown_tool',
              'message': 'Tool "$name" is not registered on this client.',
            }),
            isError: true,
          );
      }
    } catch (e) {
      debugPrint('NexAI tools: $name failed: $e');
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'tool_failed',
          'tool': name,
          'message': e.toString(),
        }),
        isError: true,
      );
    }
  }

  Future<ToolExecutionResult> _webSearch(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) async {
    final query = (args['query'] ?? '').toString().trim();
    if (query.isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"query_required"}',
        isError: true,
      );
    }
    final maxResults = _clampInt(args['max_results'], fallback: 5, min: 1, max: 8);

    // Prefer configured provider, then gateway, then DuckDuckGo.
    WebSearchProviderConfig? provider;
    for (final p in context.webSearchProviders) {
      if (p.id == context.activeWebSearchProviderId && p.enabled) {
        provider = p;
        break;
      }
    }
    provider ??= context.webSearchProviders.where((p) => p.enabled).cast<WebSearchProviderConfig?>().firstWhere(
          (p) => true,
          orElse: () => null,
        );
    if (provider != null && provider.type != 'duckduckgo') {
      try {
        final result = await _providerWebSearch(
          provider: provider,
          query: query,
          maxResults: maxResults,
          context: context,
        );
        if (!result.isError) return result;
      } catch (e) {
        debugPrint('provider search failed: $e');
      }
    }

    final proxyResults = await _tryNexaiWebSearch(
      context: context,
      query: query,
      maxResults: maxResults,
    );
    if (proxyResults != null) {
      return ToolExecutionResult(
        content: proxyResults.content,
        citations: _rankCitations(proxyResults.citations, query),
        isError: proxyResults.isError,
      );
    }

    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.duckduckgo.com/',
      queryParameters: {
        'q': query,
        'format': 'json',
        'no_redirect': 1,
        'no_html': 1,
        'skip_disambig': 1,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    final citations = <Citation>[];

    void addItem(String title, String url, String snippet, String source) {
      if (title.trim().isEmpty && url.trim().isEmpty) return;
      citations.add(
        Citation(
          title: title.trim().isEmpty ? url : title.trim(),
          url: url,
          snippet: snippet.trim(),
          source: source,
        ),
      );
    }

    final abstract = (data['AbstractText'] ?? '').toString();
    final abstractUrl = (data['AbstractURL'] ?? '').toString();
    final heading = (data['Heading'] ?? query).toString();
    if (abstract.isNotEmpty || abstractUrl.isNotEmpty) {
      addItem(heading, abstractUrl, abstract, 'duckduckgo');
    }

    final related = data['RelatedTopics'];
    if (related is List) {
      for (final item in related) {
        if (citations.length >= maxResults) break;
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final text = (map['Text'] ?? '').toString();
        final url = (map['FirstURL'] ?? '').toString();
        if (text.isEmpty && url.isEmpty) {
          final topics = map['Topics'];
          if (topics is List) {
            for (final nested in topics) {
              if (citations.length >= maxResults) break;
              if (nested is! Map) continue;
              final nestedMap = nested.map((k, v) => MapEntry(k.toString(), v));
              addItem(
                (nestedMap['Text'] ?? '').toString().split(' - ').first,
                (nestedMap['FirstURL'] ?? '').toString(),
                (nestedMap['Text'] ?? '').toString(),
                'duckduckgo',
              );
            }
          }
          continue;
        }
        addItem(text.split(' - ').first, url, text, 'duckduckgo');
      }
    }

    final results = _rankCitations(citations, query).take(maxResults).toList(growable: false);
    return ToolExecutionResult(
      content: jsonEncode({
        'query': query,
        'provider': 'duckduckgo',
        'results': results
            .map(
              (c) => {
                'title': c.title,
                'url': c.url,
                'snippet': c.snippet,
              },
            )
            .toList(),
      }),
      citations: results,
    );
  }


  List<Citation> _rankCitations(List<Citation> input, String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final scored = input.map((c) {
      final hay = '${c.title} ${c.snippet} ${c.url}'.toLowerCase();
      var score = 0;
      for (final t in terms) {
        if (hay.contains(t)) score += 1;
        if (c.title.toLowerCase().contains(t)) score += 2;
      }
      // prefer https and non-empty snippets
      if (c.url.startsWith('https://')) score += 1;
      if (c.snippet.trim().isNotEmpty) score += 1;
      return MapEntry(c, score);
    }).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));
    final seen = <String>{};
    final out = <Citation>[];
    for (final entry in scored) {
      final key = entry.key.url.trim().isEmpty ? entry.key.title : entry.key.url;
      if (!seen.add(key)) continue;
      out.add(entry.key);
    }
    return out;
  }

  Future<ToolExecutionResult> _providerWebSearch({
    required WebSearchProviderConfig provider,
    required String query,
    required int maxResults,
    required ChatToolRuntimeContext context,
  }) async {
    switch (provider.type) {
      case 'tavily':
        final key = (provider.apiKey ?? '').trim();
        if (key.isEmpty) break;
        final endpoint = provider.endpoint.trim().isEmpty
            ? 'https://api.tavily.com/search'
            : provider.endpoint.trim();
        _assertSafeEndpoint(endpoint, requireHttps: true);
        final response = await _dio.post<Map<String, dynamic>>(
          endpoint,
          data: {
            'api_key': key,
            'query': query,
            'max_results': maxResults,
            'include_answer': false,
          },
        );
        final results = response.data?['results'];
        final citations = <Citation>[];
        if (results is List) {
          for (final item in results.take(maxResults)) {
            if (item is! Map) continue;
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            citations.add(Citation(
              title: (map['title'] ?? '').toString(),
              url: (map['url'] ?? '').toString(),
              snippet: (map['content'] ?? map['snippet'] ?? '').toString(),
              source: 'tavily',
            ));
          }
        }
        return ToolExecutionResult(
          content: jsonEncode({'query': query, 'provider': 'tavily', 'results': citations.map((c) => c.toJson()).toList()}),
          citations: _rankCitations(citations, query),
        );
      case 'searxng':
        final endpoint = provider.endpoint.trim();
        if (endpoint.isEmpty) break;
        _assertSafeEndpoint(endpoint, requireHttps: true);
        final response = await _dio.get<Map<String, dynamic>>(
          endpoint,
          queryParameters: {'q': query, 'format': 'json'},
        );
        final results = response.data?['results'];
        final citations = <Citation>[];
        if (results is List) {
          for (final item in results.take(maxResults)) {
            if (item is! Map) continue;
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            citations.add(Citation(
              title: (map['title'] ?? '').toString(),
              url: (map['url'] ?? '').toString(),
              snippet: (map['content'] ?? '').toString(),
              source: 'searxng',
            ));
          }
        }
        return ToolExecutionResult(
          content: jsonEncode({'query': query, 'provider': 'searxng', 'results': citations.map((c) => c.toJson()).toList()}),
          citations: _rankCitations(citations, query),
        );
      case 'exa':
        final key = (provider.apiKey ?? '').trim();
        if (key.isEmpty) break;
        final endpoint = provider.endpoint.trim().isEmpty
            ? 'https://api.exa.ai/search'
            : provider.endpoint.trim();
        _assertSafeEndpoint(endpoint, requireHttps: true);
        final response = await _dio.post<Map<String, dynamic>>(
          endpoint,
          data: {
            'query': query,
            'numResults': maxResults,
            'type': 'auto',
          },
          options: Options(headers: {'x-api-key': key, 'Content-Type': 'application/json'}),
        );
        final results = response.data?['results'];
        final citations = <Citation>[];
        if (results is List) {
          for (final item in results.take(maxResults)) {
            if (item is! Map) continue;
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            citations.add(Citation(
              title: (map['title'] ?? '').toString(),
              url: (map['url'] ?? '').toString(),
              snippet: (map['text'] ?? map['snippet'] ?? '').toString(),
              source: 'exa',
            ));
          }
        }
        return ToolExecutionResult(
          content: jsonEncode({'query': query, 'provider': 'exa', 'results': citations.map((c) => c.toJson()).toList()}),
          citations: _rankCitations(citations, query),
        );
      case 'jina':
        final endpoint = provider.endpoint.trim().isEmpty
            ? 'https://s.jina.ai/'
            : provider.endpoint.trim();
        _assertSafeEndpoint(endpoint, requireHttps: true);
        final response = await _dio.get<String>(
          endpoint + Uri.encodeComponent(query),
          options: Options(
            headers: {
              if ((provider.apiKey ?? '').trim().isNotEmpty)
                'Authorization': 'Bearer ${provider.apiKey!.trim()}',
              'Accept': 'application/json',
            },
            responseType: ResponseType.plain,
          ),
        );
        final raw = response.data ?? '';
        // jina may return markdown-ish lines; keep as one citation source list fallback
        final citations = <Citation>[
          Citation(
            title: 'Jina search: $query',
            url: 'https://s.jina.ai/${Uri.encodeComponent(query)}',
            snippet: raw.length > 400 ? raw.substring(0, 400) : raw,
            source: 'jina',
          ),
        ];
        return ToolExecutionResult(
          content: jsonEncode({'query': query, 'provider': 'jina', 'results': citations.map((c) => c.toJson()).toList()}),
          citations: citations,
        );
      case 'nexai_gateway':
        final gateway = context.toolGatewayBaseUrl.trim().isNotEmpty
            ? context.toolGatewayBaseUrl.trim()
            : provider.endpoint.trim();
        if (gateway.isEmpty) break;
        final gatewayUrl = gateway.replaceAll(RegExp(r'/+$'), '') + '/tools/web_search';
        _assertSafeEndpoint(gatewayUrl, requireHttps: true);
        final response = await _dio.post<Map<String, dynamic>>(
          gatewayUrl,
          data: {'query': query, 'max_results': maxResults},
          options: Options(
            headers: {
              if (context.apiKey.isNotEmpty) 'Authorization': 'Bearer ${context.apiKey}',
              'Content-Type': 'application/json',
            },
          ),
        );
        final list = response.data?['results'] ?? response.data?['data']?['results'];
        final citations = <Citation>[];
        if (list is List) {
          for (final item in list.take(maxResults)) {
            if (item is! Map) continue;
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            citations.add(Citation(
              title: (map['title'] ?? '').toString(),
              url: (map['url'] ?? '').toString(),
              snippet: (map['snippet'] ?? '').toString(),
              source: 'nexai_gateway',
            ));
          }
        }
        return ToolExecutionResult(
          content: jsonEncode({'query': query, 'provider': 'nexai_gateway', 'results': citations.map((c) => c.toJson()).toList()}),
          citations: _rankCitations(citations, query),
        );
      default:
        break;
    }
    // fallback empty forces ddg path
    return const ToolExecutionResult(content: '{"provider":"none"}', isError: true);
  }

  Future<ToolExecutionResult?> _tryNexaiWebSearch({
    required ChatToolRuntimeContext context,
    required String query,
    required int maxResults,
  }) async {
    if (context.baseUrl.trim().isEmpty || context.apiKey.trim().isEmpty) {
      return null;
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${context.baseUrl}/tools/web_search',
        data: {
          'query': query,
          'max_results': maxResults,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${context.apiKey}',
            'Content-Type': 'application/json',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      if (response.statusCode != 200 || response.data == null) return null;
      final data = response.data!;
      final list = data['results'] ?? data['data']?['results'];
      if (list is! List || list.isEmpty) return null;
      final citations = <Citation>[];
      for (final item in list.take(maxResults)) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        citations.add(
          Citation(
            title: (map['title'] ?? map['name'] ?? '').toString(),
            url: (map['url'] ?? map['link'] ?? '').toString(),
            snippet: (map['snippet'] ?? map['content'] ?? map['description'] ?? '')
                .toString(),
            source: (map['source'] ?? 'nexai').toString(),
          ),
        );
      }
      if (citations.isEmpty) return null;
      return ToolExecutionResult(
        content: jsonEncode({
          'query': query,
          'provider': 'nexai',
          'results': citations
              .map(
                (c) => {
                  'title': c.title,
                  'url': c.url,
                  'snippet': c.snippet,
                },
              )
              .toList(),
        }),
        citations: citations,
      );
    } catch (_) {
      return null;
    }
  }

  ToolExecutionResult _notesSearch(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) {
    final query = (args['query'] ?? '').toString().trim();
    if (query.isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"query_required"}',
        isError: true,
      );
    }
    final limit = _clampInt(args['limit'], fallback: 8, min: 1, max: 20);
    final hits = context.notesProvider.searchNotes(query).take(limit).toList();
    final payload = hits.map((hit) {
      final note = hit.note;
      final snippet = note.bodyContent.trim();
      return {
        'id': note.id,
        'title': note.title,
        'updatedAt': note.updatedAt.toIso8601String(),
        'isStarred': note.isStarred,
        'tags': note.tags,
        'snippet': snippet.length > 240 ? '${snippet.substring(0, 240)}...' : snippet,
        'matchCount': hit.matches.length,
      };
    }).toList();
    return ToolExecutionResult(
      content: jsonEncode({
        'query': query,
        'count': payload.length,
        'notes': payload,
      }),
    );
  }

  ToolExecutionResult _notesRead(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) {
    final noteId = (args['note_id'] ?? args['noteId'] ?? '').toString().trim();
    final title = (args['title'] ?? '').toString().trim();
    final maxChars = _clampInt(args['max_chars'], fallback: 4000, min: 200, max: 12000);

    Note? note;
    if (noteId.isNotEmpty) {
      for (final item in context.notesProvider.notes) {
        if (item.id == noteId) {
          note = item;
          break;
        }
      }
    }
    note ??= title.isEmpty ? null : context.notesProvider.findNoteByTitle(title);
    if (note == null) {
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'note_not_found',
          'note_id': noteId,
          'title': title,
        }),
        isError: true,
      );
    }

    final body = note.bodyContent;
    final clipped = body.length > maxChars ? body.substring(0, maxChars) : body;
    return ToolExecutionResult(
      content: jsonEncode({
        'id': note.id,
        'title': note.title,
        'tags': note.tags,
        'isStarred': note.isStarred,
        'updatedAt': note.updatedAt.toIso8601String(),
        'content': clipped,
        'truncated': body.length > maxChars,
        'totalChars': body.length,
      }),
    );
  }

  Future<ToolExecutionResult> _generateImage(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) async {
    final prompt = (args['prompt'] ?? '').toString().trim();
    if (prompt.isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"prompt_required"}',
        isError: true,
      );
    }
    if (context.baseUrl.isEmpty || context.apiKey.isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"api_not_configured"}',
        isError: true,
      );
    }

    final size = (args['size'] ?? '1024x1024').toString();
    final before = context.imageGenerationProvider.images.length;
    await context.imageGenerationProvider.generateImage(
      baseUrl: context.baseUrl,
      apiKey: context.apiKey,
      model: context.imageModel.isEmpty ? context.selectedModel : context.imageModel,
      prompt: prompt,
      size: size,
      responseFormat: 'url',
    );

    final error = context.imageGenerationProvider.error;
    final images = context.imageGenerationProvider.images;
    if (error != null && images.length <= before) {
      return ToolExecutionResult(
        content: jsonEncode({'error': 'image_generation_failed', 'message': error}),
        isError: true,
      );
    }

    final created = images.take((images.length - before).clamp(1, 4)).toList();
    final urls = created.map((image) => image.url).where((url) => url.isNotEmpty).toList();
    return ToolExecutionResult(
      content: jsonEncode({
        'prompt': prompt,
        'size': size,
        'images': urls
            .map((url) => {'url': url})
            .toList(),
        'message': urls.isEmpty
            ? 'Image generation completed but no URL was returned.'
            : 'Generated ${urls.length} image(s).',
      }),
      citations: urls
          .map(
            (url) => Citation(
              title: 'Generated image',
              url: url,
              snippet: prompt,
              source: 'generate_image',
            ),
          )
          .toList(),
    );
  }

  Future<ToolExecutionResult> _reportArtifacts(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) async {
    final token = context.accessToken;
    if (token == null || token.isEmpty) {
      return const ToolExecutionResult(
        content:
            '{"error":"login_required","message":"User must sign in before creating artifacts."}',
        isError: true,
      );
    }
    final title = (args['title'] ?? 'Shared from chat').toString().trim();
    final content = (args['content'] ?? '').toString();
    if (content.trim().isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"content_required"}',
        isError: true,
      );
    }
    final contentType = (args['content_type'] ?? args['contentType'] ?? 'markdown')
        .toString()
        .trim();
    final language = args['language']?.toString();
    final description = args['description']?.toString();
    final visibility = (args['visibility'] ?? 'public').toString();

    final response = await context.artifactsProvider.createArtifact(
      accessToken: token,
      title: title.isEmpty ? 'Shared from chat' : title,
      contentType: contentType.isEmpty ? 'markdown' : contentType,
      content: content,
      language: language,
      visibility: visibility,
      description: description,
    );
    if (response == null) {
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'artifact_create_failed',
          'message': context.artifactsProvider.error ?? 'Unknown error',
        }),
        isError: true,
      );
    }

    return ToolExecutionResult(
      content: jsonEncode({
        'id': response.id,
        'shortId': response.shortId,
        'shareUrl': response.shareUrl,
        'embedUrl': response.embedUrl,
        'title': title,
        'visibility': visibility,
      }),
      citations: [
        Citation(
          title: title.isEmpty ? 'Artifact' : title,
          url: response.shareUrl,
          snippet: description ?? 'Shared artifact',
          source: 'report_artifacts',
        ),
      ],
    );
  }

  Future<ToolExecutionResult> _fetchUrl(Map<String, dynamic> args) async {
    final rawUrl = (args['url'] ?? '').toString().trim();
    final urlErr = NetworkSafety.validatePublicHttpUrl(rawUrl);
    if (urlErr != null) {
      return ToolExecutionResult(
        content: jsonEncode({'error': urlErr}),
        isError: true,
      );
    }
    final uri = Uri.parse(rawUrl);
    final maxChars = _clampInt(args['max_chars'], fallback: 6000, min: 500, max: 20000);
    final response = await _dio.get<List<int>>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        maxRedirects: NetworkSafety.maxRedirects,
        validateStatus: (code) => code != null && code < 400,
      ),
    );
    // Re-validate final URL after redirects.
    final finalUri = response.realUri;
    final finalErr = NetworkSafety.validatePublicHttpUrl(finalUri.toString());
    if (finalErr != null) {
      return ToolExecutionResult(
        content: jsonEncode({'error': finalErr, 'finalUrl': finalUri.toString()}),
        isError: true,
      );
    }
    final bytes = response.data ?? <int>[];
    if (bytes.length > NetworkSafety.maxDownloadBytes) {
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'response_too_large',
          'maxBytes': NetworkSafety.maxDownloadBytes,
          'actualBytes': bytes.length,
        }),
        isError: true,
      );
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    final text = _htmlToText(body);
    final clipped = text.length > maxChars ? text.substring(0, maxChars) : text;
    final title = _extractHtmlTitle(body) ?? uri.host;
    return ToolExecutionResult(
      content: jsonEncode({
        'url': finalUri.toString(),
        'title': title,
        'content': _safeToolContent(clipped),
        'truncated': text.length > maxChars,
        'totalChars': text.length,
      }),
      citations: [
        Citation(
          title: title,
          url: uri.toString(),
          snippet: clipped.length > 180 ? '${clipped.substring(0, 180)}...' : clipped,
          source: 'fetch_url',
        ),
      ],
    );
  }

  Future<ToolExecutionResult> _createNote(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) async {
    final content = (args['content'] ?? '').toString();
    if (content.trim().isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"content_required"}',
        isError: true,
      );
    }
    if (content.length > 20000) {
      return const ToolExecutionResult(
        content: '{"error":"content_too_large","maxChars":20000}',
        isError: true,
      );
    }
    final title = (args['title'] ?? '').toString().trim();
    final note = await context.notesProvider.createNote(
      title: title,
      content: content,
    );
    return ToolExecutionResult(
      content: jsonEncode({
        'id': note.id,
        'title': note.title,
        'createdAt': note.createdAt.toIso8601String(),
        'message': 'Note created.',
      }),
    );
  }


  ToolExecutionResult _knowledgeSearch(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) {
    final query = (args['query'] ?? '').toString().trim();
    if (query.isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"query_required"}',
        isError: true,
      );
    }
    final limit = _clampInt(args['limit'], fallback: 8, min: 1, max: 20);
    final baseId = (args['base_id'] ?? args['baseId'] ?? '').toString().trim();
    final hits = context.knowledgeProvider.search(query, limit: limit, baseId: baseId.isEmpty ? null : baseId, semantic: context.semanticKnowledgeSearch);
    return ToolExecutionResult(
      content: jsonEncode({
        'query': query,
        'count': hits.length,
        'docs': hits
            .map(
              (hit) => {
                'id': hit.doc.id,
                'title': hit.doc.title,
                'sourceType': hit.doc.sourceType,
                'score': hit.score,
                'snippet': hit.snippet,
                'tags': hit.doc.tags,
              },
            )
            .toList(),
      }),
    );
  }

  ToolExecutionResult _knowledgeRead(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) {
    final docId = (args['doc_id'] ?? args['docId'] ?? '').toString().trim();
    if (docId.isEmpty) {
      return const ToolExecutionResult(
        content: '{"error":"doc_id_required"}',
        isError: true,
      );
    }
    final maxChars = _clampInt(args['max_chars'], fallback: 5000, min: 200, max: 20000);
    final doc = context.knowledgeProvider.byId(docId);
    if (doc == null) {
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'doc_not_found',
          'doc_id': docId,
        }),
        isError: true,
      );
    }
    final body = doc.content;
    final clipped = body.length > maxChars ? body.substring(0, maxChars) : body;
    return ToolExecutionResult(
      content: jsonEncode({
        'id': doc.id,
        'title': doc.title,
        'sourceType': doc.sourceType,
        'sourcePath': doc.sourcePath,
        'tags': doc.tags,
        'content': clipped,
        'truncated': body.length > maxChars,
        'totalChars': body.length,
      }),
    );
  }

  Future<ToolExecutionResult> _mcpCall(
    String qualifiedName,
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) async {
    final serverId = ChatToolCatalog.mcpServerId(qualifiedName);
    final toolName = ChatToolCatalog.mcpToolName(qualifiedName);
    if (serverId == null || toolName == null || toolName.isEmpty) {
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'invalid_mcp_tool',
          'tool': qualifiedName,
        }),
        isError: true,
      );
    }
    McpServerConfig? server;
    for (final item in context.mcpServers) {
      if (item.id == serverId && item.enabled) {
        server = item;
        break;
      }
    }
    if (server == null) {
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'mcp_server_not_found',
          'serverId': serverId,
          'tool': toolName,
        }),
        isError: true,
      );
    }
    if (server.allowTools.isNotEmpty && !server.allowTools.contains(toolName)) {
      return ToolExecutionResult(
        content: jsonEncode({
          'error': 'mcp_tool_not_allowed',
          'serverId': serverId,
          'tool': toolName,
          'allowTools': server.allowTools,
        }),
        isError: true,
      );
    }
    final mcpResult = await _mcpClient.callTool(
      server: server,
      toolName: toolName,
      arguments: args,
    );
    return ToolExecutionResult(
      content: _safeToolContent(mcpResult.content),
      citations: mcpResult.citations,
      isError: mcpResult.isError,
    );
  }


  Future<ToolExecutionResult> _knowledgeManage(
    Map<String, dynamic> args,
    ChatToolRuntimeContext context,
  ) async {
    final action = (args['action'] ?? '').toString().trim().toLowerCase();
    final baseId = (args['base_id'] ?? args['baseId'] ?? context.knowledgeProvider.activeBaseId).toString();
    switch (action) {
      case 'create':
        final title = (args['title'] ?? 'Untitled').toString();
        final content = (args['content'] ?? '').toString();
        if (content.trim().isEmpty) {
          return const ToolExecutionResult(content: '{"error":"content_required"}', isError: true);
        }
        if (content.length > 20000) {
          return const ToolExecutionResult(content: '{"error":"content_too_large","maxChars":20000}', isError: true);
        }
        final tags = args['tags'] is List
            ? (args['tags'] as List).map((e) => e.toString()).toList()
            : <String>[];
        final doc = await context.knowledgeProvider.importText(
          title: title,
          content: content,
          baseId: baseId,
          folder: (args['folder'] ?? '').toString(),
          tags: tags,
        );
        return ToolExecutionResult(content: jsonEncode({'action': 'create', 'id': doc.id, 'title': doc.title, 'baseId': doc.baseId}));
      case 'update':
        final docId = (args['doc_id'] ?? args['docId'] ?? '').toString();
        if (docId.isEmpty) {
          return const ToolExecutionResult(content: '{"error":"doc_id_required"}', isError: true);
        }
        await context.knowledgeProvider.updateDoc(
          id: docId,
          title: args['title']?.toString(),
          content: args['content']?.toString(),
          folder: args['folder']?.toString(),
          tags: args['tags'] is List ? (args['tags'] as List).map((e) => e.toString()).toList() : null,
          baseId: baseId,
        );
        return ToolExecutionResult(content: jsonEncode({'action': 'update', 'id': docId}));
      case 'delete':
        final docId = (args['doc_id'] ?? args['docId'] ?? '').toString();
        if (docId.isEmpty) {
          return const ToolExecutionResult(content: '{"error":"doc_id_required"}', isError: true);
        }
        await context.knowledgeProvider.deleteDoc(docId);
        return ToolExecutionResult(content: jsonEncode({'action': 'delete', 'id': docId}));
      default:
        return ToolExecutionResult(content: jsonEncode({'error': 'invalid_action', 'action': action}), isError: true);
    }
  }

  ToolExecutionResult _getCurrentTime(Map<String, dynamic> args) {
    final now = DateTime.now();
    return ToolExecutionResult(
      content: jsonEncode({
        'iso': now.toIso8601String(),
        'local': now.toLocal().toString(),
        'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
        'timezoneName': now.timeZoneName,
      }),
    );
  }

  static int _clampInt(
    Object? value, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final parsed = value is int
        ? value
        : int.tryParse(value?.toString() ?? '') ?? fallback;
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  static String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    return _decodeHtml(match.group(1) ?? '').trim();
  }

  static String _htmlToText(String html) {
    var text = html;
    text = text.replaceAll(
      RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _decodeHtml(text);
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return text.trim();
  }

  static String _decodeHtml(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
