import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'android_native/android_crash_service.dart';

class CrashBreadcrumbs {
  static const int _maxEvents = 40;
  static final List<String> _events = <String>[];
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');

  CrashBreadcrumbs._();

  static void record(String event) {
    final sanitized = _sanitize(event).trim();
    if (sanitized.isEmpty) return;
    if (_events.length >= _maxEvents) {
      _events.removeAt(0);
    }
    final clipped = sanitized.length > 180
        ? sanitized.substring(0, 180)
        : sanitized;
    final entry = '${_timeFormat.format(DateTime.now())}  $clipped';
    _events.add(entry);

    // Best-effort mirror into lumen-crash for Android-native crash context.
    // Ignore failures; channel may not be ready during very early bootstrap.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Fire-and-forget; do not block Dart crash capture paths.
      // ignore: unawaited_futures
      AndroidCrashService.recordBreadcrumb(clipped);
    }
  }

  static List<String> snapshot() => List.unmodifiable(_events);

  static String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/home/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/Users/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'content://[^\s]+'), '[content-uri]')
        .replaceAll(RegExp(r'file://[^\s]+'), '[file-uri]');
  }
}
