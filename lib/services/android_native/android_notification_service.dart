library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidNotificationChannels {
  static const mediaTasks = 'nexai_media_tasks';
  static const updates = 'nexai_updates';
  static const sync = 'nexai_sync';
  static const security = 'nexai_security';
}

class AndroidNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/notifications',
  );

  static bool get _available => !kIsWeb && Platform.isAndroid;

  Future<AndroidNativeResult<Map<String, dynamic>>> initializeChannels() =>
      _invokeMap('initializeChannels');

  Future<AndroidNativeResult<Map<String, dynamic>>> areNotificationsEnabled() =>
      _invokeMap('areNotificationsEnabled');

  Future<AndroidNativeResult<Map<String, dynamic>>> showProgressNotification({
    required String taskId,
    required String title,
    required String message,
    required double progress,
    int? id,
  }) {
    return _invokeMap('showProgressNotification', {
      'taskId': taskId,
      'title': title,
      'message': message,
      'progress': progress,
      'id': ?id,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> showNotification({
    required int id,
    required String title,
    required String message,
    String channelId = AndroidNotificationChannels.updates,
    String route = 'home',
  }) {
    return _invokeMap('showNotification', {
      'id': id,
      'title': title,
      'message': message,
      'channelId': channelId,
      'route': route,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> cancelNotification(int id) =>
      _invokeMap('cancelNotification', {'id': id});

  Future<AndroidNativeResult<Map<String, dynamic>>> _invokeMap(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(method, arguments);
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }
}
