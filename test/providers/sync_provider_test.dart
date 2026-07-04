import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/providers/sync_provider.dart';

void main() {
  group('SyncProvider restore staging', () {
    test(
      'refuses partial restore when any encrypted record is undecryptable',
      () async {
        final provider = SyncProvider();

        await expectLater(
          provider.debugDecryptSnapshot({
            'records': [
              {
                'id': 'note-1',
                'category': 'notes',
                'updatedAt': '2026-07-04T00:00:00.000Z',
                'deleted': false,
                'crypto': {'alg': 'unsupported'},
              },
            ],
          }),
          throwsA(isA<SyncRestoreException>()),
        );
      },
    );

    test(
      'ignores explicitly deleted records without requiring ciphertext',
      () async {
        final provider = SyncProvider();
        final snapshot = await provider.debugDecryptSnapshot({
          'records': [
            {
              'id': 'note-1',
              'category': 'notes',
              'updatedAt': '2026-07-04T00:00:00.000Z',
              'deleted': true,
            },
          ],
        });

        expect(snapshot['notes'], isEmpty);
      },
    );
  });
}
