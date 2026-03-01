import 'message.dart';

class SearchResult {
  final int conversationIndex;
  final Conversation conversation;
  final Message message;
  final int messageIndex;

  SearchResult({
    required this.conversationIndex,
    required this.conversation,
    required this.message,
    required this.messageIndex,
  });
}
