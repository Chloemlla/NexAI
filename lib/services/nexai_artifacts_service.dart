/// NexAI Artifacts API Service
/// Handles all communication with the NexAI backend artifacts endpoints
library;

import 'dart:convert';
import '../models/artifact.dart';
import 'package:flutter/foundation.dart';

import 'nexai_backend_client.dart';

const String _nexaiBaseUrl = 'https://tts.chloemlla.com/api/nexai';

// ─── Public API ───────────────────────────────────────────────────────────────

class NexaiArtifactsApi {
  static String _baseUrl = _nexaiBaseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get baseUrl => _baseUrl;

  /// POST /artifacts - Create a new artifact
  static Future<ArtifactCreateResponse> createArtifact({
    required String accessToken,
    required String title,
    required String contentType,
    required String content,
    String? language,
    String visibility = 'public',
    String? password,
    String? description,
    List<String>? tags,
    int? expiresInDays,
  }) async {
    // Base64 encode content
    final encodedContent = base64Encode(utf8.encode(content));

    final body = {
      'title': title,
      'content_type': contentType,
      'content': encodedContent,
      'language': ?language,
      'visibility': visibility,
      'password': ?password,
      'description': ?description,
      'tags': ?tags,
      'expires_in_days': ?expiresInDays,
    };

    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/artifacts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ArtifactCreateResponse.fromJson(data['data']);
    } else {
      final error = jsonDecode(response.body);
      debugPrint(
        '[ArtifactsApi] createArtifact ${response.statusCode}: ${response.body}',
      );
      throw Exception(error['error'] ?? 'Failed to create artifact');
    }
  }

  /// GET /artifacts/:shortId - Get artifact by short ID
  static Future<Artifact> getArtifact(
    String shortId, {
    String? password,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (password != null) {
      headers['X-Password'] = password;
    }

    final response = await NexaiBackendClient.get(
      Uri.parse('$_baseUrl/artifacts/$shortId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Artifact.fromJson(data['data']);
    } else if (response.statusCode == 403) {
      final error = jsonDecode(response.body);
      if (error['error'] == 'password_required') {
        throw PasswordRequiredException();
      } else if (error['error'] == 'invalid_password') {
        throw InvalidPasswordException();
      }
      throw Exception(error['message']);
    } else if (response.statusCode == 404) {
      throw ArtifactNotFoundException();
    } else {
      final error = jsonDecode(response.body);
      debugPrint(
        '[ArtifactsApi] getArtifact ${response.statusCode}: ${response.body}',
      );
      throw Exception(error['error'] ?? 'Failed to get artifact');
    }
  }

  /// PATCH /artifacts/:shortId - Update artifact
  static Future<void> updateArtifact(
    String shortId, {
    required String accessToken,
    String? title,
    String? visibility,
    String? password,
    String? description,
    List<String>? tags,
    int? expiresInDays,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (visibility != null) body['visibility'] = visibility;
    if (password != null) body['password'] = password;
    if (description != null) body['description'] = description;
    if (tags != null) body['tags'] = tags;
    if (expiresInDays != null) body['expires_in_days'] = expiresInDays;

    final response = await NexaiBackendClient.patch(
      Uri.parse('$_baseUrl/artifacts/$shortId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      debugPrint(
        '[ArtifactsApi] updateArtifact ${response.statusCode}: ${response.body}',
      );
      throw Exception(error['error'] ?? 'Failed to update artifact');
    }
  }

  /// DELETE /artifacts/:shortId - Delete artifact
  static Future<void> deleteArtifact(
    String shortId, {
    required String accessToken,
  }) async {
    final response = await NexaiBackendClient.delete(
      Uri.parse('$_baseUrl/artifacts/$shortId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      debugPrint(
        '[ArtifactsApi] deleteArtifact ${response.statusCode}: ${response.body}',
      );
      throw Exception(error['error'] ?? 'Failed to delete artifact');
    }
  }

  /// GET /artifacts - List user's artifacts
  static Future<ArtifactListResponse> listArtifacts({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String sort = 'createdAt',
    String order = 'desc',
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
      'order': order,
    };

    final uri = Uri.parse(
      '$_baseUrl/artifacts',
    ).replace(queryParameters: queryParams);

    final response = await NexaiBackendClient.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ArtifactListResponse.fromJson(data['data']);
    } else {
      final error = jsonDecode(response.body);
      debugPrint(
        '[ArtifactsApi] listArtifacts ${response.statusCode}: ${response.body}',
      );
      throw Exception(error['error'] ?? 'Failed to list artifacts');
    }
  }

  /// POST /artifacts/:shortId/view - Record view
  static Future<void> recordView(String shortId) async {
    try {
      await NexaiBackendClient.post(
        Uri.parse('$_baseUrl/artifacts/$shortId/view'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'referer': '', 'user_agent': 'NexAI Flutter App'}),
      );
    } catch (e) {
      debugPrint('[ArtifactsApi] recordView failed for $shortId: $e');
    }
  }
}
