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
