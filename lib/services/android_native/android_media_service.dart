library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidNativeTaskEvent {
  const AndroidNativeTaskEvent({
    required this.taskId,
    required this.type,
    required this.progress,
    required this.message,
    required this.payload,
  });

  final String taskId;
  final String type;
  final double progress;
  final String message;
  final Map<String, dynamic> payload;

  factory AndroidNativeTaskEvent.fromMap(Map<String, dynamic> map) {
    return AndroidNativeTaskEvent(
      taskId: map['taskId']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      message: map['message']?.toString() ?? '',
      payload: asStringMap(map['payload']),
    );
  }
}

class AndroidMediaService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/media',
  );
  static const EventChannel _events = EventChannel(
    'com.chloemlla.nexai/native_task_events',
  );

  static bool get _available => !kIsWeb && Platform.isAndroid;

  Stream<AndroidNativeTaskEvent> get events {
    if (!_available) return const Stream.empty();
    return _events.receiveBroadcastStream().map(
      (event) => AndroidNativeTaskEvent.fromMap(asStringMap(event)),
    );
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> getVideoMetadata({
    required String uriOrPath,
  }) => _invokeMap('getVideoMetadata', {'uri': uriOrPath});

  Future<AndroidNativeResult<Map<String, dynamic>>> startAudioExtraction({
    required String uriOrPath,
    String format = 'm4a',
    String? taskId,
  }) {
    return _invokeMap('startAudioExtraction', {
      'uri': uriOrPath,
      'format': format,
      'taskId': ?taskId,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> startVideoCompression({
    required String uriOrPath,
    Map<String, dynamic> options = const {},
    String? taskId,
  }) {
    return _invokeMap('startVideoCompression', {
      'uri': uriOrPath,
      'options': options,
      'taskId': ?taskId,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> cancelTask(
    String taskId,
  ) => _invokeMap('cancelTask', {'taskId': taskId});

  Future<AndroidNativeResult<Map<String, dynamic>>> getTaskStatus(
    String taskId,
  ) => _invokeMap('getTaskStatus', {'taskId': taskId});

  Future<AndroidNativeResult<Map<String, dynamic>>> _invokeMap(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(method, arguments);
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }
}
