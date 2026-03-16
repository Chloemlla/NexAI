/// NexAI Auth State Provider
/// Manages authentication state, token persistence, and auto-refresh
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../services/nexai_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _keyAccessToken = 'nexai_access_token';
  static const _keyRefreshToken = 'nexai_refresh_token';
  static const _keyUserId = 'nexai_user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  NexaiUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  Map<String, dynamic>? _lastPasskeyDebugContext;
  Map<String, dynamic>? _lastGoogleDebugContext;

  // OAuth config from server
  bool _googleEnabled = false;
  String _googleClientId = '';
  bool _githubEnabled = false;
  String _githubClientId = '';

  // Getters
  NexaiUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _currentUser != null && _accessToken != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  bool get googleEnabled => _googleEnabled;
  bool get githubEnabled => _githubEnabled;
  String get googleClientId => _googleClientId;
  String get githubClientId => _githubClientId;
  Map<String, dynamic>? get lastPasskeyDebugContext => _lastPasskeyDebugContext;
  Map<String, dynamic>? get lastGoogleDebugContext => _lastGoogleDebugContext;

  /// Initialize: load persisted tokens and try to restore session
  Future<void> init() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      // ① Restore session first — must not be blocked by network calls.
      _accessToken = await _storage.read(key: _keyAccessToken);
      _refreshToken = await _storage.read(key: _keyRefreshToken);

      if (_accessToken != null) {
        // Try to get current user with stored token
        try {
          final res = await NexaiAuthApi.getCurrentUser(
            accessToken: _accessToken!,
          );
          if (res.success && res.user != null) {
            _currentUser = res.user;
          } else if (_refreshToken != null) {
            // Access token expired, try refresh
            await _tryRefreshToken();
          } else {
            await _clearTokens();
          }
        } catch (e) {
          // Network error — keep tokens, user is considered 'offline logged-in'.
          // Session will be validated on next successful request.
          debugPrint(
            '[NexAI Auth] Session restore network error (offline?): $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[NexAI Auth] Init storage error: $e');
      // Storage read failed — do not clear tokens, treat as transient error.
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }

    // ② Load OAuth config in background — failure must not affect login state.
    _loadOAuthConfig().ignore();
  }

  /// Load OAuth config from server
  Future<void> _loadOAuthConfig() async {
    try {
      final config = await NexaiAuthApi.getOAuthConfig();
      _googleEnabled = config.googleEnabled;
      _googleClientId = config.googleClientId;
      _githubEnabled = config.githubEnabled;
      _githubClientId = config.githubClientId;
    } catch (e) {
      debugPrint('[NexAI Auth] Failed to load OAuth config: $e');
    }
  }

  /// Register with email + username + password
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await NexaiAuthApi.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );

      if (res.success && res.accessToken != null && res.user != null) {
        await _saveSession(res.user!, res.accessToken!, res.refreshToken);
        return true;
      } else {
        _error = res.error ?? '注册失败';
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with email/username + password
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await NexaiAuthApi.login(
        identifier: identifier,
        password: password,
      );

      if (res.success && res.accessToken != null && res.user != null) {
        await _saveSession(res.user!, res.accessToken!, res.refreshToken);
        return true;
      } else {
        _error = res.error ?? '登录失败';
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Google Sign-In
  Future<bool> signInWithGoogle() async {
    // Check platform support - google_sign_in only supports Android, iOS, and Web
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _error = 'Google 登录暂不支持桌面平台\n请使用 Android 或 Web 版本';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final debugContext = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'operation': 'signInWithGoogle',
      'googleClientId': _googleClientId,
      'googleEnabled': _googleEnabled,
      'platform': defaultTargetPlatform.toString(),
    };

    try {
      // Check if Google OAuth is configured
      if (!_googleEnabled || _googleClientId.isEmpty) {
        _error = 'Google 登录未配置或未启用\n请联系管理员配置 Google OAuth';
        debugContext['error'] = _error;
        debugContext['errorType'] = 'GoogleNotConfigured';
        _lastGoogleDebugContext = debugContext;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Use server client ID (Web Application type) for backend verification
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleClientId,
        scopes: ['email', 'profile'],
      );

      debugContext['googleSignInConfigured'] = true;

      final account = await googleSignIn.signIn();
      if (account == null) {
        _error = '已取消 Google 登录';
        debugContext['cancelled'] = true;
        _lastGoogleDebugContext = debugContext;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      debugContext['accountEmail'] = account.email;
      debugContext['accountId'] = account.id;
      debugContext['accountDisplayName'] = account.displayName;

      final auth = await account.authentication;
      debugContext['hasAccessToken'] = auth.accessToken != null;
      debugContext['hasIdToken'] = auth.idToken != null;
      debugContext['hasServerAuthCode'] = auth.serverAuthCode != null;

      final idToken = auth.idToken;
      if (idToken == null) {
        _error = '无法获取 Google ID Token\n'
            '这通常是因为 Google Client ID 配置不正确\n'
            '请确保使用的是 Web Application 类型的 Client ID';
        debugContext['error'] = _error;
        debugContext['errorType'] = 'MissingIdToken';
        _lastGoogleDebugContext = debugContext;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      debugContext['idTokenLength'] = idToken.length;

      // Send idToken to backend
      final res = await NexaiAuthApi.googleAuth(idToken: idToken);

      debugContext['backendResponse'] = {
        'success': res.success,
        'hasAccessToken': res.accessToken != null,
        'hasUser': res.user != null,
        'error': res.error,
      };

      if (res.success && res.accessToken != null && res.user != null) {
        await _saveSession(res.user!, res.accessToken!, res.refreshToken);
        debugContext['success'] = true;
        debugContext['userId'] = res.user!.id;
        return true;
      } else {
        _error = res.error ?? 'Google 登录失败';
        debugContext['success'] = false;
        debugContext['error'] = _error;
        _lastGoogleDebugContext = debugContext;
        return false;
      }
    } catch (e, stackTrace) {
      debugContext['error'] = e.toString();
      debugContext['errorType'] = e.runtimeType.toString();
      debugContext['errorDetails'] = _extractErrorDetails(e);
      debugContext['stackTrace'] = stackTrace.toString();

      debugPrint('[NexAI Google] Sign-in error: $e');
      debugPrint('[NexAI Google] Error type: ${e.runtimeType}');
      debugPrint('[NexAI Google] Stack trace: $stackTrace');

      _error = 'Google 登录错误: ${_extractErrorDetails(e)}';
      _lastGoogleDebugContext = debugContext;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_accessToken != null) {
        await NexaiAuthApi.logout(accessToken: _accessToken!);
      }
      // Also sign out from Google
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    } catch (e) {
      debugPrint('[NexAI Auth] Logout error: $e');
    } finally {
      await _clearTokens();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update profile
  Future<bool> updateProfile({
    String? displayName,
    String? username,
    String? avatarUrl,
  }) async {
    if (_accessToken == null) return false;
    _error = null;

    try {
      final res = await NexaiAuthApi.updateProfile(
        accessToken: _accessToken!,
        displayName: displayName,
        username: username,
        avatarUrl: avatarUrl,
      );

      if (res.success && res.user != null) {
        _currentUser = res.user;
        notifyListeners();
        return true;
      } else {
        _error = res.error ?? '更新失败';
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      return false;
    }
  }

  /// Link Google account
  Future<bool> linkGoogle() async {
    // Check platform support - google_sign_in only supports Android, iOS, and Web
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _error = 'Google 登录暂不支持桌面平台\n请使用 Android 或 Web 版本';
      notifyListeners();
      return false;
    }

    if (_accessToken == null) return false;
    _error = null;

    final debugContext = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'operation': 'linkGoogle',
      'userId': _currentUser?.id,
      'googleClientId': _googleClientId,
      'platform': defaultTargetPlatform.toString(),
    };

    try {
      // Check if Google OAuth is configured
      if (!_googleEnabled || _googleClientId.isEmpty) {
        _error = 'Google 登录未配置或未启用\n请联系管理员配置 Google OAuth';
        debugContext['error'] = _error;
        debugContext['errorType'] = 'GoogleNotConfigured';
        _lastGoogleDebugContext = debugContext;
        return false;
      }

      final googleSignIn = GoogleSignIn(
        serverClientId: _googleClientId,
        scopes: ['email', 'profile'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        debugContext['cancelled'] = true;
        _lastGoogleDebugContext = debugContext;
        return false;
      }

      debugContext['accountEmail'] = account.email;

      final auth = await account.authentication;
      debugContext['hasIdToken'] = auth.idToken != null;

      final idToken = auth.idToken;
      if (idToken == null) {
        _error = '无法获取 Google ID Token\n'
            '这通常是因为 Google Client ID 配置不正确\n'
            '请确保使用的是 Web Application 类型的 Client ID';
        debugContext['error'] = _error;
        debugContext['errorType'] = 'MissingIdToken';
        _lastGoogleDebugContext = debugContext;
        return false;
      }

      final res = await NexaiAuthApi.linkGoogle(
        accessToken: _accessToken!,
        idToken: idToken,
      );

      debugContext['backendResponse'] = {
        'success': res.success,
        'error': res.error,
      };

      if (res.success && res.user != null) {
        _currentUser = res.user;
        debugContext['success'] = true;
        notifyListeners();
        return true;
      } else {
        _error = res.error ?? '关联失败';
        debugContext['error'] = _error;
        _lastGoogleDebugContext = debugContext;
        return false;
      }
    } catch (e, stackTrace) {
      debugContext['error'] = e.toString();
      debugContext['errorType'] = e.runtimeType.toString();
      debugContext['errorDetails'] = _extractErrorDetails(e);
      debugContext['stackTrace'] = stackTrace.toString();

      debugPrint('[NexAI Google] Link error: $e');
      debugPrint('[NexAI Google] Stack trace: $stackTrace');

      _error = '关联错误: ${_extractErrorDetails(e)}';
      _lastGoogleDebugContext = debugContext;
      return false;
    }
  }

  /// Unlink Google account
  Future<bool> unlinkGoogle() async {
    if (_accessToken == null) return false;
    _error = null;

    try {
      final res = await NexaiAuthApi.unlinkGoogle(accessToken: _accessToken!);

      if (res.success && res.user != null) {
        _currentUser = res.user;
        notifyListeners();
        return true;
      } else {
        _error = res.error ?? '取消关联失败';
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ========== WebAuthn (Passkeys) ==========

  /// Bind a new Passkey to the current account
  Future<bool> bindPasskey() async {
    if (_accessToken == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final debugContext = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'operation': 'bindPasskey',
      'userId': _currentUser?.id,
      'username': _currentUser?.username,
    };

    try {
      final passkeyAuth = PasskeyAuthenticator();

      // 1. Get options from backend
      final optionsMap = await NexaiAuthApi.generatePasskeyRegistrationOptions(
        accessToken: _accessToken!,
      );

      debugContext['rawOptions'] = optionsMap;
      debugPrint('[NexAI Passkey] Registration options: $optionsMap');

      // 2. Convert JSON to RegisterRequestType with comprehensive null safety
      final sanitizedOptions = _sanitizePasskeyRegistrationOptions(optionsMap);

      debugContext['sanitizedOptions'] = sanitizedOptions;
      debugPrint('[NexAI Passkey] Sanitized options: $sanitizedOptions');

      final registerRequest = RegisterRequestType.fromJson(sanitizedOptions);

      // 3. Prompt user to create passkey using PasskeyAuthenticator
      final credential = await passkeyAuth.register(registerRequest);

      debugContext['credentialId'] = credential.id;

      // 4. Send credential to backend to verify (convert to JSON)
      await NexaiAuthApi.verifyPasskeyRegistration(
        accessToken: _accessToken!,
        responseInfo: credential.toJson(),
      );

      debugContext['success'] = true;
      return true;
    } catch (e, stackTrace) {
      debugContext['error'] = e.toString();
      debugContext['errorType'] = e.runtimeType.toString();
      debugContext['errorDetails'] = _extractErrorDetails(e);
      debugContext['stackTrace'] = stackTrace.toString();

      debugPrint('[NexAI Passkey] Bind error: $e');
      debugPrint('[NexAI Passkey] Error type: ${e.runtimeType}');
      debugPrint('[NexAI Passkey] Stack trace: $stackTrace');

      _error = '绑定 Passkey 失败: ${_extractErrorDetails(e)}';
      _lastPasskeyDebugContext = debugContext;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login using a Passkey
  Future<bool> loginWithPasskey({required String identifier}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final debugContext = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'operation': 'loginWithPasskey',
      'identifier': identifier,
    };

    try {
      final passkeyAuth = PasskeyAuthenticator();

      // 1. Get options from backend
      final optionsMap =
          await NexaiAuthApi.generatePasskeyAuthenticationOptions(
            identifier: identifier,
          );

      debugContext['rawOptions'] = optionsMap;
      debugPrint('[NexAI Passkey] Authentication options: $optionsMap');

      // 2. Convert JSON to AuthenticateRequestType with comprehensive null safety
      final sanitizedOptions = _sanitizePasskeyAuthenticationOptions(optionsMap);

      debugContext['sanitizedOptions'] = sanitizedOptions;
      debugPrint('[NexAI Passkey] Sanitized auth options: $sanitizedOptions');

      final authRequest = AuthenticateRequestType.fromJson(sanitizedOptions);

      // 3. Prompt user to authenticate
      final assertion = await passkeyAuth.authenticate(authRequest);

      debugContext['assertionId'] = assertion.id;

      // 4. Send assertion to backend to verify (convert to JSON)
      final res = await NexaiAuthApi.verifyPasskeyAuthentication(
        identifier: identifier,
        responseInfo: assertion.toJson(),
      );

      if (res.success && res.accessToken != null && res.user != null) {
        await _saveSession(res.user!, res.accessToken!, res.refreshToken);
        debugContext['success'] = true;
        debugContext['userId'] = res.user!.id;
        return true;
      } else {
        _error = res.error ?? 'Passkey 登录失败';
        debugContext['success'] = false;
        debugContext['error'] = _error;
        _lastPasskeyDebugContext = debugContext;
        return false;
      }
    } catch (e, stackTrace) {
      debugContext['error'] = e.toString();
      debugContext['errorType'] = e.runtimeType.toString();
      debugContext['errorDetails'] = _extractErrorDetails(e);
      debugContext['stackTrace'] = stackTrace.toString();

      debugPrint('[NexAI Passkey] Login error: $e');
      debugPrint('[NexAI Passkey] Error type: ${e.runtimeType}');
      debugPrint('[NexAI Passkey] Stack trace: $stackTrace');

      _error = 'Passkey 登录失败: ${_extractErrorDetails(e)}';
      _lastPasskeyDebugContext = debugContext;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== Internal Methods ==========

  /// Extract detailed error information from exception
  String _extractErrorDetails(dynamic error) {
    if (error == null) return 'Unknown error';

    // Try to get meaningful error message
    final errorStr = error.toString();

    // If it's just "Instance of 'ClassName'", try to extract more info
    if (errorStr.startsWith('Instance of ')) {
      final buffer = StringBuffer();
      buffer.write(errorStr);

      // Try to access common error properties
      try {
        if (error is Error) {
          buffer.write(' - ${error.stackTrace}');
        }
      } catch (_) {}

      try {
        // Try to get message property if it exists
        final dynamic errorObj = error;
        if (errorObj.message != null) {
          buffer.write(' - Message: ${errorObj.message}');
        }
      } catch (_) {}

      return buffer.toString();
    }

    return errorStr;
  }

  /// Sanitize passkey registration options to handle null values and encoding
  Map<String, dynamic> _sanitizePasskeyRegistrationOptions(
    Map<String, dynamic> options,
  ) {
    final sanitized = Map<String, dynamic>.from(options);

    // Handle challenge - ensure it's properly formatted
    // The passkeys package expects challenge as-is from the server
    // (server should send base64url-encoded string)
    if (sanitized['challenge'] == null) {
      throw Exception('Missing required field: challenge');
    }

    // Handle user object
    if (sanitized['user'] != null) {
      final user = Map<String, dynamic>.from(
        sanitized['user'] as Map<String, dynamic>,
      );

      // Ensure required user fields exist
      if (user['id'] == null) {
        throw Exception('Missing required field: user.id');
      }
      if (user['name'] == null) {
        throw Exception('Missing required field: user.name');
      }
      // Handle empty displayName
      if (user['displayName'] == null || user['displayName'] == '') {
        user['displayName'] = user['name'];
      }

      sanitized['user'] = user;
    } else {
      throw Exception('Missing required field: user');
    }

    // Handle rp (Relying Party)
    if (sanitized['rp'] == null) {
      throw Exception('Missing required field: rp');
    }

    // Ensure excludeCredentials is a list (not null)
    if (sanitized['excludeCredentials'] == null) {
      sanitized['excludeCredentials'] = [];
    } else if (sanitized['excludeCredentials'] is List) {
      // Ensure each credential has proper structure
      final credentials = sanitized['excludeCredentials'] as List;
      sanitized['excludeCredentials'] = credentials.map((cred) {
        if (cred is Map<String, dynamic>) {
          final credMap = Map<String, dynamic>.from(cred);
          // Ensure type field exists
          if (credMap['type'] == null) {
            credMap['type'] = 'public-key';
          }
          // Add empty transports array if missing - passkeys package may expect this
          if (!credMap.containsKey('transports') || credMap['transports'] == null) {
            credMap['transports'] = <String>[];
          }
          return credMap;
        }
        return cred;
      }).toList();
    }

    // Handle authenticatorSelection
    if (sanitized['authenticatorSelection'] != null) {
      final authSelection = Map<String, dynamic>.from(
        sanitized['authenticatorSelection'] as Map<String, dynamic>,
      );

      // Remove null authenticatorAttachment or keep it if it has a value
      if (authSelection['authenticatorAttachment'] == null) {
        authSelection.remove('authenticatorAttachment');
      }

      // Set defaults for other fields if missing
      if (authSelection['requireResidentKey'] == null) {
        authSelection['requireResidentKey'] = false;
      }
      if (authSelection['userVerification'] == null) {
        authSelection['userVerification'] = 'preferred';
      }

      sanitized['authenticatorSelection'] = authSelection;
    }

    // Handle pubKeyCredParams - ensure it's a list with proper structure
    if (sanitized['pubKeyCredParams'] == null) {
      // Provide default algorithms if missing
      sanitized['pubKeyCredParams'] = [
        {'type': 'public-key', 'alg': -7},  // ES256
        {'type': 'public-key', 'alg': -257}, // RS256
      ];
    }

    // Handle attestation
    if (sanitized['attestation'] == null) {
      sanitized['attestation'] = 'none';
    }

    // Handle timeout
    if (sanitized['timeout'] == null) {
      sanitized['timeout'] = 60000; // 60 seconds default
    }

    // Handle extensions
    if (sanitized['extensions'] == null) {
      sanitized['extensions'] = {};
    }

    // Remove hints field if it's null or empty array - it may cause type cast issues
    if (sanitized['hints'] == null ||
        (sanitized['hints'] is List && (sanitized['hints'] as List).isEmpty)) {
      sanitized.remove('hints');
    }

    return sanitized;
  }

  /// Sanitize passkey authentication options to handle null values and encoding
  Map<String, dynamic> _sanitizePasskeyAuthenticationOptions(
    Map<String, dynamic> options,
  ) {
    final sanitized = Map<String, dynamic>.from(options);

    // Handle challenge - ensure it's properly formatted
    if (sanitized['challenge'] == null) {
      throw Exception('Missing required field: challenge');
    }

    // Handle rpId
    if (sanitized['rpId'] == null) {
      throw Exception('Missing required field: rpId');
    }

    // Ensure allowCredentials is a list (not null)
    if (sanitized['allowCredentials'] == null) {
      sanitized['allowCredentials'] = [];
    } else if (sanitized['allowCredentials'] is List) {
      // Ensure each credential has proper structure
      final credentials = sanitized['allowCredentials'] as List;
      sanitized['allowCredentials'] = credentials.map((cred) {
        if (cred is Map<String, dynamic>) {
          final credMap = Map<String, dynamic>.from(cred);
          // Ensure type field exists
          if (credMap['type'] == null) {
            credMap['type'] = 'public-key';
          }
          // Add empty transports array if missing
          if (!credMap.containsKey('transports') || credMap['transports'] == null) {
            credMap['transports'] = <String>[];
          }
          return credMap;
        }
        return cred;
      }).toList();
    }

    // Handle userVerification
    if (sanitized['userVerification'] == null) {
      sanitized['userVerification'] = 'preferred';
    }

    // Handle timeout
    if (sanitized['timeout'] == null) {
      sanitized['timeout'] = 60000; // 60 seconds default
    }

    // Handle extensions
    if (sanitized['extensions'] == null) {
      sanitized['extensions'] = {};
    }

    // Remove hints field if it's null or empty array
    if (sanitized['hints'] == null ||
        (sanitized['hints'] is List && (sanitized['hints'] as List).isEmpty)) {
      sanitized.remove('hints');
    }

    return sanitized;
  }

  // ========== Session Management ==========

  Future<void> _saveSession(
    NexaiUser user,
    String accessToken,
    String? refreshToken,
  ) async {
    _currentUser = user;
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    await _storage.write(key: _keyUserId, value: user.id);
  }

  Future<void> _clearTokens() async {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;

    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
  }

  Future<void> _tryRefreshToken() async {
    if (_refreshToken == null) return;

    try {
      final res = await NexaiAuthApi.refreshToken(refreshToken: _refreshToken!);

      if (res.success && res.accessToken != null) {
        _accessToken = res.accessToken;
        _refreshToken = res.refreshToken ?? _refreshToken;

        await _storage.write(key: _keyAccessToken, value: _accessToken!);
        if (res.refreshToken != null) {
          await _storage.write(key: _keyRefreshToken, value: res.refreshToken!);
        }

        // Retry getting user info
        final userRes = await NexaiAuthApi.getCurrentUser(
          accessToken: _accessToken!,
        );
        if (userRes.success && userRes.user != null) {
          _currentUser = userRes.user;
        }
      } else {
        await _clearTokens();
      }
    } catch (e) {
      debugPrint('[NexAI Auth] Token refresh error: $e');
    }
  }
}
