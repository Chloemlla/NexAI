library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_native_result.dart';

class AndroidSecuritySnapshot {
  const AndroidSecuritySnapshot({
    required this.raw,
    required this.rooted,
    required this.debuggerAttached,
    required this.emulator,
    required this.vpnActive,
    required this.fridaDetected,
    required this.xposedDetected,
    required this.adbEnabled,
    required this.developmentSettingsEnabled,
    required this.debugBuild,
    required this.tracerPid,
    required this.tracerAttached,
    required this.antiDebugScore,
    this.signatureSha256,
    this.apkSha256,
    this.dexSha256,
  });

  final Map<String, dynamic> raw;
  final bool rooted;
  final bool debuggerAttached;
  final bool emulator;
  final bool vpnActive;
  final bool fridaDetected;
  final bool xposedDetected;
  final bool adbEnabled;
  final bool developmentSettingsEnabled;
  final bool debugBuild;
  final int tracerPid;
  final bool tracerAttached;
  final double antiDebugScore;
  final String? signatureSha256;
  final String? apkSha256;
  final String? dexSha256;

  factory AndroidSecuritySnapshot.fromMap(Map<String, dynamic> map) {
    final tracerPid = (map['tracerPid'] as num?)?.toInt() ?? 0;
    return AndroidSecuritySnapshot(
      raw: map,
      rooted: map['rooted'] == true,
      debuggerAttached: map['debuggerAttached'] == true,
      emulator: map['emulator'] == true,
      vpnActive: map['vpnActive'] == true,
      fridaDetected: map['fridaDetected'] == true,
      xposedDetected: map['xposedDetected'] == true,
      adbEnabled: map['adbEnabled'] == true,
      developmentSettingsEnabled: map['developmentSettingsEnabled'] == true,
      debugBuild: map['debugBuild'] == true,
      tracerPid: tracerPid,
      tracerAttached: map['tracerAttached'] == true || tracerPid > 0,
      antiDebugScore: (map['antiDebugScore'] as num?)?.toDouble() ?? 0,
      signatureSha256: map['signatureSha256']?.toString(),
      apkSha256: map['apkSha256']?.toString(),
      dexSha256: map['dexSha256']?.toString(),
    );
  }
}

class AndroidSecurityService {
  static const MethodChannel _channel = MethodChannel(
    'com.chloemlla.nexai/security',
  );

  static bool get _available => !kIsWeb && Platform.isAndroid;

  Future<AndroidNativeResult<AndroidSecuritySnapshot>>
  getSecuritySnapshot() async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(
      'getSecuritySnapshot',
    );
    return AndroidNativeResult.fromEnvelope(
      envelope,
      (data) => AndroidSecuritySnapshot.fromMap(asStringMap(data)),
    );
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> getOverlayRisk() async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>('getOverlayRisk');
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }

  Future<AndroidNativeResult<Map<String, dynamic>>> getStartupSecuritySnapshot() async {
    if (!_available) return AndroidNativeResult.unsupported();
    final envelope = await _channel.invokeMethod<Object?>(
      'getStartupSecuritySnapshot',
    );
    return AndroidNativeResult.fromEnvelope(envelope, asStringMap);
  }

  Future<void> setSecureScreen({required bool enable}) async {
    if (!_available) return;
    await _channel.invokeMethod<void>('setSecureScreen', {'enable': enable});
  }
}
