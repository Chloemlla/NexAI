import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart' show isAndroid;
import '../providers/artifacts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/image_generation_provider.dart';
import '../providers/notes_provider.dart';
import '../models/chat_knowledge.dart';
import '../services/chat_speech_service.dart';
import '../providers/knowledge_provider.dart';
import '../providers/settings_provider.dart';
import '../services/chat_tool_catalog.dart';
import '../services/chat_tool_executor.dart';
import '../models/chat_tool.dart';
import '../utils/file_access_helper.dart';
import '../models/chat_assistant.dart';
import '../models/message.dart';
import '../utils/navigation_helper.dart';
import '../widgets/message_bubble.dart';
import '../widgets/rich_content_view.dart';
import '../widgets/welcome_view.dart';
import 'image_generation_page.dart';
import '../theme/lumen_tokens.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatAttachment> _pendingAttachments = [];
  final _rng = Random.secure();
  final _speechService = ChatSpeechService();
  bool _isListening = false;
  String _partialSpeech = '';

  List<({Message message, int originalIndex})> _visibleEntries(List<Message> messages) {
    final entries = <({Message message, int originalIndex})>[];
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.role == 'tool') continue;
      entries.add((message: msg, originalIndex: i));
    }
    return entries;
  }

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final Map<String, String> _draftsByConversationId = {};
  bool _hasText = false;
  bool _isAtBottom = true;
  bool _forceScroll = false;
  bool _showComposerPreview = false;
  String? _activeConversationId;
  int _observedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final isAtBottom = pos.pixels >= pos.maxScrollExtent - 100;
    if (isAtBottom != _isAtBottom) {
      setState(() => _isAtBottom = isAtBottom);
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    _saveDraftForConversation(_activeConversationId, text);
    setState(() {
      _hasText = text.trim().isNotEmpty;
      if (!_hasText) {
        _showComposerPreview = false;
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveDraftForConversation(String? conversationId, String text) {
    if (conversationId == null) return;
    if (text.isEmpty) {
      _draftsByConversationId.remove(conversationId);
      return;
    }
    _draftsByConversationId[conversationId] = text;
  }

  void _replaceComposerText(String text, {bool collapsePreview = false}) {
    _controller.removeListener(_onTextChanged);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _controller.addListener(_onTextChanged);
    _hasText = text.trim().isNotEmpty;
    if (!_hasText || collapsePreview) {
      _showComposerPreview = false;
    }
  }

  void _restoreDraftForConversation(String? conversationId) {
    final restoredText = conversationId == null
        ? ''
        : (_draftsByConversationId[conversationId] ?? '');
    if (_controller.text == restoredText) {
      _hasText = restoredText.trim().isNotEmpty;
      if (!_hasText) {
        _showComposerPreview = false;
      }
      return;
    }
    _replaceComposerText(restoredText, collapsePreview: true);
  }

  void _maybeScrollToFocus(ChatProvider chat) {
    final focus = chat.focusMessageIndex;
    if (focus == null) return;
    final visible = _visibleEntries(chat.messages);
    final target = visible.indexWhere((e) => e.originalIndex == focus);
    if (target < 0) {
      chat.clearFocusMessage();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Approximate jump: use item extent estimate.
      final offset = (target * 140.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(offset);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) chat.clearFocusMessage();
      });
    });
  }

  void _syncVisibleConversation(ChatProvider chat) {
    final conversationId = chat.currentConversation?.id;
    final messageCount = chat.messages.length;
    final previousConversationId = _activeConversationId;
    final conversationChanged = conversationId != previousConversationId;
    final messageCountChanged = messageCount != _observedMessageCount;

    if (conversationChanged) {
      _saveDraftForConversation(previousConversationId, _controller.text);
    }

    _activeConversationId = conversationId;
    _observedMessageCount = messageCount;

    if (conversationChanged) {
      _restoreDraftForConversation(conversationId);
      _isAtBottom = true;
      if (messageCount > 0) {
        _scrollToBottom(animate: false, ignoreScrollPosition: true);
      }
      return;
    }

    if (messageCountChanged || chat.isLoading || _forceScroll) {
      _scrollToBottom(animate: _forceScroll);
    }
  }

  void _scrollToBottom({
    bool animate = true,
    bool ignoreScrollPosition = false,
  }) {
    final settings = context.read<SettingsProvider>();
    if (!settings.smartAutoScroll && !_forceScroll && !ignoreScrollPosition) {
      return;
    }

    // If not at bottom and not forced, don't scroll
    if (!_isAtBottom && !_forceScroll && !ignoreScrollPosition) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        try {
          final target = _scrollController.position.maxScrollExtent;
          final distance = (target - _scrollController.position.pixels).abs();

          if (distance < 1) {
            _forceScroll = false;
            return;
          }

          if (animate && distance > 32) {
            _scrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          } else {
            _scrollController.jumpTo(target);
          }

          _forceScroll = false;
        } catch (_) {}
      }
    });
  }

  void _jumpToLatestMessage() {
    _forceScroll = true;
    _scrollToBottom(ignoreScrollPosition: true);
  }

  void _configureChatTools(ChatProvider chat, SettingsProvider settings) {
    final toolsEnabled = settings.chatToolsEnabled && settings.apiMode == 'OpenAI';
    var tools = toolsEnabled
        ? ChatToolCatalog.enabledFromFlags(
            webSearchEnabled: settings.toolWebSearchEnabled,
            notesEnabled: settings.toolNotesEnabled,
            imageEnabled: settings.toolImageEnabled,
            artifactsEnabled: settings.toolArtifactsEnabled,
            fetchUrlEnabled: settings.toolFetchUrlEnabled,
            createNoteEnabled: settings.toolCreateNoteEnabled,
            knowledgeEnabled: settings.toolKnowledgeEnabled,
          )
        : <ChatToolDefinition>[];

    // Remote MCP tools are loaded async; use last known empty here and refresh opportunistically.
    // Full discovery is triggered by settings page / manual refresh.
    if (toolsEnabled && settings.remoteMcpEnabled) {
      // placeholder: MCP tools attached by settings refresh into ChatProvider.enabledTools externally if needed
    }

    final notes = context.read<NotesProvider>();
    final images = context.read<ImageGenerationProvider>();
    final artifacts = context.read<ArtifactsProvider>();
    final knowledge = context.read<KnowledgeProvider>();
    final auth = context.read<AuthProvider>();

    // Keep any already-loaded MCP tools from chat.enabledTools
    final existingMcp = chat.enabledTools
        .where((t) => ChatToolCatalog.isMcpTool(t.name))
        .toList();
    if (existingMcp.isNotEmpty) {
      tools = [...tools, ...existingMcp];
    }

    chat.configureTools(
      tools: tools,
      runtimeContext: tools.isEmpty
          ? null
          : ChatToolRuntimeContext(
              notesProvider: notes,
              imageGenerationProvider: images,
              artifactsProvider: artifacts,
              knowledgeProvider: knowledge,
              mcpServers: settings.remoteMcpEnabled
                  ? settings.mcpServers.where((s) => s.enabled).toList()
                  : const <McpServerConfig>[],
              baseUrl: settings.baseUrl,
              apiKey: settings.apiKey,
              selectedModel: settings.selectedModel,
              accessToken: auth.accessToken,
              imageModel: settings.imageToolModel.isEmpty
                  ? settings.selectedModel
                  : settings.imageToolModel,
            ),
      onApprove: _approveToolCall,
      maxRounds: settings.maxToolRounds,
    );
  }

  Future<bool> _approveToolCall(ToolApprovalRequest request) async {
    if (!mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('工具调用确认', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(request.name, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(request.summary),
                const SizedBox(height: 12),
                Text(
                  request.arguments.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('拒绝'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('允许'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final settings = context.read<SettingsProvider>();
    if (!settings.isConfigured) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('请在设置中配置您的 API 密钥。')),
            ],
          ),
          action: SnackBarAction(
            label: '去设置',
            onPressed: NavigationHelper.goToSettings,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    final attachments = List<ChatAttachment>.from(_pendingAttachments);
    _controller.clear();
    _saveDraftForConversation(_activeConversationId, '');
    setState(() {
      _pendingAttachments.clear();
      _showComposerPreview = false;
    });
    final chat = context.read<ChatProvider>();
    _configureChatTools(chat, settings);

    _forceScroll = true;

    try {
      await chat.sendMessage(
        content: text,
        apiMode: settings.apiMode,
        baseUrl: settings.baseUrl,
        apiKey: settings.apiKey,
        model: settings.selectedModel,
        temperature: settings.temperature,
        maxTokens: settings.maxTokens,
        systemPrompt: settings.systemPrompt,
        vertexProjectId: settings.vertexProjectId,
        vertexLocation: settings.vertexLocation,
        attachments: attachments,
      );
    } catch (e) {
      // Error is already handled inside ChatProvider
    }

    if (!mounted) return;
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  Future<void> _openImageGenerationPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImageGenerationPage()));
  }

  void _clearComposer() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  String _newAttachmentId() {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }


  Future<void> _toggleSpeechInput() async {
    if (_isListening) {
      await _speechService.stopListening();
      setState(() {
        _isListening = false;
        if (_partialSpeech.trim().isNotEmpty) {
          final merged = _controller.text.isEmpty
              ? _partialSpeech.trim()
              : '${_controller.text} ${_partialSpeech.trim()}';
          _replaceComposerText(merged);
        }
        _partialSpeech = '';
      });
      return;
    }
    try {
      setState(() {
        _isListening = true;
        _partialSpeech = '';
      });
      await _speechService.startListening(
        onResult: (text, isFinal) {
          if (!mounted) return;
          setState(() {
            _partialSpeech = text;
            if (isFinal) {
              final merged = _controller.text.isEmpty
                  ? text.trim()
                  : '${_controller.text} ${text.trim()}';
              _replaceComposerText(merged);
              _partialSpeech = '';
              _isListening = false;
            }
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('语音输入失败：$e')),
      );
    }
  }

  Future<void> _importKnowledgeDoc() async {
    final knowledge = context.read<KnowledgeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final path = await FileAccessHelper.pickFile(
      allowedExtensions: const ['txt', 'md', 'markdown', 'json', 'csv', 'log'],
    );
    if (path == null) return;
    try {
      final doc = await knowledge.importFile(path);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(doc == null ? '导入失败' : '已导入知识文档：${doc.title}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _exportChatJson() async {
    final chat = context.read<ChatProvider>();
    final raw = chat.exportConversationsJson(currentOnly: true);
    await SharePlus.instance.share(
      ShareParams(text: raw, subject: 'NexAI chat export'),
    );
  }

  // Kept for future chat backup UX entrypoint.
  // ignore: unused_element
  Future<void> _importChatJson() async {
    final chat = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final path = await FileAccessHelper.pickFile(allowedExtensions: const ['json']);
    if (path == null) return;
    try {
      final raw = await File(path).readAsString();
      final count = await chat.importConversationsJson(raw);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已导入/合并 $count 条会话数据')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _editCompareModels(SettingsProvider settings) async {
    final chat = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (chat.currentConversation == null) {
      await chat.newConversation();
    }
    if (!mounted) return;
    final selected = <String>{
      ...?chat.currentConversation?.compareModels,
    };
    final models = settings.models;
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('多模型对比'),
                    subtitle: Text(
                      '选择 2–${ChatProvider.maxCompareModels} 个模型；下一条消息将依次生成对比回答',
                    ),
                  ),
                  ...models.map((model) {
                    final checked = selected.contains(model);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(model),
                      onChanged: (v) {
                        setModal(() {
                          if (v == true) {
                            if (selected.length >= ChatProvider.maxCompareModels &&
                                !selected.contains(model)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '最多选择 ${ChatProvider.maxCompareModels} 个模型',
                                  ),
                                ),
                              );
                              return;
                            }
                            selected.add(model);
                          } else {
                            selected.remove(model);
                          }
                        });
                      },
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null) return;
    if (result.length == 1) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('请至少选择 2 个模型，或清空以关闭对比')),
      );
    }
    await chat.setCompareModels(result.toList());
    if (!mounted) return;
    setState(() {});
  }


  bool _shouldShowChatToolsOnboarding(SettingsProvider settings) {
    if (!settings.loaded) return false;
    if (settings.chatToolsOnboardingDismissed) return false;
    // Only guide OpenAI-compatible tool path.
    if (settings.apiMode != 'OpenAI') return false;
    // Keep soft: hide once user already enabled tools.
    if (settings.chatToolsEnabled) return false;
    return true;
  }

  Widget _buildChatToolsOnboardingBanner(
    ColorScheme cs,
    SettingsProvider settings,
  ) {
    return Material(
      color: cs.primaryContainer.withAlpha(140),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '试试对话工具（灰度）',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '可先启用推荐组合：笔记检索/创建。联网、MCP、多模型仍默认关闭。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: cs.onPrimaryContainer.withAlpha(220),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () async {
                          await settings.enableRecommendedChatTools();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已启用推荐工具：笔记检索/创建'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text('一键启用推荐工具'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () async {
                          await settings.dismissChatToolsOnboarding();
                          if (!mounted) return;
                          NavigationHelper.goToSettings();
                        },
                        child: const Text('去设置'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '关闭引导',
              visualDensity: VisualDensity.compact,
              onPressed: () => settings.dismissChatToolsOnboarding(),
              icon: Icon(Icons.close_rounded, size: 18, color: cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickChatImage() async {
    final path = await FileAccessHelper.pickImage();
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    final name = path.split(RegExp(r'[\\/]')).last;
    setState(() {
      _pendingAttachments.add(
        ChatAttachment(
          id: _newAttachmentId(),
          type: 'image',
          name: name,
          path: path,
          mimeType: name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : (name.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/jpeg'),
          sizeBytes: file.lengthSync(),
        ),
      );
    });
  }

  void _removePendingAttachment(String id) {
    setState(() {
      _pendingAttachments.removeWhere((item) => item.id == id);
    });
  }

  Future<void> _showAssistantPicker(SettingsProvider settings) async {
    final chat = context.read<ChatProvider>();
    final current = chat.currentConversation;
    final selectedId = current?.assistantId ?? ChatAssistantCatalog.generalId;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('选择助手人设')),
              ...ChatAssistantCatalog.presets.map((assistant) {
                return ListTile(
                  leading: Icon(
                    selectedId == assistant.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text('${assistant.emoji} ${assistant.name}'),
                  subtitle: Text(assistant.description),
                  selected: selectedId == assistant.id,
                  onTap: () => Navigator.pop(ctx, assistant.id),
                );
              }),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    if (chat.currentConversation == null) {
      await chat.newConversation();
    }
    await chat.updateConversationSettings(assistantId: selected);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showPromptTemplates() async {
    final selected = await showModalBottomSheet<PromptTemplate>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('插入提示模板')),
              ...PromptTemplateCatalog.all.map((template) {
                return ListTile(
                  title: Text(template.title),
                  subtitle: Text(template.description ?? ''),
                  onTap: () => Navigator.pop(ctx, template),
                );
              }),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    final expanded = PromptTemplateCatalog.expand(selected, _controller.text);
    _replaceComposerText(expanded);
    setState(() {});
  }

  Widget _buildPendingAttachments(ColorScheme cs) {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _pendingAttachments[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                child: Image.file(
                  File(item.path),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  onTap: () => _removePendingAttachment(item.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14, color: cs.onError),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFollowUpQueueBar(ColorScheme cs, ChatProvider chat) {
    if (chat.followUpQueueLength == 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
      ),
      child: Row(
        children: [
          Icon(Icons.queue_rounded, size: 16, color: cs.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已排队 ${chat.followUpQueueLength} 条后续消息',
              style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
            ),
          ),
          TextButton(
            onPressed: chat.clearFollowUpQueue,
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }


  int _lineCount(String text) {
    if (text.isEmpty) return 0;
    return '\n'.allMatches(text).length + 1;
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildAndroid(context);
    return _buildDesktop(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildAndroid(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final messages = chat.messages;
    final visibleEntries = _visibleEntries(messages);
    final mq = MediaQuery.of(context);
    final keyboardVisible = mq.viewInsets.bottom > 0;
    // Responsive horizontal padding: wider on tablets
    final screenWidth = mq.size.width;
    // Keep composer/message gutters on the Lumen page shell scale.
    final contentHorizontalPad =
        LumenTokens.horizontalPaddingForWidth(screenWidth);

    _syncVisibleConversation(chat);
    _maybeScrollToFocus(chat);

    return Column(
      children: [
        if (_shouldShowChatToolsOnboarding(settings))
          _buildChatToolsOnboardingBanner(cs, settings),
        // Quick settings bar (only show when not configured or when there are messages)
        if (!settings.isConfigured || messages.isNotEmpty)
          _buildQuickSettingsBar(cs, settings),

        // ── Message list ──
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: visibleEntries.isEmpty
                    ? const WelcomeView()
                    : GestureDetector(
                        onTap: () => _focusNode.unfocus(),
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: false,
                          child: ListView.builder(
                            controller: _scrollController,
                            // Parent Scaffold resizes for IME; dismiss on drag.
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              contentHorizontalPad,
                              10,
                              contentHorizontalPad,
                              10,
                            ),
                            itemCount:
                                visibleEntries.length + (chat.isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == visibleEntries.length && chat.isLoading) {
                                return _buildThinkingIndicator(cs, chat);
                              }
                              return RepaintBoundary(
                                key: ValueKey(
                                  'msg_${visibleEntries[index].message.timestamp.millisecondsSinceEpoch}_$index',
                                ),
                                child: MessageBubble(
                                  message: visibleEntries[index].message,
                                  messageIndex: visibleEntries[index].originalIndex,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
              if (messages.isNotEmpty && !_isAtBottom)
                Positioned(
                  right: contentHorizontalPad,
                  bottom: 16,
                  child: _buildScrollToBottomButton(cs),
                ),
            ],
          ),
        ),

        if (_hasText) _buildComposerActionBar(cs),
        if (_showComposerPreview && _hasText) _buildPreviewBubble(cs),
        _buildFollowUpQueueBar(cs, chat),
        if (_pendingAttachments.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(contentHorizontalPad, 0, contentHorizontalPad, 8),
            child: _buildPendingAttachments(cs),
          ),
        if (_isListening && _partialSpeech.trim().isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(contentHorizontalPad, 0, contentHorizontalPad, 6),
            child: Text(
              '识别中：$_partialSpeech',
              style: TextStyle(fontSize: 12, color: cs.primary),
            ),
          ),

        // ── Input bar ──
        // AnimatedPadding so the bar slides up smoothly with the keyboard
        Material(
          color: cs.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          child: SafeArea(
            top: false,
            // When keyboard is visible, SafeArea bottom is not needed
            // because the system already insets for us
            bottom: !keyboardVisible,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                contentHorizontalPad,
                8,
                contentHorizontalPad,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: IconButton(
                      icon: Icon(Icons.attach_file_rounded, color: cs.primary, size: 22),
                      onPressed: _pickChatImage,
                      tooltip: '添加图片附件',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: IconButton(
                      icon: Icon(Icons.smart_toy_outlined, color: cs.primary, size: 22),
                      onPressed: () => _showAssistantPicker(settings),
                      tooltip: '选择助手',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: IconButton(
                      icon: Icon(Icons.auto_awesome_outlined, color: cs.primary, size: 22),
                      onPressed: _showPromptTemplates,
                      tooltip: '提示模板',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color: _isListening ? cs.error : cs.primary,
                        size: 22,
                      ),
                      onPressed: _toggleSpeechInput,
                      tooltip: _isListening ? '停止语音输入' : '语音输入',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: IconButton(
                      icon: Icon(Icons.menu_book_outlined, color: cs.primary, size: 22),
                      onPressed: _importKnowledgeDoc,
                      tooltip: '导入知识文档',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: IconButton(
                      icon: Icon(Icons.hub_outlined, color: cs.primary, size: 22),
                      onPressed: () => _editCompareModels(settings),
                      tooltip: '多模型对比',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: IconButton(
                      icon: Icon(Icons.ios_share_outlined, color: cs.primary, size: 22),
                      onPressed: _exportChatJson,
                      tooltip: '导出会话 JSON',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 8),
                    child: IconButton(
                      icon: Icon(Icons.image_outlined, color: cs.primary, size: 22),
                      onPressed: () => _openImageGenerationPage(context),
                      tooltip: '打开绘图页面',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  // Text field
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // Cap max height so it doesn't eat the whole screen
                        maxHeight: mq.size.height * 0.25,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null, // grows freely up to constraint
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: '问我任何问题...',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withAlpha(140),
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withAlpha(200),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LumenTokens.radiusXl,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LumenTokens.radiusXl,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LumenTokens.radiusXl,
                            ),
                            borderSide: BorderSide(
                              color: cs.primary.withAlpha(100),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button with animated state
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _buildSendButton(cs, chat.isLoading),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBubble(
    ColorScheme cs, {
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(14, 0, 14, 8),
    double maxHeightFactor = 0.2,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: LumenTokens.cardBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 12, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '预览',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
            ),
            child: SingleChildScrollView(
              child: RichContentView(content: _controller.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerActionBar(
    ColorScheme cs, {
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(14, 0, 14, 8),
  }) {
    final text = _controller.text;
    final charCount = text.length;
    final lineCount = _lineCount(text);

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: LumenTokens.cardBorderRadius,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildComposerStatPill(
            cs,
            icon: Icons.text_fields_rounded,
            label: '$charCount 字',
          ),
          _buildComposerStatPill(
            cs,
            icon: Icons.subject_rounded,
            label: '$lineCount 行',
          ),
          TextButton.icon(
            onPressed: () =>
                setState(() => _showComposerPreview = !_showComposerPreview),
            icon: Icon(
              _showComposerPreview
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 18,
            ),
            label: Text(_showComposerPreview ? '收起预览' : '打开预览'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: cs.primary,
            ),
          ),
          TextButton.icon(
            onPressed: _clearComposer,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('清空'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerStatPill(
    ColorScheme cs, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(200),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton(ColorScheme cs) {
    return FloatingActionButton.small(
      heroTag: 'chat_scroll_to_bottom',
      onPressed: _jumpToLatestMessage,
      backgroundColor: cs.surfaceContainerLow,
      foregroundColor: cs.primary,
      elevation: 0,
      highlightElevation: 0,
      tooltip: '跳到最新消息',
      child: const Icon(Icons.keyboard_arrow_down_rounded),
    );
  }

  Widget _buildDesktopStatusPill(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSettingsBar(ColorScheme cs, SettingsProvider settings) {
    if (!settings.isConfigured) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cs.errorContainer.withAlpha(180),
          border: Border(
            bottom: BorderSide(color: cs.error.withAlpha(60), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: cs.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'API 密钥未配置',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to settings page
                NavigationHelper.goToSettings();
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('配置'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(120),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withAlpha(60), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                final chat = context.watch<ChatProvider>();
                final assistant = ChatAssistantCatalog.byId(
                  chat.currentConversation?.assistantId,
                );
                final model = chat.resolveModel(settings.selectedModel);
                return Text(
                  '${assistant.emoji} ${assistant.name} · $model',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
              border: Border.all(color: cs.primary.withAlpha(60), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thermostat_rounded, size: 12, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  settings.temperature.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
              border: Border.all(color: cs.secondary.withAlpha(60), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.token_rounded, size: 12, color: cs.secondary),
                const SizedBox(width: 4),
                Text(
                  settings.maxTokens >= 1000
                      ? '${(settings.maxTokens / 1000).toStringAsFixed(1)}k'
                      : '${settings.maxTokens}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: NavigationHelper.goToSettings,
            tooltip: '聊天设置',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.tune_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ColorScheme cs, bool isLoading) {
    final canSend = (_hasText || _pendingAttachments.isNotEmpty) && !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: isLoading
            ? cs.error
            : (canSend ? cs.primary : cs.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: isLoading
              ? () => context.read<ChatProvider>().cancelGeneration()
              : (canSend ? _send : null),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? Icon(
                      Icons.stop_rounded,
                      key: const ValueKey('stop'),
                      size: 22,
                      color: cs.onError,
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      key: const ValueKey('send'),
                      size: 22,
                      color: canSend
                          ? cs.onPrimary
                          : cs.onSurfaceVariant.withAlpha(100),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator(ColorScheme cs, ChatProvider chat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/app_icon_runtime.png', width: 30, height: 30),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThinkingDots(color: cs.primary),
                  const SizedBox(width: 12),
                  Text(
                    chat.activeToolName == null
                        ? '思考中...'
                        : '工具执行中：${chat.activeToolName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Desktop: Material Design ───
  Widget _buildDesktop(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final messages = chat.messages;
    final visibleEntries = _visibleEntries(messages);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    _syncVisibleConversation(chat);
    _maybeScrollToFocus(chat);

    return Column(
      children: [
        if (_shouldShowChatToolsOnboarding(settings))
          _buildChatToolsOnboardingBanner(cs, settings),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: visibleEntries.isEmpty
                    ? const WelcomeView()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        addAutomaticKeepAlives: true,
                        itemCount: visibleEntries.length + (chat.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == visibleEntries.length && chat.isLoading) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const SizedBox(width: 48),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    chat.activeToolName == null
                                      ? '思考中...'
                                      : '工具执行中：${chat.activeToolName}',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return RepaintBoundary(
                            key: ValueKey(
                              'msg_${visibleEntries[index].message.timestamp.millisecondsSinceEpoch}_$index',
                            ),
                            child: MessageBubble(
                              message: visibleEntries[index].message,
                              messageIndex: visibleEntries[index].originalIndex,
                            ),
                          );
                        },
                      ),
              ),
              if (messages.isNotEmpty && !_isAtBottom)
                Positioned(
                  right: 24,
                  bottom: 16,
                  child: _buildScrollToBottomButton(cs),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withAlpha(80)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasText) ...[
                _buildComposerActionBar(cs, margin: EdgeInsets.zero),
                if (_showComposerPreview) ...[
                  _buildPreviewBubble(
                    cs,
                    margin: EdgeInsets.zero,
                    maxHeightFactor: 0.18,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: _buildDesktopStatusPill(
                            cs,
                            icon: Icons.smart_toy_outlined,
                            label: settings.selectedModel,
                            backgroundColor: cs.primaryContainer.withAlpha(140),
                            foregroundColor: cs.primary,
                          ),
                        ),
                        _buildDesktopStatusPill(
                          cs,
                          icon: Icons.hub_outlined,
                          label: settings.apiMode,
                          backgroundColor: cs.secondaryContainer.withAlpha(160),
                          foregroundColor: cs.secondary,
                        ),
                        _buildDesktopStatusPill(
                          cs,
                          icon: Icons.thermostat_rounded,
                          label: settings.temperature.toStringAsFixed(1),
                          backgroundColor: cs.tertiaryContainer.withAlpha(160),
                          foregroundColor: cs.tertiary,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: NavigationHelper.goToSettings,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('聊天设置'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 10),
                    child: IconButton(
                      icon: Icon(
                        Icons.image_outlined,
                        color: cs.primary,
                        size: 22,
                      ),
                      onPressed: () => _openImageGenerationPage(context),
                      tooltip: '打开绘图页面',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): _send,
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          meta: true,
                        ): _send,
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: '输入您的消息...',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withAlpha(200),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: cs.outlineVariant.withAlpha(80),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: cs.primary.withAlpha(100),
                              width: 1.5,
                            ),
                          ),
                        ),
                        maxLines: 8,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: chat.isLoading
                        ? () => chat.cancelGeneration()
                        : ((!_hasText && _pendingAttachments.isEmpty) ? null : _send),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      chat.isLoading ? Icons.stop_rounded : Icons.send_rounded,
                      size: 18,
                    ),
                    label: Text(chat.isLoading ? '停止' : '发送'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ctrl / Command + Enter 发送',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Animated thinking dots ───
class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 0.2
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            // Bounce: 0→1→0 over the cycle
            final scale = t < 0.5 ? (t * 2) : (2 - t * 2);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -3 * scale),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha((120 + 135 * scale).round()),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
