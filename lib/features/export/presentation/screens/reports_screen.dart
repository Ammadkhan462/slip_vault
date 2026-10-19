import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/export/data/report_export_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isExporting = false;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final monthLabel = '${_monthNames[_selectedMonth - 1]} $_selectedYear';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Reports'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Month Selector Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      if (_selectedMonth == 1) {
                        _selectedMonth = 12;
                        _selectedYear--;
                      } else {
                        _selectedMonth--;
                      }
                    });
                  },
                ),
                Text(
                  monthLabel,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      if (_selectedMonth == 12) {
                        _selectedMonth = 1;
                        _selectedYear++;
                      } else {
                        _selectedMonth++;
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Monthly Totals Card
            FutureBuilder<Map<String, int>>(
              future: db.getMonthlyTotals(_selectedYear, _selectedMonth),
              builder: (context, snapshot) {
                final received = snapshot.data?['received'] ?? 0;
                final sent = snapshot.data?['sent'] ?? 0;
                final net = received - sent;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Net Cash Flow', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '${net >= 0 ? '+' : ''}PKR ${(net / 100).toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: net >= 0 ? AppColors.tertiary : AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Inflow', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                Text('PKR ${(received / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Total Outflow', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                Text('PKR ${(sent / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Export Actions
            Text('EXPORT FORMATS', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Export PDF
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: AppColors.primaryContainer),
                ),
                title: const Text('Export Statement as PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Formatted A4 ledger table with totals for printing or tax proof.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _isExporting ? null : () => _exportPdf(monthLabel),
              ),
            ),
            const SizedBox(height: 12),

            // Export CSV
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.table_view, color: AppColors.tertiary),
                ),
                title: const Text('Export Spreadsheet as CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('UTF-8 with Excel BOM compatibility for spreadsheets and accounting.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _isExporting ? null : () => _exportCsv(monthLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(String monthLabel) async {
    setState(() => _isExporting = true);
    try {
      final db = ref.read(databaseProvider);
      final entries = await db.select(db.entries).get();
      final totals = await db.getMonthlyTotals(_selectedYear, _selectedMonth);
      final file = await ReportExportService.generatePdfReport(
        entries: entries,
        monthLabel: monthLabel,
        totalReceivedMinor: totals['received'] ?? 0,
        totalSentMinor: totals['sent'] ?? 0,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Slip Vault Monthly PDF Report - $monthLabel',
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsv(String monthLabel) async {
    setState(() => _isExporting = true);
    try {
      final db = ref.read(databaseProvider);
      final entries = await db.select(db.entries).get();
      final file = await ReportExportService.generateCsvReport(entries: entries, monthLabel: monthLabel);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Slip Vault Monthly CSV Report - $monthLabel',
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
