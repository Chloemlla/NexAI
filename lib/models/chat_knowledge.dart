/// Local document knowledge base models for chat tools.
library;

import 'dart:convert';

import 'message.dart' show asStringMap;

class KnowledgeBase {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnowledgeBase({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  KnowledgeBase copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
  }) =>
      KnowledgeBase(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory KnowledgeBase.fromJson(Map<String, dynamic> json) => KnowledgeBase(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Default').toString(),
        description: (json['description'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class KnowledgeDoc {
  final String id;
  final String baseId;
  final String title;
  final String sourceType; // file | note | url | paste
  final String sourcePath;
  final String content;
  final String folder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final Map<String, double> termWeights;

  const KnowledgeDoc({
    required this.id,
    this.baseId = 'default',
    required this.title,
    required this.sourceType,
    required this.sourcePath,
    required this.content,
    this.folder = '',
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.termWeights = const {},
  });

  KnowledgeDoc copyWith({
    String? baseId,
    String? title,
    String? content,
    String? folder,
    DateTime? updatedAt,
    List<String>? tags,
    Map<String, double>? termWeights,
  }) =>
      KnowledgeDoc(
        id: id,
        baseId: baseId ?? this.baseId,
        title: title ?? this.title,
        sourceType: sourceType,
        sourcePath: sourcePath,
        content: content ?? this.content,
        folder: folder ?? this.folder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        tags: tags ?? this.tags,
        termWeights: termWeights ?? this.termWeights,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'baseId': baseId,
        'title': title,
        'sourceType': sourceType,
        'sourcePath': sourcePath,
        'content': content,
        'folder': folder,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'tags': tags,
        if (termWeights.isNotEmpty) 'termWeights': termWeights,
      };

  factory KnowledgeDoc.fromJson(Map<String, dynamic> json) {
    final weightsRaw = json['termWeights'];
    final weights = <String, double>{};
    if (weightsRaw is Map) {
      weightsRaw.forEach((k, v) {
        final d = v is num ? v.toDouble() : double.tryParse(v.toString());
        if (d != null) weights[k.toString()] = d;
      });
    }
    return KnowledgeDoc(
      id: (json['id'] ?? '').toString(),
      baseId: (json['baseId'] ?? 'default').toString(),
      title: (json['title'] ?? 'Untitled').toString(),
      sourceType: (json['sourceType'] ?? 'file').toString(),
      sourcePath: (json['sourcePath'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      folder: (json['folder'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      tags: (json['tags'] is List)
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      termWeights: weights,
    );
  }

  static String encodeList(List<KnowledgeDoc> docs) =>
      jsonEncode(docs.map((d) => d.toJson()).toList());

  static List<KnowledgeDoc> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Object>()
        .map((e) => KnowledgeDoc.fromJson(asStringMap(e, 'knowledgeDoc')))
        .toList();
  }
}

class KnowledgeSearchHit {
  final KnowledgeDoc doc;
  final String snippet;
  final int score;
  final double semanticScore;

  const KnowledgeSearchHit({
    required this.doc,
    required this.snippet,
    required this.score,
    this.semanticScore = 0,
  });
}

class McpServerConfig {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  final String? bearerToken;
  final List<String> allowTools;
  final DateTime? lastHealthyAt;
  final String? lastError;

  const McpServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.bearerToken,
    this.allowTools = const [],
    this.lastHealthyAt,
    this.lastError,
  });

  McpServerConfig copyWith({
    String? name,
    String? url,
    bool? enabled,
    String? bearerToken,
    List<String>? allowTools,
    DateTime? lastHealthyAt,
    String? lastError,
    bool clearError = false,
  }) =>
      McpServerConfig(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        enabled: enabled ?? this.enabled,
        bearerToken: bearerToken ?? this.bearerToken,
        allowTools: allowTools ?? this.allowTools,
        lastHealthyAt: lastHealthyAt ?? this.lastHealthyAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'enabled': enabled,
        if (bearerToken != null && bearerToken!.isNotEmpty)
          'bearerToken': bearerToken,
        if (allowTools.isNotEmpty) 'allowTools': allowTools,
        if (lastHealthyAt != null)
          'lastHealthyAt': lastHealthyAt!.toIso8601String(),
        if (lastError != null) 'lastError': lastError,
      };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) =>
      McpServerConfig(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'MCP').toString(),
        url: (json['url'] ?? '').toString(),
        enabled: json['enabled'] as bool? ?? true,
        bearerToken: json['bearerToken']?.toString(),
        allowTools: json['allowTools'] is List
            ? (json['allowTools'] as List).map((e) => e.toString()).toList()
            : const <String>[],
        lastHealthyAt:
            DateTime.tryParse((json['lastHealthyAt'] ?? '').toString()),
        lastError: json['lastError']?.toString(),
      );
}

class WebSearchProviderConfig {
  final String id;
  final String name;
  final String type; // duckduckgo | tavily | searxng | exa | jina | nexai_gateway
  final String endpoint;
  final String? apiKey;
  final bool enabled;

  const WebSearchProviderConfig({
    required this.id,
    required this.name,
    required this.type,
    this.endpoint = '',
    this.apiKey,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'endpoint': endpoint,
        if (apiKey != null && apiKey!.isNotEmpty) 'apiKey': apiKey,
        'enabled': enabled,
      };

  factory WebSearchProviderConfig.fromJson(Map<String, dynamic> json) =>
      WebSearchProviderConfig(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Search').toString(),
        type: (json['type'] ?? 'duckduckgo').toString(),
        endpoint: (json['endpoint'] ?? '').toString(),
        apiKey: json['apiKey']?.toString(),
        enabled: json['enabled'] as bool? ?? true,
      );
}
