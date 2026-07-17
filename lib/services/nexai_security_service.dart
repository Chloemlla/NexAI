/// NexAI Security API Service
///
/// Uses the same signed/pinned backend client as auth/sync/artifacts so
/// security endpoints share one request pipeline.
library;

import 'dart:convert';

import 'nexai_backend_client.dart';

class NexAISecurityService {
  static const String defaultBaseUrl = 'https://tts.chloemlla.com/api/nexai';
  static String _baseUrl = defaultBaseUrl;

  /// Optional constructor arg retained for call-site compatibility.
  /// The Dio instance is ignored; requests go through [NexaiBackendClient].
  NexAISecurityService([Object? ignoredClient]);

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get baseUrl => _baseUrl;

  Map<String, String> _jsonHeaders({String? accessToken}) {
    return <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, dynamic>? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Report security event
  Future<SecurityEventResponse> reportSecurityEvent(
    SecurityEventRequest request, {
    String? accessToken,
  }) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/security/report'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode(request.toJson()),
    );
    final json = _decode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        json != null) {
      return SecurityEventResponse.fromJson(json);
    }
    throw Exception(
      json?['error']?.toString() ??
          'security report failed (${response.statusCode})',
    );
  }

  /// Get device security status
  Future<SecurityStatusResponse> getSecurityStatus({String? accessToken}) async {
    final response = await NexaiBackendClient.get(
      Uri.parse('$_baseUrl/security/status'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final json = _decode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        json != null) {
      return SecurityStatusResponse.fromJson(json);
    }
    throw Exception(
      json?['error']?.toString() ??
          'security status failed (${response.statusCode})',
    );
  }

  /// Check anomalies (requires authentication)
  Future<AnomaliesResponse> checkAnomalies({required String accessToken}) async {
    final response = await NexaiBackendClient.get(
      Uri.parse('$_baseUrl/security/anomalies'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final json = _decode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        json != null) {
      return AnomaliesResponse.fromJson(json);
    }
    throw Exception(
      json?['error']?.toString() ??
          'security anomalies failed (${response.statusCode})',
    );
  }

  /// Track device (requires authentication)
  Future<TrackDeviceResponse> trackDevice({required String accessToken}) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/security/track'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode(<String, dynamic>{}),
    );
    final json = _decode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        json != null) {
      return TrackDeviceResponse.fromJson(json);
    }
    throw Exception(
      json?['error']?.toString() ??
          'security track failed (${response.statusCode})',
    );
  }
}

// ── Data Models ───────────────────────────────────────────────────────────

class SecurityEventRequest {
  final String eventType;
  final Map<String, dynamic>? details;
  final String? timestamp;

  SecurityEventRequest({
    required this.eventType,
    this.details,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        if (details != null) 'details': details,
        if (timestamp != null) 'timestamp': timestamp,
      };
}

class SecurityEventResponse {
  final String status;
  final String action;
  final String message;

  SecurityEventResponse({
    required this.status,
    required this.action,
    required this.message,
  });

  factory SecurityEventResponse.fromJson(Map<String, dynamic> json) {
    return SecurityEventResponse(
      status: json['status']?.toString() ?? 'recorded',
      action: json['action']?.toString() ?? 'monitor',
      message: json['message']?.toString() ?? '',
    );
  }
}

class SecurityStatusResponse {
  final String deviceFingerprint;
  final String status;
  final String riskLevel;
  final List<String> restrictions;
  final String message;

  SecurityStatusResponse({
    required this.deviceFingerprint,
    required this.status,
    required this.riskLevel,
    required this.restrictions,
    required this.message,
  });

  factory SecurityStatusResponse.fromJson(Map<String, dynamic> json) {
    final restrictionsRaw = json['restrictions'];
    return SecurityStatusResponse(
      deviceFingerprint: json['device_fingerprint']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      riskLevel: json['risk_level']?.toString() ?? 'SAFE',
      restrictions: restrictionsRaw is List
          ? restrictionsRaw.map((e) => e.toString()).toList()
          : const <String>[],
      message: json['message']?.toString() ?? '',
    );
  }
}

class AnomaliesResponse {
  final String deviceFingerprint;
  final String userId;
  final Anomalies anomalies;
  final AnomalyDetails details;

  AnomaliesResponse({
    required this.deviceFingerprint,
    required this.userId,
    required this.anomalies,
    required this.details,
  });

  factory AnomaliesResponse.fromJson(Map<String, dynamic> json) {
    final anomaliesRaw = json['anomalies'];
    final detailsRaw = json['details'];
    return AnomaliesResponse(
      deviceFingerprint: json['device_fingerprint']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      anomalies: Anomalies.fromJson(
        anomaliesRaw is Map<String, dynamic> ? anomaliesRaw : const {},
      ),
      details: AnomalyDetails.fromJson(
        detailsRaw is Map<String, dynamic> ? detailsRaw : const {},
      ),
    );
  }
}

class Anomalies {
  final bool multiAccount;
  final bool frequentDeviceSwitch;

  Anomalies({
    required this.multiAccount,
    required this.frequentDeviceSwitch,
  });

  factory Anomalies.fromJson(Map<String, dynamic> json) {
    return Anomalies(
      multiAccount: json['multi_account'] == true,
      frequentDeviceSwitch: json['frequent_device_switch'] == true,
    );
  }
}

class AnomalyDetails {
  final int accountCount;
  final int deviceCount;

  AnomalyDetails({
    required this.accountCount,
    required this.deviceCount,
  });

  factory AnomalyDetails.fromJson(Map<String, dynamic> json) {
    return AnomalyDetails(
      accountCount: int.tryParse('${json['account_count'] ?? 0}') ?? 0,
      deviceCount: int.tryParse('${json['device_count'] ?? 0}') ?? 0,
    );
  }
}

class TrackDeviceResponse {
  final String status;
  final String deviceFingerprint;
  final String riskLevel;
  final int riskScore;

  TrackDeviceResponse({
    required this.status,
    required this.deviceFingerprint,
    required this.riskLevel,
    required this.riskScore,
  });

  factory TrackDeviceResponse.fromJson(Map<String, dynamic> json) {
    return TrackDeviceResponse(
      status: json['status']?.toString() ?? 'tracked',
      deviceFingerprint: json['device_fingerprint']?.toString() ?? '',
      riskLevel: json['risk_level']?.toString() ?? 'SAFE',
      riskScore: int.tryParse('${json['risk_score'] ?? 0}') ?? 0,
    );
  }
}
