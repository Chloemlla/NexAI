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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use server client ID (Web Application type) for backend verification
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleClientId.isNotEmpty ? _googleClientId : null,
        scopes: ['email', 'profile'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        _error = '已取消 Google 登录';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _error = '无法获取 Google ID Token';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Send idToken to backend
      final res = await NexaiAuthApi.googleAuth(idToken: idToken);

      if (res.success && res.accessToken != null && res.user != null) {
        await _saveSession(res.user!, res.accessToken!, res.refreshToken);
        return true;
      } else {
        _error = res.error ?? 'Google 登录失败';
        return false;
      }
    } catch (e) {
      _error = 'Google 登录错误: $e';
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
    if (_accessToken == null) return false;
    _error = null;

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleClientId.isNotEmpty ? _googleClientId : null,
        scopes: ['email', 'profile'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) return false;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _error = '无法获取 Google ID Token';
        return false;
      }

      final res = await NexaiAuthApi.linkGoogle(
        accessToken: _accessToken!,
        idToken: idToken,
      );

      if (res.success && res.user != null) {
        _currentUser = res.user;
        notifyListeners();
        return true;
      } else {
        _error = res.error ?? '关联失败';
        return false;
      }
    } catch (e) {
      _error = '关联错误: $e';
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

    try {
      final passkeyAuth = PasskeyAuthenticator();

      // 1. Get options from backend
      final optionsMap = await NexaiAuthApi.generatePasskeyRegistrationOptions(
        accessToken: _accessToken!,
      );

      // 2. Convert JSON to RegisterRequestType
      final registerRequest = RegisterRequestType.fromJson(optionsMap);

      // 3. Prompt user to create passkey using PasskeyAuthenticator
      final credential = await passkeyAuth.register(registerRequest);

      // 4. Send credential to backend to verify (convert to JSON)
      await NexaiAuthApi.verifyPasskeyRegistration(
        accessToken: _accessToken!,
        responseInfo: credential.toJson(),
      );

      return true;
    } catch (e) {
      debugPrint('[NexAI Passkey] Bind error: $e');
      _error = '绑定 Passkey 失败: $e';
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

    try {
      final passkeyAuth = PasskeyAuthenticator();

      // 1. Get options from backend
      final optionsMap =
          await NexaiAuthApi.generatePasskeyAuthenticationOptions(
            identifier: identifier,
          );

      // 2. Convert JSON to AuthenticateRequestType
      final authRequest = AuthenticateRequestType.fromJson(optionsMap);

      // 3. Prompt user to authenticate
      final assertion = await passkeyAuth.authenticate(authRequest);

      // 4. Send assertion to backend to verify (convert to JSON)
      final res = await NexaiAuthApi.verifyPasskeyAuthentication(
        identifier: identifier,
        responseInfo: assertion.toJson(),
      );

      if (res.success && res.accessToken != null && res.user != null) {
        await _saveSession(res.user!, res.accessToken!, res.refreshToken);
        return true;
      } else {
        _error = res.error ?? 'Passkey 登录失败';
        return false;
      }
    } catch (e) {
      debugPrint('[NexAI Passkey] Login error: $e');
      _error = 'Passkey 登录失败: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== Internal Methods ==========

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
