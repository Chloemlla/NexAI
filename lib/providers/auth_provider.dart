/// NexAI Auth State Provider
/// Manages authentication state, token persistence, and auto-refresh
library;

import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/android_native/android_native_result.dart';
import '../services/android_native/android_passkey_service.dart';
import '../services/nexai_auth_service.dart';
import '../utils/build_config.dart';

class AndroidPasskeyNativeException implements Exception {
  AndroidPasskeyNativeException({
    required this.operation,
    required this.code,
    required this.message,
    required this.details,
  });

  final String operation;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  bool get isUserCanceled {
    final normalizedCode = code.toLowerCase();
    final normalizedType = details['type']?.toString().toLowerCase() ?? '';
    final normalizedClass =
        details['exceptionClass']?.toString().toLowerCase() ?? '';
    final normalizedMessage = message.toLowerCase();
    final normalizedSimpleName =
        details['simpleName']?.toString().toLowerCase() ?? '';

    return normalizedCode.contains('user_canceled') ||
        normalizedCode.contains('user_cancelled') ||
        normalizedCode.contains('cancellation') ||
        normalizedType.contains('user_canceled') ||
        normalizedType.contains('user_cancelled') ||
        normalizedClass.contains('cancellation') ||
        normalizedSimpleName.contains('cancellation') ||
        normalizedMessage.contains('user cancelled') ||
        normalizedMessage.contains('user canceled') ||
        normalizedMessage.contains('cancelled the selector') ||
        normalizedMessage.contains('canceled the selector');
  }

  @override
  String toString() {
    return 'AndroidPasskeyNativeException('
        'operation=$operation, code=$code, message=$message)';
  }
}

class AuthProvider extends ChangeNotifier {
  static const _keyAccessToken = 'nexai_access_token';
  static const _keyRefreshToken = 'nexai_refresh_token';
  static const _keyUserId = 'nexai_user_id';
  static const _keyUserJson = 'nexai_user_json';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  final AndroidPasskeyService _androidPasskeyService = AndroidPasskeyService();

  NexaiUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  Map<String, dynamic>? _lastPasskeyDebugContext;
  Map<String, dynamic>? _lastGoogleDebugContext;
  Map<String, dynamic>? _lastOAuthConfigDebugContext;

  // OAuth config from server
  bool _googleEnabled = false;
  String _googleClientId = '';
  bool _githubEnabled = false;
  String _githubClientId = '';
  bool _oauthConfigLoaded = false;

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
  bool get oauthConfigLoaded => _oauthConfigLoaded;
  bool get googleSignInSupportedPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  Map<String, dynamic>? get lastPasskeyDebugContext => _lastPasskeyDebugContext;
  Map<String, dynamic>? get lastGoogleDebugContext => _lastGoogleDebugContext;
  Map<String, dynamic>? get lastOAuthConfigDebugContext =>
      _lastOAuthConfigDebugContext;

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
        _currentUser = await _readCachedUser();

        // Try to get current user with stored token
        try {
          final res = await NexaiAuthApi.getCurrentUser(
            accessToken: _accessToken!,
          );
          if (res.success && res.user != null) {
            _currentUser = res.user;
            await _saveCachedUser(res.user!);
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
    final debugContext = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'operation': 'loadOAuthConfig',
      'request': {
        'method': 'GET',
        'url': NexaiAuthApi.oauthConfigUrl,
      },
    };

    try {
      final config = await NexaiAuthApi.getOAuthConfig();
      _googleEnabled = config.googleEnabled;
      _googleClientId = config.googleClientId;
      _githubEnabled = config.githubEnabled;
      _githubClientId = config.githubClientId;
      debugContext.addAll(config.toDebugMap());
      _lastOAuthConfigDebugContext = debugContext;
    } catch (e) {
      if (e is OAuthConfigRequestException) {
        debugContext.addAll(e.toDebugMap());
      } else {
        debugContext['error'] = e.toString();
        debugContext['errorType'] = e.runtimeType.toString();
        debugContext['errorDetails'] = _extractErrorDetails(e);
      }
      _lastOAuthConfigDebugContext = debugContext;
      debugPrint('[NexAI Auth] Failed to load OAuth config: $e');
    } finally {
      _oauthConfigLoaded = true;
      notifyListeners();
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
    if (!googleSignInSupportedPlatform) {
      _error = 'Google 快速登录暂不支持桌面平台\n请使用 Android 或 Web 版本';
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
        _error = 'Google 快速登录未配置或未启用\n请联系管理员配置 Google OAuth';
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
        _error = '已取消 Google 快速登录';
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
      debugContext['hasServerAuthCode'] = account.serverAuthCode != null;

      final idToken = auth.idToken;
      if (idToken == null) {
        _error =
            '无法获取 Google ID Token\n'
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
        _error = res.error ?? 'Google 快速登录失败';
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

      _error = 'Google 快速登录错误: ${_extractErrorDetails(e)}';
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
        await _saveCachedUser(res.user!);
        _signalPasskeyState(
          reason: 'profile_update',
          includeAcceptedCredentials: false,
        ).ignore();
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
    if (!googleSignInSupportedPlatform) {
      _error = 'Google 快速登录暂不支持桌面平台\n请使用 Android 或 Web 版本';
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
        _error = 'Google 快速登录未配置或未启用\n请联系管理员配置 Google OAuth';
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
        _error =
            '无法获取 Google ID Token\n'
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
        await _saveCachedUser(res.user!);
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
        await _saveCachedUser(res.user!);
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
      'accountEmail': _currentUser?.email,
      'apiBaseUrl': NexaiAuthApi.baseUrl,
      'steps': <Map<String, dynamic>>[],
    };

    void markStep(String step) {
      debugContext['lastStep'] = step;
      (debugContext['steps'] as List<Map<String, dynamic>>).add({
        'step': step,
        'at': DateTime.now().toIso8601String(),
      });
      debugPrint('[NexAI Passkey] bindPasskey step: $step');
    }

    try {
      markStep('collect_environment');
      debugContext.addAll(await _buildPasskeyEnvironmentContext());

      if (!_isAndroidPasskeyNativePlatform) {
        throw UnsupportedError(
          'Passkey 目前仅支持 Android 原生 Credential Manager',
        );
      }

      // 1. Get options from backend
      markStep('request_registration_options');
      final optionsMap = await NexaiAuthApi.generatePasskeyRegistrationOptions(
        accessToken: _accessToken!,
      );

      debugContext['rawOptions'] = optionsMap;
      debugContext['rawOptionsDiagnostics'] =
          _buildRegistrationOptionsDiagnostics(optionsMap);
      debugPrint('[NexAI Passkey] Registration options: $optionsMap');

      // 2. Validate the backend WebAuthn JSON and pass it through as
      // Credential Manager requestJson.
      markStep('prepare_registration_request_json');
      final requestOptions = _preparePasskeyRegistrationRequestJson(optionsMap);

      debugContext['requestOptions'] = requestOptions;
      debugContext['requestOptionsDiagnostics'] =
          _buildRegistrationOptionsDiagnostics(requestOptions);
      debugPrint('[NexAI Passkey] Request options: $requestOptions');

      // 3. Prompt user to create passkey through Android Credential Manager
      markStep('invoke_native_register');
      final nativeResult = await _androidPasskeyService.register(
        options: requestOptions,
      );
      debugContext['nativeRegisterResult'] =
          _summarizeAndroidNativeResult(nativeResult);
      if (!nativeResult.ok || nativeResult.data == null) {
        throw _buildAndroidPasskeyNativeException(
          'register',
          nativeResult.error,
        );
      }
      final credential = _extractNativePasskeyResponse(
        nativeResult.data!,
        'registration',
      );

      markStep('native_register_completed');
      debugContext['credentialId'] = credential['id'];
      debugContext['credentialType'] = credential['type'];
      debugContext['credentialResponseSummary'] =
          _summarizePasskeyResponse(credential);

      // 4. Send credential to backend to verify (convert to JSON)
      markStep('verify_registration_with_backend');
      await NexaiAuthApi.verifyPasskeyRegistration(
        accessToken: _accessToken!,
        responseInfo: credential,
      );

      // 5. Refresh /auth/me so local user.passkeys reflects the new binding.
      markStep('refresh_user_after_registration');
      try {
        final me = await NexaiAuthApi.getCurrentUser(accessToken: _accessToken!);
        if (me.success && me.user != null) {
          var refreshed = me.user!;
          // Backend may omit passkeys on /auth/me; keep optimistic binding state.
          if (!refreshed.hasPasskey && credential['id'] != null) {
            refreshed = refreshed.copyWith(
              passkeys: [
                NexaiPasskeyCredential(id: credential['id'].toString()),
              ],
            );
          }
          _currentUser = refreshed;
          await _saveCachedUser(refreshed);
          debugContext['passkeyCount'] = refreshed.passkeyCount;
        } else if (_currentUser != null && credential['id'] != null) {
          final optimistic = _currentUser!.copyWith(
            passkeys: [
              NexaiPasskeyCredential(id: credential['id'].toString()),
            ],
          );
          _currentUser = optimistic;
          await _saveCachedUser(optimistic);
          debugContext['passkeyCount'] = optimistic.passkeyCount;
          debugContext['passkeyOptimistic'] = true;
        }
      } catch (e) {
        if (_currentUser != null && credential['id'] != null) {
          final optimistic = _currentUser!.copyWith(
            passkeys: [
              NexaiPasskeyCredential(id: credential['id'].toString()),
            ],
          );
          _currentUser = optimistic;
          await _saveCachedUser(optimistic);
          debugContext['passkeyCount'] = optimistic.passkeyCount;
          debugContext['passkeyOptimistic'] = true;
        }
        debugContext['refreshUserError'] = e.toString();
        debugPrint('[NexAI Passkey] Refresh user after register failed: $e');
      }

      markStep('registration_verified');
      debugContext['success'] = true;
      _signalPasskeyState(reason: 'passkey_registration_verified').ignore();
      return true;
    } catch (e, stackTrace) {
      if (_isPasskeyUserCancellation(e)) {
        debugContext['cancelled'] = true;
        debugContext['success'] = false;
        debugContext['error'] = e.toString();
        debugContext['errorType'] = e.runtimeType.toString();
        debugContext['errorDetails'] = _extractErrorDetails(e);
        debugContext['errorDiagnostics'] =
            _buildErrorDiagnostics(e, stackTrace);
        debugContext['errorHints'] = _buildPasskeyErrorHints(e, debugContext);
        debugPrint('[NexAI Passkey] Bind cancelled by user');
        _error = '已取消绑定通行密钥';
        _lastPasskeyDebugContext = debugContext;
        return false;
      }

      debugContext['error'] = e.toString();
      debugContext['errorType'] = e.runtimeType.toString();
      debugContext['errorDetails'] = _extractErrorDetails(e);
      debugContext['errorDiagnostics'] = _buildErrorDiagnostics(e, stackTrace);
      debugContext['errorHints'] = _buildPasskeyErrorHints(e, debugContext);
      debugContext['stackTrace'] = stackTrace.toString();

      debugPrint('[NexAI Passkey] Bind error: $e');
      debugPrint('[NexAI Passkey] Error type: ${e.runtimeType}');
      debugPrint('[NexAI Passkey] Last step: ${debugContext['lastStep']}');
      debugPrint(
        '[NexAI Passkey] Error diagnostics: '
        '${debugContext['errorDiagnostics']}',
      );
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
  Future<bool> loginWithPasskey({String? identifier}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final debugContext = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'operation': 'loginWithPasskey',
      'identifier': identifier,
      'steps': <Map<String, dynamic>>[],
    };

    void markStep(String step) {
      debugContext['lastStep'] = step;
      (debugContext['steps'] as List<Map<String, dynamic>>).add({
        'step': step,
        'at': DateTime.now().toIso8601String(),
      });
      debugPrint('[NexAI Passkey] loginWithPasskey step: $step');
    }

    try {
      markStep('collect_environment');
      debugContext.addAll(await _buildPasskeyEnvironmentContext());

      if (!_isAndroidPasskeyNativePlatform) {
        throw UnsupportedError(
          'Passkey 目前仅支持 Android 原生 Credential Manager',
        );
      }

      final trimmedIdentifier = identifier?.trim() ?? '';
      final discoverable = trimmedIdentifier.isEmpty;
      debugContext['discoverable'] = discoverable;
      debugContext['identifier'] = trimmedIdentifier.isEmpty
          ? null
          : trimmedIdentifier;

      // 1. Get options from backend
      markStep(
        discoverable
            ? 'request_discoverable_authentication_options'
            : 'request_authentication_options',
      );
      final optionsMap = discoverable
          ? await NexaiAuthApi
              .generateDiscoverablePasskeyAuthenticationOptions()
          : await NexaiAuthApi.generatePasskeyAuthenticationOptions(
              identifier: trimmedIdentifier,
            );

      debugContext['rawOptions'] = optionsMap;
      debugPrint('[NexAI Passkey] Authentication options: $optionsMap');

      final challenge = optionsMap['challenge']?.toString() ?? '';
      debugContext['challengePresent'] = challenge.isNotEmpty;
      if (discoverable && challenge.isEmpty) {
        throw Exception('Discoverable 登录选项缺少 challenge');
      }

      // 2. Validate the backend WebAuthn JSON and pass it through as
      // Credential Manager requestJson.
      markStep('prepare_authentication_request_json');
      final requestOptions = _preparePasskeyAuthenticationRequestJson(
        optionsMap,
      );

      debugContext['requestOptions'] = requestOptions;
      debugContext['requestOptionsDiagnostics'] =
          _buildAuthenticationOptionsDiagnostics(requestOptions);
      debugPrint('[NexAI Passkey] Auth request options: $requestOptions');

      // 3. Prompt user to authenticate through Android Credential Manager
      markStep('invoke_native_authenticate');
      final nativeResult = await _androidPasskeyService.authenticate(
        options: requestOptions,
      );
      debugContext['nativeAuthenticateResult'] =
          _summarizeAndroidNativeResult(nativeResult);
      if (!nativeResult.ok || nativeResult.data == null) {
        throw _buildAndroidPasskeyNativeException(
          'authenticate',
          nativeResult.error,
        );
      }
      final assertion = _extractNativePasskeyResponse(
        nativeResult.data!,
        'authentication',
      );

      markStep('native_authenticate_completed');
      debugContext['assertionId'] = assertion['id'];
      debugContext['assertionType'] = assertion['type'];
      debugContext['assertionResponseSummary'] =
          _summarizePasskeyResponse(assertion);

      // 4. Send assertion to backend to verify (convert to JSON)
      markStep(
        discoverable
            ? 'verify_discoverable_authentication_with_backend'
            : 'verify_authentication_with_backend',
      );
      AuthResponse res;
      try {
        res = discoverable
            ? await NexaiAuthApi.verifyDiscoverablePasskeyAuthentication(
                responseInfo: assertion,
                challenge: challenge,
              )
            : await NexaiAuthApi.verifyPasskeyAuthentication(
                identifier: trimmedIdentifier,
                responseInfo: assertion,
              );
      } catch (e) {
        if (_shouldSignalUnknownCredentialFromError(e)) {
          await _signalUnknownPasskeyCredential(
            requestOptions: requestOptions,
            assertion: assertion,
            reason: discoverable
                ? 'passkey_discoverable_verify_exception'
                : 'passkey_authentication_verify_exception',
            debugContext: debugContext,
          );
        }
        rethrow;
      }

      if (res.success && res.accessToken != null && res.user != null) {
        await _saveSession(res.user!, res.accessToken!, res.refreshToken);
        _signalPasskeyState(reason: 'passkey_authentication_verified').ignore();
        markStep('authentication_verified');
        debugContext['success'] = true;
        debugContext['userId'] = res.user!.id;
        debugContext['passkeyCount'] = res.user!.passkeyCount;
        return true;
      } else {
        if (_shouldSignalUnknownCredential(res.error, res.code)) {
          await _signalUnknownPasskeyCredential(
            requestOptions: requestOptions,
            assertion: assertion,
            reason: 'passkey_authentication_verify_failed',
            debugContext: debugContext,
          );
        }
        _error = res.error ?? 'Passkey 登录失败';
        debugContext['success'] = false;
        debugContext['error'] = _error;
        debugContext['errorCode'] = res.code;
        _lastPasskeyDebugContext = debugContext;
        return false;
      }
    } catch (e, stackTrace) {
      if (_isPasskeyUserCancellation(e)) {
        debugContext['cancelled'] = true;
        debugContext['success'] = false;
        debugContext['error'] = e.toString();
        debugContext['errorType'] = e.runtimeType.toString();
        debugContext['errorDetails'] = _extractErrorDetails(e);
        debugContext['errorDiagnostics'] =
            _buildErrorDiagnostics(e, stackTrace);
        debugContext['errorHints'] = _buildPasskeyErrorHints(e, debugContext);
        debugPrint('[NexAI Passkey] Login cancelled by user');
        _error = '已取消 Passkey 登录';
        _lastPasskeyDebugContext = debugContext;
        return false;
      }

      debugContext['error'] = e.toString();
      debugContext['errorType'] = e.runtimeType.toString();
      debugContext['errorDetails'] = _extractErrorDetails(e);
      debugContext['errorDiagnostics'] = _buildErrorDiagnostics(e, stackTrace);
      debugContext['errorHints'] = _buildPasskeyErrorHints(e, debugContext);
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

  Future<Map<String, dynamic>> _buildPasskeyEnvironmentContext() async {
    final context = <String, dynamic>{
      'platform': defaultTargetPlatform.toString(),
      'isWeb': kIsWeb,
      'buildMode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'dartProductMode': const bool.fromEnvironment('dart.vm.product'),
      'nexaiBuild': {
        'versionName': BuildConfig.versionName,
        'versionCode': BuildConfig.versionCode,
        'buildTime': BuildConfig.buildTime,
        'commitHash': BuildConfig.commitHash,
        'shortHash': BuildConfig.shortHash,
        'fullVersion': BuildConfig.fullVersion,
      },
    };

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      context['packageInfo'] = {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'buildSignature': packageInfo.buildSignature,
        'installerStore': packageInfo.installerStore,
      };
    } catch (e) {
      context['packageInfoError'] = e.toString();
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final android = await DeviceInfoPlugin().androidInfo;
        context['androidDevice'] = {
          'sdkInt': android.version.sdkInt,
          'release': android.version.release,
          'previewSdkInt': android.version.previewSdkInt,
          'codename': android.version.codename,
          'brand': android.brand,
          'manufacturer': android.manufacturer,
          'model': android.model,
          'device': android.device,
          'product': android.product,
          'hardware': android.hardware,
          'supportedAbis': android.supportedAbis,
          'isPhysicalDevice': android.isPhysicalDevice,
        };
      } catch (e) {
        context['androidDeviceError'] = e.toString();
      }
    }

    return context;
  }

  Map<String, dynamic> _buildRegistrationOptionsDiagnostics(
    Map<String, dynamic> options,
  ) {
    final rp = options['rp'] is Map
        ? Map<String, dynamic>.from(options['rp'] as Map)
        : <String, dynamic>{};
    final user = options['user'] is Map
        ? Map<String, dynamic>.from(options['user'] as Map)
        : <String, dynamic>{};
    final pubKeyCredParams = options['pubKeyCredParams'] is List
        ? options['pubKeyCredParams'] as List
        : const [];
    final excludeCredentials = options['excludeCredentials'] is List
        ? options['excludeCredentials'] as List
        : const [];
    final authSelection = options['authenticatorSelection'] is Map
        ? Map<String, dynamic>.from(options['authenticatorSelection'] as Map)
        : <String, dynamic>{};
    final extensions = options['extensions'] is Map
        ? Map<String, dynamic>.from(options['extensions'] as Map)
        : <String, dynamic>{};
    final warnings = <String>[];

    final rpId = rp['id']?.toString() ?? '';
    final userName = user['name']?.toString() ?? '';
    final userDisplayName = user['displayName']?.toString() ?? '';
    if (rpId.isEmpty) warnings.add('rp.id is empty or missing');
    if (userName.isEmpty) warnings.add('user.name is empty or missing');
    if (userDisplayName.isEmpty) {
      warnings.add('user.displayName is empty or missing');
    }
    if (pubKeyCredParams.isEmpty) {
      warnings.add('pubKeyCredParams is empty or missing');
    }
    if (authSelection['authenticatorAttachment'] == 'platform' &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      warnings.add(
        'authenticatorAttachment=platform requires an enabled Android '
        'credential provider and a Google account on many devices',
      );
    }

    return {
      'rp': {
        'name': rp['name'],
        'id': rpId,
        'idLength': rpId.length,
      },
      'user': {
        'name': userName,
        'nameLength': userName.length,
        'displayName': userDisplayName,
        'displayNameLength': userDisplayName.length,
        'id': _base64UrlDiagnostics(user['id']),
      },
      'challenge': _base64UrlDiagnostics(options['challenge']),
      'pubKeyCredParams': pubKeyCredParams.map((param) {
        if (param is Map) {
          final map = Map<String, dynamic>.from(param);
          return {'type': map['type'], 'alg': map['alg']};
        }
        return {'raw': param.toString(), 'type': param.runtimeType.toString()};
      }).toList(),
      'timeout': options['timeout'],
      'attestation': options['attestation'],
      'excludeCredentialCount': excludeCredentials.length,
      'excludeCredentials': excludeCredentials.map((credential) {
        if (credential is Map) {
          final map = Map<String, dynamic>.from(credential);
          return {
            'type': map['type'],
            'id': _base64UrlDiagnostics(map['id']),
            'transports': map['transports'],
          };
        }
        return {
          'raw': credential.toString(),
          'type': credential.runtimeType.toString(),
        };
      }).toList(),
      'authenticatorSelection': authSelection,
      'extensionKeys': extensions.keys.toList(),
      'hintsType': options['hints']?.runtimeType.toString(),
      'hintsLength': options['hints'] is List
          ? (options['hints'] as List).length
          : null,
      'warnings': warnings,
    };
  }

  Map<String, dynamic> _base64UrlDiagnostics(dynamic value) {
    final text = value?.toString();
    final diagnostics = <String, dynamic>{
      'present': value != null,
      'type': value?.runtimeType.toString(),
      'length': text?.length ?? 0,
      'hasPadding': text?.contains('=') ?? false,
      'charsetLooksBase64Url': text == null
          ? false
          : RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(text),
    };

    if (text == null || text.isEmpty) {
      diagnostics['validBase64Url'] = false;
      diagnostics['decodeError'] = 'empty';
      return diagnostics;
    }

    try {
      final bytes = base64Url.decode(base64Url.normalize(text));
      diagnostics['validBase64Url'] = true;
      diagnostics['decodedByteLength'] = bytes.length;
      diagnostics['decodedUtf8Preview'] = _tryDecodeUtf8Preview(bytes);
    } catch (e) {
      diagnostics['validBase64Url'] = false;
      diagnostics['decodeError'] = e.toString();
    }

    return diagnostics;
  }

  bool get _isAndroidPasskeyNativePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidPasskeyNativeException _buildAndroidPasskeyNativeException(
    String operation,
    AndroidNativeError? error,
  ) {
    return AndroidPasskeyNativeException(
      operation: operation,
      code: error?.code ?? 'native_failure',
      message: error?.message ?? 'Android native passkey operation failed',
      details: error?.details ?? const <String, dynamic>{},
    );
  }

  bool _isPasskeyUserCancellation(Object error) {
    if (error is AndroidPasskeyNativeException) {
      return error.isUserCanceled;
    }

    if (error is AndroidNativeError) {
      return AndroidPasskeyNativeException(
        operation: 'unknown',
        code: error.code,
        message: error.message,
        details: error.details,
      ).isUserCanceled;
    }

    final text = error.toString().toLowerCase();
    return text.contains('user_canceled') ||
        text.contains('user_cancelled') ||
        text.contains('user cancelled') ||
        text.contains('user canceled') ||
        text.contains('cancelled the selector') ||
        text.contains('canceled the selector') ||
        text.contains('type_user_canceled');
  }

  bool get wasLastPasskeyCancelled {
    final context = _lastPasskeyDebugContext;
    if (context == null) return false;
    if (context['cancelled'] == true) return true;
    final error = context['error']?.toString() ?? '';
    return _isPasskeyUserCancellation(error);
  }

  Map<String, dynamic> _summarizeAndroidNativeResult(
    AndroidNativeResult<Map<String, dynamic>> result,
  ) {
    final data = result.data;
    return {
      'ok': result.ok,
      'error': result.error?.toDebugMap(),
      if (data != null) ...{
        'responseJsonLength': data['responseJson']?.toString().length,
        'responseType': data['responseType'],
        'credentialType': data['credentialType'],
        'hasResponseInfo': data['responseInfo'] is Map,
      },
    };
  }

  Map<String, dynamic> _extractNativePasskeyResponse(
    Map<String, dynamic> nativeData,
    String operation,
  ) {
    final responseInfo = nativeData['responseInfo'];
    if (responseInfo is Map) {
      return Map<String, dynamic>.from(responseInfo);
    }

    final responseJson = nativeData['responseJson']?.toString();
    if (responseJson != null && responseJson.isNotEmpty) {
      final decoded = jsonDecode(responseJson);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }

    throw AndroidPasskeyNativeException(
      operation: operation,
      code: 'invalid_native_response',
      message: 'Android native passkey response is missing responseInfo',
      details: {
        'nativeDataKeys': nativeData.keys.toList(),
        'responseJsonLength': responseJson?.length,
      },
    );
  }

  String? _tryDecodeUtf8Preview(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      if (text.runes.any((rune) => rune < 0x20 && rune != 0x0a)) {
        return null;
      }
      return text.length > 80 ? '${text.substring(0, 80)}...' : text;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _summarizePasskeyResponse(
    Map<String, dynamic> response,
  ) {
    final rawId = response['rawId']?.toString();
    final authenticatorResponse = response['response'] is Map
        ? Map<String, dynamic>.from(response['response'] as Map)
        : <String, dynamic>{};

    return {
      'idLength': response['id']?.toString().length,
      'rawId': _base64UrlDiagnostics(rawId),
      'type': response['type'],
      'clientExtensionResults': response['clientExtensionResults'],
      'responseFieldLengths': authenticatorResponse.map(
        (key, value) => MapEntry(key, value?.toString().length),
      ),
    };
  }

  Map<String, dynamic> _buildErrorDiagnostics(
    Object error,
    StackTrace? stackTrace,
  ) {
    final diagnostics = <String, dynamic>{
      'runtimeType': error.runtimeType.toString(),
      'toString': error.toString(),
      'hashCode': error.hashCode,
      'isPlatformException': error is PlatformException,
      'isAndroidPasskeyNativeException':
          error is AndroidPasskeyNativeException,
    };

    if (error is PlatformException) {
      diagnostics['platformException'] = {
        'code': error.code,
        'message': error.message,
        'details': error.details,
        'stacktrace': error.stacktrace,
      };
    }

    if (error is AndroidPasskeyNativeException) {
      diagnostics['androidPasskeyNativeException'] = {
        'operation': error.operation,
        'code': error.code,
        'message': error.message,
        'details': error.details,
      };
    }

    if (error is PasskeyApiException) {
      diagnostics['passkeyApiException'] = {
        'statusCode': error.statusCode,
        'code': error.code,
        'message': error.message,
        'isUnknownCredential': error.isUnknownCredential,
      };
    }

    final dynamic errorObj = error;
    final fields = <String, dynamic>{};
    void readField(String key, dynamic Function() read) {
      try {
        final value = read();
        if (value != null) fields[key] = value.toString();
      } catch (_) {}
    }

    readField('code', () => errorObj.code);
    readField('message', () => errorObj.message);
    readField('details', () => errorObj.details);
    readField('cause', () => errorObj.cause);
    readField('error', () => errorObj.error);
    readField('exception', () => errorObj.exception);
    readField('localizedMessage', () => errorObj.localizedMessage);
    readField('statusCode', () => errorObj.statusCode);
    readField('stacktrace', () => errorObj.stacktrace);
    diagnostics['readableFields'] = fields;

    if (stackTrace != null) {
      final firstFrames = stackTrace
          .toString()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(8)
          .toList();
      diagnostics['firstStackFrames'] = firstFrames;
    }

    return diagnostics;
  }

  List<String> _buildPasskeyErrorHints(
    Object error,
    Map<String, dynamic> debugContext,
  ) {
    final hints = <String>[];
    final errorType = error.runtimeType.toString();
    final lastStep = debugContext['lastStep']?.toString();

    if (lastStep == 'invoke_native_register' ||
        lastStep == 'invoke_native_authenticate') {
      hints.add(
        'The request reached the Kotlin Credential Manager layer and failed '
        'inside the native Android API.',
      );
    }

    if (error is AndroidPasskeyNativeException) {
      final nativeType = error.details['type']?.toString() ?? '';
      final nativeClass = error.details['exceptionClass']?.toString() ?? '';
      final nativeCode = error.code.toLowerCase();
      hints.add(
        'Native Credential Manager error: ${error.code}; see details.type '
        'and exceptionClass in Passkey 调试信息.',
      );
      if (nativeCode.contains('no_credential') ||
          nativeCode.contains('no_create_option') ||
          nativeType.contains('NO_CREDENTIAL')) {
        hints.add(
          'No Android credential provider could satisfy the request. Check '
          'device Credential Manager/passkey provider setup and Google account.',
        );
      }
      if (nativeClass.contains('DomException') ||
          nativeType.contains('DOM_EXCEPTION') ||
          nativeType.contains('INVALID_STATE')) {
        hints.add(
          'The relying party domain may not be associated with this app. '
          'Check assetlinks.json for package name and signing certificate.',
        );
      }
      if (error.isUserCanceled ||
          nativeCode.contains('user_canceled') ||
          nativeCode.contains('cancellation') ||
          nativeType.contains('USER_CANCELED')) {
        hints.add(
          'The native passkey prompt was cancelled by the user. '
          'This is not a configuration failure; the user can retry when ready.',
        );
      }
    }

    if (errorType == 'wOa' ||
        errorType == 'tOa' ||
        error.toString() == "Instance of 'wOa'" ||
        error.toString() == "Instance of 'tOa'") {
      hints.add(
        'The exception class name is obfuscated in the release build. '
        'Use Last Step, Error Diagnostics, device info, and Android logcat '
        'around the same timestamp to identify the Credential Manager error.',
      );
    }

    return hints;
  }

  /// Extract detailed error information from exception
  String _extractErrorDetails(dynamic error) {
    if (error == null) return 'Unknown error';

    if (error is AndroidPasskeyNativeException) {
      final nativeType = error.details['type'];
      return [
        'code=${error.code}',
        'message=${error.message}',
        if (nativeType != null) 'type=$nativeType',
      ].join(', ');
    }

    if (error is PasskeyApiException) {
      return [
        'status=${error.statusCode}',
        if (error.code != null && error.code!.isNotEmpty) 'code=${error.code}',
        'message=${error.message}',
      ].join(', ');
    }

    final diagnostics = _buildErrorDiagnostics(error as Object, null);
    final readableFields = diagnostics['readableFields'];
    if (readableFields is Map && readableFields.isNotEmpty) {
      final message = readableFields['message'];
      final code = readableFields['code'];
      final details = readableFields['details'];
      return [
        if (code != null) 'code=$code',
        if (message != null) 'message=$message',
        if (details != null) 'details=$details',
      ].join(', ');
    }

    final errorStr = error.toString();
    if (errorStr.startsWith('Instance of ')) {
      return '$errorStr (no public message field; see Passkey 调试信息)';
    }

    return errorStr;
  }

  /// Validate registration options and preserve the backend WebAuthn JSON
  /// semantics for Android Credential Manager requestJson.
  Map<String, dynamic> _preparePasskeyRegistrationRequestJson(
    Map<String, dynamic> options,
  ) {
    final request = _jsonRoundTripObject(options, 'registration options');

    _requireNonEmptyString(request, 'challenge');
    final rp = _requireObject(request, 'rp');
    _requireNonEmptyString(rp, 'rp.id', fieldName: 'id');
    final user = _requireObject(request, 'user');
    _ensurePasskeyUserDisplayName(user);
    _requireNonEmptyString(user, 'user.id', fieldName: 'id');
    _requireNonEmptyString(user, 'user.name', fieldName: 'name');
    _requireNonEmptyString(user, 'user.displayName', fieldName: 'displayName');
    _requireNonEmptyList(request, 'pubKeyCredParams');

    return request;
  }

  /// Validate authentication options and preserve the backend WebAuthn JSON
  /// semantics for Android Credential Manager requestJson.
  Map<String, dynamic> _preparePasskeyAuthenticationRequestJson(
    Map<String, dynamic> options,
  ) {
    final request = _jsonRoundTripObject(options, 'authentication options');

    _requireNonEmptyString(request, 'challenge');
    _requireNonEmptyString(request, 'rpId');

    // Discoverable / Conditional UI uses an empty allowCredentials list so the
    // credential provider can present any resident passkey for this RP.
    final allowCredentials = request['allowCredentials'];
    if (allowCredentials != null && allowCredentials is! List) {
      throw Exception('Invalid allowCredentials field');
    }

    return request;
  }

  Map<String, dynamic> _buildAuthenticationOptionsDiagnostics(
    Map<String, dynamic> options,
  ) {
    final allowCredentials = options['allowCredentials'] is List
        ? options['allowCredentials'] as List
        : const [];

    return {
      'rpId': options['rpId'],
      'rpIdLength': options['rpId']?.toString().length,
      'challenge': _base64UrlDiagnostics(options['challenge']),
      'timeout': options['timeout'],
      'userVerification': options['userVerification'],
      'allowCredentialCount': allowCredentials.length,
      'allowCredentials': allowCredentials.map((credential) {
        if (credential is Map) {
          final map = Map<String, dynamic>.from(credential);
          return {
            'type': map['type'],
            'id': _base64UrlDiagnostics(map['id']),
            'transports': map['transports'],
          };
        }
        return {
          'raw': credential.toString(),
          'type': credential.runtimeType.toString(),
        };
      }).toList(),
      'extensionKeys': options['extensions'] is Map
          ? (options['extensions'] as Map).keys.map((key) => '$key').toList()
          : const <String>[],
      'hintsType': options['hints']?.runtimeType.toString(),
      'hintsLength': options['hints'] is List
          ? (options['hints'] as List).length
          : null,
    };
  }

  Map<String, dynamic> _jsonRoundTripObject(
    Map<String, dynamic> value,
    String label,
  ) {
    try {
      final decoded = jsonDecode(jsonEncode(value));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (e) {
      throw Exception('Invalid $label JSON: $e');
    }
    throw Exception('Invalid $label JSON object');
  }

  Map<String, dynamic> _requireObject(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Missing required field: $key');
  }

  void _requireNonEmptyString(
    Map<String, dynamic> source,
    String path, {
    String? fieldName,
  }) {
    final value = source[fieldName ?? path];
    if (value is String && value.isNotEmpty) return;
    throw Exception('Missing required field: $path');
  }

  void _ensurePasskeyUserDisplayName(Map<String, dynamic> user) {
    final displayName = user['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return;

    user['displayName'] =
        _firstNonEmptyString([
          _currentUser?.displayName,
          _currentUser?.username,
          user['name']?.toString(),
          _currentUser?.email,
        ]) ??
        'NexAI user';
  }

  String? _firstNonEmptyString(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  void _requireNonEmptyList(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is List && value.isNotEmpty) return;
    throw Exception('Missing required field: $key');
  }

  Future<void> _signalPasskeyState({
    required String reason,
    bool includeAcceptedCredentials = true,
  }) async {
    if (!_isAndroidPasskeyNativePlatform || _accessToken == null) return;

    try {
      final options = await NexaiAuthApi.getPasskeySignalOptions(
        accessToken: _accessToken!,
      );
      final results = <String, dynamic>{};

      if (includeAcceptedCredentials) {
        final acceptedCredentials = _optionalSignalRequest(
          options,
          'allAcceptedCredentials',
        );
        if (acceptedCredentials != null) {
          final result = await _androidPasskeyService
              .signalAllAcceptedCredentials(options: acceptedCredentials);
          results['allAcceptedCredentials'] =
              _summarizeAndroidNativeResult(result);
        }
      }

      final currentUserDetails = _optionalSignalRequest(
        options,
        'currentUserDetails',
      );
      if (currentUserDetails != null) {
        final result = await _androidPasskeyService.signalCurrentUserDetails(
          options: currentUserDetails,
        );
        results['currentUserDetails'] = _summarizeAndroidNativeResult(result);
      }

      if (results.isNotEmpty) {
        debugPrint('[NexAI Passkey] Signal state ($reason): $results');
      }
    } catch (e, stackTrace) {
      debugPrint('[NexAI Passkey] Signal state failed ($reason): $e');
      debugPrint('[NexAI Passkey] Signal state stack trace: $stackTrace');
    }
  }

  Future<void> _signalUnknownPasskeyCredential({
    required Map<String, dynamic> requestOptions,
    required Map<String, dynamic> assertion,
    required String reason,
    Map<String, dynamic>? debugContext,
  }) async {
    if (!_isAndroidPasskeyNativePlatform) return;

    final rpId = requestOptions['rpId']?.toString();
    final credentialId =
        assertion['id']?.toString() ?? assertion['rawId']?.toString();
    if (rpId == null ||
        rpId.isEmpty ||
        credentialId == null ||
        credentialId.isEmpty) {
      debugContext?['signalUnknownCredentialSkipped'] = {
        'reason': reason,
        'rpIdPresent': rpId != null && rpId.isNotEmpty,
        'credentialIdPresent': credentialId != null && credentialId.isNotEmpty,
      };
      return;
    }

    final signalOptions = {
      'rpId': rpId,
      'credentialId': credentialId,
    };

    try {
      final result = await _androidPasskeyService.signalUnknownCredential(
        options: signalOptions,
      );
      final summary = _summarizeAndroidNativeResult(result);
      debugContext?['signalUnknownCredential'] = {
        'reason': reason,
        'rpId': rpId,
        'credentialId': _base64UrlDiagnostics(credentialId),
        'result': summary,
      };
      debugPrint('[NexAI Passkey] Signal unknown credential: $summary');
    } catch (e, stackTrace) {
      debugContext?['signalUnknownCredentialError'] = {
        'reason': reason,
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'stackTrace': stackTrace.toString(),
      };
      debugPrint('[NexAI Passkey] Signal unknown credential failed: $e');
    }
  }

  Map<String, dynamic>? _optionalSignalRequest(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];
    if (value is Map<String, dynamic>) {
      return _jsonRoundTripObject(value, '$key signal options');
    }
    if (value is Map) {
      return _jsonRoundTripObject(
        value.map((key, value) => MapEntry(key.toString(), value)),
        '$key signal options',
      );
    }
    return null;
  }

  bool _shouldSignalUnknownCredentialFromError(Object error) {
    if (error is PasskeyApiException && error.isUnknownCredential) {
      return true;
    }
    if (error is AuthResponse) {
      return _shouldSignalUnknownCredential(error.error, error.code);
    }
    return _shouldSignalUnknownCredential(error.toString(), null);
  }

  /// Only signal unknown credentials for stable backend codes from Happy-TTS:
  /// unknown_credential / credential_not_found / passkey_not_found.
  bool _shouldSignalUnknownCredential(String? error, [String? code]) {
    final normalizedCode = code?.toLowerCase().trim() ?? '';
    if (normalizedCode == 'unknown_credential' ||
        normalizedCode == 'credential_not_found' ||
        normalizedCode == 'passkey_not_found') {
      return true;
    }

    final text = error?.toLowerCase() ?? '';
    if (text.isEmpty) return false;
    return text.contains('unknown_credential') ||
        text.contains('credential_not_found') ||
        text.contains('passkey_not_found') ||
        text.contains('no_such_credential') ||
        text.contains('unrecognized_credential') ||
        text.contains('credential not found') ||
        text.contains('未知凭据') ||
        text.contains('凭据不存在');
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
    await _saveCachedUser(user);
  }

  Future<void> _clearTokens() async {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;

    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserJson);
  }

  Future<void> _saveCachedUser(NexaiUser user) async {
    await _storage.write(key: _keyUserJson, value: jsonEncode(user.toJson()));
  }

  Future<NexaiUser?> _readCachedUser() async {
    final cached = await _storage.read(key: _keyUserJson);
    if (cached == null || cached.isEmpty) return null;

    try {
      final decoded = jsonDecode(cached);
      if (decoded is Map<String, dynamic>) {
        return NexaiUser.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[NexAI Auth] Cached user parse error: $e');
    }
    return null;
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
          await _saveCachedUser(userRes.user!);
        }
      } else {
        await _clearTokens();
      }
    } catch (e) {
      debugPrint('[NexAI Auth] Token refresh error: $e');
    }
  }
}
