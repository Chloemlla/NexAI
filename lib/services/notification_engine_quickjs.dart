import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/quickjs/quickjs_runtime2.dart';

import 'notification_engine.dart';
import 'notification_engine_fallback.dart';
import 'notification_models.dart';

/// Notification engine backed by the embedded QuickJS runtime (Android only).
///
/// Constructing [QuickJsRuntime2] dlopens libfastdev_quickjs_runtime.so, so any
/// native load failure throws here and the caller falls back to the Dart
/// mirror. Commands are evaluated against the JS queue and the authoritative
/// state is re-read via `NexNotifyCenter.snapshot()` after each command.
class QuickJsNexNotificationEngine implements NexNotificationEngine {
  QuickJsNexNotificationEngine() {
    _rt = QuickJsRuntime2(timeout: 500, memoryLimit: 8 * 1024 * 1024);
    // Drain the runtime's event-loop port so repeated evals never buffer.
    _rt.port.listen((Object? _) {});
  }

  late final QuickJsRuntime2 _rt;
  bool _ready = false;
  bool _failed = false;
  void Function(List<NexNotification>)? _onSnapshot;

  @override
  Future<void> init() async {
    if (_failed) {
      throw StateError('QuickJS engine previously failed');
    }
    try {
      final source =
          await rootBundle.loadString('assets/js/notification_center.js');
      final result = _rt.evaluate(source);
      if (result.isError) {
        throw StateError(
          'notification_center.js evaluation failed: ${result.stringResult}',
        );
      }
      _ready = true;
    } catch (_) {
      _failed = true;
      rethrow;
    }
  }

  @override
  void onSnapshot(void Function(List<NexNotification>) callback) {
    _onSnapshot = callback;
  }

  @override
  void push(NexNotifyData data) {
    _call('NexNotifyCenter.push', jsonEncode(data.toJson()));
    _sync();
  }

  @override
  void expire(int id) => _mutate('NexNotifyCenter.expire($id)');

  @override
  void dismiss(int id) => _mutate('NexNotifyCenter.dismiss($id)');

  @override
  void pause(int id) => _mutate('NexNotifyCenter.pause($id)');

  @override
  void resume(int id) => _mutate('NexNotifyCenter.resume($id)');

  void _mutate(String expression) {
    _call(expression, null);
    _sync();
  }

  void _call(String expression, String? argumentJson) {
    if (!_ready) return;
    final source =
        argumentJson == null ? expression : '$expression($argumentJson)';
    final result = _rt.evaluate(source);
    if (result.isError) {
      debugPrint('[NexNotify] engine error: ${result.stringResult}');
    }
  }

  void _sync() {
    if (!_ready) return;
    final result = _rt.evaluate('NexNotifyCenter.snapshot()');
    if (result.isError) {
      debugPrint('[NexNotify] engine snapshot failed: ${result.stringResult}');
      return;
    }
    final decoded = jsonDecode(result.stringResult);
    if (decoded is! List) return;
    final items = decoded.map(NexNotification.fromJson).toList(growable: false);
    _onSnapshot?.call(items);
  }
}

/// Choose the engine for the current platform. QuickJS is Android-only; the
/// Dart mirror serves web, host tests, and any native load failure.
NexNotificationEngine createNexNotificationEngine() {
  if (!kIsWeb && Platform.isAndroid) {
    return QuickJsNexNotificationEngine();
  }
  return FallbackNexNotificationEngine();
}
