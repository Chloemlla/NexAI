import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexai/services/nexai_ip_verification.dart';

/// Synapse 首访闸门（`/api/ip-verification`）在 NexAI 侧的契约：
///
/// 线上 chloemlla.com 的闸门是开着的，`/api/nexai/**` 的每个请求都必须带
/// `X-Fingerprint` 与 `X-IP-Verification-Token`。NexAI 之前完全不参与握手，
/// 于是注册/登录/同步/制品/安全上报全被 403 挡在业务之前。这里锁住三件事：
///  1. 403 且带错误码/`requiresVerification` 才认定为闸门拦截（别的 403 不许乱重放）；
///  2. 干净 IP 能拿到令牌并被后续请求复用；
///  3. 要人机验证/IP 被封时不硬撞（冷却窗口内不再发请求），并把原因留给界面。
/// `package:http` 的 Response(String) 默认按 **latin-1** 编码 body，写中文会直接抛
/// 「Contains invalid characters」；统一走 UTF-8 字节 + 明确的 charset。
http.Response jsonResponse(Object payload, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(payload)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  const fingerprint = 'abc12345def';

  setUp(() {
    NexaiIpVerification.resetForTest();
    NexaiIpVerification.fingerprintOverride = () async => fingerprint;
  });

  tearDown(() {
    NexaiIpVerification.fingerprintOverride = null;
    NexaiIpVerification.resetForTest();
  });

  test('只在 403 + 闸门错误码时认定为闸门拦截', () {
    final gated = jsonResponse({
      'success': false,
      'error': 'IP verification required',
      'errorCode': 'IP_VERIFICATION_REQUIRED',
      'requiresVerification': true,
    }, 403);
    expect(NexaiIpVerification.isVerificationRequired(gated), isTrue);

    final requiresFlagOnly = jsonResponse({'requiresVerification': true}, 403);
    expect(NexaiIpVerification.isVerificationRequired(requiresFlagOnly), isTrue);

    expect(
      NexaiIpVerification.isVerificationRequired(
        jsonResponse({'error': '未授权', 'code': 'NEXAI_AUTH_REQUIRED'}, 403),
      ),
      isFalse,
      reason: '普通 403（令牌失效等）重放没有意义',
    );
    expect(
      NexaiIpVerification.isVerificationRequired(jsonResponse({}, 500)),
      isFalse,
    );
  });

  test('干净 IP 直接拿到 auto 令牌，并在后续请求里复用', () async {
    var sessionCalls = 0;
    final client = MockClient((request) async {
      sessionCalls += 1;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://chloemlla.com/api/ip-verification/session',
        reason: '握手必须打到主机根，而不是 /api/nexai 下面',
      );
      expect(jsonDecode(request.body)['fingerprint'], fingerprint);
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 30))
          .toIso8601String();
      return jsonResponse({
        'success': true,
        'verified': true,
        'requiresVerification': false,
        'token': 'token-1',
        'expiresAt': expiresAt,
        'issuedBy': 'auto',
      }, 200);
    });

    final url = Uri.parse('https://chloemlla.com/api/nexai/auth/me');
    final token = await NexaiIpVerification.refresh(url, client: client, force: true);
    expect(token, 'token-1');

    final headers = await NexaiIpVerification.headersFor();
    expect(headers[NexaiIpVerification.fingerprintHeader], fingerprint);
    expect(headers[NexaiIpVerification.tokenHeader], 'token-1');
    expect(NexaiIpVerification.hasFreshToken, isTrue);

    // 缓存命中：不该再打一次握手。
    await NexaiIpVerification.refresh(url, client: client);
    expect(sessionCalls, 1);
  });

  test('需要人机验证时返回 null、标记原因，且冷却窗口内不再请求', () async {
    var sessionCalls = 0;
    final client = MockClient((request) async {
      sessionCalls += 1;
      return jsonResponse({
        'success': true,
        'verified': false,
        'requiresVerification': true,
        'reason': 'risk_score',
      }, 200);
    });

    final url = Uri.parse('https://chloemlla.com/api/nexai/auth/login');
    expect(await NexaiIpVerification.refresh(url, client: client, force: true), isNull);
    expect(NexaiIpVerification.requiresInteractiveVerification, isTrue);
    expect(NexaiIpVerification.hasFreshToken, isFalse);

    // 冷却窗口：普通调用（force=false）不再撞闸门。
    expect(await NexaiIpVerification.refresh(url, client: client), isNull);
    expect(sessionCalls, 1);
  });

  test('IP 被封禁时不把令牌当成功，并给出 banned 状态', () async {
    final client = MockClient((request) async {
      return jsonResponse({
        'success': false,
        'error': 'IP已被封禁',
        'banned': true,
        'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
      }, 403);
    });

    final token = await NexaiIpVerification.refresh(
      Uri.parse('https://chloemlla.com/api/nexai/sync/v2'),
      client: client,
      force: true,
    );
    expect(token, isNull);
    expect(NexaiIpVerification.isBanned, isTrue);
    expect(NexaiIpVerification.hasFreshToken, isFalse);
  });

  test('握手抛异常/超时也不外泄，业务请求照原样拿到 403', () async {
    final client = MockClient((request) async {
      throw const SocketExceptionStub();
    });

    final token = await NexaiIpVerification.refresh(
      Uri.parse('https://chloemlla.com/api/nexai/artifacts'),
      client: client,
      force: true,
    );
    expect(token, isNull);
    expect(NexaiIpVerification.lastFailureReason, 'exception');
  });

  test('取不到指纹时只返回空头，不发注定被拒的请求', () async {
    NexaiIpVerification.fingerprintOverride = () async => '';
    var sessionCalls = 0;
    final client = MockClient((request) async {
      sessionCalls += 1;
      return jsonResponse({}, 200);
    });

    expect(await NexaiIpVerification.headersFor(), isEmpty);
    expect(
      await NexaiIpVerification.refresh(
        Uri.parse('https://chloemlla.com/api/nexai/auth/me'),
        client: client,
        force: true,
      ),
      isNull,
    );
    expect(sessionCalls, 0);
    expect(NexaiIpVerification.lastFailureReason, 'missing_fingerprint');
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
