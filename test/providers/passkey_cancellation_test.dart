import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/providers/auth_provider.dart';

void main() {
  group('AndroidPasskeyNativeException.isUserCanceled', () {
    test('detects CreateCredentialCancellationException style codes', () {
      final error = AndroidPasskeyNativeException(
        operation: 'register',
        code: 'create_credential_create_credential_cancellation',
        message: 'User cancelled the selector',
        details: {
          'exceptionClass':
              'androidx.credentials.exceptions.CreateCredentialCancellationException',
          'simpleName': 'CreateCredentialCancellationException',
          'type':
              'android.credentials.CreateCredentialException.TYPE_USER_CANCELED',
        },
      );

      expect(error.isUserCanceled, isTrue);
    });

    test('detects stable user_canceled code from native layer', () {
      final error = AndroidPasskeyNativeException(
        operation: 'authenticate',
        code: 'user_canceled',
        message: 'User cancelled the selector',
        details: const <String, dynamic>{},
      );

      expect(error.isUserCanceled, isTrue);
    });

    test('does not treat unrelated native failures as cancellation', () {
      final error = AndroidPasskeyNativeException(
        operation: 'register',
        code: 'create_credential_no_create_options',
        message: 'No create options available',
        details: {
          'type':
              'android.credentials.CreateCredentialException.TYPE_NO_CREATE_OPTIONS',
        },
      );

      expect(error.isUserCanceled, isFalse);
    });
  });
}