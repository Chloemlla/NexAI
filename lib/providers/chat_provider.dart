import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_assistant.dart';
import '../models/chat_tool.dart';
import '../models/message.dart';
import '../models/search_result.dart';
import '../services/chat_tool_catalog.dart';
import '../services/chat_tool_executor.dart';
import '../utils/atomic_file_writer.dart';
import '../utils/certificate_error_helper.dart';
import '../utils/network_safety.dart';

typedef ToolApprovalHandler = Future<bool> Function(ToolApprovalRequest request);

String _newId() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ChatProvider extends ChangeNotifier {
  static const int sessionSchemaVersion = 2;

  final List<Conversation> _conversations = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  String? _activeToolName;
  CancelToken? _cancelToken;
  int _runSerial = 0;
  final List<_QueuedChatTurn> _followUpQueue = [];
  int? _focusMessageIndex;
  String? _focusQuery;
  int _siblingGroupSeq = 1;

  ToolApprovalHandler? approvalHandler;
  ChatToolRuntimeContext? toolRuntimeContext;
  List<ChatToolDefinition> enabledTools = const [];
  int maxToolRounds = 6;

  final ChatToolExecutor _toolExecutor = ChatToolExecutor();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  List<Conversation> get conversations => _conversations;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String? get activeToolName => _activeToolName;
  List<String> get followUpQueue =>
      _followUpQueue.map((item) => item.content).toList(growable: false);
  int get followUpQueueLength => _followUpQueue.length;
  int? get focusMessageIndex => _focusMessageIndex;
  String? get focusQuery => _focusQuery;
  Conversation? get currentConversation =>
      _currentIndex >= 0 && _currentIndex < _conversations.length
      ? _conversations[_currentIndex]
      : null;
  List<Message> get messages => currentConversation?.messages ?? [];

  void configureTools({
    required List<ChatToolDefinition> tools,
    required ChatToolRuntimeContext? runtimeContext,
    ToolApprovalHandler? onApprove,
    int? maxRounds,
  }) {
    enabledTools = List<ChatToolDefinition>.unmodifiable(tools);
    toolRuntimeContext = runtimeContext;
    approvalHandler = onApprove;
    if (maxRounds != null && maxRounds > 0) maxToolRounds = maxRounds;
  }

  void cancelGeneration() {
    final token = _cancelToken;
    if (token != null && !token.isCancelled) token.cancel('user_cancelled');
  }


  List<Message> siblingsOf(int messageIndex) {
    final conversation = currentConversation;
    if (conversation == null) return const [];
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) {
      return const [];
    }
    final target = conversation.messages[messageIndex];
    final group = target.siblingGroupId;
    if (group == null) return [target];
    return conversation.messages
        .where((m) => m.siblingGroupId == group)
        .toList(growable: false);
  }

  Future<void> activateSibling({
    required int messageIndex,
    required int siblingAbsoluteIndex,
  }) async {
    final conversation = currentConversation;
    if (conversation == null) return;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final group = conversation.messages[messageIndex].siblingGroupId;
    if (group == null) return;
    for (var i = 0; i < conversation.messages.length; i++) {
      final m = conversation.messages[i];
      if (m.siblingGroupId != group) continue;
      // recreate with flipped active flag via content copy since fields final-ish
      conversation.messages[i] = Message(
        role: m.role,
        content: m.content,
        timestamp: m.timestamp,
        isError: m.isError,
        toolCallId: m.toolCallId,
        toolCalls: List<ToolCallRecord>.from(m.toolCalls),
        toolRuns: List<ToolRunRecord>.from(m.toolRuns),
        citations: List<Citation>.from(m.citations),
        attachments: List<ChatAttachment>.from(m.attachments),
        reasoning: m.reasoning,
        stats: m.stats,
        modelId: m.modelId,
        siblingGroupId: m.siblingGroupId,
        isActiveBranch: i == siblingAbsoluteIndex,
        isPinned: m.isPinned,
      );
    }
    notifyListeners();
    await _save();
  }

  Future<void> pinMessage(int messageIndex, {bool pinned = true}) async {
    final conversation = currentConversation;
    if (conversation == null) return;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final m = conversation.messages[messageIndex];
    if (m.isPinned == pinned) return;
    m.isPinned = pinned;
    // Drop any legacy pin-as-citation markers from older builds.
    m.citations.removeWhere((c) => c.source == 'pin');
    notifyListeners();
    await _save();
  }

  Future<void> quoteToComposer(int messageIndex) async {
    // UI reads content via getter; no-op state broadcast for listeners
    setFocusMessage(messageIndex: messageIndex, query: 'quote');
  }

  String exportSessionPackage({bool currentOnly = true}) {
    final payload = {
      'schemaVersion': sessionSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'conversations': currentOnly
          ? (currentConversation == null ? [] : [currentConversation!.toJson()])
          : _conversations.map((c) => c.toJson()).toList(),
    };
    return jsonEncode(payload);
  }

  Future<int> importSessionPackage(String raw, {bool merge = true}) async {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return importConversationsJson(raw, merge: merge);
    }
    if (decoded is Map) {
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      final list = map['conversations'];
      if (list is List) {
        if (!merge) {
          await restoreFromList(list);
          return list.length;
        }
        await mergeItems(list);
        return list.length;
      }
    }
    throw const FormatException('Unsupported session package');
  }

  void removeFollowUpAt(int index) {
    if (index < 0 || index >= _followUpQueue.length) return;
    _followUpQueue.removeAt(index);
    notifyListeners();
  }

  void editFollowUpAt(int index, String content) {
    if (index < 0 || index >= _followUpQueue.length) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      removeFollowUpAt(index);
      return;
    }
    final prev = _followUpQueue[index];
    _followUpQueue[index] = _QueuedChatTurn(
      content: trimmed,
      attachments: prev.attachments,
      apiMode: prev.apiMode,
      baseUrl: prev.baseUrl,
      apiKey: prev.apiKey,
      model: prev.model,
      temperature: prev.temperature,
      maxTokens: prev.maxTokens,
      systemPrompt: prev.systemPrompt,
      vertexProjectId: prev.vertexProjectId,
      vertexLocation: prev.vertexLocation,
    );
    notifyListeners();
  }

  Future<void> branchFromMessage(int messageIndex) async {
    final conversation = currentConversation;
    if (conversation == null) return;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final cloned = Conversation(
      id: _newId(),
      title: '${conversation.title} (branch)',
      createdAt: DateTime.now(),
      messages: conversation.messages
          .take(messageIndex + 1)
          .map(
            (m) => Message(
              role: m.role,
              content: m.content,
              timestamp: m.timestamp,
              isError: m.isError,
              toolCallId: m.toolCallId,
              toolCalls: List<ToolCallRecord>.from(m.toolCalls),
              toolRuns: List<ToolRunRecord>.from(m.toolRuns),
              citations: List<Citation>.from(m.citations),
              attachments: List<ChatAttachment>.from(m.attachments),
              reasoning: m.reasoning,
              stats: m.stats,
              modelId: m.modelId,
              siblingGroupId: m.siblingGroupId,
              isActiveBranch: true,
              isPinned: m.isPinned,
            ),
          )
          .toList(),
      assistantId: conversation.assistantId,
      modelOverride: conversation.modelOverride,
      systemPromptOverride: conversation.systemPromptOverride,
      compareModels: List<String>.from(conversation.compareModels),
    );
    _conversations.insert(0, cloned);
    _currentIndex = 0;
    notifyListeners();
    await _save();
  }

  void clearFollowUpQueue() {
    if (_followUpQueue.isEmpty) return;
    _followUpQueue.clear();
    notifyListeners();
  }

  void setFocusMessage({required int messageIndex, String? query}) {
    _focusMessageIndex = messageIndex;
    _focusQuery = query;
    notifyListeners();
  }

  void clearFocusMessage() {
    if (_focusMessageIndex == null && _focusQuery == null) return;
    _focusMessageIndex = null;
    _focusQuery = null;
    notifyListeners();
  }

  static const int maxCompareModels = 3;

  Future<void> setCompareModels(List<String> models) async {
    final conversation = currentConversation;
    if (conversation == null) return;
    final unique = models
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    // Hard product cap to control cost/latency.
    conversation.compareModels = unique.take(maxCompareModels).toList();
    notifyListeners();
    await _save();
  }

  String exportConversationsJson({bool currentOnly = false}) {
    if (currentOnly) {
      final c = currentConversation;
      if (c == null) return '[]';
      return jsonEncode([c.toJson()]);
    }
    return Conversation.encodeList(_conversations);
  }

  Future<int> importConversationsJson(String raw, {bool merge = true}) async {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Expected conversations JSON array');
    }
    if (!merge) {
      await restoreFromList(decoded);
      return decoded.length;
    }
    await mergeItems(decoded);
    return decoded.length;
  }

  Future<void> updateConversationSettings({
    String? assistantId,
    String? modelOverride,
    String? systemPromptOverride,
    bool clearModelOverride = false,
    bool clearSystemPromptOverride = false,
  }) async {
    final conversation = currentConversation;
    if (conversation == null) return;
    if (assistantId != null && assistantId.isNotEmpty) {
      conversation.assistantId = assistantId;
    }
    if (clearModelOverride) {
      conversation.modelOverride = null;
    } else if (modelOverride != null) {
      conversation.modelOverride =
          modelOverride.trim().isEmpty ? null : modelOverride.trim();
    }
    if (clearSystemPromptOverride) {
      conversation.systemPromptOverride = null;
    } else if (systemPromptOverride != null) {
      conversation.systemPromptOverride = systemPromptOverride.trim().isEmpty
          ? null
          : systemPromptOverride.trim();
    }
    notifyListeners();
    await _save();
  }

  String resolveSystemPrompt(String fallback) {
    final conversation = currentConversation;
    final override = conversation?.systemPromptOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    final assistant = ChatAssistantCatalog.byId(conversation?.assistantId);
    if (assistant.systemPrompt.trim().isNotEmpty) return assistant.systemPrompt;
    return fallback;
  }

  String resolveModel(String fallback) {
    final conversation = currentConversation;
    final override = conversation?.modelOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    final preferred = ChatAssistantCatalog.byId(conversation?.assistantId)
        .preferredModel
        ?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    return fallback;
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower == 'authorization' ||
        lower == 'proxy-authorization' ||
        lower == 'key' ||
        lower.contains('apikey') ||
        lower.contains('api_key') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret');
  }

  static String _redactString(String value) {
    var redacted = value.replaceAll(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      'Bearer <redacted>',
    );
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'([?&](?:key|api_key|apikey|access_token|token|password|secret)=)[^&\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}<redacted>',
    );
    redacted = redacted.replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{12,}'), 'sk-<redacted>');
    redacted = redacted.replaceAll(RegExp(r'AIza[0-9A-Za-z_-]{20,}'), 'AIza<redacted>');
    return redacted;
  }

  static dynamic _redactSensitive(dynamic value) {
    if (value is Map) {
      return value.map((key, mapValue) {
        final keyString = key.toString();
        return MapEntry(
          keyString,
          _isSensitiveKey(keyString) ? '<redacted>' : _redactSensitive(mapValue),
        );
      });
    }
    if (value is Iterable) return value.map(_redactSensitive).toList();
    if (value is String) return _redactString(value);
    return value;
  }

  static String _encodeDiagnostic(dynamic data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(_redactSensitive(data));
    } catch (_) {
      return _redactString(data.toString());
    }
  }

  static String _redactedUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return _redactString(uri.toString());
    final queryParameters = uri.queryParameters.map((key, value) {
      return MapEntry(key, _isSensitiveKey(key) ? '<redacted>' : _redactString(value));
    });
    return uri.replace(queryParameters: queryParameters).toString();
  }

  static String _buildRequestDiagnostics(RequestOptions options) {
    final details = {
      'url': _redactedUri(options.uri),
      'method': options.method,
      'headers': _redactSensitive(options.headers),
    };
    return '**Request Summary:**\n```json\n${_encodeDiagnostic(details)}\n```';
  }

  static String _buildResponseDiagnostics(dynamic data) {
    if (data == null) return '';
    return '\n\n**Response Data:**\n```json\n${_encodeDiagnostic(data)}\n```';
  }

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
      await writeTextAtomically(file, Conversation.encodeList(_conversations));
    } catch (e) {
      debugPrint('NexAI: error saving conversations: $e');
    }
  }

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

  Future<void> newConversation() async {
    _conversations.insert(
      0,
      Conversation(id: _newId(), title: '新对话', messages: [], createdAt: DateTime.now()),
    );
    _currentIndex = 0;
    notifyListeners();
    await _save();
  }

  void selectConversation(int index) {
    if (index < 0 || index >= _conversations.length) return;
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> deleteConversation(int index) async {
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
    await _save();
  }

  Future<void> sendMessage({
    required String content,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
    List<ChatAttachment> attachments = const [],
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;

    if (currentConversation == null) await newConversation();
    final conversation = currentConversation!;

    final turn = _QueuedChatTurn(
      content: trimmed,
      attachments: List<ChatAttachment>.from(attachments),
      apiMode: apiMode,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: resolveModel(model),
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: resolveSystemPrompt(systemPrompt),
      vertexProjectId: vertexProjectId,
      vertexLocation: vertexLocation,
    );

    if (_isLoading) {
      _followUpQueue.add(turn);
      notifyListeners();
      return;
    }

    await _runQueuedTurn(conversation: conversation, turn: turn);
  }

  Future<void> resendMessage({
    required int messageIndex,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
  }) async {
    if (_isLoading) return;
    final conversation = currentConversation;
    if (conversation == null || messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final message = conversation.messages[messageIndex];
    if (message.role != 'user') return;
    conversation.messages.removeRange(messageIndex + 1, conversation.messages.length);
    notifyListeners();
    await _performApiCall(
      conversation: conversation,
      apiMode: apiMode,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: resolveModel(model),
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: resolveSystemPrompt(systemPrompt),
      vertexProjectId: vertexProjectId,
      vertexLocation: vertexLocation,
    );
  }

  Future<void> regenerateLastAssistant({
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
    int? assistantMessageIndex,
  }) async {
    if (_isLoading) return;
    final conversation = currentConversation;
    if (conversation == null || conversation.messages.isEmpty) return;

    // Prefer regenerating from the user turn that owns [assistantMessageIndex].
    var userIndex = -1;
    if (assistantMessageIndex != null &&
        assistantMessageIndex >= 0 &&
        assistantMessageIndex < conversation.messages.length) {
      for (var i = assistantMessageIndex; i >= 0; i--) {
        if (conversation.messages[i].role == 'user') {
          userIndex = i;
          break;
        }
      }
    }
    if (userIndex < 0) {
      for (var i = conversation.messages.length - 1; i >= 0; i--) {
        if (conversation.messages[i].role == 'user') {
          userIndex = i;
          break;
        }
      }
    }
    if (userIndex < 0) return;
    // Keep history including user; strip trailing assistants/tools after it.
    conversation.messages.removeRange(userIndex + 1, conversation.messages.length);
    notifyListeners();
    await _performApiCall(
      conversation: conversation,
      apiMode: apiMode,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: resolveModel(model),
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: resolveSystemPrompt(systemPrompt),
      vertexProjectId: vertexProjectId,
      vertexLocation: vertexLocation,
    );
  }

  Future<void> editAndResendMessage({
    required int messageIndex,
    required String newContent,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
  }) async {
    if (_isLoading) return;
    final conversation = currentConversation;
    if (conversation == null || messageIndex < 0 || messageIndex >= conversation.messages.length) return;
    final message = conversation.messages[messageIndex];
    if (message.role != 'user') return;
    message.updateContent(newContent);
    conversation.messages.removeRange(messageIndex + 1, conversation.messages.length);
    notifyListeners();
    await _performApiCall(
      conversation: conversation,
      apiMode: apiMode,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: resolveModel(model),
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: resolveSystemPrompt(systemPrompt),
      vertexProjectId: vertexProjectId,
      vertexLocation: vertexLocation,
    );
  }

  Future<void> _performApiCall({
    required Conversation conversation,
    required String apiMode,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required String vertexProjectId,
    required String vertexLocation,
  }) async {
    final runId = ++_runSerial;
    _isLoading = true;
    _activeToolName = null;
    _cancelToken = CancelToken();
    notifyListeners();
    try {
      if (apiMode == 'Vertex') {
        await _performVertexCall(
          conversation, apiKey, model, temperature, maxTokens, systemPrompt, vertexProjectId, vertexLocation,
        );
      } else {
        await _performOpenAiToolLoop(
          conversation: conversation,
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || e.type == DioExceptionType.cancel) {
        conversation.messages.add(Message(role: 'assistant', content: '已停止生成。', timestamp: DateTime.now()));
      } else {
        final isHandshakeError = CertificateErrorHelper.isHandshakeCertificateError(e);
        if (isHandshakeError) {
          unawaited(CertificateErrorHelper.maybePromptToClearCertificateCache(e));
        }
        String errorMsg;
        String requestDetails = '';
        if (e.response != null) {
          try {
            final errorData = e.response!.data;
            if (errorData is Map) {
              final message = errorData['error']?['message']?.toString();
              errorMsg = message != null && message.isNotEmpty ? _redactString(message) : 'HTTP ${e.response!.statusCode}';
            } else {
              errorMsg = 'HTTP ${e.response!.statusCode}';
            }
          } catch (_) {
            errorMsg = 'HTTP ${e.response!.statusCode}';
          }
          requestDetails = '\n${_buildRequestDiagnostics(e.requestOptions)}${_buildResponseDiagnostics(e.response!.data)}';
        } else {
          errorMsg = _redactString(e.message ?? '连接失败');
          requestDetails = '\n${_buildRequestDiagnostics(e.requestOptions)}';
        }
        conversation.messages.add(Message(
          role: 'assistant',
          content: '请求失败：$errorMsg${isHandshakeError ? '\n\n${CertificateErrorHelper.handshakeUserMessage()}' : ''}$requestDetails',
          timestamp: DateTime.now(),
          isError: true,
        ));
      }
    } catch (e) {
      conversation.messages.add(Message(
        role: 'assistant',
        content: '连接失败：${_redactString(e.toString())}',
        timestamp: DateTime.now(),
        isError: true,
      ));
    }
    if (runId == _runSerial) {
      _isLoading = false;
      _activeToolName = null;
      _cancelToken = null;
      notifyListeners();
      await _save();
      await _drainFollowUpQueue(conversation);
    }
  }

  Future<void> _runQueuedTurn({
    required Conversation conversation,
    required _QueuedChatTurn turn,
  }) async {
    conversation.messages.add(
      Message(
        role: 'user',
        content: turn.content,
        timestamp: DateTime.now(),
        attachments: turn.attachments,
      ),
    );
    if (conversation.messages.where((m) => m.role == 'user').length == 1) {
      final titleSource = turn.content.isNotEmpty
          ? turn.content
          : (turn.attachments.isNotEmpty ? turn.attachments.first.name : '新对话');
      conversation.title = titleSource.length > 30
          ? '${titleSource.substring(0, 30)}...'
          : titleSource;
    }

    final compare = conversation.compareModels
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList()
        .take(maxCompareModels)
        .toList();
    if (turn.apiMode == 'OpenAI' && compare.length >= 2) {
      await _performMultiModelCompare(
        conversation: conversation,
        turn: turn,
        models: compare,
      );
      return;
    }

    await _performApiCall(
      conversation: conversation,
      apiMode: turn.apiMode,
      baseUrl: turn.baseUrl,
      apiKey: turn.apiKey,
      model: turn.model,
      temperature: turn.temperature,
      maxTokens: turn.maxTokens,
      systemPrompt: turn.systemPrompt,
      vertexProjectId: turn.vertexProjectId,
      vertexLocation: turn.vertexLocation,
    );
  }

  Future<void> _performMultiModelCompare({
    required Conversation conversation,
    required _QueuedChatTurn turn,
    required List<String> models,
  }) async {
    final runId = ++_runSerial;
    _isLoading = true;
    _activeToolName = null;
    _cancelToken = CancelToken();
    notifyListeners();
    final groupId = _siblingGroupSeq++;
    try {
      // Sequential compare keeps tool approval UX simple and avoids races on shared conversation.
      for (var i = 0; i < models.length; i++) {
        if (_cancelToken?.isCancelled == true) break;
        final model = models[i];
        _activeToolName = 'compare:$model';
        notifyListeners();
        await _performOpenAiToolLoop(
          conversation: conversation,
          baseUrl: turn.baseUrl,
          apiKey: turn.apiKey,
          model: model,
          temperature: turn.temperature,
          maxTokens: turn.maxTokens,
          systemPrompt: turn.systemPrompt,
          modelTag: model,
          siblingGroupId: groupId,
          markActive: i == 0,
        );
      }
    } catch (e) {
      conversation.messages.add(
        Message(
          role: 'assistant',
          content: '多模型对比失败：${e.toString()}',
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    }
    if (runId == _runSerial) {
      _isLoading = false;
      _activeToolName = null;
      _cancelToken = null;
      notifyListeners();
      await _save();
      await _drainFollowUpQueue(conversation);
    }
  }

  Future<void> _drainFollowUpQueue(Conversation conversation) async {
    if (_isLoading || _followUpQueue.isEmpty) return;
    if (currentConversation?.id != conversation.id) {
      // Keep queue for the active conversation only.
      return;
    }
    final next = _followUpQueue.removeAt(0);
    notifyListeners();
    await _runQueuedTurn(conversation: conversation, turn: next);
  }

  Future<void> _performOpenAiToolLoop({
    required Conversation conversation,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    String? modelTag,
    int? siblingGroupId,
    bool markActive = true,
  }) async {
    final tools = enabledTools;
    // Tools are available whenever runtime context is configured.
    // Gateway URL enables richer remote providers; local tools still work without it.
    final useTools = tools.isNotEmpty && toolRuntimeContext != null;

    for (var round = 0; round < maxToolRounds; round++) {
      final token = _cancelToken;
      if (token != null && token.isCancelled) {
        throw DioException(
          requestOptions: RequestOptions(path: baseUrl),
          type: DioExceptionType.cancel,
          error: 'user_cancelled',
        );
      }

      final turn = await _performOpenAiCall(
        conversation: conversation,
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
        systemPrompt: systemPrompt,
        tools: useTools ? tools : const [],
        modelTag: modelTag,
        siblingGroupId: siblingGroupId,
        markActive: markActive,
      );
      if (turn.toolCalls.isEmpty) return;

      if (!useTools) {
        turn.assistantMessage.updateContent(
          turn.assistantMessage.content.isEmpty
              ? '模型请求了工具调用，但当前客户端未启用工具。'
              : turn.assistantMessage.content,
        );
        turn.assistantMessage.markAsError();
        return;
      }

      final executed = await _executeToolCalls(
        conversation: conversation,
        assistantMessage: turn.assistantMessage,
        toolCalls: turn.toolCalls,
      );
      if (!executed) return;
    }

    conversation.messages.add(Message(
      role: 'assistant',
      content: '已达到最大工具调用轮次（$maxToolRounds），已停止继续调用。',
      timestamp: DateTime.now(),
      isError: true,
    ));
  }

  Future<_OpenAiTurnResult> _performOpenAiCall({
    required Conversation conversation,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
    required String systemPrompt,
    required List<ChatToolDefinition> tools,
    String? modelTag,
    int? siblingGroupId,
    bool markActive = true,
  }) async {
    final messagesPayload = <Map<String, dynamic>>[];
    if (systemPrompt.isNotEmpty) {
      messagesPayload.add({'role': 'system', 'content': systemPrompt});
    }
    for (final msg in conversation.messages) {
      if (msg.isError) continue;
      messagesPayload.add(_toOpenAiMessage(msg));
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': messagesPayload,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
    };
    if (tools.isNotEmpty) {
      body['tools'] = tools.map((tool) => tool.toOpenAiTool()).toList();
      body['tool_choice'] = 'auto';
    }

    final response = await _dio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      data: body,
      cancelToken: _cancelToken,
      options: Options(
        headers: {
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          'Accept': 'text/event-stream',
        },
        responseType: ResponseType.stream,
      ),
    );

    if (response.statusCode != 200) {
      final errorMessage = Message(
        role: 'assistant',
        content: '请求失败：HTTP ${response.statusCode}',
        timestamp: DateTime.now(),
        isError: true,
      );
      conversation.messages.add(errorMessage);
      notifyListeners();
      return _OpenAiTurnResult(assistantMessage: errorMessage, toolCalls: const []);
    }

    final startedAt = DateTime.now();
    int? ttftMs;
    final assistantMessage = Message(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      modelId: modelTag ?? model,
      siblingGroupId: siblingGroupId,
      isActiveBranch: markActive,
    );
    conversation.messages.add(assistantMessage);
    notifyListeners();

    final buffer = StringBuffer();
    final toolBuffers = <int, _ToolCallBuffer>{};
    String lineBuf = '';
    var done = false;
    MessageStats? usageStats;

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
          final choices = json['choices'];
          if (choices is! List || choices.isEmpty || choices.first is! Map) continue;
          final choice = (choices.first as Map).map((k, v) => MapEntry(k.toString(), v));
          final delta = choice['delta'];
          if (delta is! Map) continue;
          final deltaMap = delta.map((k, v) => MapEntry(k.toString(), v));
          final content = deltaMap['content'];
          if (content is String && content.isNotEmpty) {
            ttftMs ??= DateTime.now().difference(startedAt).inMilliseconds;
            buffer.write(content);
            assistantMessage.updateContent(buffer.toString());
            notifyListeners();
          }

          final reasoningDelta = deltaMap['reasoning_content'] ??
              deltaMap['reasoning'] ??
              (deltaMap['delta'] is Map ? (deltaMap['delta'] as Map)['reasoning'] : null);
          if (reasoningDelta is String && reasoningDelta.isNotEmpty) {
            assistantMessage.appendReasoning(reasoningDelta);
            notifyListeners();
          }

          final usage = json['usage'];
          if (usage is Map) {
            usageStats = MessageStats.fromJson(
              usage.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
          final toolCalls = deltaMap['tool_calls'];
          if (toolCalls is List) {
            for (final item in toolCalls) {
              if (item is! Map) continue;
              final map = item.map((k, v) => MapEntry(k.toString(), v));
              final index = map['index'] is int
                  ? map['index'] as int
                  : int.tryParse(map['index']?.toString() ?? '') ?? 0;
              final bucket = toolBuffers.putIfAbsent(index, _ToolCallBuffer.new);
              if (map['id'] != null) bucket.id = map['id'].toString();
              final function = map['function'];
              if (function is Map) {
                final fn = function.map((k, v) => MapEntry(k.toString(), v));
                if (fn['name'] != null) bucket.name = fn['name'].toString();
                if (fn['arguments'] != null) bucket.arguments.write(fn['arguments'].toString());
              }
            }
          }
        } catch (_) {}
      }
    }

    final toolCalls = <ToolCallRecord>[];
    final sortedKeys = toolBuffers.keys.toList()..sort();
    for (final key in sortedKeys) {
      final bucket = toolBuffers[key]!;
      if (bucket.name.trim().isEmpty) continue;
      toolCalls.add(ToolCallRecord(
        id: bucket.id.isEmpty ? 'call_${_newId()}' : bucket.id,
        name: bucket.name,
        argumentsJson: bucket.arguments.toString().isEmpty ? '{}' : bucket.arguments.toString(),
      ));
    }

    final completionMs = DateTime.now().difference(startedAt).inMilliseconds;
    assistantMessage.stats = (usageStats ?? const MessageStats()).merge(
      MessageStats(
        timeToFirstTokenMs: ttftMs,
        completionMs: completionMs,
      ),
    );

    if (toolCalls.isNotEmpty) {
      assistantMessage.toolCalls
        ..clear()
        ..addAll(toolCalls);
      for (final call in toolCalls) {
        assistantMessage.upsertToolRun(ToolRunRecord(
          callId: call.id,
          name: call.name,
          argumentsJson: call.argumentsJson,
          status: ChatToolRunStatus.pending,
          updatedAt: DateTime.now(),
        ));
      }
      if (assistantMessage.content.trim().isEmpty) {
        assistantMessage.updateContent('正在调用工具…');
      }
      notifyListeners();
    } else if (assistantMessage.content.isEmpty) {
      assistantMessage.updateContent('接口返回为空');
      assistantMessage.markAsError();
      notifyListeners();
    }

    return _OpenAiTurnResult(assistantMessage: assistantMessage, toolCalls: toolCalls);
  }

  Future<bool> _executeToolCalls({
    required Conversation conversation,
    required Message assistantMessage,
    required List<ToolCallRecord> toolCalls,
  }) async {
    final runtime = toolRuntimeContext;
    if (runtime == null) return false;

    for (final call in toolCalls) {
      final token = _cancelToken;
      if (token != null && token.isCancelled) return false;

      final definition = ChatToolCatalog.byName(call.name);
      final args = call.decodeArguments();
      final summary = _toolSummary(call.name, args);

      assistantMessage.upsertToolRun(ToolRunRecord(
        callId: call.id,
        name: call.name,
        argumentsJson: call.argumentsJson,
        status: ChatToolRunStatus.pending,
        resultPreview: summary,
        updatedAt: DateTime.now(),
      ));
      _activeToolName = call.name;
      notifyListeners();

      var approved = true;
      final needsPrompt = definition?.approval == ChatToolApprovalPolicy.prompt || definition == null;
      if (needsPrompt) {
        final handler = approvalHandler;
        approved = handler == null
            ? false
            : await handler(ToolApprovalRequest(
                callId: call.id,
                name: call.name,
                arguments: args,
                summary: summary,
              ));
      }

      if (!approved) {
        final deniedContent = '{"error":"denied_by_user","tool":"${call.name}","message":"User denied this tool call."}';
        assistantMessage.upsertToolRun(ToolRunRecord(
          callId: call.id,
          name: call.name,
          argumentsJson: call.argumentsJson,
          status: ChatToolRunStatus.denied,
          resultPreview: '用户拒绝执行',
          updatedAt: DateTime.now(),
        ));
        conversation.messages.add(Message(
          role: 'tool',
          content: deniedContent,
          timestamp: DateTime.now(),
          toolCallId: call.id,
        ));
        notifyListeners();
        continue;
      }

      assistantMessage.upsertToolRun(ToolRunRecord(
        callId: call.id,
        name: call.name,
        argumentsJson: call.argumentsJson,
        status: ChatToolRunStatus.running,
        resultPreview: summary,
        updatedAt: DateTime.now(),
      ));
      notifyListeners();

      final result = await _toolExecutor.execute(
        name: call.name,
        arguments: args,
        context: runtime,
      );

      final preview = result.content.length > 240
          ? '${result.content.substring(0, 240)}...'
          : result.content;
      assistantMessage.upsertToolRun(ToolRunRecord(
        callId: call.id,
        name: call.name,
        argumentsJson: call.argumentsJson,
        status: result.isError ? ChatToolRunStatus.error : ChatToolRunStatus.success,
        resultPreview: preview,
        citations: result.citations,
        updatedAt: DateTime.now(),
      ));
      if (result.citations.isNotEmpty) {
        assistantMessage.addCitations(result.citations);
      }
      conversation.messages.add(Message(
        role: 'tool',
        content: NetworkSafety.redactSecrets(result.content),
        timestamp: DateTime.now(),
        toolCallId: call.id,
        citations: result.citations,
        isError: result.isError,
      ));
      notifyListeners();
    }

    _activeToolName = null;
    notifyListeners();
    return true;
  }

  Map<String, dynamic> _toOpenAiMessage(Message msg) {
    if (msg.role == 'tool') {
      return {
        'role': 'tool',
        'tool_call_id': msg.toolCallId ?? '',
        'content': msg.content,
      };
    }
    if (msg.role == 'assistant' && msg.toolCalls.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': msg.content,
        'tool_calls': msg.toolCalls.map((c) => c.toOpenAiToolCall()).toList(),
      };
    }
    if (msg.role == 'user' && msg.hasAttachments) {
      return {
        'role': 'user',
        'content': _messageContentForApi(msg),
      };
    }
    return {'role': msg.role, 'content': msg.content};
  }

  dynamic _messageContentForApi(Message msg) {
    if (!msg.hasAttachments) return msg.content;
    final parts = <Map<String, dynamic>>[];
    final text = msg.content.trim();
    if (text.isNotEmpty) {
      parts.add({'type': 'text', 'text': text});
    } else {
      parts.add({'type': 'text', 'text': '请结合附件回答。'});
    }
    var imageCount = 0;
    for (final attachment in msg.attachments) {
      if (attachment.type != 'image') continue;
      if (imageCount >= NetworkSafety.maxImagesPerMessage) break;
      try {
        final file = File(attachment.path);
        final size = file.lengthSync();
        if (size <= 0 || size > NetworkSafety.maxImageBytes) {
          debugPrint(
            'NexAI: skip attachment ${attachment.path}, size=$size limit=${NetworkSafety.maxImageBytes}',
          );
          continue;
        }
        final bytes = file.readAsBytesSync();
        if (bytes.length > NetworkSafety.maxImageBytes) continue;
        final b64 = base64Encode(bytes);
        final mime = attachment.mimeType ?? _guessImageMime(attachment.name);
        parts.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mime;base64,$b64',
          },
        });
        imageCount += 1;
      } catch (e) {
        debugPrint('NexAI: failed to encode attachment ${attachment.path}: $e');
      }
    }
    return parts;
  }

  String _guessImageMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _toolSummary(String name, Map<String, dynamic> args) {
    switch (name) {
      case ChatToolCatalog.webSearch:
        return '搜索：${args['query'] ?? ''}';
      case ChatToolCatalog.notesSearch:
        return '笔记搜索：${args['query'] ?? ''}';
      case ChatToolCatalog.notesRead:
        return '读取笔记：${args['title'] ?? args['note_id'] ?? args['noteId'] ?? ''}';
      case ChatToolCatalog.generateImage:
        return '绘图：${args['prompt'] ?? ''}';
      case ChatToolCatalog.reportArtifacts:
        return '发布 Artifact：${args['title'] ?? ''}';
      case ChatToolCatalog.fetchUrl:
        return '抓取：${args['url'] ?? ''}';
      case ChatToolCatalog.createNote:
        return '创建笔记：${args['title'] ?? 'Untitled'}';
      default:
        return '调用 $name';
    }
  }

  Future<void> _performVertexCall(
    Conversation conversation,
    String apiKey,
    String model,
    double temperature,
    int maxTokens,
    String systemPrompt,
    String vertexProjectId,
    String vertexLocation,
  ) async {
    final contentsPayload = <Map<String, dynamic>>[];
    for (final msg in conversation.messages) {
      if (msg.isError || msg.role == 'tool') continue;
      final role = msg.role == 'assistant' ? 'model' : 'user';
      contentsPayload.add({
        'role': role,
        'parts': [
          {'text': msg.content},
        ],
      });
    }

    final payload = <String, dynamic>{
      'contents': contentsPayload,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };
    if (systemPrompt.isNotEmpty) {
      payload['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt},
        ],
      };
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    final String url;
    if (vertexProjectId.isEmpty) {
      url =
          'https://aiplatform.googleapis.com/v1/publishers/google/models/$model:streamGenerateContent?key=$apiKey&alt=sse';
    } else {
      url =
          'https://aiplatform.googleapis.com/v1/projects/$vertexProjectId/locations/$vertexLocation/publishers/google/models/$model:streamGenerateContent?alt=sse';
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _dio.post<ResponseBody>(
      url,
      data: payload,
      cancelToken: _cancelToken,
      options: Options(headers: headers, responseType: ResponseType.stream),
    );

    if (response.statusCode == 200) {
      final assistantMessage = Message(role: 'assistant', content: '', timestamp: DateTime.now());
      conversation.messages.add(assistantMessage);
      notifyListeners();
      final buffer = StringBuffer();
      String lineBuf = '';
      await for (final chunk in response.data!.stream.cast<List<int>>().transform(utf8.decoder)) {
        lineBuf += chunk;
        final lines = lineBuf.split('\n');
        lineBuf = lines.removeLast();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
          final data = trimmed.substring(6);
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final candidates = json['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'] as String?;
                if (text != null) {
                  buffer.write(text);
                  assistantMessage.updateContent(buffer.toString());
                  notifyListeners();
                }
              }
            }
          } catch (_) {}
        }
      }
      if (assistantMessage.content.isEmpty) {
        assistantMessage.updateContent('接口返回为空');
        assistantMessage.markAsError();
      }
    } else {
      conversation.messages.add(Message(
        role: 'assistant',
        content: '请求失败：HTTP ${response.statusCode}',
        timestamp: DateTime.now(),
        isError: true,
      ));
    }
  }

  Future<void> restoreFromList(List<dynamic> list) async {
    final restored = list
        .map((e) => Conversation.fromJson(asStringMap(e, 'conversation')))
        .toList();
    _conversations
      ..clear()
      ..addAll(restored);
    _currentIndex = _conversations.isNotEmpty ? 0 : -1;
    notifyListeners();
    await _save();
  }

  Future<void> mergeItems(List<dynamic> list) async {
    for (final item in list) {
      final json = asStringMap(item, 'conversation');
      final incoming = Conversation.fromJson(json);
      final idx = _conversations.indexWhere((c) => c.id == incoming.id);
      if (idx == -1) {
        _conversations.insert(0, incoming);
      } else {
        final existingLast = _conversations[idx].messages.isNotEmpty
            ? _conversations[idx].messages.last.timestamp
            : _conversations[idx].createdAt;
        final incomingLast = incoming.messages.isNotEmpty
            ? incoming.messages.last.timestamp
            : incoming.createdAt;
        if (!incomingLast.isBefore(existingLast)) {
          _conversations[idx] = incoming;
        }
      }
    }
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('disposed');
    _dio.close();
    super.dispose();
  }
}

class _OpenAiTurnResult {
  final Message assistantMessage;
  final List<ToolCallRecord> toolCalls;
  const _OpenAiTurnResult({required this.assistantMessage, required this.toolCalls});
}

class _ToolCallBuffer {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}


class _QueuedChatTurn {
  final String content;
  final List<ChatAttachment> attachments;
  final String apiMode;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;
  final String systemPrompt;
  final String vertexProjectId;
  final String vertexLocation;

  const _QueuedChatTurn({
    required this.content,
    required this.attachments,
    required this.apiMode,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    required this.systemPrompt,
    required this.vertexProjectId,
    required this.vertexLocation,
  });
}
