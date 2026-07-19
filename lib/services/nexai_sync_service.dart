/// NexAI Cloud Sync API Service
/// Handles all communication with the NexAI backend sync endpoints
library;

import 'dart:convert';

import 'nexai_backend_client.dart';

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
    final response = await NexaiBackendClient.get(
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
    final response = await NexaiBackendClient.put(
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
    final response = await NexaiBackendClient.delete(
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
    final response = await NexaiBackendClient.get(
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

  /// POST /sync/v2/incremental — 端到端加密增量同步（服务端已支持）
  static Future<Map<String, dynamic>?> postIncrementalSyncV2({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/sync/v2/incremental'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (_isSuccess(response.statusCode)) {
      final decoded = _tryDecode(response.body);
      if (decoded?['success'] == true) {
        return decoded?['data'] as Map<String, dynamic>? ?? {};
      }
    }
    return null;
  }

}
