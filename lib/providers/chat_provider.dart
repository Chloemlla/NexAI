import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/message.dart';
import '../models/search_result.dart';

/// Generates a random UUID v4 without external dependencies.
String _newId() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
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

  // ─── Persistence ───

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nexai_chats.json');
  }

  Future<void> loadConversations() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        if (jsonStr.isNotEmpty) {
          _conversations.clear();
          _conversations.addAll(Conversation.decodeList(jsonStr));
          if (_conversations.isNotEmpty) _currentIndex = 0;
        }
      }
    } catch (e) {
      debugPrint('NexAI: error loading conversations: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      await file.writeAsString(Conversation.encodeList(_conversations));
    } catch (e) {
      debugPrint('NexAI: error saving conversations: $e');
    }
  }

  // ─── Conversation management ───

  List<SearchResult> searchMessages(String query) {
    if (query.isEmpty) return [];
    final results = <SearchResult>[];
    final q = query.toLowerCase();

    for (int i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];
      for (int j = 0; j < conv.messages.length; j++) {
        final msg = conv.messages[j];
        if (msg.content.toLowerCase().contains(q)) {
          results.add(SearchResult(
            conversationIndex: i,
            conversation: conv,
            message: msg,
            messageIndex: j,
          ));
        }
      }
    }
    results.sort((a, b) {
      final aIdx = a.message.content.toLowerCase().indexOf(q);
      final bIdx = b.message.content.toLowerCase().indexOf(q);
      return aIdx.compareTo(bIdx);
    });
    return results;
  }

  void newConversation() {
    _conversations.insert(0, Conversation(
      id: _newId(),
      title: 'New Chat',
      messages: [],
      createdAt: DateTime.now(),
    ));
    _currentIndex = 0;
    notifyListeners();
    _save();
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
    _save();
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

    message.updateContent(newContent);
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
        final assistantMessage = Message(
          role: 'assistant',
          content: '',
          timestamp: DateTime.now(),
        );
        conversation.messages.add(assistantMessage);
        notifyListeners();

        final buffer = StringBuffer();
        String lineBuf = '';
        bool done = false;

        await for (final chunk in response.data!.stream.cast<List<int>>().transform(utf8.decoder)) {
          if (done) break;
          lineBuf += chunk;
          final lines = lineBuf.split('\n');
          lineBuf = lines.removeLast();

          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
            final data = trimmed.substring(6);
            if (data == '[DONE]') {
              done = true;
              break;
            }

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

        if (assistantMessage.content.isEmpty) {
          assistantMessage.updateContent('⚠️ Error: Empty response from API');
          assistantMessage.markAsError();
        }
      } else {
        conversation.messages.add(
          Message(
            role: 'assistant',
            content: '⚠️ Error: HTTP ${response.statusCode}',
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
    _save();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
