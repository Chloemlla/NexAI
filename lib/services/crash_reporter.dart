import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/crash_report.dart';
import 'crash_breadcrumbs.dart';
import 'crash_report_store.dart';

class CrashReporter {
  CrashReporter._();

  static final CrashReportStore store = CrashReportStore();
  static CrashReport? startupCrashReport;
  static FlutterExceptionHandler? _previousFlutterErrorHandler;

  static void install() {
    CrashBreadcrumbs.record('Crash reporter installed');
    _previousFlutterErrorHandler ??= FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        event: 'FlutterError captured',
      );
      _previousFlutterErrorHandler?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack, event: 'PlatformDispatcher error captured');
      return false;
    };
  }

  static Future<void> loadStartupCrashReport() async {
    try {
      startupCrashReport = await store.load();
    } catch (error) {
      debugPrint('NexAI crash report load failed: $error');
      startupCrashReport = null;
    }
  }

  static CrashReport recordError(
    Object error,
    StackTrace stack, {
    String? event,
  }) {
    if (event != null) {
      CrashBreadcrumbs.record(event);
    }
    CrashBreadcrumbs.record('Crash captured: ${error.runtimeType}');
    final report = CrashReport.fromError(error, stack);
    startupCrashReport = report;
    unawaited(
      store.save(report).catchError((Object saveError) {
        debugPrint('NexAI crash report save failed: $saveError');
      }),
    );
    return report;
  }

  static Future<void> clearStartupCrashReport() async {
    startupCrashReport = null;
    await store.clear();
  }
}
