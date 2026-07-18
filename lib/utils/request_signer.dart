/// HMAC-SHA256 request signing for NexAI backend API.
///
/// ## v2 (nexai-sig-v2) — server-verifiable
/// Headers:
///   X-NexAI-Sig-Version: 2
///   X-NexAI-Ts:          Unix timestamp (milliseconds preferred)
///   X-NexAI-Nonce:       random >= 16 chars
///   X-NexAI-Sig:         hex(HMAC-SHA256(key, canonical))
///   X-NexAI-Key-Id:      token | app:v1
///
/// Canonical message:
///   ts\nnonce\nMETHOD\npath\nrawBody
///
/// Key selection (B+C):
///   1) accessToken / explicit signingKey  → Token-bound (B)
///   2) NEXAI_APP_SIGN_SECRET dart-define → App secret (C)
///
/// Server error stages (Happy-TTS 5baba9cd):
///   server_signature / server_auth / rate_limit
/// Soft mode may return 2xx with X-NexAI-Sig-Result/Code headers.
///
/// ## v1 (legacy, soft client-only)
/// DeviceId-derived key — kept for compatibility; backend may ignore.
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
  RequestSigningException(
    this.message, {
    this.cause,
    this.code = 'CLIENT_SIGN_NO_KEY',
    this.stage = 'request_sign',
  });

  final String message;
  final Object? cause;
  final String code;
  final String stage;

  @override
  String toString() => cause == null
      ? 'RequestSigningException($code): $message'
      : 'RequestSigningException($code): $message ($cause)';
}

/// App shared secret for strategy C (compile-time define).
const String kNexaiAppSignSecret = String.fromEnvironment(
  'NEXAI_APP_SIGN_SECRET',
  defaultValue: '',
);

const String kNexaiAppSignKeyId = String.fromEnvironment(
  'NEXAI_APP_SIGN_KEY_ID',
  defaultValue: 'app:v1',
);

/// Adds HMAC-signing headers (v2 when possible).
Future<Map<String, String>> signRequest({
  required String method,
  required String path,
  required Map<String, String> headers,
  String body = '',
  String? signingKey,
  String? keyId,
}) {
  return signRequestV2(
    method: method,
    path: path,
    headers: headers,
    body: body,
    signingKey: signingKey,
    keyId: keyId,
  );
}

/// Server-verifiable signature (nexai-sig-v2).
Future<Map<String, String>> signRequestV2({
  required String method,
  required String path,
  required Map<String, String> headers,
  String body = '',
  String? signingKey,
  String? keyId,
}) async {
  if (kIsWeb) {
    throw RequestSigningException(
      '当前平台（Web）不支持 NexAI 请求签名',
      code: 'CLIENT_SIGN_WEB',
      stage: 'request_sign',
    );
  }

  final tokenFromHeader = _extractBearer(headers['Authorization']);
  String? key;
  var finalKeyId = keyId ?? '';

  if (signingKey != null && signingKey.isNotEmpty) {
    key = signingKey;
    if (finalKeyId.isEmpty) {
      finalKeyId = (tokenFromHeader != null && signingKey == tokenFromHeader)
          ? 'token'
          : kNexaiAppSignKeyId;
    }
  } else if (tokenFromHeader != null && tokenFromHeader.isNotEmpty) {
    key = tokenFromHeader;
    finalKeyId = 'token';
  } else if (kNexaiAppSignSecret.isNotEmpty) {
    key = kNexaiAppSignSecret;
    if (finalKeyId.isEmpty) finalKeyId = kNexaiAppSignKeyId;
  }

  if (key == null || key.isEmpty) {
    throw RequestSigningException(
      '缺少签名密钥：请先登录，或在构建时配置 NEXAI_APP_SIGN_SECRET',
      code: 'CLIENT_SIGN_NO_KEY',
      stage: 'request_sign',
    );
  }

  try {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _randomNonce(24);
    final canonical = '$ts\n$nonce\n${method.toUpperCase()}\n$path\n$body';
    final sig = Hmac(sha256, utf8.encode(key)).convert(utf8.encode(canonical));
    final sigHex = sig.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return {
      ...headers,
      'X-NexAI-Sig-Version': '2',
      'X-NexAI-Ts': ts,
      'X-NexAI-Nonce': nonce,
      'X-NexAI-Sig': sigHex,
      'X-NexAI-Key-Id': finalKeyId,
    };
  } catch (e) {
    if (e is RequestSigningException) rethrow;
    throw RequestSigningException(
      '请求签名计算失败',
      cause: e,
      code: 'CLIENT_SIGN_NO_KEY',
      stage: 'request_sign',
    );
  }
}

String? _extractBearer(String? authorization) {
  if (authorization == null) return null;
  final trimmed = authorization.trimLeft();
  if (trimmed.length < 7) return null;
  if (trimmed.substring(0, 6).toLowerCase() != 'bearer') return null;
  final codeUnit = trimmed.codeUnitAt(6);
  if (codeUnit != 0x20 && codeUnit != 0x09) return null;
  final token = trimmed.substring(7).trim();
  return token.isEmpty ? null : token;
}

String _randomNonce(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random.secure();
  return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
}

// ─── Legacy helpers kept for optional diagnostics ─────────────────────────────

String? _cachedDeviceId;
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);
const _fallbackInstallIdKey = 'nexai.request_signer.install_id.v1';

/// Legacy device id helper (not used for v2 server trust).
Future<String> debugDeviceIdFingerprint() async {
  if (_cachedDeviceId != null) return _cachedDeviceId!;
  final info = DeviceInfoPlugin();
  String raw;
  try {
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
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
  } catch (_) {
    final existing = await _storage.read(key: _fallbackInstallIdKey);
    if (existing != null && existing.isNotEmpty) {
      raw = existing;
    } else {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      raw = 'install_${base64Url.encode(bytes).replaceAll('=', '')}';
      await _storage.write(key: _fallbackInstallIdKey, value: raw);
    }
  }
  _cachedDeviceId = sha256
      .convert(utf8.encode(raw))
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return _cachedDeviceId!;
}
