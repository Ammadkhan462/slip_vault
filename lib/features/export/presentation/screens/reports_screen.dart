import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/core/widgets/vault_bottom_bar.dart';
import 'package:slip_vault/features/export/data/report_export_service.dart';
import 'package:slip_vault/features/reports/presentation/widgets/report_charts.dart';

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
        child: StreamBuilder<List<Entry>>(
          stream: db.select(db.entries).watch(),
          builder: (context, snapshot) {
            final allEntries = snapshot.data ?? [];

            // Filter entries for the selected month
            final monthEntries = allEntries.where((e) {
              final d = e.occurredAt ?? e.createdAt;
              return d.year == _selectedYear && d.month == _selectedMonth;
            }).toList();

            int received = 0;
            int sent = 0;
            for (final e in monthEntries) {
              if (e.amountMinor != null) {
                if (e.direction == Direction.received) {
                  received += e.amountMinor!;
                } else if (e.direction == Direction.sent) {
                  sent += e.amountMinor!;
                }
              }
            }
            final net = received - sent;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Month Selector Bar (Modern Pill)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: isDark ? AppColors.outlineVariantDark.withAlpha(50) : AppColors.outlineVariantLight.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        visualDensity: VisualDensity.compact,
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
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 18, color: AppColors.primaryContainer),
                          const SizedBox(width: 6),
                          Text(
                            monthLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withAlpha(30),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: const Text(
                              'Audited',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        visualDensity: VisualDensity.compact,
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
                ),
                const SizedBox(height: 16),

                // Hero Monthly Totals Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF064E3B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withAlpha(50),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Monthly Net Cash Flow',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFCCFBF1),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: const Text(
                              'On-Device Ledger',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${net >= 0 ? '+' : ''}PKR ${(net / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withAlpha(25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_downward, size: 13, color: Color(0xFF6EE7B7)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Total Inflow',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFD1FAE5), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'PKR ${(received / 100).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withAlpha(25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_upward, size: 13, color: Color(0xFFFCA5A5)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Total Outflow',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFFEE2E2), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'PKR ${(sent / 100).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 6-Month Visual Trend Bar Chart
                SixMonthCashFlowChart(
                  allEntries: allEntries,
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                ),
                const SizedBox(height: 16),

                // Top 5 Counterparties / Payees
                TopCounterpartiesWidget(monthEntries: monthEntries),
                const SizedBox(height: 16),

                // Spending by Category Breakdown
                CategoryBreakdownWidget(monthEntries: monthEntries),
                const SizedBox(height: 24),

                // Export Actions
                Text('EXPORT FORMATS', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 10),

                // Export PDF
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: AppColors.primaryContainer, size: 24),
                    ),
                    title: const Text('Export Statement as PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Formatted A4 ledger table with totals for printing or tax proof.', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: _isExporting ? null : () => _exportPdf(monthLabel, monthEntries, received, sent),
                  ),
                ),
                const SizedBox(height: 10),

                // Export CSV
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.table_view, color: AppColors.tertiary, size: 24),
                    ),
                    title: const Text('Export Spreadsheet as CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('UTF-8 with Excel BOM compatibility for spreadsheets and accounting.', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: _isExporting ? null : () => _exportCsv(monthLabel, monthEntries),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const VaultBottomBar(currentIndex: 2),
    );
  }

  Future<void> _exportPdf(String monthLabel, List<Entry> entries, int received, int sent) async {
    setState(() => _isExporting = true);
    try {
      final file = await ReportExportService.generatePdfReport(
        entries: entries,
        monthLabel: monthLabel,
        totalReceivedMinor: received,
        totalSentMinor: sent,
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

  Future<void> _exportCsv(String monthLabel, List<Entry> entries) async {
    setState(() => _isExporting = true);
    try {
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
