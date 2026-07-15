import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

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
      if (isNonFatalImageError(details.exception, details: details)) {
        CrashBreadcrumbs.record(
          'Ignored non-fatal image error: ${details.exception.runtimeType}',
        );
        _previousFlutterErrorHandler?.call(details);
        return;
      }
      recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        event: 'FlutterError captured',
      );
      _previousFlutterErrorHandler?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (isNonFatalImageError(error)) {
        CrashBreadcrumbs.record(
          'Ignored non-fatal platform image error: ${error.runtimeType}',
        );
        // Mark handled so a dead network image does not abort the app.
        return true;
      }
      recordError(error, stack, event: 'PlatformDispatcher error captured');
      return false;
    };
  }

  static Future<void> loadStartupCrashReport() async {
    try {
      final report = await store.load();
      if (report != null && isNonFatalImageCrashReport(report)) {
        CrashBreadcrumbs.record(
          'Discarded stale non-fatal image crash report ${report.reportId}',
        );
        await store.clear();
        startupCrashReport = null;
        return;
      }
      startupCrashReport = report;
    } catch (error) {
      debugPrint('NexAI crash report load failed: $error');
      startupCrashReport = null;
    }
  }

  /// Returns true for remote image / asset load failures that should not
  /// surface as a user-facing "app crash" report.
  @visibleForTesting
  static bool isNonFatalImageError(
    Object error, {
    FlutterErrorDetails? details,
  }) {
    final library = details?.library?.toLowerCase() ?? '';
    if (library.contains('image resource service') ||
        library.contains('image')) {
      return true;
    }

    final contextText = details?.context?.toString().toLowerCase() ?? '';
    if (contextText.contains('resolving an image') ||
        contextText.contains('loading an image') ||
        contextText.contains('network image')) {
      return true;
    }

    if (error is NetworkImageLoadException) {
      return true;
    }

    final typeName = error.runtimeType.toString();
    if (typeName == 'SocketException' ||
        typeName == 'HttpException' ||
        typeName == 'HandshakeException' ||
        typeName == 'TlsException' ||
        typeName == 'ClientException') {
      if (_looksLikeImageUrlFailure(error.toString())) {
        return true;
      }
    }

    final text = error.toString();
    if (_looksLikeImageUrlFailure(text) && _isBenignNetworkFailure(text)) {
      return true;
    }
    return false;
  }

  /// Detects previously persisted crash reports that were caused by a failed
  /// remote avatar / network image load (including release obfuscated types).
  @visibleForTesting
  static bool isNonFatalImageCrashReport(CrashReport report) {
    final blob = '${report.exceptionType}\n${report.rootCause}'.toLowerCase();
    if (!_looksLikeImageUrlFailure(blob) &&
        !blob.contains('googleusercontent.com') &&
        !blob.contains('ggpht.com')) {
      return false;
    }
    return _isBenignNetworkFailure(blob) ||
        blob.contains('networkimageloadexception') ||
        blob.contains('socketexception') ||
        // Release builds obfuscate exception type names (e.g. "Yp").
        report.exceptionType.trim().length <= 3;
  }

  static bool _looksLikeImageUrlFailure(String text) {
    final lower = text.toLowerCase();
    return lower.contains('googleusercontent.com') ||
        lower.contains('ggpht.com') ||
        lower.contains('gravatar.com') ||
        lower.contains('networkimage') ||
        lower.contains('network image') ||
        lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('.svg') ||
        lower.contains('/avatar') ||
        lower.contains('/photo');
  }

  static bool _isBenignNetworkFailure(String text) {
    final lower = text.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection failed') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection reset') ||
        lower.contains('connection timed out') ||
        lower.contains('connection refused') ||
        lower.contains('software caused connection abort') ||
        lower.contains('networkimageloadexception') ||
        lower.contains('http exception') ||
        lower.contains('httpexception') ||
        lower.contains('handshake exception') ||
        lower.contains('certificate') ||
        lower.contains('clientexception');
  }

  static CrashReport? recordError(
    Object error,
    StackTrace stack, {
    String? event,
  }) {
    if (isNonFatalImageError(error)) {
      if (event != null) {
        CrashBreadcrumbs.record(event);
      }
      CrashBreadcrumbs.record(
        'Skipped non-fatal image error: ${error.runtimeType}',
      );
      return null;
    }
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
