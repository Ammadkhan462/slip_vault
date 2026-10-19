import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/features/export/data/report_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ReportExportService generates CSV report with UTF-8 BOM', () async {
    final entries = [
      Entry(
        id: 1,
        kind: EntryKind.slip,
        imagePath: '/tmp/test.jpg',
        imageHash: 'hash123',
        amountMinor: 500000,
        currency: 'PKR',
        direction: Direction.received,
        counterpartyName: 'Ali Khan',
        counterpartyAccountMasked: '0300-***1234',
        transactionId: 'TX12345',
        provider: 'JazzCash',
        occurredAt: DateTime(2026, 10, 12),
        ocrText: 'JazzCash Rs 5,000 received',
        needsReview: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final csvFile = await ReportExportService.generateCsvReport(
      entries: entries,
      monthLabel: 'October 2026',
      targetDirectory: Directory.systemTemp,
    );

    expect(await csvFile.exists(), isTrue);
    final bytes = await csvFile.readAsBytes();
    // Validate UTF-8 BOM bytes explicitly
    expect(bytes.sublist(0, 3), equals([0xEF, 0xBB, 0xBF]));
    final content = await csvFile.readAsString();
    expect(content, contains('Ali Khan'));
    expect(content, contains('5000.00'));
    expect(content, contains('TX12345'));

    if (await csvFile.exists()) {
      await csvFile.delete();
    }
  });

  test('ReportExportService generates valid PDF report document', () async {
    final entries = [
      Entry(
        id: 1,
        kind: EntryKind.slip,
        imagePath: '/tmp/test.jpg',
        imageHash: 'hash123',
        amountMinor: 1250000,
        currency: 'PKR',
        direction: Direction.received,
        counterpartyName: 'Kashif Electronics',
        counterpartyAccountMasked: '0345-***9012',
        transactionId: 'TID-0498213894',
        provider: 'JazzCash',
        occurredAt: DateTime(2026, 10, 12),
        ocrText: 'Sample text',
        needsReview: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final pdfFile = await ReportExportService.generatePdfReport(
      entries: entries,
      monthLabel: 'October 2026',
      totalReceivedMinor: 1250000,
      totalSentMinor: 0,
      targetDirectory: Directory.systemTemp,
    );

    expect(await pdfFile.exists(), isTrue);
    final bytes = await pdfFile.readAsBytes();
    // PDF magic bytes: %PDF
    expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));

    if (await pdfFile.exists()) {
      await pdfFile.delete();
    }
  });
}
