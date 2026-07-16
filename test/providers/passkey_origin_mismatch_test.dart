import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/providers/auth_provider.dart';

void main() {
  group('androidApkKeyHashOriginsFromSha256', () {
    test('emits both base64url and standard base64 origins', () {
      const signature =
          'FFD1F37C27051ACC7FA18745E107E6179A28572619B63FC6F74DAC3DA44ED7CE';

      expect(
        androidApkKeyHashOriginsFromSha256(signature),
        [
          'android:apk-key-hash:_9HzfCcFGsx_oYdF4QfmF5ooVyYZtj_G902sPaRO184',
          'android:apk-key-hash:/9HzfCcFGsx/oYdF4QfmF5ooVyYZtj/G902sPaRO184',
        ],
      );
    });

    test('accepts colon-separated fingerprints', () {
      const fingerprint =
          'FF:D1:F3:7C:27:05:1A:CC:7F:A1:87:45:E1:07:E6:17:9A:28:57:26:19:B6:3F:C6:F7:4D:AC:3D:A4:4E:D7:CE';

      expect(
        androidApkKeyHashOriginsFromSha256(fingerprint),
        contains(
          'android:apk-key-hash:/9HzfCcFGsx/oYdF4QfmF5ooVyYZtj/G902sPaRO184',
        ),
      );
    });
  });

  group('parseAndroidApkKeyHashOriginMismatch', () {
    test('detects base64 vs base64url encoding mismatch', () {
      const message =
          'Exception: 注册验证失败: Unexpected registration response origin '
          '"android:apk-key-hash:/9HzfCcFGsx/oYdF4QfmF5ooVyYZtj/G902sPaRO184", '
          'expected one of: https://tts.chloemlla.com, '
          'android:apk-key-hash:_9HzfCcFGsx_oYdF4QfmF5ooVyYZtj_G902sPaRO184';

      final parsed = parseAndroidApkKeyHashOriginMismatch(message);
      expect(parsed, isNotNull);
      expect(parsed!['encodingMismatch'], isTrue);
      expect(
        parsed['actualOrigin'],
        'android:apk-key-hash:/9HzfCcFGsx/oYdF4QfmF5ooVyYZtj/G902sPaRO184',
      );
      expect(
        parsed['alternateOrigin'],
        'android:apk-key-hash:_9HzfCcFGsx_oYdF4QfmF5ooVyYZtj_G902sPaRO184',
      );
    });

    test('returns null for unrelated errors', () {
      expect(
        parseAndroidApkKeyHashOriginMismatch('Invalid challenge'),
        isNull,
      );
    });
  });
}
