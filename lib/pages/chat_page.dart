import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid;
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/welcome_view.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        try {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } catch (_) {}
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final settings = context.read<SettingsProvider>();
    if (!settings.isConfigured) {
      if (!mounted) return;
      if (isAndroid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Please configure your API key in Settings.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      } else {
        fluent.displayInfoBar(context, builder: (ctx, close) {
          return fluent.InfoBar(
            title: const Text('Please configure your API key in Settings.'),
            severity: fluent.InfoBarSeverity.warning,
            action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close),
          );
        });
      }
      return;
    }

    _controller.clear();
    final chat = context.read<ChatProvider>();

    try {
      await chat.sendMessage(
        content: text,
        baseUrl: settings.baseUrl,
        apiKey: settings.apiKey,
        model: settings.selectedModel,
        temperature: settings.temperature,
        maxTokens: settings.maxTokens,
        systemPrompt: settings.systemPrompt,
      );
    } catch (e) {
      // Error is already handled inside ChatProvider
    }

    if (!mounted) return;
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildAndroid(context);
    return _buildDesktop(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildAndroid(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;
    final messages = chat.messages;
    final mq = MediaQuery.of(context);
    final keyboardVisible = mq.viewInsets.bottom > 0;
    // Responsive horizontal padding: wider on tablets
    final screenWidth = mq.size.width;
    final isWide = screenWidth > 600;
    final horizontalPad = isWide ? screenWidth * 0.1 : 14.0;

    if (messages.isNotEmpty) _scrollToBottom();

    return Column(
      children: [
        // ── Message list ──
        Expanded(
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
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad, 10, horizontalPad, 10,
                      ),
                      itemCount: messages.length + (chat.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && chat.isLoading) {
                          return _buildThinkingIndicator(cs);
                        }
                        return RepaintBoundary(
                          key: ValueKey(
                            'msg_${messages[index].timestamp.millisecondsSinceEpoch}_$index',
                          ),
                          child: MessageBubble(message: messages[index]),
                        );
                      },
                    ),
                  ),
                ),
        ),

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
                          hintText: 'Ask anything...',
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
                      color: canSend ? cs.onPrimary : cs.onSurfaceVariant.withAlpha(100),
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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(Icons.smart_toy_rounded, size: 14, color: cs.onPrimary),
            ),
          ),
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
                    'Thinking...',
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

  // ─── Desktop: Fluent UI ───
  Widget _buildDesktop(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final theme = fluent.FluentTheme.of(context);
    final messages = chat.messages;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (messages.isNotEmpty) _scrollToBottom();

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const WelcomeView()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  addAutomaticKeepAlives: true,
                  itemCount: messages.length + (chat.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && chat.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 48),
                            fluent.ProgressRing(strokeWidth: 2),
                            SizedBox(width: 12),
                            Text('Thinking...'),
                          ],
                        ),
                      );
                    }
                    return RepaintBoundary(
                      key: ValueKey('msg_${messages[index].timestamp.millisecondsSinceEpoch}_$index'),
                      child: MessageBubble(message: messages[index]),
                    );
                  },
                ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.micaBackgroundColor.withAlpha((0.8 * 255).round()),
            border: Border(top: BorderSide(color: theme.resources.dividerStrokeColorDefault)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: fluent.TextBox(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: 'Type your message...',
                  maxLines: 6,
                  minLines: 1,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 14),
                  decoration: WidgetStatePropertyAll(BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.resources.dividerStrokeColorDefault),
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: fluent.FilledButton(
                  onPressed: chat.isLoading ? null : _send,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(fluent.FluentIcons.send, size: 16),
                  ),
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
      builder: (_, __) {
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
