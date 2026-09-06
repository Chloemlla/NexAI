import 'package:flutter/material.dart';

import '../../services/notification_models.dart';

/// A single notification card: type icon, title/message/details, close button,
/// a countdown progress bar, and hover / long-press pause (mirroring the
/// Notification.tsx behavior).
class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.item,
    required this.index,
    required this.leaving,
    required this.onClose,
    required this.onPause,
    required this.onResume,
  });

  final NexNotification item;

  /// Position in the stack; older cards sit slightly lower (index * 4).
  final int index;

  /// True while the card animates out after leaving the snapshot.
  final bool leaving;

  final VoidCallback onClose;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _progress;
  late final AnimationController _pulse;

  static const Duration _enterDuration = Duration(milliseconds: 320);
  static const Duration _leaveDuration = Duration(milliseconds: 180);
  static const Duration _fadeDuration = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    final leaving = widget.leaving;
    _enter = AnimationController(
      vsync: this,
      duration: leaving ? _leaveDuration : _enterDuration,
    );
    if (leaving) {
      _enter.value = 1.0;
      _enter.reverse();
    } else {
      _enter.forward();
    }
    _progress = AnimationController(
      vsync: this,
      duration: _remaining(widget.item),
    )..forward(from: 1.0);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.item.paused) {
      _progress.value = _fraction(widget.item.remaining, widget.item.duration);
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final item = widget.item;
    final old = oldWidget.item;
    final transitioned = item.paused != old.paused || item.start != old.start;
    if (!transitioned) return;
    if (item.paused) {
      _progress.stop();
      _progress.value = _fraction(item.remaining, item.duration);
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
      _progress.duration = _remaining(item);
      _progress.forward(from: 1.0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Duration _remaining(NexNotification item) {
    if (item.paused) return item.remaining;
    final elapsed = DateTime.now().millisecondsSinceEpoch - item.start;
    final ms = (item.duration.inMilliseconds - elapsed)
        .clamp(0, item.duration.inMilliseconds)
        .toInt();
    return Duration(milliseconds: ms);
  }

  double _fraction(Duration part, Duration whole) {
    final total = whole.inMicroseconds;
    if (total <= 0) return 0;
    return (part.inMicroseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final color = item.type.color;
    final fade = item.faded ? 0.6 : 1.0;
    final stackY = widget.leaving ? -24.0 : widget.index * 4.0;

    final card = MouseRegion(
      onEnter: (_) => widget.onPause(),
      onExit: (_) => widget.onResume(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => widget.onPause(),
        onLongPressEnd: (_) => widget.onResume(),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          elevation: item.faded ? 2 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: item.paused
                ? BorderSide(color: color.withValues(alpha: 0.6), width: 1.5)
                : BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: item.details.isEmpty
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    _StatusIcon(type: item.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.title != null && item.title!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                item.title!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Text(
                            item.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.details.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  for (final detail in item.details)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Container(
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: theme
                                                  .colorScheme.outlineVariant,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          detail,
                                          style: theme
                                              .textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: '关闭通知',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildProgress(theme, color),
                if (item.paused)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '悬停暂停 · Hover to pause',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final entrySlide =
            widget.leaving ? 0.0 : -32.0 * (1.0 - _enter.value);
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: stackY),
          duration: _enterDuration,
          curve: Curves.easeOutCubic,
          builder: (context, y, _) => TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fade),
            duration: _fadeDuration,
            builder: (context, fadeValue, _) => Opacity(
              opacity: (_enter.value * fadeValue).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, y + entrySlide),
                child: child,
              ),
            ),
          ),
        );
      },
      child: card,
    );
  }

  Widget _buildProgress(ThemeData theme, Color color) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_progress, _pulse]),
      builder: (context, _) {
        final paused = widget.item.paused;
        final pulse = paused ? 0.5 + 0.5 * _pulse.value : 1.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * _progress.value;
              return Container(
                height: 4,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: width,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          color.withValues(alpha: 0.5 * pulse),
                          color.withValues(alpha: pulse),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.type});

  final NexNotifyType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: type.lightFill,
        shape: BoxShape.circle,
      ),
      child: Icon(type.icon, size: 15, color: type.color),
    );
  }
}

extension on NexNotifyType {
  Color get color => switch (this) {
        NexNotifyType.success => const Color(0xFF22C55E),
        NexNotifyType.error => const Color(0xFFEF4444),
        NexNotifyType.warning => const Color(0xFFEAB308),
        NexNotifyType.info => const Color(0xFF3B82F6),
      };

  Color get lightFill => switch (this) {
        NexNotifyType.success => const Color(0xFFE9FBE8),
        NexNotifyType.error => const Color(0xFFFBEAEA),
        NexNotifyType.warning => const Color(0xFFFFFBE8),
        NexNotifyType.info => const Color(0xFFE8F1FB),
      };

  IconData get icon => switch (this) {
        NexNotifyType.success => Icons.check,
        NexNotifyType.error => Icons.close,
        NexNotifyType.warning => Icons.priority_high,
        NexNotifyType.info => Icons.info_outline,
      };
}
