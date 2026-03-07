import 'package:flutter_test/flutter_test.dart';
import 'package:pato_track/features/capture/services/sms_parser_service.dart';

void main() {
  group('SmsParserService', () {
    final service = SmsParserService();

    test('parses an outgoing M-Pesa payment confirmation', () {
      final parsed = service.parseMpesa(
        'QJD7X8Y9Z0 Confirmed. Ksh1,250.00 paid to KPLC PREPAID. '
        'New M-PESA balance is Ksh4,820.50.',
        DateTime(2026, 3, 6, 9, 30),
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'expense');
      expect(parsed.amount, 1250.0);
      expect(parsed.description, 'Paid to KPLC PREPAID (QJD7X8Y9Z0)');
      expect(parsed.balanceAfter, 4820.50);
      expect(parsed.source, 'sms');
      expect(parsed.isReviewed, isTrue);
    });

    test('returns null for non M-Pesa messages', () {
      final parsed = service.parseMpesa(
        'Your OTP is 123456. Do not share it with anyone.',
        DateTime(2026, 3, 6, 9, 30),
      );

      expect(parsed, isNull);
    });
  });
}
