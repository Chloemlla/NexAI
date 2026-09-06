import 'notification_center.dart';
import 'notification_models.dart';

/// Drop-in global facade replacing SmartDialog.showToast for in-app toasts.
///
/// The underlying queue is driven by the embedded QuickJS engine on Android
/// (falling back to a Dart mirror on web / tests / native load failure).
class NexNotify {
  NexNotify._();

  static void show(
    String message, {
    NexNotifyType type = NexNotifyType.info,
    String? title,
    List<String> details = const <String>[],
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    NotificationCenter.instance.show(
      NexNotifyData(
        message: message,
        type: type,
        title: title,
        details: details,
        duration: duration,
      ),
    );
  }
}
