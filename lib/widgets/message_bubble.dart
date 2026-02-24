import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show isAndroid;
import '../models/message.dart';
import 'rich_content_view.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildM3Bubble(context);
    return _buildFluentBubble(context);
  }

  // ─── Android: Material 3 bubble ───
  Widget _buildM3Bubble(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
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
              child: Center(child: Icon(Icons.smart_toy_rounded, size: 14, color: cs.onPrimary)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.82),
              decoration: BoxDecoration(
                color: isUser ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 22),
                ),
                border: message.isError
                    ? Border.all(color: cs.error.withAlpha(120))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUser)
                    RepaintBoundary(
                      child: SelectableText(
                        message.content,
                        style: TextStyle(fontSize: 15, color: cs.onPrimaryContainer, height: 1.45),
                      ),
                    )
                  else
                    RepaintBoundary(child: RichContentView(content: message.content)),
                  const SizedBox(height: 6),
                  _M3Footer(message: message, isUser: isUser),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Icon(Icons.person_rounded, size: 14, color: cs.onSecondaryContainer)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Desktop: Fluent UI bubble ───
  Widget _buildFluentBubble(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isUser = message.role == 'user';
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.accentColor, theme.accentColor.lighter]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(child: Icon(fluent.FluentIcons.robot, size: 16, color: fluent.Colors.white)),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              decoration: BoxDecoration(
                color: isUser
                    ? Color.fromRGBO(theme.accentColor.value >> 16 & 0xFF, theme.accentColor.value >> 8 & 0xFF, theme.accentColor.value & 0xFF, isDark ? 0.3 : 0.12)
                    : (isDark ? const Color(0xFF2D2D2D) : fluent.Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 12),
                ),
                border: message.isError
                    ? Border.all(color: fluent.Colors.red.withAlpha((0.5 * 255).round()))
                    : (isDark ? null : Border.all(color: const Color(0xFFE8E8E8))),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? (0.2 * 255).round() : (0.05 * 255).round()), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUser)
                    RepaintBoundary(
                      child: SelectableText(message.content, style: TextStyle(fontSize: 14, color: theme.typography.body?.color)),
                    )
                  else
                    RepaintBoundary(child: RichContentView(content: message.content)),
                  const SizedBox(height: 6),
                  _FluentFooter(message: message, isUser: isUser),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(child: Icon(fluent.FluentIcons.contact, size: 16, color: theme.typography.body?.color)),
            ),
          ],
        ],
      ),
    );
  }
}

class _M3Footer extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _M3Footer({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 10, color: cs.outline.withAlpha(180)),
        ),
        if (!isUser) ...[
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Copied to clipboard'),
                      ],
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 14, color: cs.outline.withAlpha(180)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FluentFooter extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _FluentFooter({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 10, color: theme.inactiveColor),
        ),
        if (!isUser) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              fluent.displayInfoBar(context, builder: (ctx, close) {
                return fluent.InfoBar(
                  title: const Text('Copied to clipboard'),
                  severity: fluent.InfoBarSeverity.info,
                  action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close),
                );
              });
            },
            child: Icon(fluent.FluentIcons.copy, size: 12, color: theme.inactiveColor),
          ),
        ],
      ],
    );
  }
}
