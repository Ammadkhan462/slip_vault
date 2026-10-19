import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';
import 'package:slip_vault/features/import/domain/provider_detector.dart';

void main() {
  group('ProviderDetector Tests', () {
    test('Detects JazzCash from OCR text', () {
      const text = 'Transaction Successful! Mobilink Microfinance Bank JazzCash TID: 981247';
      expect(ProviderDetector.detect(text), equals('JazzCash'));
    });

    test('Detects Easypaisa from OCR text', () {
      const text = 'Money Transferred! Telenor Microfinance Bank easypaisa Trx ID: EP12984';
      expect(ProviderDetector.detect(text), equals('Easypaisa'));
    });

    test('Detects SadaPay from OCR text', () {
      const text = 'Paid via SadaPay to Ali Khan Rs 3,500';
      expect(ProviderDetector.detect(text), equals('SadaPay'));
    });

    test('Detects Raast from OCR text', () {
      const text = 'State Bank of Pakistan Raast P2P payment of PKR 10,000 sent';
      expect(ProviderDetector.detect(text), equals('Raast'));
    });
  });

  group('GenericParser Tests', () {
    final parser = GenericParser();

    test('Parses labeled JazzCash slip text fixture', () {
      const fixture = '''
      JazzCash
      Payment Successful
      Amount: Rs 12,500.00
      Paid to: Kashif Electronics
      Account: 0345-***9012
      TID: 0498213894
      Date: 12-10-2026
      ''';

      final result = parser.parse(fixture);
      expect(result.provider, equals('JazzCash'));
      expect(result.amountMinor, equals(1250000));
      expect(result.direction, equals('sent'));
      expect(result.counterpartyName, contains('Kashif Electronics'));
      expect(result.transactionId, equals('0498213894'));
      expect(result.counterpartyAccountMasked, contains('0345-***9012'));
    });

    test('Parses received Easypaisa slip text fixture', () {
      const fixture = '''
      Easypaisa
      You have received money!
      Amount: PKR 5,000
      Received from: Muhammad Tariq
      Transaction ID: 98214309
      Date: 2026-10-12
      ''';

      final result = parser.parse(fixture);
      expect(result.provider, equals('Easypaisa'));
      expect(result.amountMinor, equals(500000));
      expect(result.direction, equals('received'));
      expect(result.counterpartyName, contains('Muhammad Tariq'));
      expect(result.transactionId, equals('98214309'));
    });

    test('Flags low confidence when critical fields missing', () {
      const noisyText = 'Random text with no amount or transaction id';
      final result = parser.parse(noisyText);
      expect(result.needsReview, isTrue);
      expect(result.amountMinor, isNull);
    });
  });
}
