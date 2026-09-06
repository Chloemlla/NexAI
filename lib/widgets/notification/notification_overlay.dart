import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/notification_center.dart';
import '../../services/notification_models.dart';
import 'notification_card.dart';

/// Hosts the in-app notification stack above the app's route content, top-right
/// with a cascade, mirroring the Notification.tsx fixed container.
class NotificationOverlay extends StatefulWidget {
  const NotificationOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  @override
  void initState() {
    super.initState();
    unawaited(NotificationCenter.instance.init());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: ListenableBuilder(
                  listenable: NotificationCenter.instance,
                  builder: (context, _) => _NotificationStack(
                    items: NotificationCenter.instance.items,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the snapshot; items leaving the snapshot are kept briefly in a
/// "leaving" state so the exit animation can play before removal.
class _NotificationStack extends StatefulWidget {
  const _NotificationStack({required this.items});

  final List<NexNotification> items;

  @override
  State<_NotificationStack> createState() => _NotificationStackState();
}

class _NotificationStackState extends State<_NotificationStack> {
  static const Duration _exitKeep = Duration(milliseconds: 220);

  final Map<int, NexNotification> _leaving = <int, NexNotification>{};
  final Map<int, Timer> _exitTimers = <int, Timer>{};

  @override
  void didUpdateWidget(_NotificationStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final present = <int>{for (final it in widget.items) it.id};
    for (final it in oldWidget.items) {
      if (present.contains(it.id) || _leaving.containsKey(it.id)) continue;
      _leaving[it.id] = it;
      _exitTimers[it.id] = Timer(_exitKeep, () {
        if (!mounted) return;
        setState(() {
          _leaving.remove(it.id);
          _exitTimers.remove(it.id);
        });
      });
    }
  }

  @override
  void dispose() {
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    final items = widget.items;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      cards.add(NotificationCard(
        key: ValueKey<int>(item.id),
        item: item,
        index: i,
        leaving: false,
        onClose: () => NotificationCenter.instance.dismiss(item.id),
        onPause: () => NotificationCenter.instance.pause(item.id),
        onResume: () => NotificationCenter.instance.resume(item.id),
      ));
    }
    final leavingEntries = _leaving.entries.toList()
      ..sort((a, b) => a.value.start.compareTo(b.value.start));
    for (final entry in leavingEntries) {
      cards.add(NotificationCard(
        key: ValueKey<int>(-entry.key),
        item: entry.value,
        index: 0,
        leaving: true,
        onClose: () => NotificationCenter.instance.dismiss(entry.key),
        onPause: () => NotificationCenter.instance.pause(entry.key),
        onResume: () => NotificationCenter.instance.resume(entry.key),
      ));
    }

    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(cards[i]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
