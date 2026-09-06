import 'notification_models.dart';

/// Queue state machine that drives the in-app notification stack.
///
/// Android uses the embedded QuickJS runtime
/// ([QuickJsNexNotificationEngine]); web, host tests, and native load failures
/// fall back to a pure-Dart mirror with the same snapshot contract.
abstract class NexNotificationEngine {
  /// Prepare the queue (load the JS bundle for QuickJS). Throws on failure so
  /// callers can swap to the fallback engine.
  Future<void> init();

  /// Push [data] to the front of the queue; existing items become faded.
  void push(NexNotifyData data);

  /// Remove [id] after its countdown elapsed.
  void expire(int id);

  /// Remove [id] immediately (manual close).
  void dismiss(int id);

  /// Freeze [id]'s countdown (hover / long-press).
  void pause(int id);

  /// Restart [id]'s countdown from its remaining time.
  void resume(int id);

  /// Register the receiver for queue snapshots; replaces any prior receiver.
  void onSnapshot(void Function(List<NexNotification>) callback);
}
