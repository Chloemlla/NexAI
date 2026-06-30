library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidFingerprintSnapshot {
  const AndroidFingerprintSnapshot({
    required this.raw,
    required this.derivedSha256,
  });

  final Map<String, dynamic> raw;
  final String derivedSha256;

  factory AndroidFingerprintSnapshot.fromMap(Map<String, dynamic> map) {
    return AndroidFingerprintSnapshot(
      raw: map,
      derivedSha256: map['derivedSha256']?.toString() ?? '',
    );
  }
}

class AndroidFingerprintService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/fingerprint',
  );

  static bool get _available => !kIsWeb && Platform.isAndroid;

  Future<AndroidNativeResult<AndroidFingerprintSnapshot>>
  getFingerprintSnapshot() async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(
      'getFingerprintSnapshot',
    );
    return AndroidNativeResult.fromEnvelope(
      envelope,
      (data) => AndroidFingerprintSnapshot.fromMap(asStringMap(data)),
    );
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> getHardwareInfo() =>
      _invokeMap('getHardwareInfo');

  Future<AndroidNativeResult<Map<String, dynamic>>> getSoftwareInfo() =>
      _invokeMap('getSoftwareInfo');

  Future<AndroidNativeResult<Map<String, dynamic>>> getStorageInfo() =>
      _invokeMap('getStorageInfo');

  Future<AndroidNativeResult<Map<String, dynamic>>> getSensorFingerprint() =>
      _invokeMap('getSensorFingerprint');

  Future<AndroidNativeResult<Map<String, dynamic>>> getNetworkInfo() =>
      _invokeMap('getNetworkInfo');

  Future<AndroidNativeResult<Map<String, dynamic>>> getSystemProperties() =>
      _invokeMap('getSystemProperties');

  Future<AndroidNativeResult<Map<String, dynamic>>> _invokeMap(
    String method,
  ) async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(method);
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }
}
