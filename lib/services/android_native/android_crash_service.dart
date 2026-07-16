import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/crash_report.dart';

/// Android host bridge into lumen-crash for Flutter/Dart failures.
class AndroidCrashService {
  AndroidCrashService._();

  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/crash',
  );

  static bool get _available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isInstalled() async {
    if (!_available) return false;
    try {
      final installed = await _channel.invokeMethod<bool>('isInstalled');
      return installed == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> recordBreadcrumb(String event) async {
    if (!_available) return false;
    final sanitized = event.trim();
    if (sanitized.isEmpty) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'recordBreadcrumb',
        <String, Object?>{'event': sanitized},
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> recordReport(CrashReport report) async {
    if (!_available) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'recordReport',
        <String, Object?>{
          'reportId': report.reportId,
          'crashedAtMillis': report.crashedAtMillis,
          'crashedAtText': report.crashedAtText,
          'exceptionType': report.exceptionType,
          'rootCause': report.rootCause,
          'threadName': report.threadName,
          'processName': report.processName,
          'systemInfo': report.systemInfo,
          'stackTrace': report.stackTrace,
          'recentEvents': report.recentEvents,
        },
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearPendingReport() async {
    if (!_available) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('clearPendingReport');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}
