import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/core/widgets/vault_bottom_bar.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

enum VaultFilter { all, received, sent, needsReview, other }

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  VaultFilter _activeFilter = VaultFilter.all;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backfillUnparsedEntries();
    });
  }

  Future<void> _backfillUnparsedEntries() async {
    try {
      final db = ref.read(databaseProvider);
      final unparsed = await (db.select(db.entries)
            ..where((tbl) =>
                (tbl.amountMinor.isNull() | tbl.direction.equals(Direction.unknown.name)) &
                tbl.ocrText.isNotNull()))
          .get();

      if (unparsed.isEmpty) return;
      final parser = GenericParser();
      for (final entry in unparsed) {
        if (entry.ocrText.trim().isEmpty) continue;
        final parsed = parser.parse(entry.ocrText);
        Direction dir = Direction.unknown;
        if (parsed.direction == 'received') dir = Direction.received;
        if (parsed.direction == 'sent') dir = Direction.sent;

        await (db.update(db.entries)..where((tbl) => tbl.id.equals(entry.id))).write(
          EntriesCompanion(
            amountMinor: drift.Value(parsed.amountMinor),
            currency: drift.Value(parsed.currency),
            direction: drift.Value(dir),
            counterpartyName: drift.Value(parsed.counterpartyName),
            counterpartyAccountMasked: drift.Value(parsed.counterpartyAccountMasked),
            transactionId: drift.Value(parsed.transactionId),
            provider: drift.Value(parsed.provider),
            occurredAt: drift.Value(parsed.occurredAt ?? entry.createdAt),
            needsReview: drift.Value(parsed.needsReview),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final monthLabel = '${_monthNames[_selectedMonth - 1]} $_selectedYear';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n?.vaultTitle ?? 'Slip Vault',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Month Selector Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chevron_left, size: 20),
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
                        const SizedBox(width: 6),
                        Text(
                          monthLabel,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chevron_right, size: 20),
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
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        l10n?.allOnDevice ?? 'All on-device',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Live Stream of Entries from Drift for Real-Time Reactivity
            Expanded(
              child: StreamBuilder<List<Entry>>(
                stream: db.select(db.entries).watch(),
                builder: (context, snapshot) {
                  final allEntries = snapshot.data ?? [];

                  // Calculate live totals for the selected month
                  int received = 0;
                  int sent = 0;
                  int receivedCount = 0;
                  int sentCount = 0;
                  for (final e in allEntries) {
                    final date = e.occurredAt ?? e.createdAt;
                    if (date.year == _selectedYear && date.month == _selectedMonth && e.amountMinor != null) {
                      if (e.direction == Direction.received) {
                        received += e.amountMinor!;
                        receivedCount++;
                      } else if (e.direction == Direction.sent) {
                        sent += e.amountMinor!;
                        sentCount++;
                      }
                    }
                  }
                  final net = received - sent;

                  // Apply filter for the selected month
                  final filtered = allEntries.where((e) {
                    final date = e.occurredAt ?? e.createdAt;
                    if (date.year != _selectedYear || date.month != _selectedMonth) return false;
                    if (_activeFilter == VaultFilter.received) return e.direction == Direction.received;
                    if (_activeFilter == VaultFilter.sent) return e.direction == Direction.sent;
                    if (_activeFilter == VaultFilter.needsReview) return e.needsReview;
                    if (_activeFilter == VaultFilter.other) return e.kind == EntryKind.other;
                    return true;
                  }).toList();

                  return Column(
                    children: [
                      // Modern Deep Teal Gradient Hero Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF064E3B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F766E).withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        l10n?.netCashFlow ?? 'Net Cash Flow',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.22),
                                          borderRadius: BorderRadius.circular(9999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF34D399),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'All on-device',
                                              style: TextStyle(
                                                color: Color(0xFFD1FAE5),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${net >= 0 ? '+' : '-'}PKR ${(net.abs() / 100).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.22),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                l10n?.totalReceived ?? 'Total Received',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '+$receivedCount',
                                                  style: const TextStyle(
                                                    color: Color(0xFF6EE7B7),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'PKR ${(received / 100).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFF6EE7B7),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: (received + sent) > 0 ? (received / (received + sent)) : 0.0,
                                              backgroundColor: Colors.white.withOpacity(0.12),
                                              valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                                              minHeight: 3,
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
                                        color: Colors.black.withOpacity(0.22),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                l10n?.totalSent ?? 'Total Sent',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '-$sentCount',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.9),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'PKR ${(sent / 100).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: (received + sent) > 0 ? (sent / (received + sent)) : 0.0,
                                              backgroundColor: Colors.white.withOpacity(0.12),
                                              valueColor: const AlwaysStoppedAnimation(Color(0xFF94A3B8)),
                                              minHeight: 3,
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
                      ),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _FilterChipItem(
                              label: l10n?.all ?? 'All',
                              isSelected: _activeFilter == VaultFilter.all,
                              onTap: () => setState(() => _activeFilter = VaultFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipItem(
                              label: '${l10n?.received ?? 'Received'} $receivedCount',
                              isSelected: _activeFilter == VaultFilter.received,
                              onTap: () => setState(() => _activeFilter = VaultFilter.received),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipItem(
                              label: '${l10n?.sent ?? 'Sent'} $sentCount',
                              isSelected: _activeFilter == VaultFilter.sent,
                              onTap: () => setState(() => _activeFilter = VaultFilter.sent),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipItem(
                              label: l10n?.needsReview ?? 'Needs Review',
                              isSelected: _activeFilter == VaultFilter.needsReview,
                              onTap: () => setState(() => _activeFilter = VaultFilter.needsReview),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipItem(
                              label: l10n?.otherScreenshots ?? 'Other',
                              isSelected: _activeFilter == VaultFilter.other,
                              onTap: () => setState(() => _activeFilter = VaultFilter.other),
                            ),
                          ],
                        ),
                      ),

                      // Filtered entries list
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.receipt_outlined,
                                          size: 48,
                                          color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        l10n?.emptyVaultTitle ?? 'No slips or screenshots yet',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n?.emptyVaultSubtitle ??
                                            'Tap the + button or share screenshots from your gallery directly to Slip Vault.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isReceived = item.direction == Direction.received;
                                  final amt = item.amountMinor != null ? (item.amountMinor! / 100).toStringAsFixed(0) : '0';
                                  final curr = item.currency.isNotEmpty ? item.currency : 'PKR';
                                  final occurred = item.occurredAt ?? item.createdAt;
                                  final timeStr = '${occurred.hour.toString().padLeft(2, '0')}:${occurred.minute.toString().padLeft(2, '0')}';

                                  return InkWell(
                                    onTap: () {
                                      if (item.needsReview) {
                                        context.push('/review/${item.id}');
                                      } else {
                                        context.push('/detail/${item.id}');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                _buildBrandAvatar(item.provider, item.imagePath, isDark),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              item.counterpartyName ?? item.provider ?? 'Payment Slip',
                                                              style: theme.textTheme.titleSmall?.copyWith(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                              maxLines: 1,
                                                            ),
                                                          ),
                                                          if (!item.needsReview) ...[
                                                            const SizedBox(width: 4),
                                                            const Icon(Icons.check_circle, size: 14, color: Color(0xFF0F766E)),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          if (item.provider != null) ...[
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                item.provider!,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                          ],
                                                          if (item.counterpartyAccountMasked != null)
                                                            Expanded(
                                                              child: Text(
                                                                item.counterpartyAccountMasked!,
                                                                style: theme.textTheme.bodySmall?.copyWith(
                                                                  color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                                                                  fontSize: 11,
                                                                  fontFamily: 'monospace',
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${isReceived ? '+' : '-'}$curr $amt',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w800,
                                                        color: isReceived
                                                            ? const Color(0xFF10B981)
                                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      timeStr,
                                                      style: theme.textTheme.labelSmall?.copyWith(
                                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Container(
                                              padding: const EdgeInsets.only(top: 8),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.tag, size: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        item.transactionId != null ? 'TID-${item.transactionId}' : 'Screenshot OCR',
                                                        style: TextStyle(
                                                          fontFamily: 'monospace',
                                                          fontSize: 11,
                                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        decoration: BoxDecoration(
                                                          color: item.needsReview ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item.needsReview ? 'Needs Review' : 'Auto-verified',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: item.needsReview
                                                              ? const Color(0xFFF59E0B)
                                                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const VaultBottomBar(currentIndex: 0),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/import'),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(l10n?.importScreenshots ?? 'Import Slip'),
      ),
    );
  }

  Widget _buildBrandAvatar(String? provider, String imagePath, bool isDark) {
    final prov = provider?.toLowerCase() ?? '';
    Color bgColor = const Color(0xFF0F766E);
    String initials = 'SLIP';

    if (prov.contains('jazz')) {
      bgColor = const Color(0xFFE11D48);
      initials = 'JC';
    } else if (prov.contains('easy')) {
      bgColor = const Color(0xFF059669);
      initials = 'EP';
    } else if (prov.contains('sada')) {
      bgColor = const Color(0xFF0D9488);
      initials = 'SP';
    } else if (prov.contains('faysal')) {
      bgColor = const Color(0xFF1E3A8A);
      initials = 'FB';
    } else if (prov.contains('raast')) {
      bgColor = const Color(0xFFD97706);
      initials = 'RAAST';
    } else if (prov.contains('meezan')) {
      bgColor = const Color(0xFF4338CA);
      initials = 'MB';
    } else if (prov.contains('hbl')) {
      bgColor = const Color(0xFF047857);
      initials = 'HBL';
    } else if (prov.contains('naya')) {
      bgColor = const Color(0xFFEA580C);
      initials = 'NP';
    } else if (prov.contains('paypal')) {
      bgColor = const Color(0xFF003087);
      initials = 'PP';
    } else if (prov.contains('cash app')) {
      bgColor = const Color(0xFF00D632);
      initials = 'CA';
    } else if (prov.contains('venmo')) {
      bgColor = const Color(0xFF008CFF);
      initials = 'VM';
    } else if (prov.contains('zelle')) {
      bgColor = const Color(0xFF7414CA);
      initials = 'ZL';
    } else if (prov.contains('wise')) {
      bgColor = const Color(0xFF9FE870);
      initials = 'WISE';
    } else if (prov.contains('revolut')) {
      bgColor = const Color(0xFF191C1F);
      initials = 'REV';
    } else if (prov.contains('chase')) {
      bgColor = const Color(0xFF117ACA);
      initials = 'JPMC';
    } else if (prov.contains('america') || prov.contains('bofa')) {
      bgColor = const Color(0xFFE31837);
      initials = 'BOA';
    } else if (prov.contains('wells')) {
      bgColor = const Color(0xFFD71E28);
      initials = 'WF';
    } else if (prov.contains('barclays')) {
      bgColor = const Color(0xFF00AEEF);
      initials = 'BARC';
    } else if (prov.contains('hsbc')) {
      bgColor = const Color(0xFFDB0011);
      initials = 'HSBC';
    } else if (prov.contains('emirates') || prov.contains('enbd')) {
      bgColor = const Color(0xFF0A2540);
      initials = 'ENBD';
    } else if (prov.contains('rajhi')) {
      bgColor = const Color(0xFF003882);
      initials = 'RAJHI';
    } else if (prov.contains('hdfc')) {
      bgColor = const Color(0xFF004C8F);
      initials = 'HDFC';
    } else if (prov.contains('sbi') || prov.contains('state bank of india')) {
      bgColor = const Color(0xFF280071);
      initials = 'SBI';
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
