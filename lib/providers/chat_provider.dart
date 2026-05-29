import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/message.dart';
import '../models/search_result.dart';

/// Generates a random UUID v4 without external dependencies.
String _newId() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ChatProvider extends ChangeNotifier {
  final List<Conversation> _conversations = [];
  int _currentIndex = -1;
  bool _isLoading = false;

  // Reuse Dio instance for connection pooling
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  List<Conversation> get conversations => _conversations;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;

  Conversation? get currentConversation =>
      _currentIndex >= 0 && _currentIndex < _conversations.length
      ? _conversations[_currentIndex]
      : null;

  List<Message> get messages => currentConversation?.messages ?? [];

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower == 'authorization' ||
        lower == 'proxy-authorization' ||
        lower == 'key' ||
        lower.contains('apikey') ||
        lower.contains('api_key') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret');
  }

  static String _redactString(String value) {
    var redacted = value.replaceAll(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      'Bearer <redacted>',
    );
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'([?&](?:key|api_key|apikey|access_token|token|password|secret)=)[^&\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}<redacted>',
    );
    redacted = redacted.replaceAll(
      RegExp(r'sk-[A-Za-z0-9_-]{12,}'),
      'sk-<redacted>',
    );
    redacted = redacted.replaceAll(
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
      'AIza<redacted>',
    );
    return redacted;
  }

  static dynamic _redactSensitive(dynamic value) {
    if (value is Map) {
      return value.map((key, mapValue) {
        final keyString = key.toString();
        return MapEntry(
          keyString,
          _isSensitiveKey(keyString)
              ? '<redacted>'
              : _redactSensitive(mapValue),
        );
      });
    }
    if (value is Iterable) {
      return value.map(_redactSensitive).toList();
    }
    if (value is String) {
      return _redactString(value);
    }
    return value;
  }

  static String _encodeDiagnostic(dynamic data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(_redactSensitive(data));
    } catch (_) {
      return _redactString(data.toString());
    }
  }

  static String _redactedUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return _redactString(uri.toString());

    final queryParameters = uri.queryParameters.map((key, value) {
      return MapEntry(
        key,
        _isSensitiveKey(key) ? '<redacted>' : _redactString(value),
      );
    });

    return uri.replace(queryParameters: queryParameters).toString();
  }

  static String _buildRequestDiagnostics(RequestOptions options) {
    final details = {
      'url': _redactedUri(options.uri),
      'method': options.method,
      'headers': _redactSensitive(options.headers),
    };

    return '''
**Request Summary:**
```json
${_encodeDiagnostic(details)}
```''';
  }

  static String _buildResponseDiagnostics(dynamic data) {
    if (data == null) return '';

    return '''

**Response Data:**
```json
${_encodeDiagnostic(data)}
```''';
  }

  // ─── Persistence ───

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nexai_chats.json');
  }

  Future<void> loadConversations() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        if (jsonStr.isNotEmpty) {
          _conversations.clear();
          _conversations.addAll(Conversation.decodeList(jsonStr));
          if (_conversations.isNotEmpty) _currentIndex = 0;
        }
      }
    } catch (e) {
      debugPrint('NexAI: error loading conversations: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      await file.writeAsString(Conversation.encodeList(_conversations));
    } catch (e) {
      debugPrint('NexAI: error saving conversations: $e');
    }
  }

  // ─── Conversation management ───

  List<SearchResult> searchMessages(String query) {
    if (query.isEmpty) return [];
    final results = <SearchResult>[];
    final q = query.toLowerCase();

    for (int i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];
      for (int j = 0; j < conv.messages.length; j++) {
        final msg = conv.messages[j];
        if (msg.content.toLowerCase().contains(q)) {
          results.add(
            SearchResult(
              conversationIndex: i,
              conversation: conv,
              message: msg,
              messageIndex: j,
            ),
          );
        }
      }
    }
    results.sort((a, b) {
      final aIdx = a.message.content.toLowerCase().indexOf(q);
      final bIdx = b.message.content.toLowerCase().indexOf(q);
      return aIdx.compareTo(bIdx);
    });
    return results;
  }

  Future<void> newConversation() async {
    _conversations.insert(
      0,
      Conversation(
        id: _newId(),
        title: '新对话',
        messages: [],
        createdAt: DateTime.now(),
      ),
    );
    _currentIndex = 0;
    notifyListeners();
    await _save();
  }

  void selectConversation(int index) {
    if (index < 0 || index >= _conversations.length) return;
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> deleteConversation(int index) async {
    if (index < 0 || index >= _conversations.length) return;
    if (_isLoading && index == _currentIndex) return;

    _conversations.removeAt(index);
    if (_conversations.isEmpty) {
      _currentIndex = -1;
    } else if (_currentIndex == index) {
      _currentIndex = index.clamp(0, _conversations.length - 1);
    } else if (_currentIndex > index) {
      _currentIndex--;
    }
    notifyListeners();
    await _save();
  }

  Future<void> sendMessage({
    required String content,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
  }) async {
    if (_isLoading) return;

    if (currentConversation == null) {
      newConversation();
    }

    final conversation = currentConversation!;

    final userMessage = Message(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
    conversation.messages.add(userMessage);

    if (conversation.messages.where((m) => m.role == 'user').length == 1) {
      conversation.title = content.length > 30
          ? '${content.substring(0, 30)}...'
          : content;
    }

    await _performApiCall(
      conversation: conversation,
      apiMode: apiMode,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      vertexProjectId: vertexProjectId,
      vertexLocation: vertexLocation,
    );
  }

  /// Resend a message (for failed messages)
  Future<void> resendMessage({
    required int messageIndex,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
  }) async {
    if (_isLoading) return;
    final conversation = currentConversation;
    if (conversation == null ||
        messageIndex < 0 ||
        messageIndex >= conversation.messages.length) {
      return;
    }

    final message = conversation.messages[messageIndex];
    if (message.role != 'user') return;

    conversation.messages.removeRange(
      messageIndex + 1,
      conversation.messages.length,
    );
    notifyListeners();

    await _performApiCall(
      conversation: conversation,
      apiMode: apiMode,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      vertexProjectId: vertexProjectId,
      vertexLocation: vertexLocation,
    );
  }

  /// Edit and resend a message
  Future<void> editAndResendMessage({
    required int messageIndex,
    required String newContent,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
  }) async {
    if (_isLoading) return;
    final conversation = currentConversation;
    if (conversation == null ||
        messageIndex < 0 ||
        messageIndex >= conversation.messages.length) {
      return;
    }

    final message = conversation.messages[messageIndex];
    if (message.role != 'user') return;

    message.updateContent(newContent);
    conversation.messages.removeRange(
      messageIndex + 1,
      conversation.messages.length,
    );
    notifyListeners();

    await _performApiCall(
      conversation: conversation,
      apiMode: apiMode,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      vertexProjectId: vertexProjectId,
      vertexLocation: vertexLocation,
    );
  }

  /// Core API call logic (extracted for reuse)
  Future<void> _performApiCall({
    required Conversation conversation,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (apiMode == 'Vertex') {
        await _performVertexCall(
          conversation,
          apiKey,
          model,
          temperature,
          maxTokens,
          systemPrompt,
          vertexProjectId,
          vertexLocation,
        );
      } else {
        await _performOpenAiCall(
          conversation,
          baseUrl,
          apiKey,
          model,
          temperature,
          maxTokens,
          systemPrompt,
        );
      }
    } on DioException catch (e) {
      String errorMsg;
      String requestDetails = '';

      if (e.response != null) {
        try {
          final errorData = e.response!.data;
          if (errorData is Map) {
            final message = errorData['error']?['message']?.toString();
            errorMsg = message != null && message.isNotEmpty
                ? _redactString(message)
                : 'HTTP ${e.response!.statusCode}';
          } else {
            errorMsg = 'HTTP ${e.response!.statusCode}';
          }
        } catch (_) {
          errorMsg = 'HTTP ${e.response!.statusCode}';
        }

        requestDetails =
            '\n${_buildRequestDiagnostics(e.requestOptions)}'
            '${_buildResponseDiagnostics(e.response!.data)}';
      } else {
        errorMsg = _redactString(e.message ?? 'Connection error');
        requestDetails = '\n${_buildRequestDiagnostics(e.requestOptions)}';
      }
      conversation.messages.add(
        Message(
          role: 'assistant',
          content: 'Error: $errorMsg$requestDetails',
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    } catch (e) {
      conversation.messages.add(
        Message(
          role: 'assistant',
          content: 'Connection error: ${_redactString(e.toString())}',
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    }

    _isLoading = false;
    notifyListeners();
    await _save();
  }

  Future<void> _performOpenAiCall(
    Conversation conversation,
    String baseUrl,
    String apiKey,
    String model,
    double temperature,
    int maxTokens,
    String systemPrompt,
  ) async {
    final messagesPayload = <Map<String, String>>[];
    if (systemPrompt.isNotEmpty) {
      messagesPayload.add({'role': 'system', 'content': systemPrompt});
    }
    for (final msg in conversation.messages) {
      if (msg.isError) continue;
      messagesPayload.add({'role': msg.role, 'content': msg.content});
    }

    final response = await _dio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      data: {
        'model': model,
        'messages': messagesPayload,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      },
      options: Options(
        headers: {
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          'Accept': 'text/event-stream',
        },
        responseType: ResponseType.stream,
      ),
    );

    if (response.statusCode == 200) {
      final assistantMessage = Message(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
      );
      conversation.messages.add(assistantMessage);
      notifyListeners();

      final buffer = StringBuffer();
      String lineBuf = '';
      bool done = false;

      await for (final chunk
          in response.data!.stream.cast<List<int>>().transform(utf8.decoder)) {
        if (done) break;
        lineBuf += chunk;
        final lines = lineBuf.split('\n');
        lineBuf = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
          final data = trimmed.substring(6);
          if (data == '[DONE]') {
            done = true;
            break;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta'];
            if (delta != null && delta['content'] != null) {
              buffer.write(delta['content'] as String);
              assistantMessage.updateContent(buffer.toString());
              notifyListeners();
            }
          } catch (_) {
            // Skip malformed SSE chunks
          }
        }
      }

      if (assistantMessage.content.isEmpty) {
        assistantMessage.updateContent('Error: Empty response from API');
        assistantMessage.markAsError();
      }
    } else {
      conversation.messages.add(
        Message(
          role: 'assistant',
          content: 'Error: HTTP ${response.statusCode}',
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    }
  }

  Future<void> _performVertexCall(
    Conversation conversation,
    String apiKey,
    String model,
    double temperature,
    int maxTokens,
    String systemPrompt,
    String vertexProjectId,
    String vertexLocation,
  ) async {
    final contentsPayload = <Map<String, dynamic>>[];
    for (final msg in conversation.messages) {
      if (msg.isError) continue;
      // Vertex roles are user and model
      final role = msg.role == 'assistant' ? 'model' : 'user';
      contentsPayload.add({
        'role': role,
        'parts': [
          {'text': msg.content},
        ],
      });
    }

    final payload = <String, dynamic>{
      'contents': contentsPayload,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };

    if (systemPrompt.isNotEmpty) {
      payload['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt},
        ],
      };
    }

    String url;
    Map<String, String> headers = {'Content-Type': 'application/json'};

    // If project ID is empty, use Express Mode (API Key in query)
    if (vertexProjectId.isEmpty) {
      url =
          'https://aiplatform.googleapis.com/v1/publishers/google/models/$model:streamGenerateContent?key=$apiKey&alt=sse';
    } else {
      // Standard Mode (Bearer Token)
      url =
          'https://aiplatform.googleapis.com/v1/projects/$vertexProjectId/locations/$vertexLocation/publishers/google/models/$model:streamGenerateContent?alt=sse';
      // In Standard mode, the "apiKey" field from settings actually acts as the access token.
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _dio.post<ResponseBody>(
      url,
      data: payload,
      options: Options(headers: headers, responseType: ResponseType.stream),
    );

    if (response.statusCode == 200) {
      final assistantMessage = Message(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
      );
      conversation.messages.add(assistantMessage);
      notifyListeners();

      final buffer = StringBuffer();
      String lineBuf = '';

      await for (final chunk
          in response.data!.stream.cast<List<int>>().transform(utf8.decoder)) {
        lineBuf += chunk;
        final lines = lineBuf.split('\n');
        lineBuf = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
          final data = trimmed.substring(6);

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final candidates = json['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts =
                  candidates[0]['content']?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'] as String?;
                if (text != null) {
                  buffer.write(text);
                  assistantMessage.updateContent(buffer.toString());
                  notifyListeners();
                }
              }
            }
          } catch (_) {
            // Ignore malformed JSON or other SSE events
          }
        }
      }

      if (assistantMessage.content.isEmpty) {
        assistantMessage.updateContent('Error: Empty response from API');
        assistantMessage.markAsError();
      }
    } else {
      conversation.messages.add(
        Message(
          role: 'assistant',
          content: 'Error: HTTP ${response.statusCode}',
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    }
  }

  /// 从 JSON 列表恢复对话（云同步用）
  Future<void> restoreFromList(List<dynamic> list) async {
    _conversations.clear();
    _conversations.addAll(
      list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)),
    );
    if (_conversations.isNotEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = -1;
    }
    notifyListeners();
    await _save();
  }

  /// 增量合并：按 id upsert 对话
  Future<void> mergeItems(List<dynamic> list) async {
    for (final item in list) {
      final json = item as Map<String, dynamic>;
      final incoming = Conversation.fromJson(json);
      final idx = _conversations.indexWhere((c) => c.id == incoming.id);
      if (idx == -1) {
        _conversations.insert(0, incoming);
      } else {
        // 用最后消息时间判断哪个更新
        final existingLast = _conversations[idx].messages.isNotEmpty
            ? _conversations[idx].messages.last.timestamp
            : _conversations[idx].createdAt;
        final incomingLast = incoming.messages.isNotEmpty
            ? incoming.messages.last.timestamp
            : incoming.createdAt;
        if (incomingLast.isAfter(existingLast) ||
            incomingLast == existingLast) {
          _conversations[idx] = incoming;
        }
      }
    }
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
