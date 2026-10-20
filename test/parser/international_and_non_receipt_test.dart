import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';

void main() {
  final parser = GenericParser();

  group('Non-Receipt & Security Screenshot Tests', () {
    test('Identifies SafeNest / spam caller warning as non-receipt', () {
      const nonReceiptText = '''
        SafeNest AI Live Shield
        Protected by AI • Family Shield Active
        Defense Simulator (Interactive Demo Mode)
        IRS Gift Card Coercion | Bank Vault Wire Fraud
        Unknown Caller 01:54
        +1 (800) 349-9218 High Risk
        Live Speech Guard (Listening) MIC ACTIVE
        Suspicious Words Detected
        "...you owe unpaid fees, purchase Target gift cards Federal warrant now to avoid a Federal warrant..."
        Target gift cards Federal warrant
        Dad, take a gentle breath.
        Please do not buy cards or share account
        44
      ''';

      final result = parser.parse(nonReceiptText);
      expect(result.isReceipt, isFalse);
      expect(result.needsReview, isTrue);
      expect(result.amountMinor, isNull);
      expect(result.direction, equals('unknown'));
      expect(result.counterpartyName, isNull);
      expect(result.transactionId, isNull);
    });

    test('Identifies random chat screenshot as non-receipt', () {
      const chatText = '''
        Alex: Hey are you coming to dinner tonight?
        10:04 AM
        Me: Yeah see you there at 8!
        Alex: Sounds good, don't forget the keys.
      ''';

      final result = parser.parse(chatText);
      expect(result.isReceipt, isFalse);
      expect(result.amountMinor, isNull);
      expect(result.direction, equals('unknown'));
    });
  });

  group('International Currency & Global Bank Tests', () {
    test('Parses US Dollar (USD) PayPal payment receipt', () {
      const fixture = '''
        PayPal
        You sent a payment
        Amount: \$ 125.50 USD
        Paid to: Sarah Jenkins Design
        Transaction ID: PP-8492019482
        Date: 2026-10-15
      ''';

      final result = parser.parse(fixture);
      expect(result.isReceipt, isTrue);
      expect(result.provider, equals('PayPal'));
      expect(result.currency, equals('USD'));
      expect(result.amountMinor, equals(12550));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, equals('Sarah Jenkins Design'));
      expect(result.transactionId, equals('PP-8492019482'));
    });

    test('Parses Euro (EUR) Revolut transfer receipt', () {
      const fixture = '''
        Revolut
        Transfer Successful
        Paid to: Marco Rossi
        Amount: € 84.00
        Ref: REV-98214309
        Date: 2026-10-12
      ''';

      final result = parser.parse(fixture);
      expect(result.isReceipt, isTrue);
      expect(result.provider, equals('Revolut'));
      expect(result.currency, equals('EUR'));
      expect(result.amountMinor, equals(8400));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, equals('Marco Rossi'));
      expect(result.transactionId, equals('REV-98214309'));
    });

    test('Parses British Pound (GBP) Monzo / Barclays transfer receipt', () {
      const fixture = '''
        Barclays
        Payment Sent Successfully
        Sent to: David Smith Consulting
        Amount: £ 450.00
        Transaction ID: BARC-392019
        Date: 2026-10-09
      ''';

      final result = parser.parse(fixture);
      expect(result.isReceipt, isTrue);
      expect(result.provider, equals('Barclays'));
      expect(result.currency, equals('GBP'));
      expect(result.amountMinor, equals(45000));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, equals('David Smith Consulting'));
      expect(result.transactionId, equals('BARC-392019'));
    });

    test('Parses UAE Dirham (AED) Emirates NBD payment slip', () {
      const fixture = '''
        Emirates NBD
        Transfer Completed
        Beneficiary: Al Futtaim Motors
        Amount: AED 3,200.00
        Ref No: ENBD-847291
        Date: 2026-10-14
      ''';

      final result = parser.parse(fixture);
      expect(result.isReceipt, isTrue);
      expect(result.provider, equals('Emirates NBD'));
      expect(result.currency, equals('AED'));
      expect(result.amountMinor, equals(320000));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, equals('Al Futtaim Motors'));
      expect(result.transactionId, equals('ENBD-847291'));
    });

    test('Parses Saudi Riyal (SAR) Al Rajhi Bank transfer receipt', () {
      const fixture = '''
        Al Rajhi Bank
        Money Transferred
        Paid to: Abdullah Al-Ghamdi
        Amount: SAR 750.00
        Transaction ID: RJH-102938
        Date: 2026-10-16
      ''';

      final result = parser.parse(fixture);
      expect(result.isReceipt, isTrue);
      expect(result.provider, equals('Al Rajhi Bank'));
      expect(result.currency, equals('SAR'));
      expect(result.amountMinor, equals(75000));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, equals('Abdullah Al-Ghamdi'));
      expect(result.transactionId, equals('RJH-102938'));
    });

    test('Parses Indian Rupee (INR) HDFC / UPI payment receipt', () {
      const fixture = '''
        HDFC Bank
        Payment Successful
        Paid to: Ramesh Electronics
        Amount: ₹ 4,500.00
        TID: HDFC-982143
        Date: 2026-10-11
      ''';

      final result = parser.parse(fixture);
      expect(result.isReceipt, isTrue);
      expect(result.provider, equals('HDFC Bank'));
      expect(result.currency, equals('INR'));
      expect(result.amountMinor, equals(450000));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, equals('Ramesh Electronics'));
      expect(result.transactionId, equals('HDFC-982143'));
    });
  });
}
