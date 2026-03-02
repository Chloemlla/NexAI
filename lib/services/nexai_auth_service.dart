/// NexAI Auth API Service
/// Handles all communication with the NexAI backend auth endpoints
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    final res = await http.post(
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
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/google — send Google idToken
  static Future<AuthResponse> googleAuth({
    required String idToken,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/github — send GitHub code
  static Future<AuthResponse> githubAuth({
    required String code,
  }) async {
    final res = await http.post(
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
    final res = await http.get(
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
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/logout
  static Future<AuthResponse> logout({
    required String accessToken,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
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
    final res = await http.put(
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
    final res = await http.post(
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
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/unlink-google'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return AuthResponse.fromResponse(res);
  }

  /// POST /auth/forgot-password
  static Future<AuthResponse> forgotPassword({
    required String email,
  }) async {
    final res = await http.post(
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
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    return AuthResponse.fromResponse(res);
  }

  /// GET /auth/oauth-config
  static Future<OAuthConfigResponse> getOAuthConfig() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/oauth-config'),
      headers: {'Content-Type': 'application/json'},
    );
    final body = jsonDecode(res.body);
    return OAuthConfigResponse(
      success: body['success'] == true,
      googleEnabled: body['data']?['google']?['enabled'] == true,
      googleClientId: body['data']?['google']?['clientId'] ?? '',
      githubEnabled: body['data']?['github']?['enabled'] == true,
      githubClientId: body['data']?['github']?['clientId'] ?? '',
    );
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
    final body = jsonDecode(res.body);
    return AuthResponse(
      success: body['success'] == true,
      message: body['message'],
      error: body['error'],
      user: body['data']?['user'] != null
          ? NexaiUser.fromJson(body['data']['user'])
          : null,
      accessToken: body['data']?['accessToken'],
      refreshToken: body['data']?['refreshToken'],
      isNewUser: body['data']?['isNewUser'],
      statusCode: res.statusCode,
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
}
