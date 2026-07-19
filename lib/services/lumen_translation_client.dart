/// DeepLX-style public translation client aligned with Project-Lumen.
///
/// Endpoints (host defaults to tts.chloemlla.com):
///   GET  /api/public/deeplx/config
///   POST /api/public/deeplx/translate
///
/// Request signing mirrors Project-Lumen's X-Lumen-* headers so the public
/// translation service can verify clients consistently.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'pinned_http_client.dart';

class LumenTranslationException implements Exception {
  LumenTranslationException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class LumenTranslationConfig {
  const LumenTranslationConfig({
    required this.enabled,
    required this.requiresApiKey,
    required this.baseUrl,
    required this.endpointPath,
  });

  final bool enabled;
  final bool requiresApiKey;
  final String baseUrl;
  final String endpointPath;

  factory LumenTranslationConfig.fromJson(Map<String, dynamic> json) {
    return LumenTranslationConfig(
      enabled: json['enabled'] == true,
      requiresApiKey: json['requiresApiKey'] == true,
      baseUrl: (json['baseUrl'] ?? '').toString(),
      endpointPath: (json['endpointPath'] ?? '').toString(),
    );
  }
}

class LumenTranslationResult {
  const LumenTranslationResult({
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.alternatives,
  });

  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final List<String> alternatives;

  factory LumenTranslationResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSource,
    required String fallbackTarget,
  }) {
    final alternativesRaw = json['alternatives'];
    final alternatives = <String>[];
    if (alternativesRaw is List) {
      for (final item in alternativesRaw) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) alternatives.add(value);
      }
    }
    return LumenTranslationResult(
      translatedText: (json['translatedText'] ?? '').toString().trim(),
      sourceLang: (json['sourceLang'] ?? fallbackSource).toString(),
      targetLang: (json['targetLang'] ?? fallbackTarget).toString(),
      alternatives: alternatives,
    );
  }
}

class LumenTranslationClient {
  LumenTranslationClient({
    this.baseUrl = defaultBaseUrl,
    http.Client? client,
  }) : _client = client;

  static const defaultBaseUrl = 'https://tts.chloemlla.com';
  static const maxInputChars = 5000;
  static const requestTimeout = Duration(seconds: 15);

  /// Compile-time override; falls back to Project-Lumen local/dev secret.
  static const requestSigningSecret = String.fromEnvironment(
    'LUMEN_REQUEST_SIGNING_SECRET',
    defaultValue: 'project-lumen-local-request-signing-key',
  );

  final String baseUrl;
  http.Client? _client;

  Uri _uri(String path) {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$root$cleanPath');
  }

  Future<http.Client> _http({bool forceRebuild = false}) async {
    if (forceRebuild) {
      _client?.close();
      _client = null;
    }
    if (_client != null) return _client!;
    if (kIsWeb) {
      _client = http.Client();
      return _client!;
    }
    _client = await buildPinnedHttpClient();
    return _client!;
  }

  Future<void> _recoverFromTlsFailure() async {
    try {
      await invalidatePinnedClientState();
    } catch (_) {}
    _client?.close();
    _client = null;
  }

  Future<LumenTranslationConfig> fetchConfig() async {
    final response = await _send(
      method: 'GET',
      path: '/api/public/deeplx/config',
    );
    return LumenTranslationConfig.fromJson(response);
  }

  Future<LumenTranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw LumenTranslationException('请输入要翻译的文本');
    }
    if (trimmed.runes.length > maxInputChars) {
      throw LumenTranslationException('文本过长，请控制在 $maxInputChars 个字符以内');
    }

    final body = jsonEncode({
      'text': trimmed,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    });
    final response = await _send(
      method: 'POST',
      path: '/api/public/deeplx/translate',
      body: body,
    );
    final result = LumenTranslationResult.fromJson(
      response,
      fallbackSource: sourceLang,
      fallbackTarget: targetLang,
    );
    if (result.translatedText.isEmpty) {
      throw LumenTranslationException('翻译失败：结果为空');
    }
    return result;
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    String? body,
  }) async {
    final client = await _http();
    final uri = _uri(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'NexAI-Flutter',
      ..._lumenSignHeaders(
        method: method,
        uri: uri,
        body: body ?? '',
      ),
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }

    late http.Response response;
    try {
      response = await _rawSend(
        client: client,
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      );
    } on HandshakeException {
      // Stale certificate pin or rotated leaf cert: clear pin and retry once.
      await _recoverFromTlsFailure();
      try {
        final retryClient = await _http(forceRebuild: true);
        response = await _rawSend(
          client: retryClient,
          method: method,
          uri: uri,
          headers: headers,
          body: body,
        );
      } catch (retryError) {
        throw LumenTranslationException(
          '证书握手失败，已尝试自动恢复仍未成功。请到设置 > 安全 > 证书固定清除缓存后重试。\n详情：$retryError',
        );
      }
    } on TlsException {
      await _recoverFromTlsFailure();
      try {
        final retryClient = await _http(forceRebuild: true);
        response = await _rawSend(
          client: retryClient,
          method: method,
          uri: uri,
          headers: headers,
          body: body,
        );
      } catch (retryError) {
        throw LumenTranslationException(
          'TLS 连接失败，已尝试自动恢复仍未成功。请检查网络/证书或清除证书缓存后重试。\n详情：$retryError',
        );
      }
    } catch (error) {
      final msg = error.toString();
      if (msg.contains('CERTIFICATE_VERIFY_FAILED') ||
          msg.toLowerCase().contains('handshake')) {
        await _recoverFromTlsFailure();
        try {
          final retryClient = await _http(forceRebuild: true);
          response = await _rawSend(
            client: retryClient,
            method: method,
            uri: uri,
            headers: headers,
            body: body,
          );
        } catch (retryError) {
          throw LumenTranslationException(
            '证书校验失败，已尝试自动恢复仍未成功。请到设置清除证书缓存后重试。\n详情：$retryError',
          );
        }
      } else {
        throw LumenTranslationException('网络错误：$error');
      }
    }

    final raw = response.body;
    Map<String, dynamic> json = const {};
    if (raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      } else if (decoded is Map) {
        json = decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw LumenTranslationException(
        _errorMessage(json, response.statusCode),
        statusCode: response.statusCode,
      );
    }
    return json;
  }

  Future<http.Response> _rawSend({
    required http.Client client,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    if (method.toUpperCase() == 'GET') {
      return client.get(uri, headers: headers).timeout(requestTimeout);
    }
    return client
        .post(uri, headers: headers, body: body)
        .timeout(requestTimeout);
  }

  static Map<String, String> _lumenSignHeaders({
    required String method,
    required Uri uri,
    required String body,
  }) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _randomNonce();
    final bodySha = sha256.convert(utf8.encode(body)).toString();
    final values = <String, String>{
      'bodySha256': bodySha,
      'method': method.toUpperCase(),
      'nonce': nonce,
      'path': uri.path,
      'query': uri.query,
      'timestamp': timestamp,
    };
    final keys = values.keys.toList()..sort();
    final canonical = keys.map((k) => '$k=${values[k]}').join('\n');
    final secret = requestSigningSecret.trim().isEmpty
        ? 'project-lumen-local-request-signing-key'
        : requestSigningSecret.trim();
    final digest = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(canonical));
    return {
      'X-Lumen-Timestamp': timestamp,
      'X-Lumen-Nonce': nonce,
      'X-Lumen-Signature': digest.toString(),
    };
  }

  static String _randomNonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _errorMessage(Map<String, dynamic> json, int statusCode) {
    final error = json['error'];
    if (error is Map && error['message'] != null) {
      final msg = error['message'].toString().trim();
      if (msg.isNotEmpty) return msg;
    }
    final direct = (json['error'] ?? json['message'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    return switch (statusCode) {
      429 => '翻译请求过于频繁，请稍后再试',
      503 => '翻译服务未配置或暂时不可用',
      _ => '翻译失败（HTTP $statusCode）',
    };
  }
}

/// Lumen-aligned language options for the translation tool.
class LumenTranslationLanguages {
  static const source = <String, String>{
    'auto': '自动检测',
    'ZH': '中文',
    'EN': 'English',
    'JA': '日本語',
    'KO': '한국어',
  };

  static const target = <String, String>{
    'ZH': '中文',
    'EN': 'English',
    'JA': '日本語',
    'KO': '한국어',
  };
}
