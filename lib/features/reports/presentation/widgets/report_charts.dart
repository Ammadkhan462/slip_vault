import 'dart:math';
import 'package:flutter/material.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/categories/domain/category_model.dart';

class SixMonthCashFlowChart extends StatelessWidget {
  final List<Entry> allEntries;
  final int selectedYear;
  final int selectedMonth;

  const SixMonthCashFlowChart({
    super.key,
    required this.allEntries,
    required this.selectedYear,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Generate last 6 months
    final months = <({int year, int month, String label, int received, int sent})>[];
    final monthShortNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    for (int i = 5; i >= 0; i--) {
      var y = selectedYear;
      var m = selectedMonth - i;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }

      int r = 0;
      int s = 0;
      for (final e in allEntries) {
        final date = e.occurredAt ?? e.createdAt;
        if (date.year == y && date.month == m && e.amountMinor != null) {
          if (e.direction == Direction.received) {
            r += e.amountMinor!;
          } else if (e.direction == Direction.sent) {
            s += e.amountMinor!;
          }
        }
      }

      months.add((
        year: y,
        month: m,
        label: monthShortNames[m - 1],
        received: r,
        sent: s,
      ));
    }

    int maxVal = 1;
    for (final m in months) {
      maxVal = max(maxVal, max(m.received, m.sent));
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, size: 20, color: AppColors.primaryContainer),
                    SizedBox(width: 8),
                    Text(
                      '6-Month Cash Flow Trend',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const SizedBox(width: 8),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: months.map((m) {
                  final isCurrent = m.year == selectedYear && m.month == selectedMonth;
                  final inHeight = max(4.0, (m.received / maxVal) * 85);
                  final outHeight = max(4.0, (m.sent / maxVal) * 85);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 10,
                            height: inHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              border: isCurrent ? Border.all(color: Colors.white, width: 1) : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 10,
                            height: outHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              border: isCurrent ? Border.all(color: Colors.white, width: 1) : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent
                              ? AppColors.primaryContainer
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopCounterpartiesWidget extends StatelessWidget {
  final List<Entry> monthEntries;

  const TopCounterpartiesWidget({super.key, required this.monthEntries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Group by counterparty
    final totals = <String, int>{};
    int grandTotal = 0;

    for (final e in monthEntries) {
      if (e.amountMinor != null && e.amountMinor! > 0) {
        final name = (e.counterpartyName ?? e.provider ?? 'Unspecified Counterparty').trim();
        totals[name] = (totals[name] ?? 0) + e.amountMinor!;
        grandTotal += e.amountMinor!;
      }
    }

    if (totals.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.leaderboard_outlined, size: 20, color: AppColors.primaryContainer),
                SizedBox(width: 8),
                Text(
                  'Top 5 Counterparties / Payees',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...top5.map((entry) {
              final pct = grandTotal > 0 ? (entry.value / grandTotal) : 0.0;
              final amtFormatted = (entry.value / 100).toStringAsFixed(0);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'PKR $amtFormatted  (${(pct * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class CategoryBreakdownWidget extends StatelessWidget {
  final List<Entry> monthEntries;

  const CategoryBreakdownWidget({super.key, required this.monthEntries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final catTotals = <String, int>{};
    int grandTotal = 0;

    for (final e in monthEntries) {
      if (e.amountMinor != null && e.amountMinor! > 0) {
        final cat = e.category ?? 'General';
        catTotals[cat] = (catTotals[cat] ?? 0) + e.amountMinor!;
        grandTotal += e.amountMinor!;
      }
    }

    if (catTotals.isEmpty) return const SizedBox.shrink();

    final sorted = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_outline, size: 20, color: AppColors.primaryContainer),
                SizedBox(width: 8),
                Text(
                  'Spending by Category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sorted.map((item) {
                final cat = SlipCategories.get(item.key);
                final amt = (item.value / 100).toStringAsFixed(0);
                final pct = grandTotal > 0 ? ' (${(item.value * 100 / grandTotal).toStringAsFixed(0)}%)' : '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cat.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 14, color: cat.color),
                      const SizedBox(width: 6),
                      Text(
                        cat.name,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cat.color),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PKR $amt$pct',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
