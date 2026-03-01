import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  static const String _githubApiUrl =
      'https://api.github.com/repos/Chloemlla/NexAI/releases/latest';
  static const String _autoUpdateKey = 'auto_update';

  /// Check for updates automatically on app start
  static Future<void> checkUpdateOnStart(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final autoUpdate = prefs.getBool(_autoUpdateKey) ?? true;

    if (autoUpdate) {
      await checkUpdate(context, isAuto: true);
    }
  }

  /// Check for updates
  static Future<void> checkUpdate(
    BuildContext context, {
    bool isAuto = false,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http.get(Uri.parse(_githubApiUrl));

      if (response.statusCode != 200) {
        if (!isAuto && context.mounted) {
          _showErrorDialog(context, 'Failed to check for updates');
        }
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final currentVersion = packageInfo.version;

      // Compare versions: remove 'v' prefix if present
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (_isVersionUpToDate(currentVersion, latestVersion)) {
        // Already up to date
        if (!isAuto && context.mounted) {
          _showUpToDateDialog(context, currentVersion);
        }
        return;
      }

      // New version available
      if (context.mounted) {
        _showUpdateDialog(context, data, currentVersion);
      }
    } catch (e) {
      if (!isAuto && context.mounted) {
        _showErrorDialog(context, 'Error checking for updates: $e');
      }
    }
  }

  /// Compare version strings (semantic versioning)
  static bool _isVersionUpToDate(String current, String latest) {
    if (latest.isEmpty) return true;

    // Extract version numbers (e.g., "1.0.7-02eb84086" -> "1.0.7")
    final currentParts = current.split('-')[0].split('+')[0].split('.');
    final latestParts = latest.split('-')[0].split('+')[0].split('.');

    // Compare up to the maximum number of parts in either version
    final maxParts = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (int i = 0; i < maxParts; i++) {
      final currentNum = i < currentParts.length ? int.tryParse(currentParts[i]) ?? 0 : 0;
      final latestNum = i < latestParts.length ? int.tryParse(latestParts[i]) ?? 0 : 0;

      if (currentNum > latestNum) return true;
      if (currentNum < latestNum) return false;
    }

    return true; // Versions are equal
  }

  /// Show update available dialog
  static void _showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String currentVersion,
  ) {
    final tagName = data['tag_name'] as String? ?? 'Unknown';
    final body = data['body'] as String? ?? 'No release notes available';
    final htmlUrl = data['html_url'] as String? ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New version: $tagName'),
              const SizedBox(height: 8),
              Text('Current version: $currentVersion'),
              const SizedBox(height: 16),
              const Text(
                'Release Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          if (Platform.isAndroid)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstall(context, data);
              },
              child: const Text('Download'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openReleasePage(htmlUrl);
              },
              child: const Text('View Release'),
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
      String? downloadUrl;
      String? universalApkUrl;

      // Find matching APK for device architecture
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (!name.endsWith('.apk')) continue;

        // Check for universal APK as fallback
        if (name.contains('universal') || name.contains('all')) {
          universalApkUrl = asset['browser_download_url'] as String?;
        }

        // Try to match device ABI (check all supported ABIs in order)
        for (final abi in supportedAbis) {
          final abiLower = abi.toLowerCase().replaceAll('_', '-');
          if (name.contains(abiLower)) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }

        if (downloadUrl != null) break;
      }

      // Use universal APK if no specific match found
      downloadUrl ??= universalApkUrl;

      if (downloadUrl == null) {
        if (context.mounted) {
          _showErrorDialog(
            context,
            'No compatible APK found for your device (${supportedAbis.join(', ')})',
          );
        }
        return;
      }

      // Open download URL in browser
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          _showErrorDialog(context, 'Cannot open download link');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Error downloading update: $e');
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Up to Date'),
        content: Text(
          'You are running the latest version ($currentVersion)',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
        title: const Text('Error'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
}
