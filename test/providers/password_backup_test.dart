import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/providers/password_provider.dart';

void main() {
  group('PasswordProvider encrypted backup', () {
    test('round-trips passwords with AES-256-GCM passphrase', () {
      final passwords = [
        {
          'id': 'p1',
          'category': 'email',
          'password': 's3cret-value',
          'strength': 80,
          'note': 'primary',
          'createdAt': '2026-07-15T00:00:00.000',
        },
      ];

      final backup = PasswordProvider.encryptBackupPayloadForTest(
        passwords: passwords,
        passphrase: 'correct-horse-battery',
        iterations: 10000,
        salt: List<int>.filled(16, 7),
        nonce: List<int>.filled(12, 3),
      );

      final decoded = jsonDecode(backup) as Map<String, dynamic>;
      expect(decoded['format'], PasswordProvider.encryptedBackupFormat);
      expect(decoded['crypto'], isA<Map>());
      expect(jsonEncode(decoded), isNot(contains('s3cret-value')));

      final restored = PasswordProvider.decryptBackupPayloadForTest(
        backup,
        'correct-horse-battery',
      );
      expect(restored, hasLength(1));
      expect(restored.first['password'], 's3cret-value');
      expect(restored.first['category'], 'email');
    });

    test('rejects wrong passphrase', () {
      final backup = PasswordProvider.encryptBackupPayloadForTest(
        passwords: [
          {
            'id': 'p1',
            'category': 'x',
            'password': 'hidden',
            'strength': 10,
            'note': '',
            'createdAt': '2026-07-15T00:00:00.000',
          },
        ],
        passphrase: 'correct-horse-battery',
        iterations: 10000,
      );

      expect(
        () => PasswordProvider.decryptBackupPayloadForTest(
          backup,
          'wrong-passphrase',
        ),
        throwsA(isA<PasswordBackupException>()),
      );
    });
  });
}
