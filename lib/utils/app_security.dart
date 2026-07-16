/// Unified app security manager.
///
/// Provides:
///   1. APK integrity check (signature TOFU — no hardcoded fingerprint in binary)
///   2. APK file hash verification against GitHub releases
///   3. Root / jailbreak detection (honeypot mode — doesn't block, just flags)
///   4. Secure screen toggle (FLAG_SECURE on Android)
///   5. Security context accessible app-wide via [AppSecurity.instance]
library;

import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../services/android_native/android_security_service.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);

const _sigPinKey = 'nexai.apk.signature.v1';
const _githubApiUrl = 'https://api.github.com/repos/Chloemlla/NexAI/releases';

// ─── AppSecurity singleton ────────────────────────────────────────────────────

class AppSecurity {
  AppSecurity._();
  static final AppSecurity instance = AppSecurity._();

  /// True if device shows root/jailbreak indicators.
  /// Used for honeypot mode — requests will carry [isCompromised] flag.
  bool isCompromised = false;

  /// True if APK signature matches the first-run pinned value.
  bool isSignatureValid = true;

  /// True if APK file hash matches GitHub release hash.
  bool isApkHashValid = true;

  /// True if debugger is attached.
  bool isDebuggerAttached = false;

  /// True if running on emulator.
  bool isEmulator = false;

  /// True if VPN is active.
  bool isVpnActive = false;

  /// DEX file hash (for runtime integrity check)
  String? dexHash;

  AndroidSecuritySnapshot? _nativeSnapshot;
  Map<String, dynamic>? _startupSnapshot;

  /// Aggregate snapshot collected early by Kotlin Application bootstrap.
  Map<String, dynamic>? get startupSecuritySnapshot => _startupSnapshot;

  /// Passkey provider diagnostics embedded in the startup snapshot when available.
  Map<String, dynamic>? get passkeyProviderDiagnostics {
    final raw = _startupSnapshot?['passkeyProviders'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  /// Initialise security checks. Call once in [main] before [runApp].
  Future<void> init() async {
    if (kIsWeb) return;
    await _loadNativeSnapshot();
    await Future.wait([
      _checkApkSignature(),
      _checkRootStatus(),
      _checkApkFileHash(),
      _checkDebugger(),
      _checkEmulator(),
      _checkVpn(),
      _checkDexIntegrity(),
    ]);
  }

  Future<void> _loadNativeSnapshot() async {
    if (!Platform.isAndroid) return;

    final service = AndroidSecurityService();
    try {
      final startup = await service.getStartupSecuritySnapshot();
      if (startup.ok && startup.data != null) {
        _startupSnapshot = startup.data;
        final securityRaw = startup.data!['security'];
        if (securityRaw is Map) {
          _nativeSnapshot = AndroidSecuritySnapshot.fromMap(
            securityRaw.map((key, value) => MapEntry(key.toString(), value)),
          );
          debugPrint('AppSecurity: reused startup security snapshot');
          return;
        }
      } else {
        debugPrint(
          'AppSecurity: startup snapshot unavailable: ${startup.error?.code}',
        );
      }
    } catch (e) {
      debugPrint('AppSecurity: startup snapshot error: $e');
    }

    try {
      final result = await service.getSecuritySnapshot();
      if (result.ok) {
        _nativeSnapshot = result.data;
      } else {
        debugPrint(
          'AppSecurity: security snapshot unavailable: ${result.error?.code}',
        );
      }
    } catch (e) {
      debugPrint('AppSecurity: security snapshot error: $e');
    }
  }

  // ── APK Signature (TOFU) ────────────────────────────────────────────────────

  Future<void> _checkApkSignature() async {
    if (!Platform.isAndroid) return;
    try {
      final current = _nativeSnapshot?.signatureSha256;
      if (current == null || current.isEmpty) return;

      final stored = await _storage.read(key: _sigPinKey);

      if (stored == null) {
        // TOFU first run — trust and pin current signature
        await _storage.write(key: _sigPinKey, value: current);
        debugPrint('AppSecurity: APK signature pinned (TOFU)');
        isSignatureValid = true;
      } else if (stored != current) {
        // Mismatch → APK was repackaged / re-signed
        debugPrint('AppSecurity: APK SIGNATURE MISMATCH (possible repack)');
        isSignatureValid = false;
        // Strategy: set compromised flag instead of hard-exit,
        // so honeypot requests can be tracked server-side.
        isCompromised = true;
      } else {
        isSignatureValid = true;
      }
    } catch (e) {
      debugPrint('AppSecurity: signature check error: $e');
    }
  }

  /// Force-clear stored APK signature (call after legitimate app update
  /// where keystore changes — extremely rare, but supported).
  Future<void> clearSignaturePin() => _storage.delete(key: _sigPinKey);

  // ── APK File Hash Verification ───────────────────────────────────────────

  Future<void> _checkApkFileHash() async {
    if (!Platform.isAndroid) return;
    if (kDebugMode) {
      debugPrint('AppSecurity: APK hash check skipped in debug mode');
      return;
    }

    isApkHashValid = false;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Extract commit hash from version (e.g., "1.0.7-e19d98d36")
      final parts = currentVersion.split('-');
      if (parts.length < 2) {
        _markApkHashInvalid('version format missing commit hash');
        return;
      }

      final versionTag = 'v$currentVersion';

      // Fetch release data from GitHub
      final releaseData = await _fetchReleaseByTag(versionTag);
      if (releaseData == null) {
        _markApkHashInvalid('release not found on GitHub: $versionTag');
        return;
      }

      // Get device ABI
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final supportedAbis = androidInfo.supportedAbis;

      // Find matching APK asset and expected hash
      final expectedHash = await _findExpectedHash(releaseData, supportedAbis);
      if (expectedHash == null) {
        _markApkHashInvalid('no matching APK hash found in release');
        return;
      }

      // Get installed APK hash from native code
      final installedHash = _nativeSnapshot?.apkSha256;
      if (installedHash == null || installedHash.isEmpty) {
        _markApkHashInvalid('failed to calculate APK hash');
        return;
      }

      // Compare hashes
      if (installedHash.toLowerCase() != expectedHash.toLowerCase()) {
        debugPrint('AppSecurity: APK HASH MISMATCH');
        debugPrint('  Expected: $expectedHash');
        debugPrint('  Got:      $installedHash');
        isApkHashValid = false;
        isCompromised = true;
      } else {
        debugPrint('AppSecurity: APK hash verified');
        isApkHashValid = true;
      }
    } catch (e) {
      debugPrint('AppSecurity: APK hash check error: $e');
      _markApkHashInvalid('APK hash check error');
    }
  }

  void _markApkHashInvalid(String reason) {
    debugPrint('AppSecurity: APK HASH NOT VERIFIED ($reason)');
    isApkHashValid = false;
    isCompromised = true;
  }

  Future<Map<String, dynamic>?> _fetchReleaseByTag(String tag) async {
    try {
      final url = '$_githubApiUrl/tags/$tag';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('AppSecurity: failed to fetch release: $e');
      return null;
    }
  }

  Future<String?> _findExpectedHash(
    Map<String, dynamic> releaseData,
    List<String> supportedAbis,
  ) async {
    final assets = releaseData['assets'] as List<dynamic>? ?? [];
    final body = releaseData['body'] as String? ?? '';
    final manifestHashes = await _loadReleaseManifestHashes(assets);

    for (final abi in supportedAbis) {
      final abiLower = abi.toLowerCase().replaceAll('_', '-');
      final abiRaw = abi.toLowerCase();

      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '');
        final nameLower = name.toLowerCase();
        if (!nameLower.endsWith('.apk')) continue;
        if (!nameLower.contains(abiLower) && !nameLower.contains(abiRaw)) {
          continue;
        }

        // Prefer machine-readable release-manifest.json when attached.
        final fromManifest = manifestHashes[name] ??
            manifestHashes[nameLower] ??
            _matchManifestHash(manifestHashes, nameLower);
        if (fromManifest != null && fromManifest.isNotEmpty) {
          return fromManifest;
        }

        final fromBody = _extractHashFromBody(body, name);
        if (fromBody != null && fromBody.isNotEmpty) {
          return fromBody;
        }
      }
    }

    return null;
  }

  String? _matchManifestHash(
    Map<String, String> manifestHashes,
    String assetNameLower,
  ) {
    for (final entry in manifestHashes.entries) {
      if (entry.key.toLowerCase() == assetNameLower) {
        return entry.value;
      }
    }
    return null;
  }

  /// Loads sha256 values from release-manifest.json attached to the GitHub release.
  Future<Map<String, String>> _loadReleaseManifestHashes(
    List<dynamic> assets,
  ) async {
    final result = <String, String>{};
    String? manifestUrl;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name == 'release-manifest.json') {
        manifestUrl = asset['browser_download_url'] as String?;
        break;
      }
    }
    if (manifestUrl == null || manifestUrl.isEmpty) return result;

    try {
      final response = await http.get(Uri.parse(manifestUrl));
      if (response.statusCode != 200) return result;
      final decoded = json.decode(response.body);
      if (decoded is! Map) return result;
      final manifestAssets = decoded['assets'];
      if (manifestAssets is! List) return result;
      for (final item in manifestAssets) {
        if (item is! Map) continue;
        final name = item['name']?.toString();
        final hash = item['sha256']?.toString();
        if (name != null &&
            name.isNotEmpty &&
            hash != null &&
            RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
          result[name] = hash.toLowerCase();
        }
      }
    } catch (e) {
      debugPrint('AppSecurity: failed to load release-manifest.json: $e');
    }
    return result;
  }

  String? _extractHashFromBody(String body, String assetName) {
    // Parse format: "sha256:c4ff1d8f8b9f8cd5cb023a81346f389231bddf4843f2fd71845192a01af4518d"
    final lines = body.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check if this line contains the asset name
      if (line.toLowerCase().contains(assetName.toLowerCase())) {
        // Look for sha256 in nearby lines (within 5 lines)
        for (int j = i; j < i + 5 && j < lines.length; j++) {
          final hashLine = lines[j];
          final match = RegExp(
            r'sha256:([a-f0-9]{64})',
            caseSensitive: false,
          ).firstMatch(hashLine);

          if (match != null) {
            return match.group(1);
          }
        }
      }
    }

    return null;
  }

  // ── Root / Jailbreak Detection ───────────────────────────────────────────────

  Future<void> _checkRootStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isAndroid) {
        final rooted = _nativeSnapshot?.rooted ?? false;
        if (rooted) {
          debugPrint('AppSecurity: Root indicators detected');
          isCompromised = true;
        }
      }
      // iOS: MethodChannel not yet wired — can extend similarly
    } catch (e) {
      debugPrint('AppSecurity: root check error: $e');
    }
  }

  // ── Secure Screen ────────────────────────────────────────────────────────────

  /// Enable/disable [FLAG_SECURE] (prevents screenshots & screen recording).
  /// Call with [enable]=true on login and settings pages.
  Future<void> setSecureScreen({required bool enable}) async {
    if (!Platform.isAndroid) return;
    try {
      await AndroidSecurityService().setSecureScreen(enable: enable);
    } catch (e) {
      debugPrint('AppSecurity: setSecureScreen error: $e');
    }
  }

  // ── Anti-Debug ────────────────────────────────────────────────────────────

  Future<void> _checkDebugger() async {
    if (!Platform.isAndroid) return;
    try {
      final attached = _nativeSnapshot?.debuggerAttached ?? false;
      if (attached) {
        debugPrint('AppSecurity: Debugger attached');
        isDebuggerAttached = true;
        isCompromised = true;
      }
    } catch (e) {
      debugPrint('AppSecurity: debugger check error: $e');
    }
  }

  // ── Emulator Detection ────────────────────────────────────────────────────

  Future<void> _checkEmulator() async {
    if (!Platform.isAndroid) return;
    try {
      final emulator = _nativeSnapshot?.emulator ?? false;
      if (emulator) {
        debugPrint('AppSecurity: Running on emulator');
        isEmulator = true;
        isCompromised = true;
      }
    } catch (e) {
      debugPrint('AppSecurity: emulator check error: $e');
    }
  }

  // ── VPN Detection ─────────────────────────────────────────────────────────

  Future<void> _checkVpn() async {
    if (!Platform.isAndroid) return;
    try {
      final vpn = _nativeSnapshot?.vpnActive ?? false;
      if (vpn) {
        debugPrint('AppSecurity: VPN connection detected');
        isVpnActive = true;
        // VPN is not always malicious, so we don't set isCompromised
        // but we track it for risk scoring
      }
    } catch (e) {
      debugPrint('AppSecurity: VPN check error: $e');
    }
  }

  /// Calculate risk score (0-100)
  int get riskScore {
    var score = 0;
    if (!isSignatureValid) score += 50;
    if (!isApkHashValid) score += 50;
    if (isCompromised) score += 30;
    if (isDebuggerAttached) score += 40;
    if (isEmulator) score += 30;
    if (isVpnActive) score += 20;
    return score.clamp(0, 100);
  }

  /// Get risk level description
  String get riskLevel {
    final score = riskScore;
    if (score >= 80) return 'CRITICAL';
    if (score >= 50) return 'HIGH';
    if (score >= 30) return 'MEDIUM';
    if (score >= 10) return 'LOW';
    return 'SAFE';
  }

  // ── DEX Integrity Check ───────────────────────────────────────────────────

  Future<void> _checkDexIntegrity() async {
    if (!Platform.isAndroid) return;
    try {
      final hash = _nativeSnapshot?.dexSha256;
      if (hash != null && hash.isNotEmpty) {
        dexHash = hash;
        debugPrint('AppSecurity: DEX hash: ${hash.substring(0, 16)}...');

        // Store initial DEX hash for runtime comparison
        final stored = await _storage.read(key: 'nexai.dex.hash.v1');
        if (stored == null) {
          await _storage.write(key: 'nexai.dex.hash.v1', value: hash);
          debugPrint('AppSecurity: DEX hash stored (TOFU)');
        } else if (stored != hash) {
          debugPrint('AppSecurity: DEX HASH MISMATCH (runtime tampering)');
          isCompromised = true;
        }
      }
    } catch (e) {
      debugPrint('AppSecurity: DEX integrity check error: $e');
    }
  }

  /// Verify DEX integrity at runtime (call periodically)
  Future<bool> verifyDexIntegrity() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await AndroidSecurityService().getSecuritySnapshot();
      final currentHash = result.data?.dexSha256;
      if (currentHash == null) return false;

      final stored = await _storage.read(key: 'nexai.dex.hash.v1');
      return currentHash == stored;
    } catch (e) {
      debugPrint('AppSecurity: DEX verification error: $e');
      return false;
    }
  }
}
