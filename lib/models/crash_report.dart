import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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

  static final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  factory CrashReport.fromError(Object error, StackTrace stackTrace) {
    final now = DateTime.now();
    final stackText = _sanitize(stackTrace.toString());
    final exceptionType = error.runtimeType.toString();
    final rootCause = _sanitize(error.toString()).trim().isEmpty
        ? exceptionType
        : _sanitize(error.toString());
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
      ..writeln(stackTrace);
    return buffer.toString();
  }

  static String _buildSystemInfo() {
    return <String>[
      'App version: ${BuildConfig.versionName} (${BuildConfig.versionCode})',
      'Commit: ${BuildConfig.shortHash}',
      'Flutter mode: ${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'}',
      'Platform: ${defaultTargetPlatform.name}',
      'Build time: ${BuildConfig.buildTime}',
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
    return value
        .replaceAll(RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/home/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/Users/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'content://[^\s]+'), '[content-uri]')
        .replaceAll(RegExp(r'file://[^\s]+'), '[file-uri]');
  }
}
