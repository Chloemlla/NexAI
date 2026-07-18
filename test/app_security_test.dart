import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/utils/app_security.dart';

void main() {
  group('AppSecurity.resolveReleaseTag', () {
    test('accepts official android version with commit hash', () {
      expect(
        AppSecurity.resolveReleaseTag('1.0.7-4a1684455'),
        'v1.0.7-4a1684455',
      );
    });

    test('rejects bare semantic versions without release identity', () {
      expect(AppSecurity.resolveReleaseTag('1.0.7'), isNull);
    });
  });

  group('AppSecurity.extractHashFromReleaseBody', () {
    test('parses CI release notes for the matching asset', () {
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final extracted = AppSecurity.extractHashFromReleaseBody(
        '## NexAI 1.0.7-abc\n\n### APK SHA256\n'
        '- `NexAI_android_1.0.7-abc_arm64-v8a.apk`\n'
        '  - sha256:$hash\n',
        'NexAI_android_1.0.7-abc_arm64-v8a.apk',
      );

      expect(extracted, hash);
    });
  });

  group('AppSecurity apk hash validity semantics', () {
    test('only confirmed mismatch is treated as invalid', () {
      final security = AppSecurity.instance;
      security.apkHashStatus = ApkHashStatus.pending;
      expect(security.isApkHashValid, isTrue);

      security.apkHashStatus = ApkHashStatus.unavailable;
      expect(security.isApkHashValid, isTrue);

      security.apkHashStatus = ApkHashStatus.verified;
      expect(security.isApkHashValid, isTrue);
      expect(security.isApkHashVerified, isTrue);

      security.apkHashStatus = ApkHashStatus.mismatch;
      expect(security.isApkHashValid, isFalse);
      expect(security.isApkHashVerified, isFalse);

      // Reset singleton for other tests/runtime use.
      security.apkHashStatus = ApkHashStatus.pending;
    });
  });
}
