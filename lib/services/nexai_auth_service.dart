/// NexAI Auth API Service
/// Handles all communication with the NexAI backend auth endpoints
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

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final bodyStr = body is String ? body : (body?.toString() ?? '');
    final signed = await signRequest(
      method: 'POST',
      path: url.path,
      headers: _base(headers),
      body: bodyStr,
    );
    return (await _get()).post(url, headers: signed, body: body);
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
}

const String _nexaiBaseUrl = 'https://api.951100.xyz/api/nexai';

class NexaiAuthApi {
  static String _baseUrl = _nexaiBaseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get baseUrl => _baseUrl;

  /// POST /auth/register
  static Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final res = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        if (displayName != null) 'displayName': displayName,
      }),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/login
  static Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/google — send Google idToken
  static Future<AuthResponse> googleAuth({required String idToken}) async {
    final res = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/github — send GitHub code
  static Future<AuthResponse> githubAuth({required String code}) async {
    final res = await _NexaiHttp.post(
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
    final res = await _NexaiHttp.get(
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
    final res = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/logout
  static Future<AuthResponse> logout({required String accessToken}) async {
    final res = await _NexaiHttp.post(
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
    final res = await _NexaiHttp.put(
      Uri.parse('$_baseUrl/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        if (displayName != null) 'displayName': displayName,
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      }),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/link-google
  static Future<AuthResponse> linkGoogle({
    required String accessToken,
    required String idToken,
  }) async {
    final res = await _NexaiHttp.post(
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
    final res = await _NexaiHttp.post(
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
    final res = await _NexaiHttp.post(
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
    final res = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    return AuthResponse.fromResponse(res);
  }

  // / GET /auth/oauth-config
  static Future<OAuthConfigResponse> getOAuthConfig() async {
    final response = await _NexaiHttp.get(
      Uri.parse('$_baseUrl/auth/oauth-config'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return OAuthConfigResponse.fromJson(json['data']);
    }

    throw Exception('Failed to load OAuth config');
  }

  // ========== WebAuthn (Passkeys) API ==========

  // / POST /auth/passkey/register/options
  static Future<Map<String, dynamic>> generatePasskeyRegistrationOptions({
    required String accessToken,
  }) async {
    final response = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/passkey/register/options'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return json['data'] as Map<String, dynamic>;
      }
      throw Exception(json['error'] ?? '获取通行密钥注册选项失败');
    }

    final errJson = jsonDecode(response.body);
    throw Exception(errJson['error'] ?? '请求失败，状态码: ${response.statusCode}');
  }

  // / POST /auth/passkey/register/verify
  static Future<void> verifyPasskeyRegistration({
    required String accessToken,
    required Map<String, dynamic> responseInfo,
  }) async {
    final response = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/passkey/register/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(responseInfo),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return;
      }
      throw Exception(json['error'] ?? '验证通行密钥失败');
    }

    final errJson = jsonDecode(response.body);
    throw Exception(errJson['error'] ?? '请求失败，状态码: ${response.statusCode}');
  }

  // / POST /auth/passkey/login/options
  static Future<Map<String, dynamic>> generatePasskeyAuthenticationOptions({
    required String identifier,
  }) async {
    final response = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/passkey/login/options'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return json['data'] as Map<String, dynamic>;
      }
      throw Exception(json['error'] ?? '获取通行密钥登录选项失败');
    }

    final errJson = jsonDecode(response.body);
    throw Exception(errJson['error'] ?? '请求失败，状态码: ${response.statusCode}');
  }

  // / POST /auth/passkey/login/verify
  static Future<AuthResponse> verifyPasskeyAuthentication({
    required String identifier,
    required Map<String, dynamic> responseInfo,
  }) async {
    final response = await _NexaiHttp.post(
      Uri.parse('$_baseUrl/auth/passkey/login/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'response': responseInfo}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        return AuthResponse.fromJson(json['data']);
      }
      throw Exception(json['error'] ?? '通行密钥验证失败');
    }

    final errJson = jsonDecode(response.body);
    throw Exception(errJson['error'] ?? '请求失败，状态码: ${response.statusCode}');
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
  });

  factory NexaiUser.fromJson(Map<String, dynamic> json) {
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
    );
  }

  bool get hasGoogle => googleId != null && googleId!.isNotEmpty;
  bool get hasGithub => githubId != null && githubId!.isNotEmpty;
  bool get hasPassword => authProvider.contains('local');
}

class AuthResponse {
  final bool success;
  final String? message;
  final String? error;
  final NexaiUser? user;
  final String? accessToken;
  final String? refreshToken;
  final bool? isNewUser;
  final int statusCode;

  AuthResponse({
    required this.success,
    this.message,
    this.error,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isNewUser,
    required this.statusCode,
  });

  factory AuthResponse.fromResponse(http.Response res) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'success': false, 'error': 'Invalid response'};
    } catch (_) {
      body = <String, dynamic>{
        'success': false,
        'error': res.body.isNotEmpty ? res.body : 'Invalid response body',
      };
    }

    final data = body['data'];
    final dataMap = data is Map<String, dynamic> ? data : null;
    final userJson = dataMap?['user'] ?? body['user'];

    return AuthResponse(
      success: body['success'] == true,
      message: body['message'],
      error: body['error'],
      user: userJson is Map<String, dynamic>
          ? NexaiUser.fromJson(userJson)
          : null,
      accessToken: dataMap?['accessToken'] ?? body['accessToken'],
      refreshToken: dataMap?['refreshToken'] ?? body['refreshToken'],
      isNewUser: dataMap?['isNewUser'] ?? body['isNewUser'],
      statusCode: res.statusCode,
    );
  }

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] == true,
      message: json['message'],
      error: json['error'],
      user: json['user'] != null ? NexaiUser.fromJson(json['user']) : null,
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      isNewUser: json['isNewUser'],
      statusCode: json['statusCode'] ?? 200,
    );
  }
}

class OAuthConfigResponse {
  final bool success;
  final bool googleEnabled;
  final String googleClientId;
  final bool githubEnabled;
  final String githubClientId;

  OAuthConfigResponse({
    required this.success,
    required this.googleEnabled,
    required this.googleClientId,
    required this.githubEnabled,
    required this.githubClientId,
  });

  factory OAuthConfigResponse.fromJson(Map<String, dynamic> json) {
    return OAuthConfigResponse(
      success: json['success'] ?? true,
      googleEnabled: json['googleEnabled'] == true,
      googleClientId: json['googleClientId'] ?? '',
      githubEnabled: json['githubEnabled'] == true,
      githubClientId: json['githubClientId'] ?? '',
    );
  }
}
