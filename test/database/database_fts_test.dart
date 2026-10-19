import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Database FTS5 & Triggers Tests', () {
    test('Inserting entry triggers FTS5 indexing for search', () async {
      final entryId = await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/to/jazz_slip.jpg',
              imageHash: 'hash_jazz_123',
              amountMinor: const Value(500000), // Rs 5,000.00
              direction: const Value(Direction.sent),
              counterpartyName: const Value('Hamza Electronic Store'),
              transactionId: const Value('JC-992831'),
              provider: const Value('JazzCash'),
              occurredAt: Value(DateTime(2026, 10, 15, 14, 30)),
              ocrText: const Value('JazzCash Transfer Successful to Hamza Electronic Store TID JC-992831'),
            ),
          );

      expect(entryId, isNonZero);

      // Search by counterparty
      final resultsByCounterparty = await db.searchEntries('Hamza');
      expect(resultsByCounterparty.length, equals(1));
      expect(resultsByCounterparty.first.id, equals(entryId));

      // Search by transaction ID
      final resultsByTid = await db.searchEntries('992831');
      expect(resultsByTid.length, equals(1));
      expect(resultsByTid.first.counterpartyName, equals('Hamza Electronic Store'));

      // Search by raw OCR text
      final resultsByOcr = await db.searchEntries('Successful');
      expect(resultsByOcr.length, equals(1));
    });

    test('Updating entry updates FTS5 search index via trigger', () async {
      final entryId = await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/to/ep_slip.jpg',
              imageHash: 'hash_ep_456',
              amountMinor: const Value(250000),
              counterpartyName: const Value('OldVendor Name'),
              transactionId: const Value('EP-112233'),
              ocrText: const Value('Old text inside receipt'),
            ),
          );

      var resultsOld = await db.searchEntries('OldVendor');
      expect(resultsOld.length, equals(1));

      // Update counterparty and note
      await (db.update(db.entries)..where((tbl) => tbl.id.equals(entryId))).write(
        const EntriesCompanion(
          counterpartyName: Value('NewVendor Shop'),
          note: Value('Updated invoice reference 2026'),
        ),
      );

      // Old name should no longer match
      resultsOld = await db.searchEntries('OldVendor');
      expect(resultsOld.isEmpty, isTrue);

      // New name should match
      final resultsNew = await db.searchEntries('NewVendor');
      expect(resultsNew.length, equals(1));
      expect(resultsNew.first.id, equals(entryId));

      // Search inside note
      final resultsNote = await db.searchEntries('invoice');
      expect(resultsNote.length, equals(1));
    });

    test('Deleting entry removes it from FTS5 index via trigger', () async {
      final entryId = await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/to/temp_slip.jpg',
              imageHash: 'hash_del_789',
              counterpartyName: const Value('Temporary Account'),
              ocrText: const Value('UniqueEphemeralTokenString'),
            ),
          );

      var results = await db.searchEntries('UniqueEphemeralTokenString');
      expect(results.length, equals(1));

      // Delete entry
      await (db.delete(db.entries)..where((tbl) => tbl.id.equals(entryId))).go();

      // FTS search should return nothing
      results = await db.searchEntries('UniqueEphemeralTokenString');
      expect(results.isEmpty, isTrue);
    });

    test('Calculates monthly cash flow totals accurately', () async {
      // October 2026 entries
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/1',
              imageHash: 'hash_1',
              amountMinor: const Value(1000000), // Rs 10,000 received
              direction: const Value(Direction.received),
              occurredAt: Value(DateTime(2026, 10, 5)),
            ),
          );

      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/2',
              imageHash: 'hash_2',
              amountMinor: const Value(350000), // Rs 3,500 sent
              direction: const Value(Direction.sent),
              occurredAt: Value(DateTime(2026, 10, 10)),
            ),
          );

      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/3',
              imageHash: 'hash_3',
              amountMinor: const Value(150000), // Rs 1,500 sent
              direction: const Value(Direction.sent),
              occurredAt: Value(DateTime(2026, 10, 20)),
            ),
          );

      // September 2026 entry (should not be counted in October)
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/sep',
              imageHash: 'hash_sep',
              amountMinor: const Value(5000000),
              direction: const Value(Direction.received),
              occurredAt: Value(DateTime(2026, 9, 30)),
            ),
          );

      final octTotals = await db.getMonthlyTotals(2026, 10);
      expect(octTotals['received'], equals(1000000));
      expect(octTotals['sent'], equals(500000)); // 350000 + 150000

      final sepTotals = await db.getMonthlyTotals(2026, 9);
      expect(sepTotals['received'], equals(5000000));
      expect(sepTotals['sent'], equals(0));
    });
  });
}
