import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../services/crash_author_attribution.dart';
import '../services/crash_breadcrumbs.dart';
import '../utils/build_config.dart';

class CrashReport {
  CrashReport({
    required this.reportId,
    required this.crashedAtMillis,
    required this.crashedAtText,
    required this.exceptionType,
    required this.rootCause,
    required this.threadName,
    required this.processName,
    required this.systemInfo,
    required this.stackTrace,
    this.recentEvents = const <String>[],
    this.authorName = CrashAuthorAttribution.authorName,
    this.authorUrl = CrashAuthorAttribution.authorUrl,
    this.authorFingerprint,
  });

  final String reportId;
  final int crashedAtMillis;
  final String crashedAtText;
  final String exceptionType;
  final String rootCause;
  final String threadName;
  final String processName;
  final String systemInfo;
  final String stackTrace;
  final List<String> recentEvents;
  final String authorName;
  final String authorUrl;
  final String? authorFingerprint;

  static final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  factory CrashReport.fromError(Object error, StackTrace stackTrace) {
    try {
      final now = DateTime.now();
      final stackText = _sanitize(stackTrace.toString());
      final exceptionType = error.runtimeType.toString();
      final root = _rootCause(error);
      final rootText = root.toString().trim();
      final rootCause = _sanitize(
        rootText.isEmpty ? root.runtimeType.toString() : rootText,
      );
      return CrashReport(
        reportId: _reportId(
          now.millisecondsSinceEpoch,
          exceptionType,
          rootCause,
          stackText,
        ),
        crashedAtMillis: now.millisecondsSinceEpoch,
        crashedAtText: _timeFormat.format(now),
        exceptionType: exceptionType,
        rootCause: rootCause,
        threadName: 'main isolate',
        processName: 'NexAI',
        systemInfo: _buildSystemInfo(),
        stackTrace: stackText,
        recentEvents: CrashBreadcrumbs.snapshot(),
        authorFingerprint: CrashAuthorAttribution.fingerprintHex,
      );
    } catch (reportFailure) {
      return CrashReport.fromErrorFallback(error, stackTrace, reportFailure);
    }
  }

  factory CrashReport.fromErrorFallback(
    Object error,
    StackTrace stackTrace,
    Object reportFailure,
  ) {
    final now = DateTime.now();
    final stackText = stackTrace.toString();
    final exceptionType = error.runtimeType.toString();
    final rootCause = error.toString().trim().isEmpty
        ? exceptionType
        : error.toString();
    return CrashReport(
      reportId: _reportId(
        now.millisecondsSinceEpoch,
        exceptionType,
        rootCause,
        stackText,
      ),
      crashedAtMillis: now.millisecondsSinceEpoch,
      crashedAtText: now.millisecondsSinceEpoch.toString(),
      exceptionType: exceptionType,
      rootCause: rootCause,
      threadName: 'main isolate',
      processName: 'NexAI',
      systemInfo:
          'Crash report construction failed: ${reportFailure.runtimeType}\n'
          '${_buildSystemInfo()}',
      stackTrace: stackText,
      recentEvents: CrashBreadcrumbs.snapshot(),
      authorFingerprint: CrashAuthorAttribution.fingerprintHex,
    );
  }

  factory CrashReport.fromJson(Map<String, dynamic> json) {
    return CrashReport(
      reportId: (json['reportId'] as String?)?.trim().isNotEmpty == true
          ? json['reportId'] as String
          : '${json['crashedAtMillis']}'.padLeft(12, '0').substring(0, 12),
      crashedAtMillis: (json['crashedAtMillis'] as num).toInt(),
      crashedAtText: json['crashedAtText'] as String,
      exceptionType: json['exceptionType'] as String,
      rootCause: json['rootCause'] as String,
      threadName: json['threadName'] as String? ?? 'unknown',
      processName: json['processName'] as String? ?? 'unknown',
      systemInfo: json['systemInfo'] as String,
      stackTrace: json['stackTrace'] as String,
      recentEvents:
          (json['recentEvents'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList() ??
          const <String>[],
      authorName:
          json['authorName'] as String? ?? CrashAuthorAttribution.authorName,
      authorUrl: json['authorUrl'] as String? ?? CrashAuthorAttribution.authorUrl,
      authorFingerprint: json['authorFingerprint'] as String? ??
          CrashAuthorAttribution.fingerprintHex,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reportId': reportId,
      'crashedAtMillis': crashedAtMillis,
      'crashedAtText': crashedAtText,
      'exceptionType': exceptionType,
      'rootCause': rootCause,
      'threadName': threadName,
      'processName': processName,
      'systemInfo': systemInfo,
      'stackTrace': stackTrace,
      'recentEvents': recentEvents,
      'authorName': authorName,
      'authorUrl': authorUrl,
      'authorFingerprint':
          authorFingerprint ?? CrashAuthorAttribution.fingerprintHex,
    };
  }

  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('Report ID: $reportId')
      ..writeln('Crash time: $crashedAtText')
      ..writeln('Exception type: $exceptionType')
      ..writeln('Root cause: $rootCause')
      ..writeln('Thread: $threadName')
      ..writeln('Process: $processName')
      ..writeln('System info:')
      ..writeln(systemInfo);
    if (recentEvents.isNotEmpty) {
      buffer.writeln('Recent app events:');
      for (final event in recentEvents) {
        buffer.writeln(event);
      }
    }
    buffer
      ..writeln('Stack trace:')
      ..writeln(stackTrace)
      ..writeln('Author: $authorName')
      ..writeln('Author URL: $authorUrl')
      ..writeln(
        'Author fingerprint: ${authorFingerprint ?? CrashAuthorAttribution.fingerprintHex}',
      )
      ..writeln(CrashAuthorAttribution.footerLabel);
    return buffer.toString();
  }

  static Object _rootCause(Object error) {
    var current = error;
    final seen = <Object>{current};
    while (true) {
      final dynamic maybe = current;
      Object? next;
      try {
        next = maybe.cause as Object?;
      } catch (_) {
        next = null;
      }
      if (next == null || identical(next, current) || !seen.add(next)) {
        break;
      }
      current = next;
    }
    return current;
  }

  static String _buildSystemInfo() {
    return <String>[
      'App: NexAI',
      'App version: ${BuildConfig.versionName} (${BuildConfig.versionCode})',
      'Commit: ${BuildConfig.shortHash}',
      'Flutter mode: ${kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug'}',
      'Platform: ${defaultTargetPlatform.name}',
      'Build time: ${BuildConfig.buildTime}',
      'Crash SDK author: ${CrashAuthorAttribution.authorName}',
      'Crash SDK author URL: ${CrashAuthorAttribution.authorUrl}',
    ].join('\n');
  }

  static String _reportId(
    int crashedAtMillis,
    String exceptionType,
    String rootCause,
    String stackTrace,
  ) {
    final stackLines = stackTrace.split('\n');
    final firstStackLine = stackLines.isEmpty ? '' : stackLines.first;
    final seed = '$crashedAtMillis|$exceptionType|$rootCause|$firstStackLine';
    return sha256
        .convert(utf8.encode(seed))
        .bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .substring(0, 12);
  }

  static String _sanitize(String value) {
    var sanitized = value
        .replaceAll(RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/home/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/Users/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'content://[^\s]+'), '[content-uri]')
        .replaceAll(RegExp(r'file://[^\s]+'), '[file-uri]');
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      'Bearer [redacted]',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'([?&](?:key|api_key|apikey|access_token|refresh_token|token|password|secret)=)[^&\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[redacted]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'sk-[A-Za-z0-9_-]{12,}'),
      'sk-[redacted]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
      'AIza[redacted]',
    );
    return sanitized;
  }
}
