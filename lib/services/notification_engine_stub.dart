import 'notification_engine.dart';
import 'notification_engine_fallback.dart';

/// Web cannot dlopen the QuickJS runtime; the Dart mirror is the engine.
NexNotificationEngine createNexNotificationEngine() =>
    FallbackNexNotificationEngine();
