import 'dart:async';
import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/message.dart';

// Isolate-safe JSON decode for large responses
Map<String, dynamic> _decodeJson(String body) => jsonDecode(body) as Map<String, dynamic>;

class ChatProvider extends ChangeNotifier {
  final List<Conversation> _conversations = [];
  int _currentIndex = -1;
  bool _isLoading = false;

  // Reuse HTTP client for connection pooling
  final http.Client _httpClient = http.Client();

  List<Conversation> get conversations => _conversations;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;

  Conversation? get currentConversation =>
      _currentIndex >= 0 && _currentIndex < _conversations.length
          ? _conversations[_currentIndex]
          : null;

  List<Message> get messages => currentConversation?.messages ?? [];

  void newConversation() {
    _conversations.insert(0, Conversation(
      title: 'New Chat',
      messages: [],
      createdAt: DateTime.now(),
    ));
    _currentIndex = 0;
    notifyListeners();
  }

  void selectConversation(int index) {
    if (index < 0 || index >= _conversations.length) return;
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void deleteConversation(int index) {
    if (index < 0 || index >= _conversations.length) return;
    // Don't allow deleting the active conversation while a request is in-flight
    if (_isLoading && index == _currentIndex) return;

    _conversations.removeAt(index);
    if (_conversations.isEmpty) {
      _currentIndex = -1;
    } else if (_currentIndex == index) {
      // Deleted the selected one: select the nearest
      _currentIndex = index.clamp(0, _conversations.length - 1);
    } else if (_currentIndex > index) {
      // Selected was after the deleted one, shift down
      _currentIndex--;
    }
    // else: selected was before deleted, no change needed
    notifyListeners();
  }

  Future<void> sendMessage({
    required String content,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
  }) async {
    // Guard against concurrent sends
    if (_isLoading) return;

    if (currentConversation == null) {
      newConversation();
    }

    // Capture reference so it stays stable across awaits
    final conversation = currentConversation!;

    final userMessage = Message(role: 'user', content: content, timestamp: DateTime.now());
    conversation.messages.add(userMessage);

    if (conversation.messages.where((m) => m.role == 'user').length == 1) {
      conversation.title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Build payload excluding error messages from history
      final messagesPayload = <Map<String, String>>[];
      if (systemPrompt.isNotEmpty) {
        messagesPayload.add({'role': 'system', 'content': systemPrompt});
      }
      for (final msg in conversation.messages) {
        if (msg.isError) continue; // Don't send error messages to the API
        messagesPayload.add({'role': msg.role, 'content': msg.content});
      }

      final response = await _httpClient.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': messagesPayload,
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        // Offload JSON parsing to isolate for large responses
        final data = response.body.length > 10000
            ? await compute(_decodeJson, response.body)
            : jsonDecode(response.body) as Map<String, dynamic>;

        final choices = data['choices'];
        if (choices is List && choices.isNotEmpty) {
          final assistantContent = choices[0]['message']?['content'] as String? ?? '';
          conversation.messages.add(
            Message(role: 'assistant', content: assistantContent, timestamp: DateTime.now()),
          );
        } else {
          conversation.messages.add(
            Message(role: 'assistant', content: '⚠️ Error: Unexpected response format', timestamp: DateTime.now(), isError: true),
          );
        }
      } else {
        String errorMsg;
        try {
          final errorBody = jsonDecode(response.body);
          errorMsg = errorBody['error']?['message'] ?? 'Unknown error (${response.statusCode})';
        } catch (_) {
          errorMsg = 'HTTP ${response.statusCode}';
        }
        conversation.messages.add(
          Message(role: 'assistant', content: '⚠️ Error: $errorMsg', timestamp: DateTime.now(), isError: true),
        );
      }
    } catch (e) {
      conversation.messages.add(
        Message(role: 'assistant', content: '⚠️ Connection error: $e', timestamp: DateTime.now(), isError: true),
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}
