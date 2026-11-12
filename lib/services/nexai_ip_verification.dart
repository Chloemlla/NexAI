/// Synapse **首访闸门**（`/api/ip-verification`）在 NexAI 侧的实现。
///
/// 闸门开启时（线上 chloemlla.com 就是开着的），主机根下 `/api/**` 的每个请求都要带
/// `X-Fingerprint` 与 `X-IP-Verification-Token`；缺令牌一律 `403 {errorCode:
/// "IP_VERIFICATION_REQUIRED", requiresVerification:true}`。NexAI 之前完全不参与这套握手，
/// 于是注册、登录、同步、制品、安全上报**每一个**请求都被闸门挡在业务之前 —— 用户看到的
/// 是「账号密码都对，就是登不进去 / 一串 403」。
///
/// 语义与 Project-Lumen / 网页端一致：
///  - 干净 IP 由服务端直接签发 `issuedBy: "auto"` 的令牌，不打扰用户；
///  - 被标记的 IP 回 `requiresVerification: true`，需要人机验证 —— NexAI 没有验证码容器，
///    此时**不伪造、不重试轰炸**，记下原因（[lastFailureReason]）并把原 403 交回调用方；
///  - 令牌有效期听服务端（`expiresAt` 优先，其次 `tokenTtlMinutes`），本地提前 60 秒换新；
///  - 令牌只活在进程内：它绑定 (指纹, IP) 且只有 40 分钟，落盘既没必要也多一份泄露面。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'nexai_client_identity.dart';

class NexaiIpVerification {
  NexaiIpVerification._();

  static const String fingerprintHeader = 'X-Fingerprint';
  static const String tokenHeader = 'X-IP-Verification-Token';
  static const String errorCode = 'IP_VERIFICATION_REQUIRED';
  static const String bannedErrorText = 'IP已被封禁';

  static const String _sessionPath = '/api/ip-verification/session';
  static const int _defaultTtlMinutes = 40;
  static const Duration _refreshSkew = Duration(seconds: 60);
  static const Duration _retryCooldown = Duration(minutes: 5);
  static const Duration _requestTimeout = Duration(seconds: 8);

  static String? _token;
  static DateTime? _expiresAt;
  static DateTime? _blockedUntil;
  static Future<String?>? _inflight;

  /// 最近一次握手失败的原因（`requires_human` / `ip_banned` / `http_403` / `exception`…）。
  /// 只用于诊断与界面文案，不参与任何判定。
  static String? lastFailureReason;

  /// 服务端要求人机验证或 IP 被封禁时为真：界面可以据此给出「换个网络」这类可执行建议。
  static bool get requiresInteractiveVerification => lastFailureReason == 'requires_human';

  static bool get isBanned => lastFailureReason == 'ip_banned';

  /// 当前是否持有可用令牌（诊断用）。
  static bool get hasFreshToken => _isFresh(_expiresAt, DateTime.now());

  /// 给一次业务请求附加的闸门头。
  ///
  /// 没有可用令牌时只带指纹：服务端会回 403，由 [NexaiBackendClient] 走「握手 + 重放」。
  static Future<Map<String, String>> headersFor() async {
    final fingerprint = await _safeFingerprint();
    if (fingerprint.isEmpty) return const {};
    final headers = <String, String>{fingerprintHeader: fingerprint};
    final token = _token;
    if (token != null && _isFresh(_expiresAt, DateTime.now())) {
      headers[tokenHeader] = token;
    }
    return headers;
  }

  /// 拿一个可用令牌：复用缓存 → 向服务端要一个。失败返回 null，绝不抛错。
  static Future<String?> refresh(
    Uri url, {
    required http.Client client,
    bool force = false,
  }) async {
    final fingerprint = await _safeFingerprint();
    if (fingerprint.isEmpty) {
      lastFailureReason = 'missing_fingerprint';
      return null;
    }
    final now = DateTime.now();
    final cached = _token;
    if (!force && cached != null && _isFresh(_expiresAt, now)) return cached;
    final blockedUntil = _blockedUntil;
    if (!force && blockedUntil != null && now.isBefore(blockedUntil)) return null;

    final pending = _inflight;
    if (pending != null) return pending;

    final task = _requestToken(url, client, fingerprint);
    _inflight = task;
    try {
      return await task;
    } finally {
      if (identical(_inflight, task)) _inflight = null;
    }
  }

  /// 403 且是闸门拦截：说明请求根本没进业务逻辑，重放一次是安全的。
  static bool isVerificationRequired(http.Response response) {
    if (response.statusCode != 403) return false;
    final body = response.body;
    return body.contains(errorCode) || body.contains('"requiresVerification":true');
  }

  static bool isBannedResponse(http.Response response) {
    if (response.statusCode != 403) return false;
    final body = response.body;
    return body.contains(bannedErrorText) ||
        body.contains('"IP_BANNED"') ||
        body.contains('"banned":true');
  }

  /// 测试注入：单测环境没有 platform channel，指纹取不到就测不了握手。
  @visibleForTesting
  static Future<String> Function()? fingerprintOverride;

  /// 测试用：清掉进程内的令牌/冷却状态。
  @visibleForTesting
  static void resetForTest() {
    _token = null;
    _expiresAt = null;
    _blockedUntil = null;
    _inflight = null;
    lastFailureReason = null;
  }

  // ── 内部 ─────────────────────────────────────────────────────────────

  static Future<String?> _requestToken(
    Uri url,
    http.Client client,
    String fingerprint,
  ) async {
    final sessionUri = _sessionUri(url);
    if (sessionUri == null) {
      lastFailureReason = 'missing_origin';
      return null;
    }
    try {
      final response = await client
          .post(
            sessionUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'NexAI-Flutter',
            },
            body: jsonEncode({'fingerprint': fingerprint}),
          )
          .timeout(_requestTimeout);
      final text = response.body;
      final decoded = _decode(text);

      if (isBannedResponse(response) || (decoded?['banned'] == true)) {
        _blockNow();
        lastFailureReason = 'ip_banned';
        return null;
      }
      if (response.statusCode >= 400) {
        _blockNow();
        lastFailureReason = 'http_${response.statusCode}';
        return null;
      }
      if (decoded == null) {
        _blockNow();
        lastFailureReason = 'invalid_json';
        return null;
      }

      final token = (decoded['token'] as Object?)?.toString().trim() ?? '';
      if (token.isNotEmpty && decoded['verified'] != false) {
        _token = token;
        _expiresAt = _resolveExpiry(decoded);
        _blockedUntil = null;
        lastFailureReason = null;
        return token;
      }
      if (decoded['requiresVerification'] == true) {
        _blockNow();
        final reason = (decoded['reason'] ?? decoded['error'])?.toString();
        lastFailureReason = reason == 'ip_risk_blocked' ? 'ip_banned' : 'requires_human';
        return null;
      }
      // verified 但没令牌：服务端闸门没开（或该路径被豁免），交给冷却窗口，别反复撞。
      _blockNow();
      lastFailureReason = 'no_token_issued';
      return null;
    } on TimeoutException {
      _blockNow();
      lastFailureReason = 'timeout';
      return null;
    } catch (error) {
      _blockNow();
      lastFailureReason = 'exception';
      debugPrint('NexAI IP 验证握手失败: $error');
      return null;
    }
  }

  static void _blockNow() {
    _token = null;
    _expiresAt = null;
    _blockedUntil = DateTime.now().add(_retryCooldown);
  }

  static DateTime _resolveExpiry(Map<String, dynamic> json) {
    final expiresAt = json['expiresAt']?.toString();
    if (expiresAt != null && expiresAt.isNotEmpty) {
      final parsed = DateTime.tryParse(expiresAt);
      if (parsed != null) return parsed.toUtc();
    }
    final ttlMinutes = int.tryParse('${json['tokenTtlMinutes'] ?? ''}') ?? _defaultTtlMinutes;
    final effectiveMinutes = ttlMinutes > 0 ? ttlMinutes : _defaultTtlMinutes;
    return DateTime.now().toUtc().add(Duration(minutes: effectiveMinutes));
  }

  static bool _isFresh(DateTime? expiresAt, DateTime now) {
    if (expiresAt == null) return false;
    return now.toUtc().add(_refreshSkew).isBefore(expiresAt);
  }

  static Uri? _sessionUri(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) return null;
    return Uri(scheme: url.scheme, host: url.host, port: url.hasPort ? url.port : null, path: _sessionPath);
  }

  static Map<String, dynamic>? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _safeFingerprint() async {
    try {
      final override = fingerprintOverride;
      if (override != null) return await override();
      return await NexaiClientIdentity.deviceId();
    } catch (_) {
      return '';
    }
  }
}
