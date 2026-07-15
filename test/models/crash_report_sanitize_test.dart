import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/models/crash_report.dart';

void main() {
  group('CrashReport secret redaction', () {
    test('redacts bearer tokens, API keys, and query secrets', () {
      final report = CrashReport.fromError(
        Exception(
          'Bearer abc.def.ghi failed for '
          'https://api.example.com/v1?api_key=super-secret&token=t123 '
          'sk-abcdefghijklmnopqrstuvwxyz AIzaSyDummyGoogleApiKeyValue123456',
        ),
        StackTrace.fromString('Bearer xyz123\n#0 main'),
      );

      final text = report.toClipboardText();
      expect(text, contains('Bearer [redacted]'));
      expect(text, contains('api_key=[redacted]'));
      expect(text, contains('token=[redacted]'));
      expect(text, contains('sk-[redacted]'));
      expect(text, contains('AIza[redacted]'));
      expect(text, isNot(contains('super-secret')));
      expect(text, isNot(contains('abcdefghijklmnopqrstuvwxyz')));
    });
  });
}
