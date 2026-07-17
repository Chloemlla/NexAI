import 'dart:convert';

import 'package:http/http.dart' as http;

/// Uploads crash-report text to a LogPaste-compatible endpoint.
///
/// Default host matches lumen-crash-core: https://paste.gentoo.zip
/// Protocol: multipart form field `_` with the report body.
class CrashReportPasteUploader {
  static const String defaultBaseUrl = 'https://paste.gentoo.zip';

  const CrashReportPasteUploader();

  Future<String> uploadText(
    String text, {
    String baseUrl = defaultBaseUrl,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final payload = text.trim();
    if (payload.isEmpty) {
      throw StateError('Crash report text is empty.');
    }

    final endpoint = normalizeBaseUrl(baseUrl);
    final request = http.MultipartRequest('POST', Uri.parse(endpoint))
      ..fields['_'] = payload
      ..headers.addAll(<String, String>{
        'Accept': 'text/plain, */*',
        'User-Agent': 'nexai-crash-sdk',
      });

    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);
    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();

    if (response.statusCode < 200 || response.statusCode > 299) {
      final preview = body.length <= 200 ? body : body.substring(0, 200);
      throw StateError(
        'Paste upload failed with HTTP ${response.statusCode}: $preview',
      );
    }

    return resolveShareableUrl(endpoint, body);
  }

  static String normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (!trimmed.toLowerCase().startsWith('https://')) {
      throw ArgumentError('Paste upload base URL must use HTTPS.');
    }
    return trimmed;
  }

  static String resolveShareableUrl(String baseUrl, String responseText) {
    final body = responseText.trim();
    if (body.isEmpty) {
      throw StateError('Paste upload returned an empty response.');
    }

    final firstToken = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

    final lower = firstToken.toLowerCase();
    if (lower.startsWith('https://') || lower.startsWith('http://')) {
      if (!lower.startsWith('https://')) {
        throw StateError('Paste upload returned a non-HTTPS URL.');
      }
      return firstToken.replaceAll(RegExp(r'/+$'), '');
    }

    final id = firstToken.replaceAll(RegExp(r'^/+|/+$'), '');
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      final preview = id.length <= 64 ? id : id.substring(0, 64);
      throw StateError('Paste upload returned an unexpected id: $preview');
    }
    return '${normalizeBaseUrl(baseUrl)}/$id';
  }
}
