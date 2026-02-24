class Message {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isError;

  Message({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isError = false,
  });
}

class Conversation {
  String title;
  final List<Message> messages;
  final DateTime createdAt;

  Conversation({
    required this.title,
    required this.messages,
    required this.createdAt,
  });
}
