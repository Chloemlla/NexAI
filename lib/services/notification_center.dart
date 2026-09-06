import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_engine.dart';
import 'notification_engine_fallback.dart';
import 'notification_engine_quickjs.dart'
    if (dart.library.js_interop) 'notification_engine_stub.dart';
import 'notification_models.dart';

/// App-wide notification queue: forwards commands to the engine, keeps per-item
/// countdown timers, and exposes the current snapshot for the overlay.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();

  static final NotificationCenter instance = NotificationCenter._();

  NexNotificationEngine? _engine;
  List<NexNotification> _items = const <NexNotification>[];
  final Map<int, Timer> _timers = <int, Timer>{};
  final List<NexNotifyData> _pending = <NexNotifyData>[];
  bool _initialized = false;

  List<NexNotification> get items => _items;

  /// Prepare the engine. Idempotent; fails over to the Dart mirror on any
  /// QuickJS construction or load error.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    NexNotificationEngine engine;
    try {
      engine = createNexNotificationEngine();
      await engine.init();
    } catch (_) {
      debugPrint('[NexNotify] QuickJS engine unavailable, using Dart mirror');
      engine = FallbackNexNotificationEngine();
      await engine.init();
    }
    _engine = engine;
    engine.onSnapshot(_applySnapshot);
    if (_pending.isNotEmpty) {
      final queued = List<NexNotifyData>.of(_pending);
      _pending.clear();
      for (final data in queued) {
        engine.push(data);
      }
    }
  }

  void show(NexNotifyData data) {
    final engine = _engine;
    if (engine == null) {
      _pending.add(data);
      return;
    }
    engine.push(data);
  }

  void dismiss(int id) {
    _cancelTimer(id);
    _engine?.dismiss(id);
  }

  void pause(int id) {
    _cancelTimer(id);
    _engine?.pause(id);
  }

  void resume(int id) {
    _engine?.resume(id);
  }

  void _applySnapshot(List<NexNotification> next) {
    final present = <int>{for (final it in next) it.id};
    _timers.removeWhere((id, _) => !present.contains(id));
    for (final it in next) {
      if (it.paused) {
        _timers.remove(it.id)?.cancel();
        continue;
      }
      if (_timers.containsKey(it.id)) continue;
      final elapsed = DateTime.now().millisecondsSinceEpoch - it.start;
      final ms = (it.duration.inMilliseconds - elapsed)
          .clamp(0, it.duration.inMilliseconds)
          .toInt();
      _timers[it.id] = Timer(Duration(milliseconds: ms), () {
        _timers.remove(it.id);
        _engine?.expire(it.id);
      });
    }
    _items = next;
    notifyListeners();
  }

  void _cancelTimer(int id) {
    _timers.remove(id)?.cancel();
  }
}
