import 'dart:convert';

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
  })  : _content = content,
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
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
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
        id: json['id'] as String? ?? json['createdAt'] as String,
        title: json['title'] as String,
        messages: (json['messages'] as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static String encodeList(List<Conversation> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  static List<Conversation> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
