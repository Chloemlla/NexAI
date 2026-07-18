/// Chat tool-calling models shared by runtime, persistence, and UI.
library;

import 'dart:convert';

import 'message.dart' show asStringMap;

enum ChatToolApprovalPolicy { auto, prompt }

enum ChatToolRunStatus { pending, running, success, error, cancelled, denied }

class ChatToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final ChatToolApprovalPolicy approval;
  final bool readOnly;

  const ChatToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    this.approval = ChatToolApprovalPolicy.auto,
    this.readOnly = true,
  });

  Map<String, dynamic> toOpenAiTool() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

class ToolCallRecord {
  final String id;
  final String name;
  final String argumentsJson;

  const ToolCallRecord({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arguments': argumentsJson,
  };

  Map<String, dynamic> toOpenAiToolCall() => {
    'id': id,
    'type': 'function',
    'function': {
      'name': name,
      'arguments': argumentsJson,
    },
  };

  factory ToolCallRecord.fromJson(Map<String, dynamic> json) {
    final function = json['function'];
    if (function is Map) {
      final fn = asStringMap(function, 'function');
      return ToolCallRecord(
        id: (json['id'] ?? '').toString(),
        name: (fn['name'] ?? '').toString(),
        argumentsJson: (fn['arguments'] ?? '{}').toString(),
      );
    }
    return ToolCallRecord(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      argumentsJson: (json['arguments'] ?? json['argumentsJson'] ?? '{}')
          .toString(),
    );
  }

  Map<String, dynamic> decodeArguments() {
    try {
      final decoded = jsonDecode(argumentsJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }
}

class Citation {
  final String title;
  final String url;
  final String snippet;
  final String? source;

  const Citation({
    required this.title,
    required this.url,
    this.snippet = '',
    this.source,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'snippet': snippet,
    if (source != null) 'source': source,
  };

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
    title: (json['title'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
    snippet: (json['snippet'] ?? '').toString(),
    source: json['source']?.toString(),
  );
}

class ToolRunRecord {
  final String callId;
  final String name;
  final String argumentsJson;
  final ChatToolRunStatus status;
  final String resultPreview;
  final List<Citation> citations;
  final DateTime updatedAt;

  const ToolRunRecord({
    required this.callId,
    required this.name,
    required this.argumentsJson,
    required this.status,
    this.resultPreview = '',
    this.citations = const [],
    required this.updatedAt,
  });

  ToolRunRecord copyWith({
    ChatToolRunStatus? status,
    String? resultPreview,
    List<Citation>? citations,
    DateTime? updatedAt,
  }) {
    return ToolRunRecord(
      callId: callId,
      name: name,
      argumentsJson: argumentsJson,
      status: status ?? this.status,
      resultPreview: resultPreview ?? this.resultPreview,
      citations: citations ?? this.citations,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'callId': callId,
    'name': name,
    'argumentsJson': argumentsJson,
    'status': status.name,
    'resultPreview': resultPreview,
    'citations': citations.map((c) => c.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ToolRunRecord.fromJson(Map<String, dynamic> json) {
    final statusName = (json['status'] ?? 'success').toString();
    final status = ChatToolRunStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => ChatToolRunStatus.success,
    );
    final citationsRaw = json['citations'];
    final citations = <Citation>[];
    if (citationsRaw is List) {
      for (final item in citationsRaw) {
        if (item is Map) {
          citations.add(Citation.fromJson(asStringMap(item, 'citation')));
        }
      }
    }
    return ToolRunRecord(
      callId: (json['callId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      argumentsJson: (json['argumentsJson'] ?? '{}').toString(),
      status: status,
      resultPreview: (json['resultPreview'] ?? '').toString(),
      citations: citations,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ToolExecutionResult {
  final String content;
  final List<Citation> citations;
  final bool isError;

  const ToolExecutionResult({
    required this.content,
    this.citations = const [],
    this.isError = false,
  });
}

class ToolApprovalRequest {
  final String callId;
  final String name;
  final Map<String, dynamic> arguments;
  final String summary;

  const ToolApprovalRequest({
    required this.callId,
    required this.name,
    required this.arguments,
    required this.summary,
  });
}
