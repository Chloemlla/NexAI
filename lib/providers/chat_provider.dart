import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/message.dart';

class ChatProvider extends ChangeNotifier {
  final List<Conversation> _conversations = [];
  int _currentIndex = -1;
  bool _isLoading = false;

  // Reuse Dio instance for connection pooling
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 30),
  ));

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
    if (_isLoading && index == _currentIndex) return;

    _conversations.removeAt(index);
    if (_conversations.isEmpty) {
      _currentIndex = -1;
    } else if (_currentIndex == index) {
      _currentIndex = index.clamp(0, _conversations.length - 1);
    } else if (_currentIndex > index) {
      _currentIndex--;
    }
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
    if (_isLoading) return;

    if (currentConversation == null) {
      newConversation();
    }

    final conversation = currentConversation!;

    final userMessage = Message(role: 'user', content: content, timestamp: DateTime.now());
    conversation.messages.add(userMessage);

    if (conversation.messages.where((m) => m.role == 'user').length == 1) {
      conversation.title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
    }

    await _performApiCall(
      conversation: conversation,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  /// Resend a message (for failed messages)
  Future<void> resendMessage({
    required int messageIndex,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
  }) async {
    if (_isLoading) return;
    final conversation = currentConversation;
    if (conversation == null || messageIndex < 0 || messageIndex >= conversation.messages.length) {
      return;
    }

    final message = conversation.messages[messageIndex];
    if (message.role != 'user') return;

    // Remove all messages after this one (including the error response)
    conversation.messages.removeRange(messageIndex + 1, conversation.messages.length);
    notifyListeners();

    await _performApiCall(
      conversation: conversation,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  /// Edit and resend a message
  Future<void> editAndResendMessage({
    required int messageIndex,
    required String newContent,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
  }) async {
    if (_isLoading) return;
    final conversation = currentConversation;
    if (conversation == null || messageIndex < 0 || messageIndex >= conversation.messages.length) {
      return;
    }

    final message = conversation.messages[messageIndex];
    if (message.role != 'user') return;

    // Update the message content
    message.updateContent(newContent);

    // Remove all messages after this one
    conversation.messages.removeRange(messageIndex + 1, conversation.messages.length);
    notifyListeners();

    await _performApiCall(
      conversation: conversation,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  /// Core API call logic (extracted for reuse)
  Future<void> _performApiCall({
    required Conversation conversation,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final messagesPayload = <Map<String, String>>[];
      if (systemPrompt.isNotEmpty) {
        messagesPayload.add({'role': 'system', 'content': systemPrompt});
      }
      for (final msg in conversation.messages) {
        if (msg.isError) continue;
        messagesPayload.add({'role': msg.role, 'content': msg.content});
      }

      // Use Dio streaming SSE request
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/chat/completions',
        data: {
          'model': model,
          'messages': messagesPayload,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200) {
        // Add an empty assistant message that we'll append to
        final assistantMessage = Message(
          role: 'assistant',
          content: '',
          timestamp: DateTime.now(),
        );
        conversation.messages.add(assistantMessage);
        notifyListeners();

        final buffer = StringBuffer();
        String lineBuf = '';

        await for (final chunk in response.data!.stream.cast<List<int>>().transform(utf8.decoder)) {
          lineBuf += chunk;
          final lines = lineBuf.split('\n');
          // Keep the last potentially incomplete line in the buffer
          lineBuf = lines.removeLast();

          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
            final data = trimmed.substring(6);
            if (data == '[DONE]') break;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final delta = json['choices']?[0]?['delta'];
              if (delta != null && delta['content'] != null) {
                buffer.write(delta['content'] as String);
                assistantMessage.updateContent(buffer.toString());
                notifyListeners();
              }
            } catch (_) {
              // Skip malformed SSE chunks
            }
          }
        }

        // If streaming produced no content, mark as error
        if (assistantMessage.content.isEmpty) {
          assistantMessage.updateContent('⚠️ Error: Empty response from API');
          assistantMessage.markAsError();
        }
      } else {
        // Non-200: handle error
        String errorMsg = 'HTTP ${response.statusCode}';
        conversation.messages.add(
          Message(
            role: 'assistant',
            content: '⚠️ Error: $errorMsg',
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      }
    } on DioException catch (e) {
      String errorMsg;
      if (e.response != null) {
        try {
          final errorData = e.response!.data;
          if (errorData is Map) {
            errorMsg = errorData['error']?['message'] ?? 'HTTP ${e.response!.statusCode}';
          } else {
            errorMsg = 'HTTP ${e.response!.statusCode}';
          }
        } catch (_) {
          errorMsg = 'HTTP ${e.response!.statusCode}';
        }
      } else {
        errorMsg = e.message ?? 'Connection error';
      }
      conversation.messages.add(
        Message(
          role: 'assistant',
          content: '⚠️ Error: $errorMsg',
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    } catch (e) {
      conversation.messages.add(
        Message(
          role: 'assistant',
          content: '⚠️ Connection error: $e',
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
