library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidUpdateService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/update',
  );

  static bool get _available => !kIsWeb && Platform.isAndroid;

  Future<AndroidNativeResult<Map<String, dynamic>>> getInstallEnvironment() =>
      _invokeMap('getInstallEnvironment');

  Future<AndroidNativeResult<Map<String, dynamic>>> openUrl(String url) =>
      _invokeMap('openUrl', {'url': url});

  Future<AndroidNativeResult<Map<String, dynamic>>>
  openUnknownSourcesSettings() => _invokeMap('openUnknownSourcesSettings');

  Future<AndroidNativeResult<Map<String, dynamic>>> verifyApkSha256({
    required String uriOrPath,
    String? expectedSha256,
  }) {
    return _invokeMap('verifyApkSha256', {
      'uri': uriOrPath,
      'expectedSha256': ?expectedSha256,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> verifyApkPackage({
    required String uriOrPath,
    String? expectedSha256,
  }) {
    return _invokeMap('verifyApkPackage', {
      'uri': uriOrPath,
      'expectedSha256': ?expectedSha256,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> installApk({
    required String uriOrPath,
    String? expectedSha256,
  }) {
    return _invokeMap('installApk', {
      'uri': uriOrPath,
      'expectedSha256': ?expectedSha256,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> _invokeMap(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(method, arguments);
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }
}
