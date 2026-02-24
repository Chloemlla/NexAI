import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

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
      await displayInfoBar(context, builder: (ctx, close) {
        return InfoBar(
          title: const Text('API Key not configured'),
          content: const Text('Please go to Settings to configure your API key.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        );
      });
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
    final chat = context.watch<ChatProvider>();
    final theme = FluentTheme.of(context);
    final messages = chat.messages;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (messages.isNotEmpty) _scrollToBottom();

    return Column(
      children: [
        // Messages area
        Expanded(
          child: messages.isEmpty
              ? const WelcomeView()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  // addAutomaticKeepAlives reduces widget recreation
                  addAutomaticKeepAlives: true,
                  itemCount: messages.length + (chat.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && chat.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 48),
                            ProgressRing(strokeWidth: 2),
                            SizedBox(width: 12),
                            Text('Thinking...'),
                          ],
                        ),
                      );
                    }
                    // RepaintBoundary isolates each bubble's repaint
                    return RepaintBoundary(
                      child: MessageBubble(message: messages[index]),
                    );
                  },
                ),
        ),

        // Input area — respects edge-to-edge bottom inset
        Container(
          decoration: BoxDecoration(
            color: theme.micaBackgroundColor.withOpacity(0.8),
            border: Border(top: BorderSide(color: theme.resources.dividerStrokeColorDefault)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextBox(
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
                child: FilledButton(
                  onPressed: chat.isLoading ? null : _send,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(FluentIcons.send, size: 16),
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
