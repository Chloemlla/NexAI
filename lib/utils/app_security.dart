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

/// Result of APK content-hash verification against GitHub release metadata.
///
/// Only [mismatch] means the installed package is known-bad.
/// Network / release metadata failures are [unavailable], not tampering.
enum ApkHashStatus {
  pending,
  skipped,
  verified,
  mismatch,
  unavailable,
}

// ─── AppSecurity singleton ────────────────────────────────────────────────────

class AppSecurity {
  AppSecurity._();
  static final AppSecurity instance = AppSecurity._();

  /// True if device shows root/jailbreak indicators.
  /// Used for honeypot mode — requests will carry [isCompromised] flag.
  bool isCompromised = false;

  /// True if APK signature matches the first-run pinned value.
  bool isSignatureValid = true;

  /// Latest APK content-hash check status.
  ApkHashStatus apkHashStatus = ApkHashStatus.pending;

  /// True unless the APK content hash was confirmed to mismatch GitHub release.
  ///
  /// Official installs must not be treated as invalid when GitHub is unreachable
  /// or release metadata is incomplete.
  bool get isApkHashValid => apkHashStatus != ApkHashStatus.mismatch;

  /// True only after a confirmed hash match against release metadata.
  bool get isApkHashVerified => apkHashStatus == ApkHashStatus.verified;

  /// Human-readable reason for the latest hash status (debug/UX).
  String? apkHashStatusReason;

  String? expectedApkHash;
  String? installedApkHash;

  /// True if debugger is attached.
  bool isDebuggerAttached = false;

  /// True if running on emulator.
  bool isEmulator = false;

  /// True if VPN is active.
  bool isVpnActive = false;

  /// True if ADB debugging is enabled on the device.
  bool isAdbEnabled = false;

  /// True if developer options are enabled.
  bool isDevelopmentSettingsEnabled = false;

  /// True if the running app binary is debuggable.
  bool isDebugBuild = false;

  /// TracerPid from /proc/self/status when available.
  int tracerPid = 0;

  /// True if a tracer is attached.
  bool isTracerAttached = false;

  /// Aggregated anti-debug score from native snapshot (0..1).
  double antiDebugScore = 0;

  /// DEX file hash (for runtime integrity check)
  String? dexHash;

  AndroidSecuritySnapshot? _nativeSnapshot;
  Map<String, dynamic>? _startupSnapshot;
  Future<void>? _initFuture;

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
    if (kIsWeb) {
      apkHashStatus = ApkHashStatus.skipped;
      apkHashStatusReason = 'web platform';
      return;
    }
    _initFuture ??= _initInternal();
    await _initFuture;
  }

  /// Await completion of [init] from UI surfaces that need final integrity status.
  Future<void> ensureInitialized() => init();

  Future<void> _initInternal() async {
    await _loadNativeSnapshot();
    await Future.wait([
      _checkApkSignature(),
      _checkRootStatus(),
      _checkApkFileHash(),
      _checkDebugger(),
      _checkEmulator(),
      _checkVpn(),
      _checkAntiDebugSignals(),
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
      apkHashStatus = ApkHashStatus.skipped;
      apkHashStatusReason = 'debug mode';
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Official Android builds embed short commit hash: "1.0.7-e19d98d36".
      final versionTag = resolveReleaseTag(currentVersion);
      if (versionTag == null) {
        _markApkHashUnavailable('version format missing commit hash');
        return;
      }

      // Fetch release data from GitHub
      final releaseData = await _fetchReleaseByTag(versionTag);
      if (releaseData == null) {
        _markApkHashUnavailable('release not found on GitHub: $versionTag');
        return;
      }

      // Get device ABI
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final supportedAbis = androidInfo.supportedAbis;

      // Find matching APK asset and expected hash
      final expectedHash = await findExpectedHash(releaseData, supportedAbis);
      if (expectedHash == null) {
        _markApkHashUnavailable('no matching APK hash found in release');
        return;
      }

      // Get installed APK hash from native code
      final installedHash = _nativeSnapshot?.apkSha256;
      if (installedHash == null || installedHash.isEmpty) {
        _markApkHashUnavailable('failed to calculate APK hash');
        return;
      }

      expectedApkHash = expectedHash.toLowerCase();
      installedApkHash = installedHash.toLowerCase();

      // Compare hashes
      if (installedApkHash != expectedApkHash) {
        debugPrint('AppSecurity: APK HASH MISMATCH');
        debugPrint('  Expected: $expectedHash');
        debugPrint('  Got:      $installedHash');
        apkHashStatus = ApkHashStatus.mismatch;
        apkHashStatusReason = 'content hash mismatch';
        isCompromised = true;
      } else {
        debugPrint('AppSecurity: APK hash verified');
        apkHashStatus = ApkHashStatus.verified;
        apkHashStatusReason = 'matched GitHub release hash';
      }
    } catch (e) {
      debugPrint('AppSecurity: APK hash check error: $e');
      _markApkHashUnavailable('APK hash check error: $e');
    }
  }

  void _markApkHashUnavailable(String reason) {
    debugPrint('AppSecurity: APK HASH NOT VERIFIED ($reason)');
    // Fail open for user-facing warnings: official GitHub downloads must not be
    // branded as tampered when metadata/network is incomplete.
    apkHashStatus = ApkHashStatus.unavailable;
    apkHashStatusReason = reason;
  }

  /// Maps installed package version to GitHub release tag.
  /// Returns null when the build is not a publishable Android release identity.
  @visibleForTesting
  static String? resolveReleaseTag(String packageVersion) {
    final version = packageVersion.trim();
    if (version.isEmpty) return null;
    final normalized = version.startsWith('v') ? version.substring(1) : version;
    final parts = normalized.split('-');
    if (parts.length < 2 || parts[1].trim().isEmpty) {
      return null;
    }
    return 'v$normalized';
  }

  Future<Map<String, dynamic>?> _fetchReleaseByTag(String tag) async {
    try {
      final url = '$_githubApiUrl/tags/$tag';
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'NexAI-AppSecurity',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint(
        'AppSecurity: release fetch HTTP ${response.statusCode} for $tag',
      );
      return null;
    } catch (e) {
      debugPrint('AppSecurity: failed to fetch release: $e');
      return null;
    }
  }

  @visibleForTesting
  Future<String?> findExpectedHash(
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
    return extractHashFromReleaseBody(body, assetName);
  }

  /// Parses CI release notes such as:
  /// `- \`NexAI_android_1.0.7-abc_arm64-v8a.apk\`\n  - sha256:...`
  @visibleForTesting
  static String? extractHashFromReleaseBody(String body, String assetName) {
    final escaped = RegExp.escape(assetName);
    final match = RegExp(
      '`$escaped`[\\s\\S]{0,200}?sha256:([a-fA-F0-9]{64})',
      caseSensitive: false,
    ).firstMatch(body);
    if (match != null) {
      return match.group(1)?.toLowerCase();
    }

    // Fallback: asset name without backticks, then nearby sha256.
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].toLowerCase().contains(assetName.toLowerCase())) {
        continue;
      }
      for (var j = i; j < i + 5 && j < lines.length; j++) {
        final nearby = RegExp(
          r'sha256:([a-fA-F0-9]{64})',
          caseSensitive: false,
        ).firstMatch(lines[j]);
        if (nearby != null) {
          return nearby.group(1)?.toLowerCase();
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

  Future<void> _checkAntiDebugSignals() async {
    if (!Platform.isAndroid) return;
    try {
      final snapshot = _nativeSnapshot;
      if (snapshot == null) return;

      isAdbEnabled = snapshot.adbEnabled;
      isDevelopmentSettingsEnabled = snapshot.developmentSettingsEnabled;
      isDebugBuild = snapshot.debugBuild;
      tracerPid = snapshot.tracerPid;
      isTracerAttached = snapshot.tracerAttached;
      antiDebugScore = snapshot.antiDebugScore;

      if (isTracerAttached || (isAdbEnabled && isDebuggerAttached) || antiDebugScore >= 0.5) {
        debugPrint(
          'AppSecurity: elevated anti-debug signals '
          'adb=$isAdbEnabled dev=$isDevelopmentSettingsEnabled '
          'debugBuild=$isDebugBuild tracerPid=$tracerPid score=$antiDebugScore',
        );
        isCompromised = true;
      }
    } catch (e) {
      debugPrint('AppSecurity: anti-debug signal check error: $e');
    }
  }

  /// Calculate risk score (0-100)
  int get riskScore {
    var score = 0;
    if (!isSignatureValid) score += 50;
    if (apkHashStatus == ApkHashStatus.mismatch) score += 50;
    if (isCompromised) score += 30;
    if (isDebuggerAttached) score += 40;
    if (isTracerAttached) score += 35;
    if (isAdbEnabled) score += 10;
    if (isDevelopmentSettingsEnabled) score += 8;
    if (isDebugBuild) score += 12;
    if (isEmulator) score += 30;
    if (isVpnActive) score += 20;
    score += (antiDebugScore * 40).round();
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
