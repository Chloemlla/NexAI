import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../main.dart' show isAndroid;
import '../models/message.dart';
import 'rich_content_view.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isUser = message.role == 'user';
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final maxBubbleWidth = isAndroid ? screenWidth * 0.85 : 720.0;
    final avatarSize = isAndroid ? 32.0 : 36.0;
    final avatarIconSize = isAndroid ? 14.0 : 16.0;
    final bubblePadding = isAndroid ? 10.0 : 14.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _Avatar(
              size: avatarSize,
              iconSize: avatarIconSize,
              gradient: LinearGradient(
                colors: [theme.accentColor, theme.accentColor.lighter],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              icon: FluentIcons.robot,
            ),
            SizedBox(width: isAndroid ? 8 : 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.accentColor.withOpacity(isDark ? 0.3 : 0.12)
                    : (isDark ? const Color(0xFF2D2D2D) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 12),
                ),
                border: message.isError
                    ? Border.all(color: Colors.red.withOpacity(0.5))
                    : (isDark ? null : Border.all(color: const Color(0xFFE8E8E8))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(bubblePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    SelectableText(
                      message.content,
                      style: TextStyle(fontSize: 14, color: theme.typography.body?.color),
                    )
                  else
                    RepaintBoundary(
                      child: RichContentView(content: message.content),
                    ),
                  const SizedBox(height: 6),
                  _MessageFooter(message: message, isUser: isUser),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: isAndroid ? 8 : 10),
            _Avatar(
              size: avatarSize,
              iconSize: avatarIconSize,
              color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE8E8E8),
              icon: FluentIcons.contact,
              iconColor: theme.typography.body?.color,
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Gradient? gradient;
  final Color? color;
  final IconData icon;
  final Color? iconColor;
  final double size;
  final double iconSize;

  const _Avatar({
    this.gradient,
    this.color,
    required this.icon,
    this.iconColor,
    this.size = 36,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: iconColor ?? Colors.white),
      ),
    );
  }
}

class _MessageFooter extends StatelessWidget {
  final Message message;
  final bool isUser;

  const _MessageFooter({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
              displayInfoBar(context, builder: (ctx, close) {
                return InfoBar(
                  title: const Text('Copied to clipboard'),
                  severity: InfoBarSeverity.info,
                  action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
                );
              });
            },
            child: Icon(FluentIcons.copy, size: 12, color: theme.inactiveColor),
          ),
        ],
      ],
    );
  }
}
