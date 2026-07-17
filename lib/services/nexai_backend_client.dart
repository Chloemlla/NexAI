import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/app_security.dart';
import '../utils/request_signer.dart';
import 'pinned_http_client.dart';

class NexaiBackendTimeoutException implements Exception {
  NexaiBackendTimeoutException(this.method, this.url, this.timeout);

  final String method;
  final Uri url;
  final Duration timeout;

  @override
  String toString() =>
      'NexaiBackendTimeoutException: $method $url exceeded ${timeout.inSeconds}s';
}

class NexaiBackendClient {
  NexaiBackendClient._();

  static const requestTimeout = Duration(seconds: 30);
  static http.Client? _client;

  static Future<http.Client> _get() async {
    _client ??= await buildPinnedHttpClient();
    return _client!;
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
  }) {
    return signRequest(
      method: method,
      path: url.path,
      headers: _base(headers),
      body: body,
    );
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final signed = await _signedHeaders(
      method: 'GET',
      url: url,
      headers: headers,
    );
    return _withTimeout('GET', url, (await _get()).get(url, headers: signed));
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final signed = await _signedHeaders(
      method: 'POST',
      url: url,
      headers: headers,
      body: _bodyString(body),
    );
    return _withTimeout(
      'POST',
      url,
      (await _get()).post(url, headers: signed, body: body),
    );
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final signed = await _signedHeaders(
      method: 'PUT',
      url: url,
      headers: headers,
      body: _bodyString(body),
    );
    return _withTimeout(
      'PUT',
      url,
      (await _get()).put(url, headers: signed, body: body),
    );
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final signed = await _signedHeaders(
      method: 'PATCH',
      url: url,
      headers: headers,
      body: _bodyString(body),
    );
    return _withTimeout(
      'PATCH',
      url,
      (await _get()).patch(url, headers: signed, body: body),
    );
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final signed = await _signedHeaders(
      method: 'DELETE',
      url: url,
      headers: headers,
    );
    return _withTimeout(
      'DELETE',
      url,
      (await _get()).delete(url, headers: signed),
    );
  }

  static Future<http.Response> _withTimeout(
    String method,
    Uri url,
    Future<http.Response> request,
  ) {
    return request.timeout(
      requestTimeout,
      onTimeout: () {
        debugPrint('NexAI Backend: $method $url timed out');
        throw NexaiBackendTimeoutException(method, url, requestTimeout);
      },
    );
  }
}
