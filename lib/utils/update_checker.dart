import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../services/android_native/android_update_service.dart';
import 'build_config.dart';

class UpdateChecker {
  static const String _githubApiUrl =
      'https://api.github.com/repos/Chloemlla/NexAI/releases/latest';
  static const String _latestReleasePageUrl =
      'https://github.com/Chloemlla/NexAI/releases/latest';
  static const String _autoUpdateKey = 'auto_update';
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _buildTimeLeeway = Duration(minutes: 1);
  static const Map<String, String> _githubHeaders = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'NexAI-UpdateChecker',
  };

  static bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Check for updates automatically on app start
  static Future<void> checkUpdateOnStart(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final autoUpdate = prefs.getBool(_autoUpdateKey) ?? true;

    if (autoUpdate) {
      if (context.mounted) {
        await checkUpdate(context, isAuto: true);
      }
    }
  }

  /// Check for updates
  static Future<void> checkUpdate(
    BuildContext context, {
    bool isAuto = false,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http
          .get(Uri.parse(_githubApiUrl), headers: _githubHeaders)
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        if (!isAuto && context.mounted) {
          _showErrorDialog(context, '检查更新失败（HTTP ${response.statusCode}）');
        }
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final currentVersion = packageInfo.version;
      final latestPublishedAt = _parsePublishedAt(
        data['published_at'] as String?,
      );

      final latestVersion = _normalizeVersion(tagName);
      final hasNewerSemanticVersion =
          compareSemanticVersions(currentVersion, latestVersion) < 0;
      final hasNewerPublishedRelease = isReleaseNewerThanCurrentBuild(
        currentVersion: currentVersion,
        latestTag: tagName,
        latestPublishedAt: data['published_at'] as String?,
      );

      if (!hasNewerSemanticVersion && !hasNewerPublishedRelease) {
        if (!isAuto && context.mounted) {
          _showUpToDateDialog(context, currentVersion);
        }
        return;
      }

      if (context.mounted) {
        _showUpdateDialog(
          context,
          data,
          currentVersion,
          latestPublishedAt: latestPublishedAt,
          detectedByPublishedAt:
              hasNewerPublishedRelease && !hasNewerSemanticVersion,
        );
      }
    } on TimeoutException {
      if (!isAuto && context.mounted) {
        _showErrorDialog(context, '检查更新超时，请稍后重试');
      }
    } catch (e) {
      if (!isAuto && context.mounted) {
        _showErrorDialog(context, '检查更新时出错：$e');
      }
    }
  }

  /// Open the latest release page directly.
  static Future<void> openLatestReleasePage() =>
      _openReleasePage(_latestReleasePageUrl);

  /// Compare semantic versions.
  /// Returns -1 when [current] is older than [latest].
  @visibleForTesting
  static int compareSemanticVersions(String current, String latest) {
    if (latest.isEmpty) return 0;

    final currentParts = _versionCore(current).split('.');
    final latestParts = _versionCore(latest).split('.');

    final maxParts = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (int i = 0; i < maxParts; i++) {
      final currentNum = i < currentParts.length
          ? int.tryParse(currentParts[i]) ?? 0
          : 0;
      final latestNum = i < latestParts.length
          ? int.tryParse(latestParts[i]) ?? 0
          : 0;

      if (currentNum > latestNum) return 1;
      if (currentNum < latestNum) return -1;
    }

    return 0;
  }

  /// Whether the newest published release should still be offered, even when
  /// the semantic version is lower than the current build.
  @visibleForTesting
  static bool isReleaseNewerThanCurrentBuild({
    required String currentVersion,
    required String latestTag,
    required String? latestPublishedAt,
    int? currentBuildTime,
  }) {
    final normalizedLatestTag = _normalizeVersion(latestTag);
    if (normalizedLatestTag.isEmpty) return false;

    final normalizedCurrentTag = _normalizeVersion(currentVersion);
    if (normalizedCurrentTag == normalizedLatestTag) return false;

    final publishedAt = _parsePublishedAt(latestPublishedAt);
    final buildTimeSeconds = currentBuildTime ?? BuildConfig.buildTime;
    if (publishedAt == null || buildTimeSeconds <= 0) return false;

    final currentBuildAt = DateTime.fromMillisecondsSinceEpoch(
      buildTimeSeconds * 1000,
      isUtc: true,
    );
    return publishedAt.isAfter(currentBuildAt.add(_buildTimeLeeway));
  }

  /// Show update available dialog
  static void _showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String currentVersion, {
    required DateTime? latestPublishedAt,
    required bool detectedByPublishedAt,
  }) {
    final tagName = data['tag_name'] as String? ?? 'Unknown';
    final body = (data['body'] as String?)?.trim().isNotEmpty == true
        ? (data['body'] as String).trim()
        : '暂无发布说明。';
    final htmlUrl = data['html_url'] as String? ?? _latestReleasePageUrl;
    final publishedLabel = latestPublishedAt != null
        ? _formatDateTime(latestPublishedAt)
        : '未知';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('最新 Release：$tagName'),
              const SizedBox(height: 8),
              Text('当前版本：$currentVersion'),
              const SizedBox(height: 8),
              Text('发布时间：$publishedLabel'),
              if (BuildConfig.buildTime > 0) ...[
                const SizedBox(height: 8),
                Text('当前构建号：${BuildConfig.versionCode}'),
              ],
              if (detectedByPublishedAt) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '这个 Release 的发布时间晚于当前构建。即使版本号更低，仍建议升级到最新发布版本。',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('发布说明', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
          if (_isAndroidDevice)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openReleasePage(htmlUrl);
              },
              child: const Text('查看 Release'),
            ),
          if (_isAndroidDevice)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstall(context, data);
              },
              child: const Text('下载 APK'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openReleasePage(htmlUrl);
              },
              child: const Text('打开 Release'),
            ),
        ],
      ),
    );
  }

  /// Download and install APK for Android
  static Future<void> _downloadAndInstall(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final supportedAbis = androidInfo.supportedAbis;

      final assets = data['assets'] as List<dynamic>? ?? [];
      final htmlUrl = data['html_url'] as String? ?? _latestReleasePageUrl;
      final selected = selectAndroidApkAsset(assets, supportedAbis);

      if (selected == null) {
        await _openReleasePage(htmlUrl);
        if (context.mounted) {
          _showErrorDialog(
            context,
            '未找到适配当前设备的 APK，已打开 Release 页面供手动下载。\n设备 ABI: ${supportedAbis.join(', ')}',
          );
        }
        return;
      }

      final releaseBody = data['body'] as String? ?? '';
      final expectedSha256 = extractSha256ForAsset(releaseBody, selected.name);
      if (expectedSha256 == null) {
        await _openReleasePage(htmlUrl);
        if (context.mounted) {
          _showErrorDialog(
            context,
            'Release 未提供 ${selected.name} 的 SHA256 校验值，已打开 Release 页面供手动核对。',
          );
        }
        return;
      }

      final apkFile = await _downloadAssetToTemp(selected);
      final updater = AndroidUpdateService();
      final verified = await updater.verifyApkPackage(
        uriOrPath: apkFile.path,
        expectedSha256: expectedSha256,
      );
      if (!verified.ok) {
        if (context.mounted) {
          final error = verified.error;
          _showErrorDialog(
            context,
            _updateVerifyErrorMessage(error?.code, error?.message),
          );
        }
        return;
      }

      final installed = await updater.installApk(
        uriOrPath: apkFile.path,
        expectedSha256: expectedSha256,
      );
      if (!installed.ok) {
        final error = installed.error;
        final code = error?.code;
        if (code == 'permission_denied') {
          await updater.openUnknownSourcesSettings();
        }
        if (context.mounted) {
          _showErrorDialog(
            context,
            _updateVerifyErrorMessage(code, error?.message),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, '下载更新时出错：$e');
      }
    }
  }

  /// Open release page in browser
  static Future<void> _openReleasePage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Show up-to-date dialog
  static void _showUpToDateDialog(BuildContext context, String currentVersion) {
    final buildLabel = BuildConfig.buildTime > 0
        ? '\n构建号：${BuildConfig.versionCode}'
        : '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('已是最新版本'),
        content: Text('当前版本：$currentVersion$buildLabel'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更新提示'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// Get auto-update preference
  static Future<bool> getAutoUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoUpdateKey) ?? true;
  }

  /// Set auto-update preference
  static Future<void> setAutoUpdate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUpdateKey, value);
  }

  static String _normalizeVersion(String version) {
    if (version.isEmpty) return '';
    return version.startsWith('v') ? version.substring(1) : version;
  }

  static String _versionCore(String version) =>
      _normalizeVersion(version).split('-')[0].split('+')[0];

  static DateTime? _parsePublishedAt(String? publishedAt) {
    if (publishedAt == null || publishedAt.isEmpty) return null;
    return DateTime.tryParse(publishedAt)?.toUtc();
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  @visibleForTesting
  static AndroidApkAsset? selectAndroidApkAsset(
    List<dynamic> assets,
    List<String> supportedAbis,
  ) {
    AndroidApkAsset? universal;

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final originalName = asset['name'] as String? ?? '';
      final name = originalName.toLowerCase();
      final url = asset['browser_download_url'] as String?;
      if (!name.endsWith('.apk') || url == null || url.isEmpty) continue;

      final candidate = AndroidApkAsset(name: originalName, downloadUrl: url);
      if (name.contains('universal') || name.contains('all')) {
        universal = candidate;
      }

      for (final abi in supportedAbis) {
        final abiLower = abi.toLowerCase().replaceAll('_', '-');
        if (name.contains(abiLower)) return candidate;
      }
    }

    return universal;
  }

  @visibleForTesting
  static String? extractSha256ForAsset(String releaseBody, String assetName) {
    final escaped = RegExp.escape(assetName);
    final blockMatch = RegExp(
      '`$escaped`[\\s\\S]{0,160}?sha256:([a-fA-F0-9]{64})',
    ).firstMatch(releaseBody);
    if (blockMatch != null) return blockMatch.group(1)!.toLowerCase();

    final sumLineMatch = RegExp(
      '([a-fA-F0-9]{64})\\s+\\*?$escaped',
    ).firstMatch(releaseBody);
    return sumLineMatch?.group(1)?.toLowerCase();
  }

  static Future<File> _downloadAssetToTemp(AndroidApkAsset asset) async {
    final uri = Uri.parse(asset.downloadUrl);
    final response = await http
        .get(uri, headers: _githubHeaders)
        .timeout(const Duration(minutes: 3));
    if (response.statusCode != 200) {
      throw Exception('APK 下载失败（HTTP ${response.statusCode}）');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${asset.name}');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}

@visibleForTesting
class AndroidApkAsset {
  const AndroidApkAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;
}
