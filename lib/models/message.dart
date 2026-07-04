import 'dart:convert';

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

class Message {
  final String role;
  String _content;
  final DateTime timestamp;
  bool _isError;

  Message({
    required this.role,
    required String content,
    required this.timestamp,
    bool isError = false,
  }) : _content = content,
       _isError = isError;

  String get content => _content;
  bool get isError => _isError;

  void updateContent(String newContent) {
    _content = newContent;
  }

  void markAsError() {
    _isError = true;
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': _content,
    'timestamp': timestamp.toIso8601String(),
    'isError': _isError,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    role: _stringValue(json, 'role'),
    content: _stringValue(json, 'content'),
    timestamp: _dateTimeValue(json, 'timestamp'),
    isError: json['isError'] as bool? ?? false,
  );
}

class Conversation {
  final String id;
  String title;
  final List<Message> messages;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String? ?? _stringValue(json, 'createdAt'),
    title: _stringValue(json, 'title'),
    messages: _messageList(
      json['messages'],
    ).map((m) => Message.fromJson(asStringMap(m, 'message'))).toList(),
    createdAt: _dateTimeValue(json, 'createdAt'),
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
