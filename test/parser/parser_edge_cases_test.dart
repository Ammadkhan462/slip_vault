import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';
import 'package:slip_vault/features/import/domain/provider_detector.dart';

void main() {
  final parser = GenericParser();

  group('ProviderDetector Comprehensive Provider Tests', () {
    test('Detects NayaPay', () {
      const text = 'NayaPay transaction receipt Money sent successfully';
      expect(ProviderDetector.detect(text), equals('NayaPay'));
    });

    test('Detects Meezan Bank', () {
      const text = 'Meezan Bank internet banking receipt';
      expect(ProviderDetector.detect(text), equals('Meezan Bank'));
    });

    test('Detects Bank Alfalah', () {
      const text = 'Alfa Bank Alfalah digital transaction confirmation';
      expect(ProviderDetector.detect(text), equals('Bank Alfalah'));
    });

    test('Detects HBL Konnect', () {
      const text = 'HBL Konnect cash transfer slip';
      expect(ProviderDetector.detect(text), equals('HBL'));
    });

    test('Detects Allied Bank (myABL)', () {
      const text = 'myABL funds transfer via Allied Bank';
      expect(ProviderDetector.detect(text), equals('Allied Bank'));
    });

    test('Detects UBL Digital', () {
      const text = 'United Bank Limited UBL Digital payment slip';
      expect(ProviderDetector.detect(text), equals('UBL'));
    });

    test('Returns null for unknown/generic non-payment text', () {
      const text = 'Hey did you see this photo of the sunset yesterday?';
      expect(ProviderDetector.detect(text), isNull);
    });
  });

  group('GenericParser Multi-Bank Slip Fixtures', () {
    test('Parses NayaPay slip fixture', () {
      const fixture = '''
      NayaPay
      Transfer Successful
      Paid to: Farhan Siddiqui
      Account: 0312-***6789
      Amount: Rs. 15,200.50
      TID: NP-8472910
      Date: 2026-10-18
      ''';

      final result = parser.parse(fixture);
      expect(result.provider, equals('NayaPay'));
      expect(result.amountMinor, equals(1520050));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, contains('Farhan Siddiqui'));
      expect(result.counterpartyAccountMasked, contains('0312-***6789'));
      expect(result.transactionId, equals('NP-8472910'));
      expect(result.occurredAt, equals(DateTime(2026, 10, 18)));
      expect(result.needsReview, isFalse);
    });

    test('Parses SadaPay received money fixture', () {
      const fixture = '''
      SadaPay
      Money Received
      From: Bilal Ahmed
      Amount: PKR 45,000
      Ref: SD-992182
      Date: 18-10-2026
      ''';

      final result = parser.parse(fixture);
      expect(result.provider, equals('SadaPay'));
      expect(result.amountMinor, equals(4500000));
      expect(result.direction, equals('received'));
      expect(result.counterpartyName, contains('Bilal Ahmed'));
      expect(result.transactionId, equals('SD-992182'));
      expect(result.occurredAt, equals(DateTime(2026, 10, 18)));
      expect(result.needsReview, isFalse);
    });

    test('Parses Raast P2P transaction with IBAN fixture', () {
      const fixture = '''
      State Bank of Pakistan - Raast
      Sent to: Sarah Tariq
      Account: PK34MEZN0001234567890123
      Amount: PKR 1,200,000
      Transaction ID: RST99281726
      Date: 2026/09/12
      ''';

      final result = parser.parse(fixture);
      expect(result.provider, equals('Raast'));
      expect(result.amountMinor, equals(120000000)); // 1.2M Rs = 120M paisa
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, contains('Sarah Tariq'));
      expect(result.counterpartyAccountMasked, equals('PK34MEZN0001234567890123'));
      expect(result.transactionId, equals('RST99281726'));
      expect(result.occurredAt, equals(DateTime(2026, 9, 12)));
    });

    test('Parses Meezan Bank invoice payment fixture', () {
      const fixture = '''
      Meezan Bank
      Payment Successful
      Paid to: K-Electric Ltd
      Amount: Rs 8,450.00
      TID: MB7829104
      Date: 2026-10-05
      ''';

      final result = parser.parse(fixture);
      expect(result.provider, equals('Meezan Bank'));
      expect(result.amountMinor, equals(845000));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, contains('K-Electric Ltd'));
      expect(result.transactionId, equals('MB7829104'));
      expect(result.occurredAt, equals(DateTime(2026, 10, 5)));
    });
  });

  group('GenericParser Edge Cases & Confidence Scoring', () {
    test('Flags review needed when TID is missing', () {
      const text = '''
      JazzCash
      Payment Successful
      Amount: Rs 5,000
      Paid to: Shopkeeper
      ''';

      final result = parser.parse(text);
      expect(result.amountMinor, equals(500000));
      expect(result.transactionId, isNull);
      expect(result.needsReview, isTrue);
    });

    test('Flags review needed when Amount is missing', () {
      const text = '''
      Easypaisa
      Transfer Sent to: Ahmed
      TID: 88776655
      ''';

      final result = parser.parse(text);
      expect(result.amountMinor, isNull);
      expect(result.transactionId, equals('88776655'));
      expect(result.needsReview, isTrue);
    });

    test('Handles decimal amounts correctly', () {
      const text = 'Amount: Rs 150.75 TID: 12345678';
      final result = parser.parse(text);
      expect(result.amountMinor, equals(15075));
    });

    test('Direction defaults to unknown when no keywords match', () {
      const text = 'Transaction ID: 99887766 Amount: Rs 1000';
      final result = parser.parse(text);
      expect(result.direction, equals('unknown'));
      expect(result.needsReview, isTrue); // direction confidence 0.50 < 0.80
    });
  });
}
