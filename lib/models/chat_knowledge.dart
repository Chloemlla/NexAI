/// Local document knowledge base models for chat tools.
library;

import 'dart:convert';

import 'message.dart' show asStringMap;

class KnowledgeDoc {
  final String id;
  final String title;
  final String sourceType; // file | note | url | paste
  final String sourcePath;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  const KnowledgeDoc({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.sourcePath,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceType': sourceType,
    'sourcePath': sourcePath,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
  };

  factory KnowledgeDoc.fromJson(Map<String, dynamic> json) => KnowledgeDoc(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? 'Untitled').toString(),
    sourceType: (json['sourceType'] ?? 'file').toString(),
    sourcePath: (json['sourcePath'] ?? '').toString(),
    content: (json['content'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    tags: (json['tags'] is List)
        ? (json['tags'] as List).map((e) => e.toString()).toList()
        : const <String>[],
  );

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

  const KnowledgeSearchHit({
    required this.doc,
    required this.snippet,
    required this.score,
  });
}

class McpServerConfig {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  final String? bearerToken;

  const McpServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.bearerToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'enabled': enabled,
    if (bearerToken != null && bearerToken!.isNotEmpty) 'bearerToken': bearerToken,
  };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) => McpServerConfig(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? 'MCP').toString(),
    url: (json['url'] ?? '').toString(),
    enabled: json['enabled'] as bool? ?? true,
    bearerToken: json['bearerToken']?.toString(),
  );
}
