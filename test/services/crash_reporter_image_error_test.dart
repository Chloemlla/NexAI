import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/models/crash_report.dart';
import 'package:nexai/services/crash_reporter.dart';

void main() {
  group('CrashReporter.isNonFatalImageError', () {
    test('treats NetworkImageLoadException as non-fatal', () {
      final error = NetworkImageLoadException(
        statusCode: 404,
        uri: Uri.parse('https://lh3.googleusercontent.com/a/photo'),
      );
      expect(CrashReporter.isNonFatalImageError(error), isTrue);
    });

    test('treats image resource service FlutterErrorDetails as non-fatal', () {
      final details = FlutterErrorDetails(
        exception: Exception(
          'SocketException: Connection failed (OS Error: Network is unreachable, errno = 101), address = lh3.googleusercontent.com, port = 443',
        ),
        library: 'image resource service',
        context: ErrorDescription('while resolving an image'),
      );
      expect(
        CrashReporter.isNonFatalImageError(details.exception, details: details),
        isTrue,
      );
    });

    test('does not treat unrelated SocketException-like text as non-fatal', () {
      final error = Exception(
        'SocketException: Connection failed, address = api.example.com, port = 443',
      );
      expect(CrashReporter.isNonFatalImageError(error), isFalse);
    });
  });

  group('CrashReporter.isNonFatalImageCrashReport', () {
    test('matches the reported Google avatar SocketException crash', () {
      final report = CrashReport(
        reportId: '78a99bbbe657',
        crashedAtMillis: 0,
        crashedAtText: '2026-07-12 23:43:09.793',
        exceptionType: 'Yp',
        rootCause:
            'SocketException: Connection failed (OS Error: Network is unreachable, errno = 101), address = lh3.googleusercontent.com, port = 443',
        threadName: 'main isolate',
        processName: 'NexAI',
        systemInfo: 'Platform: android',
        stackTrace: '#00 abs ...',
      );
      expect(CrashReporter.isNonFatalImageCrashReport(report), isTrue);
    });

    test('keeps real crashes that mention unrelated hosts', () {
      final report = CrashReport(
        reportId: 'deadbeefcafe',
        crashedAtMillis: 0,
        crashedAtText: '2026-07-12 23:43:09.793',
        exceptionType: 'StateError',
        rootCause: 'Bad state: no element',
        threadName: 'main isolate',
        processName: 'NexAI',
        systemInfo: 'Platform: android',
        stackTrace: '#00 abs ...',
      );
      expect(CrashReporter.isNonFatalImageCrashReport(report), isFalse);
    });
  });

  group('CrashReporter.recordError', () {
    test('skips persisting non-fatal image errors', () {
      final error = Exception(
        'SocketException: Connection failed (OS Error: Network is unreachable, errno = 101), address = lh3.googleusercontent.com, port = 443',
      );
      final report = CrashReporter.recordError(
        error,
        StackTrace.current,
        event: 'test non-fatal image error',
      );
      expect(report, isNull);
    });
  });
}
