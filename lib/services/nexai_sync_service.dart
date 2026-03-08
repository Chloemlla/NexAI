/// NexAI Cloud Sync API Service
/// Handles all communication with the NexAI backend sync endpoints
import 'dart:convert';
import 'package:http/http.dart' as http;

const String _defaultBaseUrl = 'https://api.951100.xyz/api/nexai';

class NexaiSyncApi {
  static String _baseUrl = _defaultBaseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// GET /sync — 获取全部同步数据
  static Future<Map<String, dynamic>?> getSyncData({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/sync'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return body['data'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  /// PUT /sync — 全量上传同步数据
  static Future<bool> putSyncData({
    required String accessToken,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/sync'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    return false;
  }

  /// PATCH /sync/:category — 按类别局部更新
  static Future<bool> patchSyncData({
    required String accessToken,
    required String category,
    required dynamic data,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/sync/$category'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': data}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    return false;
  }

  /// DELETE /sync — 清除同步数据
  static Future<bool> deleteSyncData({required String accessToken}) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/sync'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    return false;
  }

  /// GET /sync/meta — 获取同步元信息
  static Future<Map<String, dynamic>?> getSyncMeta({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/sync/meta'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return body['data'] as Map<String, dynamic>?;
      }
    }
    return null;
  }
}
