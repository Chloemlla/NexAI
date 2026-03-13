/// NexAI Security API Service
///
/// Provides API endpoints for security event reporting, device tracking,
/// and anomaly detection.
library;

import 'package:dio/dio.dart';

class NexAISecurityService {
  final Dio _dio;
  static const String baseUrl = 'https://api.951100.xyz/api/nexai';

  NexAISecurityService(this._dio);

  /// Report security event
  Future<SecurityEventResponse> reportSecurityEvent(
    SecurityEventRequest request,
  ) async {
    final response = await _dio.post(
      '$baseUrl/security/report',
      data: request.toJson(),
    );
    return SecurityEventResponse.fromJson(response.data);
  }

  /// Get device security status
  Future<SecurityStatusResponse> getSecurityStatus() async {
    final response = await _dio.get('$baseUrl/security/status');
    return SecurityStatusResponse.fromJson(response.data);
  }

  /// Check anomalies (requires authentication)
  Future<AnomaliesResponse> checkAnomalies() async {
    final response = await _dio.get('$baseUrl/security/anomalies');
    return AnomaliesResponse.fromJson(response.data);
  }

  /// Track device (requires authentication)
  Future<TrackDeviceResponse> trackDevice() async {
    final response = await _dio.post('$baseUrl/security/track');
    return TrackDeviceResponse.fromJson(response.data);
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
      status: json['status'] as String,
      action: json['action'] as String,
      message: json['message'] as String,
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
    return SecurityStatusResponse(
      deviceFingerprint: json['device_fingerprint'] as String,
      status: json['status'] as String,
      riskLevel: json['risk_level'] as String,
      restrictions: (json['restrictions'] as List).cast<String>(),
      message: json['message'] as String,
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
    return AnomaliesResponse(
      deviceFingerprint: json['device_fingerprint'] as String,
      userId: json['user_id'] as String,
      anomalies: Anomalies.fromJson(json['anomalies'] as Map<String, dynamic>),
      details: AnomalyDetails.fromJson(json['details'] as Map<String, dynamic>),
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
      multiAccount: json['multi_account'] as bool,
      frequentDeviceSwitch: json['frequent_device_switch'] as bool,
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
      accountCount: json['account_count'] as int,
      deviceCount: json['device_count'] as int,
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
      status: json['status'] as String,
      deviceFingerprint: json['device_fingerprint'] as String,
      riskLevel: json['risk_level'] as String,
      riskScore: json['risk_score'] as int,
    );
  }
}
