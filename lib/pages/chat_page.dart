import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid;
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/navigation_helper.dart';
import '../widgets/message_bubble.dart';
import '../widgets/rich_content_view.dart';
import '../widgets/welcome_view.dart';
import 'image_generation_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

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
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    _controller.clear();
    _saveDraftForConversation(_activeConversationId, '');
    if (_showComposerPreview) {
      setState(() => _showComposerPreview = false);
    }
    final chat = context.read<ChatProvider>();

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
    final mq = MediaQuery.of(context);
    final keyboardVisible = mq.viewInsets.bottom > 0;
    // Responsive horizontal padding: wider on tablets
    final screenWidth = mq.size.width;
    final isWide = screenWidth > 600;
    final horizontalPad = isWide ? screenWidth * 0.1 : 14.0;

    _syncVisibleConversation(chat);

    return Column(
      children: [
        // Quick settings bar (only show when not configured or when there are messages)
        if (!settings.isConfigured || messages.isNotEmpty)
          _buildQuickSettingsBar(cs, settings),

        // ── Message list ──
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: messages.isEmpty
                    ? const WelcomeView()
                    : GestureDetector(
                        onTap: () => _focusNode.unfocus(),
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: false,
                          child: ListView.builder(
                            controller: _scrollController,
                            // Keyboard pushes content up via resizeToAvoidBottomInset
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              horizontalPad,
                              10,
                              horizontalPad,
                              10,
                            ),
                            itemCount:
                                messages.length + (chat.isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == messages.length && chat.isLoading) {
                                return _buildThinkingIndicator(cs);
                              }
                              return RepaintBoundary(
                                key: ValueKey(
                                  'msg_${messages[index].timestamp.millisecondsSinceEpoch}_$index',
                                ),
                                child: MessageBubble(
                                  message: messages[index],
                                  messageIndex: index,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
              if (messages.isNotEmpty && !_isAtBottom)
                Positioned(
                  right: isWide ? horizontalPad : 16,
                  bottom: 16,
                  child: _buildScrollToBottomButton(cs),
                ),
            ],
          ),
        ),

        if (_hasText) _buildComposerActionBar(cs),
        if (_showComposerPreview && _hasText) _buildPreviewBubble(cs),

        // ── Input bar ──
        // AnimatedPadding so the bar slides up smoothly with the keyboard
        Material(
          color: cs.surfaceContainerLow,
          surfaceTintColor: cs.surfaceTint,
          elevation: keyboardVisible ? 2 : 0,
          child: SafeArea(
            top: false,
            // When keyboard is visible, SafeArea bottom is not needed
            // because the system already insets for us
            bottom: !keyboardVisible,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? horizontalPad : 10,
                8,
                isWide ? horizontalPad : 6,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Image generation button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.image_outlined,
                        color: cs.primary,
                        size: 24,
                      ),
                      onPressed: () => _openImageGenerationPage(context),
                      tooltip: '打开绘图页面',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
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
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
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
      backgroundColor: cs.surface,
      foregroundColor: cs.primary,
      elevation: 2,
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
          gradient: LinearGradient(
            colors: [
              cs.errorContainer.withAlpha(200),
              cs.errorContainer.withAlpha(100),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
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
            child: Text(
              settings.selectedModel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
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
    final canSend = _hasText && !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: canSend
            ? LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: canSend ? null : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: canSend ? _send : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onSurfaceVariant,
                        strokeCap: StrokeCap.round,
                      ),
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

  Widget _buildThinkingIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/icon.png', width: 30, height: 30),
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
                    '思考中...',
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    _syncVisibleConversation(chat);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: messages.isEmpty
                    ? const WelcomeView()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        addAutomaticKeepAlives: true,
                        itemCount: messages.length + (chat.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && chat.isLoading) {
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
                                    '思考中...',
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
                              'msg_${messages[index].timestamp.millisecondsSinceEpoch}_$index',
                            ),
                            child: MessageBubble(
                              message: messages[index],
                              messageIndex: index,
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
                    onPressed: chat.isLoading || !_hasText ? null : _send,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: chat.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(chat.isLoading ? '发送中' : '发送'),
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
