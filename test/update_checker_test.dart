import 'package:flutter_test/flutter_test.dart';

import 'package:nexai/utils/update_checker.dart';

void main() {
  group('UpdateChecker.compareSemanticVersions', () {
    test('returns negative when current version is older', () {
      expect(UpdateChecker.compareSemanticVersions('1.0.7', '1.0.8'), -1);
    });

    test('ignores hash/build metadata when comparing versions', () {
      expect(
        UpdateChecker.compareSemanticVersions('1.0.7-abc123456', 'v1.0.7+99'),
        0,
      );
    });

    test('returns positive when current version is newer', () {
      expect(UpdateChecker.compareSemanticVersions('1.1.0', '1.0.9'), 1);
    });
  });

  group('UpdateChecker.isReleaseNewerThanCurrentBuild', () {
    test('offers newer release when it was published after current build', () {
      expect(
        UpdateChecker.isReleaseNewerThanCurrentBuild(
          currentVersion: '1.0.8-abc123456',
          latestTag: 'v1.0.7-def987654',
          latestPublishedAt: '2026-04-06T10:05:00Z',
          currentBuildTime:
              DateTime.utc(2026, 4, 6, 10, 0).millisecondsSinceEpoch ~/ 1000,
        ),
        isTrue,
      );
    });

    test('does not offer same tag again', () {
      expect(
        UpdateChecker.isReleaseNewerThanCurrentBuild(
          currentVersion: '1.0.7-abc123456',
          latestTag: 'v1.0.7-abc123456',
          latestPublishedAt: '2026-04-06T10:05:00Z',
          currentBuildTime:
              DateTime.utc(2026, 4, 6, 10, 0).millisecondsSinceEpoch ~/ 1000,
        ),
        isFalse,
      );
    });
  });

  group('UpdateChecker Android APK metadata', () {
    test('selects the first ABI-matching APK before universal fallback', () {
      final selected = UpdateChecker.selectAndroidApkAsset(
        [
          {
            'name': 'NexAI_android_1.0.0_universal.apk',
            'browser_download_url': 'https://example.com/universal.apk',
          },
          {
            'name': 'NexAI_android_1.0.0_arm64-v8a.apk',
            'browser_download_url': 'https://example.com/arm64.apk',
          },
        ],
        ['arm64-v8a'],
      );

      expect(selected?.name, 'NexAI_android_1.0.0_arm64-v8a.apk');
    });

    test('extracts SHA256 bound to the selected APK name', () {
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final extracted = UpdateChecker.extractSha256ForAsset(
        '- `NexAI_android_1.0.0_arm64-v8a.apk`\n  - sha256:$hash',
        'NexAI_android_1.0.0_arm64-v8a.apk',
      );

      expect(extracted, hash);
    });
  });
}
