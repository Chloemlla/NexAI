import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/app_security.dart';
import '../utils/nexai_api_error.dart';
import '../utils/request_signer.dart';
import '../utils/nexai_soft_sig_notice.dart';
import 'pinned_http_client.dart';

class NexaiBackendTimeoutException extends NexaiApiError {
  NexaiBackendTimeoutException(String method, Uri url, Duration timeout)
      : super(
          stage: 'transport',
          code: 'CLIENT_TIMEOUT',
          message: '$method $url 超过 ${timeout.inSeconds}s 未响应',
          path: url.path,
          method: method,
        );
}

class NexaiBackendClient {
  NexaiBackendClient._();

  static const requestTimeout = Duration(seconds: 30);
  static http.Client? _client;

  /// Optional explicit signing key override (e.g. refreshToken).
  static String? overrideSigningKey;
  static String? overrideKeyId;

  static Future<http.Client> _get() async {
    try {
      _client ??= await buildPinnedHttpClient();
      return _client!;
    } catch (e) {
      throw NexaiApiError(
        stage: 'tls_pinning',
        code: 'CLIENT_TLS_PIN',
        message: '安全连接（证书钉扎）失败: $e',
        cause: e,
      );
    }
  }

  static Map<String, String> _base([Map<String, String>? extra]) {
    final security = AppSecurity.instance;
    final headers = <String, String>{
      ...?extra,
      'X-Device-Risk-Score': security.riskScore.toString(),
      'X-Device-Risk-Level': security.riskLevel,
      'X-Device-Compromised': security.isCompromised ? '1' : '0',
      'X-Device-Root': security.isCompromised ? '1' : '0',
      'X-Device-Debugger': security.isDebuggerAttached ? '1' : '0',
      'X-Device-Adb': security.isAdbEnabled ? '1' : '0',
      'X-Device-Dev-Settings':
          security.isDevelopmentSettingsEnabled ? '1' : '0',
      'X-Device-Debug-Build': security.isDebugBuild ? '1' : '0',
      'X-Device-Tracer': security.isTracerAttached ? '1' : '0',
      'X-Device-Anti-Debug-Score':
          security.antiDebugScore.toStringAsFixed(2),
      'X-Device-Emulator': security.isEmulator ? '1' : '0',
      'X-Device-VPN': security.isVpnActive ? '1' : '0',
      'X-Device-Signature-Valid': security.isSignatureValid ? '1' : '0',
      'X-Device-Hash-Valid': security.isApkHashValid ? '1' : '0',
    };
    if (security.isCompromised) {
      headers['X-NexAI-Device'] = 'flagged';
    }
    return headers;
  }

  static String _bodyString(Object? body) =>
      body is String ? body : (body?.toString() ?? '');

  static Future<Map<String, String>> _signedHeaders({
    required String method,
    required Uri url,
    required Map<String, String>? headers,
    String body = '',
  }) async {
    final base = _base(headers);
    try {
      return await signRequestV2(
        method: method,
        path: url.path,
        headers: base,
        body: body,
        signingKey: overrideSigningKey,
        keyId: overrideKeyId,
      );
    } on RequestSigningException catch (e) {
      final hasBearer = _hasBearer(headers) || _hasBearer(base);
      // Soft-client: allow unsigned ONLY when not authenticated yet
      // (login/bootstrap before token/app secret). Once Authorization is present,
      // unsigned requests are forbidden.
      if (!hasBearer &&
          (e.code == 'CLIENT_SIGN_NO_KEY' || e.code == 'CLIENT_SIGN_WEB')) {
        debugPrint('NexAI Backend: signing skipped (${e.code}): ${e.message}');
        return {
          ...base,
          'X-NexAI-Sig-Skipped': e.code,
        };
      }
      throw NexaiApiError(
        stage: e.stage,
        code: e.code,
        message: e.message,
        path: url.path,
        method: method,
        cause: e,
      );
    } catch (e) {
      throw NexaiApiError(
        stage: 'request_sign',
        code: 'CLIENT_SIGN_NO_KEY',
        message: '请求签名失败: $e',
        path: url.path,
        method: method,
        cause: e,
      );
    }
  }

  static bool _hasBearer(Map<String, String>? headers) {
    if (headers == null) return false;
    final auth = headers['Authorization'] ?? headers['authorization'];
    if (auth == null) return false;
    final trimmed = auth.trimLeft();
    return trimmed.length > 7 &&
        trimmed.substring(0, 6).toLowerCase() == 'bearer' &&
        (trimmed.codeUnitAt(6) == 0x20 || trimmed.codeUnitAt(6) == 0x09);
  }

  static Future<http.Response> _send(
    String method,
    Uri url,
    Future<http.Response> Function(Map<String, String> headers) send,
    String body,
    Map<String, String>? headers,
  ) async {
    final signed = await _signedHeaders(
      method: method,
      url: url,
      headers: headers,
      body: body,
    );
    try {
      final response = await send(signed).timeout(
        requestTimeout,
        onTimeout: () {
          throw NexaiBackendTimeoutException(method, url, requestTimeout);
        },
      );
      // Soft mode (NEXAI_REQUEST_SIGNING=soft) may still return 2xx with fail headers.
      NexaiSoftSigNotice.maybeNotifyFromHeaders(
        headers: response.headers,
        path: url.path,
        method: method,
      );
      return response;
    } on NexaiApiError {
      rethrow;
    } on SocketException catch (e) {
      throw NexaiApiError(
        stage: 'transport',
        code: 'CLIENT_TRANSPORT',
        message: '网络连接失败: ${e.message}',
        path: url.path,
        method: method,
        cause: e,
      );
    } on HandshakeException catch (e) {
      throw NexaiApiError(
        stage: 'tls_pinning',
        code: 'CLIENT_TLS_PIN',
        message: 'TLS/证书握手失败: $e',
        path: url.path,
        method: method,
        cause: e,
      );
    } on TlsException catch (e) {
      throw NexaiApiError(
        stage: 'tls_pinning',
        code: 'CLIENT_TLS_PIN',
        message: 'TLS 错误: $e',
        path: url.path,
        method: method,
        cause: e,
      );
    } on TimeoutException {
      throw NexaiBackendTimeoutException(method, url, requestTimeout);
    } catch (e) {
      if (e is NexaiApiError) rethrow;
      throw NexaiApiError(
        stage: 'transport',
        code: 'CLIENT_TRANSPORT',
        message: '网络请求异常: $e',
        path: url.path,
        method: method,
        cause: e,
      );
    }
  }

  static http.Response ensureSuccess(
    http.Response response, {
    String? method,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw nexaiErrorFromResponse(
      statusCode: response.statusCode,
      body: response.body,
      path: response.request?.url.path,
      method: method ?? response.request?.method,
    );
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _send(
      'GET',
      url,
      (h) async => (await _get()).get(url, headers: h),
      '',
      headers,
    );
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final bodyStr = _bodyString(body);
    return _send(
      'POST',
      url,
      (h) async => (await _get()).post(url, headers: h, body: body),
      bodyStr,
      headers,
    );
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final bodyStr = _bodyString(body);
    return _send(
      'PUT',
      url,
      (h) async => (await _get()).put(url, headers: h, body: body),
      bodyStr,
      headers,
    );
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final bodyStr = _bodyString(body);
    return _send(
      'PATCH',
      url,
      (h) async => (await _get()).patch(url, headers: h, body: body),
      bodyStr,
      headers,
    );
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _send(
      'DELETE',
      url,
      (h) async => (await _get()).delete(url, headers: h),
      '',
      headers,
    );
  }
}
