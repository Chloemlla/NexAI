import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/services/clash_compat.dart';

void main() {
  group('ClashCompat.describeDeniedReason', () {
    test('every CMFA denial reason maps to distinct actionable text', () {
      const reasons = [
        'pending_user_approval',
        'denied_by_user',
        'signer_unverified',
        'not_partner',
        'no_signature',
      ];
      final described = reasons.map(ClashCompat.describeDeniedReason).toList();
      for (final text in described) {
        expect(text, isNotEmpty);
        expect(text.contains('Clash 返回原因'), isFalse);
      }
      expect(described.toSet().length, reasons.length);
    });

    test('unknown reasons are passed through and null is honest', () {
      expect(
        ClashCompat.describeDeniedReason('brand_new_reason'),
        contains('brand_new_reason'),
      );
      expect(ClashCompat.describeDeniedReason(null), 'Clash 未说明原因');
    });
  });
}
