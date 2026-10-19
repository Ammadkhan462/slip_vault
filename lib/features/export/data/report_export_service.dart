import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';

class ReportExportService {
  /// Generates CSV report with UTF-8 BOM so Microsoft Excel opens Urdu and special chars correctly
  static Future<File> generateCsvReport({
    required List<Entry> entries,
    required String monthLabel,
    Directory? targetDirectory,
  }) async {
    final List<List<dynamic>> rows = [
      ['Date', 'Type', 'Amount (PKR)', 'Direction', 'Provider', 'Counterparty', 'Account', 'Transaction ID', 'Status']
    ];

    for (final e in entries) {
      final amount = e.amountMinor != null ? (e.amountMinor! / 100).toStringAsFixed(2) : '0.00';
      final date = e.occurredAt != null ? e.occurredAt!.toIso8601String().split('T').first : '';
      rows.add([
        date,
        e.kind.name,
        amount,
        e.direction.name,
        e.provider ?? '',
        e.counterpartyName ?? '',
        e.counterpartyAccountMasked ?? '',
        e.transactionId ?? '',
        e.needsReview ? 'Needs Review' : 'Verified',
      ]);
    }

    final csvCodec = Csv();
    final csvContent = csvCodec.encode(rows);
    // Explicit UTF-8 BOM bytes [0xEF, 0xBB, 0xBF]
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvContent)];

    final dir = targetDirectory ?? await getTemporaryDirectory();
    final file = File('${dir.path}/SlipVault_Report_${monthLabel.replaceAll(' ', '_')}.csv');
    return file.writeAsBytes(bytes);
  }

  /// Generates clean PDF financial ledger report with summary metrics and transactions table
  static Future<File> generatePdfReport({
    required List<Entry> entries,
    required String monthLabel,
    required int totalReceivedMinor,
    required int totalSentMinor,
    Directory? targetDirectory,
  }) async {
    final pdf = pw.Document();

    final netMinor = totalReceivedMinor - totalSentMinor;
    final totalReceived = (totalReceivedMinor / 100).toStringAsFixed(2);
    final totalSent = (totalSentMinor / 100).toStringAsFixed(2);
    final netFlow = (netMinor / 100).toStringAsFixed(2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Slip Vault Monthly Statement', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(monthLabel, style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('Total Received', style: const pw.TextStyle(color: PdfColors.grey700)),
                  pw.Text('PKR $totalReceived', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                ]),
                pw.Column(children: [
                  pw.Text('Total Sent', style: const pw.TextStyle(color: PdfColors.grey700)),
                  pw.Text('PKR $totalSent', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                ]),
                pw.Column(children: [
                  pw.Text('Net Cash Flow', style: const pw.TextStyle(color: PdfColors.grey700)),
                  pw.Text('PKR $netFlow', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.teal700)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Counterparty', 'Provider', 'Tx ID', 'Amount (PKR)'],
            data: entries.map((e) {
              final amt = e.amountMinor != null ? (e.amountMinor! / 100).toStringAsFixed(2) : '-';
              final date = e.occurredAt != null ? e.occurredAt!.toIso8601String().split('T').first : '';
              final sign = e.direction == Direction.received ? '+' : '-';
              return [
                date,
                e.counterpartyName ?? 'Screenshot',
                e.provider ?? '-',
                e.transactionId ?? '-',
                '$sign$amt',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F766E)),
            cellHeight: 25,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    final dir = targetDirectory ?? await getTemporaryDirectory();
    final file = File('${dir.path}/SlipVault_Report_${monthLabel.replaceAll(' ', '_')}.pdf');
    final bytes = await pdf.save();
    return file.writeAsBytes(bytes);
  }
}
