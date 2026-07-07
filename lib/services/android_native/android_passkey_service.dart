library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidPasskeyService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/passkeys',
  );

  static bool get _available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<AndroidNativeResult<Map<String, dynamic>>> register({
    required Map<String, dynamic> options,
  }) {
    return _invokePasskey('register', options);
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> authenticate({
    required Map<String, dynamic> options,
  }) {
    return _invokePasskey('authenticate', options);
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> signalUnknownCredential({
    required Map<String, dynamic> options,
  }) {
    return _invokePasskey('signalUnknownCredential', options);
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> signalAllAcceptedCredentials({
    required Map<String, dynamic> options,
  }) {
    return _invokePasskey('signalAllAcceptedCredentials', options);
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> signalCurrentUserDetails({
    required Map<String, dynamic> options,
  }) {
    return _invokePasskey('signalCurrentUserDetails', options);
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> _invokePasskey(
    String method,
    Map<String, dynamic> options,
  ) async {
    if (!_available) return AndroidNativeResult.unsupported();

    final envelope = await _channel.invokeMethod<Object?>(method, {
      'requestJson': jsonEncode(options),
    });
    return AndroidNativeResult.fromEnvelope(
      envelope,
      _decodeNativePasskeyData,
    );
  }

  Map<String, dynamic> _decodeNativePasskeyData(Object? data) {
    final map = asStringMap(data);
    final responseJson = map['responseJson']?.toString();
    if (responseJson == null || responseJson.isEmpty) return map;

    final decoded = jsonDecode(responseJson);
    if (decoded is Map) {
      map['responseInfo'] = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return map;
  }
}
