library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidPermissionService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/permissions',
  );

  static bool get _available => !kIsWeb && Platform.isAndroid;

  Future<AndroidNativeResult<Map<String, dynamic>>> pickImage() =>
      _invokeMap('pickImage');

  Future<AndroidNativeResult<Map<String, dynamic>>> pickVideo() =>
      _invokeMap('pickVideo');

  Future<AndroidNativeResult<Map<String, dynamic>>> openDocument({
    String mimeType = '*/*',
  }) => _invokeMap('openDocument', {'mimeType': mimeType});

  Future<AndroidNativeResult<Map<String, dynamic>>> createDocument({
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) => _invokeMap('createDocument', {
    'fileName': fileName,
    'mimeType': mimeType,
  });

  Future<AndroidNativeResult<Map<String, dynamic>>>
  ensureNotificationPermission() => _invokeMap('ensureNotificationPermission');

  Future<AndroidNativeResult<Map<String, dynamic>>>
  getNotificationPermissionStatus() =>
      _invokeMap('getNotificationPermissionStatus');

  Future<AndroidNativeResult<Map<String, dynamic>>> takePersistableUriPermission({
    required String uri,
    bool read = true,
    bool write = false,
  }) => _invokeMap('takePersistableUriPermission', {
    'uri': uri,
    'read': read,
    'write': write,
  });

  Future<AndroidNativeResult<Map<String, dynamic>>> openAppSettings() =>
      _invokeMap('openAppSettings');

  Future<AndroidNativeResult<Map<String, dynamic>>> _invokeMap(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(method, arguments);
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }
}
