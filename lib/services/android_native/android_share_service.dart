library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidShareService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/share',
  );

  static bool get _available => !kIsWeb && Platform.isAndroid;

  Future<AndroidNativeResult<Map<String, dynamic>>> shareText({
    required String text,
    String? subject,
    String? title,
  }) {
    return _invokeMap('shareText', {
      'text': text,
      if (subject != null) 'subject': subject,
      if (title != null) 'title': title,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> shareFile({
    required String uri,
    String? mimeType,
    String? title,
  }) {
    return _invokeMap('shareFile', {
      'uri': uri,
      if (mimeType != null) 'mimeType': mimeType,
      if (title != null) 'title': title,
    });
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> shareFiles({
    required List<String> uris,
    String? mimeType,
    String? title,
  }) {
    return _invokeMap('shareFiles', {
      'uris': uris,
      if (mimeType != null) 'mimeType': mimeType,
      if (title != null) 'title': title,
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
