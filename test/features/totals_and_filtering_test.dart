import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/tables.dart';

void main() {
  group('Cash Flow Totals & Formatting Tests', () {
    test('Calculates positive net cash flow correctly', () {
      const received = 5000000; // Rs 50,000
      const sent = 1500000; // Rs 15,000
      final net = received - sent;
      expect(net, equals(3500000));
      final formatted = '${net >= 0 ? '+' : ''}PKR ${(net / 100).toStringAsFixed(0)}';
      expect(formatted, equals('+PKR 35000'));
    });

    test('Calculates negative net cash flow correctly', () {
      const received = 200000; // Rs 2,000
      const sent = 800000; // Rs 8,000
      final net = received - sent;
      expect(net, equals(-600000));
      final formatted = '${net >= 0 ? '+' : ''}PKR ${(net / 100).toStringAsFixed(0)}';
      expect(formatted, equals('PKR -6000'));
    });

    test('Calculates zero net cash flow correctly', () {
      const received = 100000;
      const sent = 100000;
      final net = received - sent;
      expect(net, equals(0));
      final formatted = '${net >= 0 ? '+' : ''}PKR ${(net / 100).toStringAsFixed(0)}';
      expect(formatted, equals('+PKR 0'));
    });
  });

  group('Vault Filter Predicate Tests', () {
    test('Filter matches received items', () {
      bool isMatch(Direction dir, bool needsReview, EntryKind kind, String filter) {
        switch (filter) {
          case 'received':
            return dir == Direction.received;
          case 'sent':
            return dir == Direction.sent;
          case 'needsReview':
            return needsReview;
          case 'other':
            return kind == EntryKind.other;
          default:
            return true;
        }
      }

      expect(isMatch(Direction.received, false, EntryKind.slip, 'received'), isTrue);
      expect(isMatch(Direction.sent, false, EntryKind.slip, 'received'), isFalse);
      expect(isMatch(Direction.sent, false, EntryKind.slip, 'sent'), isTrue);
      expect(isMatch(Direction.unknown, true, EntryKind.slip, 'needsReview'), isTrue);
      expect(isMatch(Direction.sent, false, EntryKind.other, 'other'), isTrue);
      expect(isMatch(Direction.sent, false, EntryKind.slip, 'all'), isTrue);
    });
  });
}
