import 'dart:convert';

import 'chat_tool.dart';

Map<String, dynamic> asStringMap(Object? value, String label) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  throw FormatException('Expected $label to be a JSON object');
}

String _stringValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string');
}

DateTime _dateTimeValue(Map<String, dynamic> json, String key) {
  final raw = _stringValue(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed != null) return parsed;
  throw FormatException('Expected "$key" to be an ISO-8601 timestamp');
}

class MessageStats {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int? thoughtsTokens;
  final int? timeToFirstTokenMs;
  final int? completionMs;
  final double? estimatedCost;

  const MessageStats({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.thoughtsTokens,
    this.timeToFirstTokenMs,
    this.completionMs,
    this.estimatedCost,
  });

  MessageStats merge(MessageStats other) => MessageStats(
    promptTokens: other.promptTokens ?? promptTokens,
    completionTokens: other.completionTokens ?? completionTokens,
    totalTokens: other.totalTokens ?? totalTokens,
    thoughtsTokens: other.thoughtsTokens ?? thoughtsTokens,
    timeToFirstTokenMs: other.timeToFirstTokenMs ?? timeToFirstTokenMs,
    completionMs: other.completionMs ?? completionMs,
    estimatedCost: other.estimatedCost ?? estimatedCost,
  );

  Map<String, dynamic> toJson() => {
    if (promptTokens != null) 'promptTokens': promptTokens,
    if (completionTokens != null) 'completionTokens': completionTokens,
    if (totalTokens != null) 'totalTokens': totalTokens,
    if (thoughtsTokens != null) 'thoughtsTokens': thoughtsTokens,
    if (timeToFirstTokenMs != null) 'timeToFirstTokenMs': timeToFirstTokenMs,
    if (completionMs != null) 'completionMs': completionMs,
    if (estimatedCost != null) 'estimatedCost': estimatedCost,
  };

  factory MessageStats.fromJson(Map<String, dynamic> json) => MessageStats(
    promptTokens: _statsAsInt(json['promptTokens'] ?? json['prompt_tokens']),
    completionTokens: _statsAsInt(
      json['completionTokens'] ?? json['completion_tokens'],
    ),
    totalTokens: _statsAsInt(json['totalTokens'] ?? json['total_tokens']),
    thoughtsTokens: _statsAsInt(
      json['thoughtsTokens'] ??
          json['reasoning_tokens'] ??
          json['thoughts_tokens'],
    ),
    timeToFirstTokenMs: _statsAsInt(json['timeToFirstTokenMs']),
    completionMs: _statsAsInt(json['completionMs']),
    estimatedCost: _statsAsDouble(json['estimatedCost']),
  );
}

int? _statsAsInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

double? _statsAsDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

class ChatAttachment {
  final String id;
  final String type; // image | file
  final String name;
  final String path;
  final String? mimeType;
  final int? sizeBytes;

  const ChatAttachment({
    required this.id,
    required this.type,
    required this.name,
    required this.path,
    this.mimeType,
    this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'path': path,
    if (mimeType != null) 'mimeType': mimeType,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    id: (json['id'] ?? '').toString(),
    type: (json['type'] ?? 'file').toString(),
    name: (json['name'] ?? '').toString(),
    path: (json['path'] ?? '').toString(),
    mimeType: json['mimeType']?.toString(),
    sizeBytes: json['sizeBytes'] is int
        ? json['sizeBytes'] as int
        : int.tryParse(json['sizeBytes']?.toString() ?? ''),
  );
}

class Message {
  final String role;
  String _content;
  String _reasoning;
  final DateTime timestamp;
  bool _isError;
  final String? toolCallId;
  final List<ToolCallRecord> toolCalls;
  final List<ToolRunRecord> toolRuns;
  final List<Citation> citations;
  final List<ChatAttachment> attachments;
  MessageStats? stats;
  final String? modelId;
  final int? siblingGroupId;
  final bool isActiveBranch;
  bool isPinned;

  Message({
    required this.role,
    required String content,
    required this.timestamp,
    bool isError = false,
    this.toolCallId,
    List<ToolCallRecord>? toolCalls,
    List<ToolRunRecord>? toolRuns,
    List<Citation>? citations,
    List<ChatAttachment>? attachments,
    String reasoning = '',
    this.stats,
    this.modelId,
    this.siblingGroupId,
    this.isActiveBranch = true,
    this.isPinned = false,
  }) : _content = content,
       _reasoning = reasoning,
       _isError = isError,
       toolCalls = toolCalls ?? <ToolCallRecord>[],
       toolRuns = toolRuns ?? <ToolRunRecord>[],
       citations = citations ?? <Citation>[],
       attachments = attachments ?? <ChatAttachment>[];

  String get content => _content;
  String get reasoning => _reasoning;
  bool get isError => _isError;
  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get isToolResult => role == 'tool';
  bool get hasAttachments => attachments.isNotEmpty;

  void updateContent(String newContent) {
    _content = newContent;
  }

  void updateReasoning(String value) {
    _reasoning = value;
  }

  void appendReasoning(String delta) {
    if (delta.isEmpty) return;
    _reasoning = '$_reasoning$delta';
  }

  void markAsError() {
    _isError = true;
  }

  void upsertToolRun(ToolRunRecord run) {
    final idx = toolRuns.indexWhere((item) => item.callId == run.callId);
    if (idx == -1) {
      toolRuns.add(run);
    } else {
      toolRuns[idx] = run;
    }
  }

  void addCitations(Iterable<Citation> items) {
    for (final item in items) {
      final exists = citations.any(
        (c) => c.url == item.url && c.title == item.title,
      );
      if (!exists) citations.add(item);
    }
  }

  List<Map<String, dynamic>> toParts() {
    final parts = <Map<String, dynamic>>[];
    if (_reasoning.isNotEmpty) {
      parts.add({'type': 'reasoning', 'text': _reasoning});
    }
    for (final a in attachments) {
      parts.add({
        'type': a.type == 'image' ? 'image' : 'file',
        'name': a.name,
        'path': a.path,
        if (a.mimeType != null) 'mimeType': a.mimeType,
      });
    }
    for (final run in toolRuns) {
      parts.add({
        'type': 'tool',
        'callId': run.callId,
        'name': run.name,
        'status': run.status.name,
        'resultPreview': run.resultPreview,
      });
    }
    if (_content.isNotEmpty) {
      parts.add({'type': 'text', 'text': _content});
    }
    for (final c in citations) {
      parts.add({
        'type': 'citation',
        'title': c.title,
        'url': c.url,
        'snippet': c.snippet,
        if (c.source != null) 'source': c.source,
      });
    }
    if (stats != null) {
      parts.add({'type': 'stats', 'data': stats!.toJson()});
    }
    return parts;
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': _content,
    'timestamp': timestamp.toIso8601String(),
    'isError': _isError,
    if (_reasoning.isNotEmpty) 'reasoning': _reasoning,
    if (toolCallId != null) 'toolCallId': toolCallId,
    if (toolCalls.isNotEmpty)
      'toolCalls': toolCalls.map((c) => c.toJson()).toList(),
    if (toolRuns.isNotEmpty)
      'toolRuns': toolRuns.map((r) => r.toJson()).toList(),
    if (citations.isNotEmpty)
      'citations': citations.map((c) => c.toJson()).toList(),
    if (attachments.isNotEmpty)
      'attachments': attachments.map((a) => a.toJson()).toList(),
    'parts': toParts(),
    if (stats != null) 'stats': stats!.toJson(),
    if (modelId != null && modelId!.isNotEmpty) 'modelId': modelId,
    if (siblingGroupId != null) 'siblingGroupId': siblingGroupId,
    'isActiveBranch': isActiveBranch,
    if (isPinned) 'isPinned': true,
  };

  factory Message.fromJson(Map<String, dynamic> json) {
    final toolCallsRaw = json['toolCalls'] ?? json['tool_calls'];
    final toolRunsRaw = json['toolRuns'];
    final citationsRaw = json['citations'];
    final citations = _parseCitations(citationsRaw);
    // Migrate legacy pin-as-citation hack.
    final legacyPinned = citations.any((c) => c.source == 'pin');
    citations.removeWhere((c) => c.source == 'pin');
    return Message(
      role: _stringValue(json, 'role'),
      content: (json['content'] ?? '').toString(),
      timestamp: json.containsKey('timestamp')
          ? _dateTimeValue(json, 'timestamp')
          : DateTime.now(),
      isError: json['isError'] as bool? ?? false,
      toolCallId: (json['toolCallId'] ?? json['tool_call_id'])?.toString(),
      toolCalls: _parseToolCalls(toolCallsRaw),
      toolRuns: _parseToolRuns(toolRunsRaw),
      citations: citations,
      attachments: _parseAttachments(json['attachments']),
      reasoning: (json['reasoning'] ?? '').toString(),
      stats: json['stats'] is Map
          ? MessageStats.fromJson(asStringMap(json['stats'], 'stats'))
          : null,
      modelId: json['modelId']?.toString(),
      siblingGroupId: json['siblingGroupId'] is int
          ? json['siblingGroupId'] as int
          : int.tryParse(json['siblingGroupId']?.toString() ?? ''),
      isActiveBranch: json['isActiveBranch'] as bool? ?? true,
      isPinned: json['isPinned'] as bool? ?? legacyPinned,
    );
  }
}

List<ToolCallRecord> _parseToolCalls(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Object>()
      .map((item) => ToolCallRecord.fromJson(asStringMap(item, 'toolCall')))
      .toList();
}

List<ToolRunRecord> _parseToolRuns(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Object>()
      .map((item) => ToolRunRecord.fromJson(asStringMap(item, 'toolRun')))
      .toList();
}

List<Citation> _parseCitations(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Object>()
      .map((item) => Citation.fromJson(asStringMap(item, 'citation')))
      .toList();
}

List<ChatAttachment> _parseAttachments(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Object>()
      .map((item) => ChatAttachment.fromJson(asStringMap(item, 'attachment')))
      .toList();
}

class Conversation {
  final String id;
  String title;
  final List<Message> messages;
  final DateTime createdAt;
  String assistantId;
  String? modelOverride;
  String? systemPromptOverride;
  List<String> compareModels;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    this.assistantId = 'general',
    this.modelOverride,
    this.systemPromptOverride,
    List<String>? compareModels,
  }) : compareModels = compareModels ?? <String>[];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'assistantId': assistantId,
    if (modelOverride != null && modelOverride!.isNotEmpty)
      'modelOverride': modelOverride,
    if (systemPromptOverride != null && systemPromptOverride!.isNotEmpty)
      'systemPromptOverride': systemPromptOverride,
    if (compareModels.isNotEmpty) 'compareModels': compareModels,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String? ?? _stringValue(json, 'createdAt'),
    title: _stringValue(json, 'title'),
    messages: _messageList(
      json['messages'],
    ).map((m) => Message.fromJson(asStringMap(m, 'message'))).toList(),
    createdAt: _dateTimeValue(json, 'createdAt'),
    assistantId: (json['assistantId'] ?? 'general').toString(),
    modelOverride: json['modelOverride']?.toString(),
    systemPromptOverride: json['systemPromptOverride']?.toString(),
    compareModels: json['compareModels'] is List
        ? (json['compareModels'] as List).map((e) => e.toString()).toList()
        : <String>[],
  );

  static String encodeList(List<Conversation> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  static List<Conversation> decodeList(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) {
      throw const FormatException('Expected conversations JSON array');
    }
    return decoded
        .map((e) => Conversation.fromJson(asStringMap(e, 'conversation')))
        .toList();
  }
}

List<dynamic> _messageList(Object? value) {
  if (value is List) return value;
  throw const FormatException('Expected "messages" to be a JSON array');
}
