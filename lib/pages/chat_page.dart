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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
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
          const SnackBar(content: Text('Please configure your API key in Settings.')),
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

    await chat.sendMessage(
      content: text,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.selectedModel,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      systemPrompt: settings.systemPrompt,
    );

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

    if (messages.isNotEmpty) _scrollToBottom();

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const WelcomeView()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length + (chat.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && chat.isLoading) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: cs.primaryContainer,
                              child: Icon(Icons.smart_toy_outlined, size: 16, color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                                  const SizedBox(width: 10),
                                  Text('Thinking...', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RepaintBoundary(child: MessageBubble(message: messages[index]));
                  },
                ),
        ),
        // M3 input bar
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha((0.3 * 255).round()))),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: chat.isLoading ? null : _send,
                  elevation: chat.isLoading ? 0 : 2,
                  backgroundColor: chat.isLoading ? cs.surfaceContainerHighest : cs.primaryContainer,
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: chat.isLoading ? cs.outline : cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
                    return RepaintBoundary(child: MessageBubble(message: messages[index]));
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
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.resources.dividerStrokeColorDefault),
                  ),
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
