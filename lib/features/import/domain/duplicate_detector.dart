import 'package:drift/drift.dart';
import 'package:slip_vault/core/database/app_database.dart';

class DuplicateMatch {
  final Entry existingEntry;
  final String reason;

  const DuplicateMatch({
    required this.existingEntry,
    required this.reason,
  });
}

class DuplicateDetector {
  static Future<DuplicateMatch?> checkDuplicate(
    AppDatabase db, {
    String? transactionId,
    int? amountMinor,
    String? counterpartyName,
    DateTime? occurredAt,
    int? excludeId,
  }) async {
    // 1. Transaction ID match (Highest Confidence)
    if (transactionId != null && transactionId.trim().isNotEmpty) {
      final tidQuery = db.select(db.entries)
        ..where((tbl) {
          var expr = tbl.transactionId.equals(transactionId.trim());
          if (excludeId != null) {
            expr = expr & tbl.id.equals(excludeId).not();
          }
          return expr;
        })
        ..limit(1);

      final match = await tidQuery.getSingleOrNull();
      if (match != null) {
        return DuplicateMatch(
          existingEntry: match,
          reason: 'Identical Transaction ID #$transactionId already recorded',
        );
      }
    }

    // 2. Same Amount + Counterparty on the same calendar day
    if (amountMinor != null && counterpartyName != null && counterpartyName.trim().isNotEmpty) {
      final date = occurredAt ?? DateTime.now();
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final sameDayQuery = db.select(db.entries)
        ..where((tbl) {
          var expr = tbl.amountMinor.equals(amountMinor) &
              tbl.occurredAt.isBiggerOrEqualValue(startOfDay) &
              tbl.occurredAt.isSmallerOrEqualValue(endOfDay);
          if (excludeId != null) {
            expr = expr & tbl.id.equals(excludeId).not();
          }
          return expr;
        });

      final candidates = await sameDayQuery.get();
      final normalizedCounterparty = counterpartyName.trim().toLowerCase();

      for (final candidate in candidates) {
        final candName = (candidate.counterpartyName ?? '').trim().toLowerCase();
        if (candName.isNotEmpty &&
            (candName == normalizedCounterparty ||
                candName.contains(normalizedCounterparty) ||
                normalizedCounterparty.contains(candName))) {
          final amtFormatted = (amountMinor / 100).toStringAsFixed(0);
          return DuplicateMatch(
            existingEntry: candidate,
            reason: 'Identical amount ($amtFormatted) to $counterpartyName recorded on the same day',
          );
        }
      }
    }

    return null;
  }
}
