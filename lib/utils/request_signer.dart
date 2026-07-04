/// HMAC-SHA256 request signing for NexAI backend API.
///
/// Each request to tts.chloemlla.com is signed with a key derived from:
///   device_id (unpredictable, hardware-bound) + timestamp_window
///
/// This prevents API scraping: even if an attacker extracts the algorithm
/// from the binary, they cannot forge signatures without the actual device_id.
///
/// Header format:
///   X-NexAI-Ts:  Unix timestamp (seconds)
///   X-NexAI-Sig: base64(HMAC-SHA256(message, derivedKey))
///
/// Message format (canonical):
///   METHOD\nPATH\nTIMESTAMP\nSHA256(body_utf8_bytes)
///
/// Key derivation:
///   derivedKey = HMAC-SHA256(deviceId, "nexai-req-v1:" + windowId)
///   windowId   = timestamp / 30   (30-second rolling window, anti-replay)
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Public API ───────────────────────────────────────────────────────────────

class RequestSigningException implements Exception {
  RequestSigningException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'RequestSigningException: $message'
      : 'RequestSigningException: $message ($cause)';
}

/// Adds HMAC-signing headers to the given [headers] map.
/// Backend calls require signing; failures are surfaced to the caller.
Future<Map<String, String>> signRequest({
  required String method,
  required String path,
  required Map<String, String> headers,
  String body = '',
}) async {
  if (kIsWeb) {
    throw RequestSigningException('Request signing is not supported on Web');
  }
  try {
    final ts = _nowSeconds();
    final sig = await _computeSignature(
      method: method.toUpperCase(),
      path: path,
      timestamp: ts,
      body: body,
    );
    return {...headers, 'X-NexAI-Ts': ts.toString(), 'X-NexAI-Sig': sig};
  } catch (e) {
    debugPrint('RequestSigner: signing error: $e');
    throw RequestSigningException('Unable to sign backend request', e);
  }
}

// ─── Internal ─────────────────────────────────────────────────────────────────

String? _cachedDeviceId;
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);
const _fallbackInstallIdKey = 'nexai.request_signer.install_id.v1';

/// Returns a stable device identifier.
/// Combines several hardware identifiers to maximise uniqueness; none are PII.
Future<String> _getDeviceId() async {
  if (_cachedDeviceId != null) return _cachedDeviceId!;
  final info = DeviceInfoPlugin();
  String raw;
  try {
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      // Android ID changes on factory reset — acceptable for our threat model.
      raw = '${a.id}|${a.model}|${a.product}';
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      raw = '${i.identifierForVendor ?? ''}|${i.model}';
    } else if (Platform.isWindows) {
      final w = await info.windowsInfo;
      raw = '${w.deviceId}|${w.computerName}';
    } else {
      raw = Platform.localHostname;
    }
  } catch (e) {
    raw = await _getOrCreateInstallId();
  }
  _cachedDeviceId = sha256
      .convert(utf8.encode(raw))
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return _cachedDeviceId!;
}

Future<String> _getOrCreateInstallId() async {
  final existing = await _storage.read(key: _fallbackInstallIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final id = 'install_${base64Url.encode(bytes).replaceAll('=', '')}';
  await _storage.write(key: _fallbackInstallIdKey, value: id);
  return id;
}

Future<String> _computeSignature({
  required String method,
  required String path,
  required int timestamp,
  required String body,
}) async {
  final deviceId = await _getDeviceId();
  final windowId = (timestamp ~/ 30).toString();

  // Derive a per-window key from the device ID
  final deviceIdBytes = utf8.encode(deviceId);
  final windowLabel = utf8.encode('nexai-req-v1:$windowId');
  final derivedKey = Hmac(sha256, deviceIdBytes).convert(windowLabel).bytes;

  // Build canonical message
  final bodyHash = sha256.convert(utf8.encode(body)).toString();
  final message = '$method\n$path\n$timestamp\n$bodyHash';

  final sig = Hmac(sha256, derivedKey).convert(utf8.encode(message));
  return base64.encode(sig.bytes);
}

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
