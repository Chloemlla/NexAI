/// NexAI Auth API Service
/// Handles all communication with the NexAI backend auth endpoints
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'nexai_backend_client.dart';

const String _nexaiBaseUrl = 'https://tts.chloemlla.com/api/nexai';

class NexaiAuthApi {
  static String _baseUrl = _nexaiBaseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get baseUrl => _baseUrl;
  static String get oauthConfigUrl => '$_baseUrl/auth/oauth-config';

  /// Safely decode JSON body, returning null on parse errors or empty body
  static Map<String, dynamic>? _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// POST /auth/register
  static Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'displayName': ?displayName,
      }),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/login
  static Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/google — send Google idToken
  static Future<AuthResponse> googleAuth({required String idToken}) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/github — send GitHub code
  static Future<AuthResponse> githubAuth({required String code}) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/github'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// GET /auth/me
  static Future<AuthResponse> getCurrentUser({
    required String accessToken,
  }) async {
    final res = await NexaiBackendClient.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/refresh
  static Future<AuthResponse> refreshToken({
    required String refreshToken,
  }) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/logout
  static Future<AuthResponse> logout({required String accessToken}) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// PUT /auth/profile
  static Future<AuthResponse> updateProfile({
    required String accessToken,
    String? displayName,
    String? username,
    String? avatarUrl,
  }) async {
    final res = await NexaiBackendClient.put(
      Uri.parse('$_baseUrl/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'displayName': ?displayName,
        'username': ?username,
        'avatarUrl': ?avatarUrl,
      }),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/link-google
  static Future<AuthResponse> linkGoogle({
    required String accessToken,
    required String idToken,
  }) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/link-google'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'idToken': idToken}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/unlink-google
  static Future<AuthResponse> unlinkGoogle({
    required String accessToken,
  }) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/unlink-google'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/forgot-password
  static Future<AuthResponse> forgotPassword({required String email}) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/reset-password
  static Future<AuthResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final res = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    return AuthResponse.fromResponse(res);
  }

  // / GET /auth/oauth-config
  static Future<OAuthConfigResponse> getOAuthConfig() async {
    final requestUrl = oauthConfigUrl;
    final response = await NexaiBackendClient.get(Uri.parse(requestUrl));
    final decoded = _decodeBody(response.body);

    if (response.statusCode == 200) {
      if (decoded != null) {
        final data = decoded['data'] ?? decoded;
        return OAuthConfigResponse.fromJson(
          data is Map<String, dynamic> ? data : {},
          requestUrl: requestUrl,
          statusCode: response.statusCode,
          rawBody: response.body,
          rawJson: decoded,
        );
      }
    }

    throw OAuthConfigRequestException(
      requestUrl: requestUrl,
      statusCode: response.statusCode,
      rawBody: response.body,
      decodedBody: decoded,
      message: decoded?['error']?.toString() ??
          decoded?['message']?.toString() ??
          'Failed to load OAuth config',
    );
  }

  // ========== WebAuthn (Passkeys) API ==========
  // Happy-TTS NexAI paths under https://tts.chloemlla.com/api/nexai
  // POST /auth/passkey/register/options  (auth required)
  // POST /auth/passkey/register/verify   (auth required, body = PublicKeyCredential)
  // POST /auth/passkey/login/options                (body: { identifier })
  // POST /auth/passkey/login/verify                 (body: { identifier, response })
  // POST /auth/passkey/login/discoverable/options   (usernameless)
  // POST /auth/passkey/login/discoverable/verify    (body: { response, challenge })
  // GET  /auth/passkey/signal/options               (auth required, Credential Manager Signal)
  // Android: Credential Manager createCredential / getCredential / signalCredentialState
  // Digital Asset Links: https://tts.chloemlla.com/.well-known/assetlinks.json

  // / POST /auth/passkey/register/options
  static Future<Map<String, dynamic>> generatePasskeyRegistrationOptions({
    required String accessToken,
  }) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/passkey/register/options'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      final json = _decodeBody(response.body);
      if (json != null && json['success'] == true) {
        return json['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(json?['error'] ?? '获取通行密钥注册选项失败');
    }

    final errJson = _decodeBody(response.body);
    throw Exception(errJson?['error'] ?? '请求失败，状态码: ${response.statusCode}');
  }

  // / POST /auth/passkey/register/verify
  static Future<void> verifyPasskeyRegistration({
    required String accessToken,
    required Map<String, dynamic> responseInfo,
  }) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/passkey/register/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(responseInfo),
    );

    if (response.statusCode == 200) {
      final json = _decodeBody(response.body);
      if (json != null && json['success'] == true) {
        return;
      }
      throw Exception(json?['error'] ?? '验证通行密钥失败');
    }

    final errJson = _decodeBody(response.body);
    throw Exception(errJson?['error'] ?? '请求失败，状态码: ${response.statusCode}');
  }

  // / POST /auth/passkey/login/options
  static Future<Map<String, dynamic>> generatePasskeyAuthenticationOptions({
    required String identifier,
  }) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/passkey/login/options'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier}),
    );

    if (response.statusCode == 200) {
      final json = _decodeBody(response.body);
      if (json != null && json['success'] == true) {
        return json['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(json?['error'] ?? '获取通行密钥登录选项失败');
    }

    final errJson = _decodeBody(response.body);
    throw Exception(errJson?['error'] ?? '请求失败，状态码: ${response.statusCode}');
  }

  // / POST /auth/passkey/login/verify
  // Body: { identifier, response } — Happy-TTS /api/nexai WebAuthn contract
  static Future<AuthResponse> verifyPasskeyAuthentication({
    required String identifier,
    required Map<String, dynamic> responseInfo,
  }) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/passkey/login/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'response': responseInfo}),
    );

    final json = _decodeBody(response.body);
    if (response.statusCode == 200) {
      if (json != null && json['success'] == true) {
        final data = json['data'];
        final authData = <String, dynamic>{
          'success': true,
        };
        if (data is Map<String, dynamic>) {
          authData.addAll(data);
        }
        if (json['message'] != null) {
          authData['message'] = json['message'];
        }
        return AuthResponse.fromJson(authData);
      }
      throw PasskeyApiException(
        statusCode: response.statusCode,
        message: json?['error']?.toString() ?? '通行密钥验证失败',
        code: json?['code']?.toString(),
        rawBody: response.body,
      );
    }

    throw PasskeyApiException(
      statusCode: response.statusCode,
      message: json?['error']?.toString() ??
          '请求失败，状态码: ${response.statusCode}',
      code: json?['code']?.toString(),
      rawBody: response.body,
    );
  }

  // / POST /auth/passkey/login/discoverable/options
  static Future<Map<String, dynamic>> generateDiscoverablePasskeyAuthenticationOptions() async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/passkey/login/discoverable/options'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({}),
    );

    final json = _decodeBody(response.body);
    if (response.statusCode == 200) {
      if (json != null && json['success'] == true) {
        return json['data'] as Map<String, dynamic>? ?? {};
      }
      throw PasskeyApiException(
        statusCode: response.statusCode,
        message: json?['error']?.toString() ?? '获取 Discoverable 登录选项失败',
        code: json?['code']?.toString(),
        rawBody: response.body,
      );
    }

    throw PasskeyApiException(
      statusCode: response.statusCode,
      message: json?['error']?.toString() ??
          '请求失败，状态码: ${response.statusCode}',
      code: json?['code']?.toString(),
      rawBody: response.body,
    );
  }

  // / POST /auth/passkey/login/discoverable/verify
  // Body: { response, challenge } — usernameless discoverable credentials
  static Future<AuthResponse> verifyDiscoverablePasskeyAuthentication({
    required Map<String, dynamic> responseInfo,
    required String challenge,
  }) async {
    final response = await NexaiBackendClient.post(
      Uri.parse('$_baseUrl/auth/passkey/login/discoverable/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'response': responseInfo,
        'challenge': challenge,
      }),
    );

    final json = _decodeBody(response.body);
    if (response.statusCode == 200) {
      if (json != null && json['success'] == true) {
        final data = json['data'];
        final authData = <String, dynamic>{
          'success': true,
        };
        if (data is Map<String, dynamic>) {
          authData.addAll(data);
        }
        if (json['message'] != null) {
          authData['message'] = json['message'];
        }
        return AuthResponse.fromJson(authData);
      }
      throw PasskeyApiException(
        statusCode: response.statusCode,
        message: json?['error']?.toString() ?? 'Discoverable 通行密钥验证失败',
        code: json?['code']?.toString(),
        rawBody: response.body,
      );
    }

    throw PasskeyApiException(
      statusCode: response.statusCode,
      message: json?['error']?.toString() ??
          '请求失败，状态码: ${response.statusCode}',
      code: json?['code']?.toString(),
      rawBody: response.body,
    );
  }

  // / GET /auth/passkey/signal/options
  static Future<Map<String, dynamic>> getPasskeySignalOptions({
    required String accessToken,
  }) async {
    final response = await NexaiBackendClient.get(
      Uri.parse('$_baseUrl/auth/passkey/signal/options'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final json = _decodeBody(response.body);
      if (json != null && json['success'] == true) {
        return json['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(json?['error'] ?? '获取通行密钥 Signal 选项失败');
    }

    final errJson = _decodeBody(response.body);
    throw Exception(errJson?['error'] ?? '请求失败，状态码: ${response.statusCode}');
  }
}

// ========== Response Models ==========

class NexaiUser {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String authProvider;
  final bool emailVerified;
  final String role;
  final String? googleId;
  final String? googleEmail;
  final String? githubId;
  final String? githubUsername;
  final DateTime? lastLoginAt;
  final int loginCount;
  /// Server-side passkey summaries from /auth/me when present.
  final List<NexaiPasskeyCredential> passkeys;

  NexaiUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.authProvider,
    required this.emailVerified,
    required this.role,
    this.googleId,
    this.googleEmail,
    this.githubId,
    this.githubUsername,
    this.lastLoginAt,
    required this.loginCount,
    this.passkeys = const [],
  });

  factory NexaiUser.fromJson(Map<String, dynamic> json) {
    final rawPasskeys = json['passkeys'];
    final passkeys = <NexaiPasskeyCredential>[];
    if (rawPasskeys is List) {
      for (final item in rawPasskeys) {
        if (item is Map) {
          passkeys.add(
            NexaiPasskeyCredential.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return NexaiUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? '',
      avatarUrl: json['avatarUrl'],
      authProvider: json['authProvider'] ?? 'local',
      emailVerified: json['emailVerified'] == true,
      role: json['role'] ?? 'user',
      googleId: json['googleId'],
      googleEmail: json['googleEmail'],
      githubId: json['githubId'],
      githubUsername: json['githubUsername'],
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'])
          : null,
      loginCount: json['loginCount'] ?? 0,
      passkeys: passkeys,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'authProvider': authProvider,
    'emailVerified': emailVerified,
    'role': role,
    'googleId': googleId,
    'googleEmail': googleEmail,
    'githubId': githubId,
    'githubUsername': githubUsername,
    'lastLoginAt': lastLoginAt?.toIso8601String(),
    'loginCount': loginCount,
    'passkeys': passkeys.map((p) => p.toJson()).toList(),
  };

  NexaiUser copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? authProvider,
    bool? emailVerified,
    String? role,
    String? googleId,
    String? googleEmail,
    String? githubId,
    String? githubUsername,
    DateTime? lastLoginAt,
    int? loginCount,
    List<NexaiPasskeyCredential>? passkeys,
  }) {
    return NexaiUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authProvider: authProvider ?? this.authProvider,
      emailVerified: emailVerified ?? this.emailVerified,
      role: role ?? this.role,
      googleId: googleId ?? this.googleId,
      googleEmail: googleEmail ?? this.googleEmail,
      githubId: githubId ?? this.githubId,
      githubUsername: githubUsername ?? this.githubUsername,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      loginCount: loginCount ?? this.loginCount,
      passkeys: passkeys ?? this.passkeys,
    );
  }

  bool get hasGoogle => googleId != null && googleId!.isNotEmpty;
  bool get hasGithub => githubId != null && githubId!.isNotEmpty;
  bool get hasPassword => authProvider.contains('local');
  /// Happy-TTS NexAI enforces a single passkey per account.
  bool get hasPasskey => passkeys.isNotEmpty;
  int get passkeyCount => passkeys.length;
}

class NexaiPasskeyCredential {
  final String id;
  final List<String> transports;
  final String? deviceType;
  final bool? backedUp;
  final int? counter;

  const NexaiPasskeyCredential({
    required this.id,
    this.transports = const [],
    this.deviceType,
    this.backedUp,
    this.counter,
  });

  factory NexaiPasskeyCredential.fromJson(Map<String, dynamic> json) {
    final transports = <String>[];
    final rawTransports = json['transports'];
    if (rawTransports is List) {
      for (final item in rawTransports) {
        final text = item?.toString();
        if (text != null && text.isNotEmpty) transports.add(text);
      }
    }

    return NexaiPasskeyCredential(
      id: json['id']?.toString() ?? '',
      transports: transports,
      deviceType: json['deviceType']?.toString(),
      backedUp: json['backedUp'] is bool ? json['backedUp'] as bool : null,
      counter: json['counter'] is int
          ? json['counter'] as int
          : int.tryParse(json['counter']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'transports': transports,
    'deviceType': deviceType,
    'backedUp': backedUp,
    'counter': counter,
  };
}

class AuthResponse {
  final bool success;
  final String? message;
  final String? error;
  /// Stable backend error code, e.g. unknown_credential for Signal API.
  final String? code;
  final NexaiUser? user;
  final String? accessToken;
  final String? refreshToken;
  final bool? isNewUser;
  final int statusCode;

  AuthResponse({
    required this.success,
    this.message,
    this.error,
    this.code,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isNewUser,
    required this.statusCode,
  });

  factory AuthResponse.fromResponse(http.Response res) {
    final body = NexaiAuthApi._decodeBody(res.body);

    // Handle non-JSON or malformed responses
    if (body == null) {
      return AuthResponse(
        success: res.statusCode >= 200 && res.statusCode < 300,
        error: res.statusCode >= 400
            ? 'Server returned non-JSON response'
            : null,
        statusCode: res.statusCode,
      );
    }

    // Try multiple locations for user/token data (data.user, user, data)
    final dataField = body['data'];
    final userData =
        dataField is Map<String, dynamic> && dataField['user'] != null
        ? dataField['user']
        : body['user'];

    final accessToken =
        dataField is Map<String, dynamic> && dataField['accessToken'] != null
        ? dataField['accessToken']
        : body['accessToken'];

    final refreshToken =
        dataField is Map<String, dynamic> && dataField['refreshToken'] != null
        ? dataField['refreshToken']
        : body['refreshToken'];

    return AuthResponse(
      success: body['success'] == true,
      message: body['message'] as String?,
      error: body['error'] as String?,
      code: body['code']?.toString(),
      user: userData != null && userData is Map<String, dynamic>
          ? NexaiUser.fromJson(userData)
          : null,
      accessToken: accessToken as String?,
      refreshToken: refreshToken as String?,
      isNewUser:
          (dataField is Map<String, dynamic>
                  ? dataField['isNewUser']
                  : body['isNewUser'])
              as bool?,
      statusCode: res.statusCode,
    );
  }

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] == true,
      message: json['message'],
      error: json['error'],
      code: json['code']?.toString(),
      user: json['user'] != null ? NexaiUser.fromJson(json['user']) : null,
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      isNewUser: json['isNewUser'],
      statusCode: json['statusCode'] ?? 200,
    );
  }
}

/// Thrown when a NexAI passkey API call fails with an optional stable error code.
class PasskeyApiException implements Exception {
  PasskeyApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.rawBody = '',
  });

  final int statusCode;
  final String message;
  final String? code;
  final String rawBody;

  bool get isUnknownCredential {
    final normalized = code?.toLowerCase() ?? '';
    return normalized == 'unknown_credential' ||
        normalized == 'credential_not_found' ||
        normalized == 'passkey_not_found';
  }

  @override
  String toString() {
    if (code != null && code!.isNotEmpty) {
      return 'PasskeyApiException($statusCode, code=$code): $message';
    }
    return 'PasskeyApiException($statusCode): $message';
  }
}

class OAuthConfigRequestException implements Exception {
  final String requestUrl;
  final int statusCode;
  final String rawBody;
  final Map<String, dynamic>? decodedBody;
  final String message;

  OAuthConfigRequestException({
    required this.requestUrl,
    required this.statusCode,
    required this.rawBody,
    required this.decodedBody,
    required this.message,
  });

  Map<String, dynamic> toDebugMap() => {
        'request': {
          'method': 'GET',
          'url': requestUrl,
        },
        'response': {
          'statusCode': statusCode,
          'body': rawBody,
          if (decodedBody != null) 'json': decodedBody,
        },
        'message': message,
      };

  @override
  String toString() =>
      'OAuthConfigRequestException($statusCode): $message; body=$rawBody';
}

class OAuthConfigResponse {
  final bool success;
  final bool googleEnabled;
  final String googleClientId;
  final bool githubEnabled;
  final String githubClientId;
  final String requestUrl;
  final int statusCode;
  final String rawBody;
  final Map<String, dynamic>? rawJson;

  OAuthConfigResponse({
    required this.success,
    required this.googleEnabled,
    required this.googleClientId,
    required this.githubEnabled,
    required this.githubClientId,
    required this.requestUrl,
    required this.statusCode,
    required this.rawBody,
    required this.rawJson,
  });

  factory OAuthConfigResponse.fromJson(
    Map<String, dynamic> json, {
    String requestUrl = '',
    int statusCode = 200,
    String rawBody = '',
    Map<String, dynamic>? rawJson,
  }) {
    // Handle nested structure from API documentation:
    // { "google": { "enabled": true, "clientId": "..." }, "github": { ... } }
    final google = json['google'] as Map<String, dynamic>?;
    final github = json['github'] as Map<String, dynamic>?;

    return OAuthConfigResponse(
      success: json['success'] ?? true,
      googleEnabled: google?['enabled'] == true,
      googleClientId: google?['clientId'] as String? ?? '',
      githubEnabled: github?['enabled'] == true,
      githubClientId: github?['clientId'] as String? ?? '',
      requestUrl: requestUrl,
      statusCode: statusCode,
      rawBody: rawBody,
      rawJson: rawJson,
    );
  }

  Map<String, dynamic> toDebugMap() => {
        'request': {
          'method': 'GET',
          'url': requestUrl,
        },
        'response': {
          'statusCode': statusCode,
          'body': rawBody,
          if (rawJson != null) 'json': rawJson,
        },
        'parsed': {
          'success': success,
          'googleEnabled': googleEnabled,
          'googleClientId': googleClientId,
          'githubEnabled': githubEnabled,
          'githubClientId': githubClientId,
        },
      };
}
