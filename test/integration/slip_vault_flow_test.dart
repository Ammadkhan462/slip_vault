import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/features/export/data/report_export_service.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Slip Vault End-to-End Flow Integration Test', () {
    late AppDatabase db;
    late Directory tempDir;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tempDir = Directory.systemTemp.createTempSync('integration_test_');
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Full lifecycle: batch insert 20 entries, FTS5 search, totals, and report export', () async {
      // 1. Simulate 20 imported payment slips
      final providers = ['JazzCash', 'Easypaisa', 'SadaPay', 'NayaPay', 'Raast'];
      final counterparties = [
        'Kashif Electronics',
        'Ali Grocery Store',
        'Metro Cash & Carry',
        'Fatima Rent Account',
        'Imran Pharmacy'
      ];

      for (int i = 1; i <= 20; i++) {
        final isReceived = i % 2 == 0;
        final provider = providers[i % providers.length];
        final counterparty = counterparties[i % counterparties.length];
        final amountPaisa = i * 100000; // Rs 1,000 to Rs 20,000

        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                imagePath: '/storage/emulated/0/Pictures/slip_$i.jpg',
                imageHash: 'sha256_hash_mock_$i',
                amountMinor: drift.Value(amountPaisa),
                direction: drift.Value(isReceived ? Direction.received : Direction.sent),
                counterpartyName: drift.Value(counterparty),
                provider: drift.Value(provider),
                transactionId: drift.Value('TID-2026-$i'),
                occurredAt: drift.Value(DateTime(2026, 10, (i % 28) + 1, 12, 0)),
                ocrText: drift.Value('$provider payment of Rs ${(amountPaisa / 100).toStringAsFixed(0)} to $counterparty TID-2026-$i transfer successful'),
              ),
            );
      }

      // Verify all 20 entries exist
      final allEntries = await db.select(db.entries).get();
      expect(allEntries.length, equals(20));

      // 2. Full-text search (FTS5) queries
      final searchByCounterparty = await db.searchEntries('Kashif');
      expect(searchByCounterparty.isNotEmpty, isTrue);
      for (final item in searchByCounterparty) {
        expect(item.ocrText.contains('Kashif') || item.counterpartyName!.contains('Kashif'), isTrue);
      }

      final searchByTid = await db.searchEntries('TID-2026-15');
      expect(searchByTid.length, equals(1));
      expect(searchByTid.first.transactionId, equals('TID-2026-15'));

      final searchByProvider = await db.searchEntries('SadaPay');
      expect(searchByProvider.length, equals(4)); // 20 / 5 = 4 entries

      // 3. Monthly totals aggregation
      final octTotals = await db.getMonthlyTotals(2026, 10);
      expect(octTotals['received'], isPositive);
      expect(octTotals['sent'], isPositive);

      // 4. Report export verification
      final csvFile = await ReportExportService.generateCsvReport(
        entries: allEntries,
        monthLabel: 'October 2026',
        targetDirectory: tempDir,
      );
      final csvBytes = await csvFile.readAsBytes();
      expect(csvBytes.isNotEmpty, isTrue);
      // Verify UTF-8 BOM
      expect(csvBytes[0], equals(0xEF));
      expect(csvBytes[1], equals(0xBB));
      expect(csvBytes[2], equals(0xBF));

      // Verify PDF generation
      final pdfFile = await ReportExportService.generatePdfReport(
        entries: allEntries,
        monthLabel: 'October 2026',
        totalReceivedMinor: octTotals['received'] ?? 0,
        totalSentMinor: octTotals['sent'] ?? 0,
        targetDirectory: tempDir,
      );
      final pdfBytes = await pdfFile.readAsBytes();
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
