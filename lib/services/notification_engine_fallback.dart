import 'notification_engine.dart';
import 'notification_models.dart';

/// Pure-Dart mirror of the QuickJS notification queue. Kept behaviorally
/// identical so web, host tests, and the Android fallback path all behave the
/// same way.
class FallbackNexNotificationEngine implements NexNotificationEngine {
  final List<NexNotification> _items = <NexNotification>[];
  int _seq = 0;
  void Function(List<NexNotification>)? _onSnapshot;

  @override
  Future<void> init() async {}

  @override
  void onSnapshot(void Function(List<NexNotification>) callback) {
    _onSnapshot = callback;
  }

  @override
  void push(NexNotifyData data) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = ++_seq;
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _copy(_items[i], faded: true);
    }
    _items.insert(
      0,
      NexNotification(
        id: id,
        type: data.type,
        message: data.message,
        title: data.title,
        details: List<String>.of(data.details),
        duration: data.duration,
        start: now,
        faded: false,
        paused: false,
        remaining: data.duration,
      ),
    );
    _emit();
  }

  @override
  void expire(int id) {
    if (_remove(id)) _emit();
  }

  @override
  void dismiss(int id) => expire(id);

  @override
  void pause(int id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.id == id || it.paused) continue;
      final elapsed = now - it.start;
      final remainingMs = it.duration.inMilliseconds - elapsed;
      _items[i] = _copy(
        it,
        paused: true,
        remaining: Duration(
          milliseconds: remainingMs < 0 ? 0 : remainingMs,
        ),
      );
      _emit();
      return;
    }
  }

  @override
  void resume(int id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.id != id || !it.paused) continue;
      _items[i] = _copy(
        it,
        paused: false,
        start: now - (it.duration - it.remaining).inMilliseconds,
      );
      _emit();
      return;
    }
  }

  bool _remove(int id) {
    final index = _items.indexWhere((it) => it.id == id);
    if (index < 0) return false;
    _items.removeAt(index);
    return true;
  }

  void _emit() => _onSnapshot?.call(List<NexNotification>.of(_items));

  NexNotification _copy(
    NexNotification it, {
    bool? faded,
    bool? paused,
    int? start,
    Duration? remaining,
  }) {
    return NexNotification(
      id: it.id,
      type: it.type,
      message: it.message,
      title: it.title,
      details: it.details,
      duration: it.duration,
      start: start ?? it.start,
      faded: faded ?? it.faded,
      paused: paused ?? it.paused,
      remaining: remaining ?? it.remaining,
    );
  }
}
