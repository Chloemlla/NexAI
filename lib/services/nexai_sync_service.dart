/// NexAI Cloud Sync API Service
/// Handles all communication with the NexAI backend sync endpoints
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'pinned_http_client.dart';
import '../utils/app_security.dart';
import '../utils/request_signer.dart';

// ─── Pinned HTTP wrapper ──────────────────────────────────────────────────────
// Lazily initialises a certificate-pinned client on first use.
// Subsequent calls reuse the same instance (connection pool preserved).
class _NexaiHttp {
  static http.Client? _client;

  static Future<http.Client> _get() async {
    _client ??= await buildPinnedHttpClient();
    return _client!;
  }

  /// Base headers: Content-Type + optional compromise honeypot flag.
  static Map<String, String> _base([Map<String, String>? extra]) {
    final h = <String, String>{...?extra};
    // Honeypot: server sees this flag and can throttle/track compromised devices
    if (AppSecurity.instance.isCompromised) {
      h['X-NexAI-Device'] = 'flagged';
    }
    return h;
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final signed = await signRequest(
      method: 'GET',
      path: url.path,
      headers: _base(headers),
    );
    return (await _get()).get(url, headers: signed);
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final bodyStr = body is String ? body : (body?.toString() ?? '');
    final signed = await signRequest(
      method: 'PUT',
      path: url.path,
      headers: _base(headers),
      body: bodyStr,
    );
    return (await _get()).put(url, headers: signed, body: body);
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final signed = await signRequest(
      method: 'DELETE',
      path: url.path,
      headers: _base(headers),
    );
    return (await _get()).delete(url, headers: signed);
  }
}

const String _defaultBaseUrl = 'https://tts.chloemlla.com/api/nexai';

class NexaiSyncApi {
  static String _baseUrl = _defaultBaseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Check if status code indicates success (2xx range)
  static bool _isSuccess(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  /// Safely decode JSON body, returning null on parse errors
  static Map<String, dynamic>? _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// GET /sync/v2 — 获取端到端加密同步数据
  static Future<Map<String, dynamic>?> getSyncDataV2({
    required String accessToken,
  }) async {
    final response = await _NexaiHttp.get(
      Uri.parse('$_baseUrl/sync/v2'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (_isSuccess(response.statusCode)) {
      final body = _tryDecode(response.body);
      if (body?['success'] == true) {
        return body?['data'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  /// PUT /sync/v2 — 全量上传端到端加密同步数据
  static Future<Map<String, dynamic>?> putSyncDataV2({
    required String accessToken,
    required Map<String, dynamic> snapshot,
  }) async {
    final response = await _NexaiHttp.put(
      Uri.parse('$_baseUrl/sync/v2'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(snapshot),
    );

    if (_isSuccess(response.statusCode)) {
      final body = _tryDecode(response.body);
      if (body?['success'] == true) {
        return body?['data'] as Map<String, dynamic>? ?? {};
      }
    }
    return null;
  }

  /// DELETE /sync/v2 — 清除端到端加密同步数据
  static Future<bool> deleteSyncDataV2({required String accessToken}) async {
    final response = await _NexaiHttp.delete(
      Uri.parse('$_baseUrl/sync/v2'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (_isSuccess(response.statusCode)) {
      final body = _tryDecode(response.body);
      return body?['success'] == true;
    }
    return false;
  }

  /// GET /sync/v2/meta — 获取端到端加密同步元信息
  static Future<Map<String, dynamic>?> getSyncMetaV2({
    required String accessToken,
  }) async {
    final response = await _NexaiHttp.get(
      Uri.parse('$_baseUrl/sync/v2/meta'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (_isSuccess(response.statusCode)) {
      final body = _tryDecode(response.body);
      if (body?['success'] == true) {
        return body?['data'] as Map<String, dynamic>?;
      }
    }
    return null;
  }
}
