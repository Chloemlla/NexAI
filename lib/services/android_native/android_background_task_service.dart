library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_media_service.dart';
import 'android_native_result.dart';

class AndroidBackgroundTaskService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/background',
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

  Future<AndroidNativeResult<Map<String, dynamic>>> enqueueTask({
    required String type,
    String? taskId,
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> constraints = const {},
    int retryCount = 0,
  }) {
    return _invokeMap('enqueueTask', {
      'type': type,
      'taskId': ?taskId,
      'payload': payload,
      'constraints': constraints,
      'retryCount': retryCount,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> getTaskStatus(
    String taskId,
  ) => _invokeMap('getTaskStatus', {'taskId': taskId});

  Future<AndroidNativeResult<List<Map<String, dynamic>>>> listTasks() async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>('listTasks');
    return AndroidNativeResult.fromEnvelope(envelope, asStringMapList);
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> cancelTask(
    String taskId,
  ) => _invokeMap('cancelTask', {'taskId': taskId});

  Future<AndroidNativeResult<Map<String, dynamic>>> _invokeMap(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(method, arguments);
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }
}
