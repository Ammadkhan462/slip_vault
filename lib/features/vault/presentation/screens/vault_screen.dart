import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/core/widgets/vault_bottom_bar.dart';
import 'package:slip_vault/features/categories/domain/category_model.dart';
import 'package:slip_vault/features/export/data/report_export_service.dart';
import 'package:slip_vault/features/import/domain/gallery_sync_service.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';
import 'package:slip_vault/features/tour/data/vault_tour_service.dart';
import 'package:slip_vault/features/tour/presentation/widgets/vault_coach_mark.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

enum VaultFilter { all, received, sent, needsReview, other }

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  VaultFilter _activeFilter = VaultFilter.all;
  String? _selectedCategory;
  String _selectedCurrency = 'ALL';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isSyncingGallery = false;

  // Batch Multi-Select
  final Set<int> _selectedEntryIds = {};
  bool get _isSelectionMode => _selectedEntryIds.isNotEmpty;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // GlobalKeys for Interactive Bubble Guidance
  final GlobalKey _autoSyncKey = GlobalKey();
  final GlobalKey _heroCardKey = GlobalKey();
  final GlobalKey _filterBarKey = GlobalKey();

  Timer? _backfillTimer;
  Timer? _tourTimer;

  @override
  void initState() {
    super.initState();
    // Defer background backfill by 2 seconds so first frame renders instantly
    _backfillTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _backfillUnparsedEntries();
    });

    // Check if first-time user needs interactive bubble guidance
    _tourTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _checkFirstTimeVaultTour();
    });
  }

  @override
  void dispose() {
    _backfillTimer?.cancel();
    _tourTimer?.cancel();
    VaultCoachMark.dismiss();
    super.dispose();
  }

  Future<void> _checkFirstTimeVaultTour() async {
    final completed = await VaultTourService.isCompleted();
    if (!completed && mounted) {
      _showVaultTour();
    }
  }

  void _showVaultTour() {
    VaultCoachMark.show(
      context: context,
      targets: [
        TourTarget(
          key: _autoSyncKey,
          title: '1-Tap Auto-Sync Scanner',
          description:
              'Tap here to automatically scan your device Screenshots and WhatsApp folders. Slip Vault imports new slips in seconds while skipping non-receipts.',
          icon: Icons.sync,
          radius: 9999,
          targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        TourTarget(
          key: _heroCardKey,
          title: 'Net Cash Flow & Currencies',
          description:
              'Monitor total income, expenses, and cash flow. Switch between currency pills (PKR, USD, EUR, AED) to view segregated totals accurately.',
          icon: Icons.account_balance_wallet_outlined,
          radius: 20,
          targetPadding: const EdgeInsets.all(4),
        ),
        TourTarget(
          key: _filterBarKey,
          title: 'Smart Filters & Categories',
          description:
              'Easily filter slips by Received, Sent, or Needs Review. You can also assign and filter by custom tags like Utilities, Salary, or Freelance.',
          icon: Icons.tune,
          radius: 12,
          targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
      ],
    );
  }

  Future<void> _backfillUnparsedEntries() async {
    try {
      final db = ref.read(databaseProvider);
      final unparsed = await (db.select(db.entries)
            ..where((tbl) =>
                (tbl.amountMinor.isNull() |
                    tbl.direction.equals(Direction.unknown.name) |
                    tbl.category.isNull()) &
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

        final detectedCat = SlipCategories.detect(
          ocrText: entry.ocrText,
          counterparty: parsed.counterpartyName ?? entry.counterpartyName,
          provider: parsed.provider ?? entry.provider,
          direction: parsed.direction,
        );

        await (db.update(db.entries)..where((tbl) => tbl.id.equals(entry.id))).write(
          EntriesCompanion(
            amountMinor: drift.Value(entry.amountMinor ?? parsed.amountMinor),
            currency: drift.Value(entry.currency.isNotEmpty ? entry.currency : parsed.currency),
            direction: drift.Value(entry.direction != Direction.unknown ? entry.direction : dir),
            counterpartyName: drift.Value(entry.counterpartyName ?? parsed.counterpartyName),
            counterpartyAccountMasked: drift.Value(entry.counterpartyAccountMasked ?? parsed.counterpartyAccountMasked),
            transactionId: drift.Value(entry.transactionId ?? parsed.transactionId),
            provider: drift.Value(entry.provider ?? parsed.provider),
            occurredAt: drift.Value(entry.occurredAt ?? parsed.occurredAt ?? entry.createdAt),
            category: drift.Value(entry.category ?? detectedCat),
            needsReview: drift.Value(entry.needsReview || parsed.needsReview),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _pickAndSyncFromGallery() async {
    setState(() => _isSyncingGallery = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (picked.isEmpty) return;

      final files = picked.map((x) => File(x.path)).toList();
      final syncService = ref.read(gallerySyncServiceProvider);
      final result = await syncService.importFiles(files);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.importedCount > 0
                ? '✅ Synced ${result.importedCount} new payment slips (${result.skippedDuplicates} duplicates, ${result.skippedNonReceipts} non-receipts skipped)'
                : '0 payment slips detected in selected images.',
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingGallery = false);
    }
  }

  Future<void> _syncGalleryScreenshots() async {
    setState(() => _isSyncingGallery = true);
    try {
      final syncService = ref.read(gallerySyncServiceProvider);
      final result = await syncService.syncScreenshots();
      if (!mounted) return;

      if (result.permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Storage permission needed to scan screenshots.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (result.importedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Synced ${result.importedCount} new payment slips (${result.skippedDuplicates} duplicates, ${result.skippedNonReceipts} non-receipts skipped)'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.scannedCount == 0) {
        // Fallback option in case Android Scoped Storage blocked folder access
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No screenshots found in device gallery folders.'),
            action: SnackBarAction(
              label: 'Select Images',
              textColor: const Color(0xFF6366F1),
              onPressed: () => _pickAndSyncFromGallery(),
            ),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Up to date: ${result.scannedCount} recent images scanned, no new payment slips.'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery sync: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingGallery = false);
    }
  }

  Future<void> _batchExportPdf(List<Entry> selectedEntries) async {
    if (selectedEntries.isEmpty) return;
    try {
      int rec = 0;
      int snt = 0;
      for (final e in selectedEntries) {
        if (e.amountMinor != null) {
          if (e.direction == Direction.received) rec += e.amountMinor!;
          if (e.direction == Direction.sent) snt += e.amountMinor!;
        }
      }
      final file = await ReportExportService.generatePdfReport(
        entries: selectedEntries,
        monthLabel: 'Selected (${selectedEntries.length} Slips)',
        totalReceivedMinor: rec,
        totalSentMinor: snt,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Slip Vault Selected Slips PDF Report',
        ),
      );
      setState(() => _selectedEntryIds.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _showBatchCategorizeDialog() async {
    if (_selectedEntryIds.isEmpty) return;
    final selectedCat = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Categorize ${_selectedEntryIds.length} Selected Slips',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: SlipCategories.all.length,
                  itemBuilder: (ctx, index) {
                    final cat = SlipCategories.all[index];
                    return ListTile(
                      leading: Icon(cat.icon, color: cat.color),
                      title: Text(cat.name),
                      onTap: () => ctx.pop(cat.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedCat != null) {
      final db = ref.read(databaseProvider);
      for (final id in _selectedEntryIds) {
        await (db.update(db.entries)..where((tbl) => tbl.id.equals(id))).write(
          EntriesCompanion(category: drift.Value(selectedCat)),
        );
      }
      setState(() => _selectedEntryIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated category to "$selectedCat" for selected slips')),
        );
      }
    }
  }

  Future<void> _confirmBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedEntryIds.length} Slips?'),
        content: const Text('This will permanently delete the selected entries and their images from your vault.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      for (final id in _selectedEntryIds) {
        await (db.delete(db.entries)..where((tbl) => tbl.id.equals(id))).go();
      }
      setState(() => _selectedEntryIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected slips deleted successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final monthLabel = '${_monthNames[_selectedMonth - 1]} $_selectedYear';

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedEntryIds.clear()),
              ),
              title: Text('${_selectedEntryIds.length} Selected'),
              actions: [
                IconButton(
                  tooltip: 'Batch Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () async {
                    final all = await db.select(db.entries).get();
                    final selected = all.where((e) => _selectedEntryIds.contains(e.id)).toList();
                    await _batchExportPdf(selected);
                  },
                ),
                IconButton(
                  tooltip: 'Batch Categorize',
                  icon: const Icon(Icons.label_outline),
                  onPressed: _showBatchCategorizeDialog,
                ),
                IconButton(
                  tooltip: 'Batch Delete',
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: _confirmBatchDelete,
                ),
              ],
            )
          : AppBar(
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
        child: StreamBuilder<List<Entry>>(
          stream: db.select(db.entries).watch(),
          builder: (context, snapshot) {
            final allEntries = snapshot.data ?? [];

            // Find duplicate TIDs for instant fraud detection badge
            final duplicateTids = <String>{};
            final seenTids = <String>{};
            for (final e in allEntries) {
              if (e.transactionId != null && e.transactionId!.trim().isNotEmpty) {
                final tid = e.transactionId!.trim();
                if (seenTids.contains(tid)) {
                  duplicateTids.add(tid);
                } else {
                  seenTids.add(tid);
                }
              }
            }

            // Month entries
            final monthEntries = allEntries.where((e) {
              final date = e.occurredAt ?? e.createdAt;
              return date.year == _selectedYear && date.month == _selectedMonth;
            }).toList();

            // Distinct currencies in current month
            final availableCurrencies = monthEntries
                .map((e) => e.currency.isNotEmpty ? e.currency.toUpperCase() : 'PKR')
                .toSet()
                .toList();

            // Calculate live totals (respecting currency filter)
            int received = 0;
            int sent = 0;
            int receivedCount = 0;
            int sentCount = 0;
            for (final e in monthEntries) {
              if (_selectedCurrency != 'ALL' &&
                  e.currency.toUpperCase() != _selectedCurrency.toUpperCase()) {
                continue;
              }
              if (e.amountMinor != null) {
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
            final filtered = monthEntries.where((e) {
              if (_selectedCurrency != 'ALL' &&
                  e.currency.toUpperCase() != _selectedCurrency.toUpperCase()) {
                return false;
              }
              if (_selectedCategory != null && e.category != _selectedCategory) {
                return false;
              }
              if (_activeFilter == VaultFilter.received) return e.direction == Direction.received;
              if (_activeFilter == VaultFilter.sent) return e.direction == Direction.sent;
              if (_activeFilter == VaultFilter.needsReview) return e.needsReview;
              if (_activeFilter == VaultFilter.other) return e.kind == EntryKind.other;
              return true;
            }).toList();

            final displayCurr = _selectedCurrency == 'ALL'
                ? (availableCurrencies.isNotEmpty ? availableCurrencies.first : 'PKR')
                : _selectedCurrency;

            return CustomScrollView(
              slivers: [
                // Month Selector Bar & 1-Tap Auto-Sync
                SliverToBoxAdapter(
                  child: Padding(
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

                        // 1-Tap Auto-Sync Screenshots Button
                        InkWell(
                          key: _autoSyncKey,
                          onTap: _isSyncingGallery ? null : _syncGalleryScreenshots,
                          borderRadius: BorderRadius.circular(9999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isSyncingGallery
                                  ? AppColors.primaryContainer.withOpacity(0.2)
                                  : (isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: AppColors.primaryContainer.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _isSyncingGallery
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryContainer),
                                      )
                                    : const Icon(Icons.sync, size: 15, color: AppColors.primaryContainer),
                                const SizedBox(width: 5),
                                Text(
                                  _isSyncingGallery ? 'Syncing...' : 'Auto-Sync',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Modern Deep Teal Gradient Hero Card with Multi-Currency Switcher
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      key: _heroCardKey,
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Multi-Currency Pills Row (when more than 1 currency present)
                          if (availableCurrencies.length > 1) ...[
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCurrencyPill('ALL', _selectedCurrency == 'ALL'),
                                  ...availableCurrencies.map((c) => _buildCurrencyPill(c, _selectedCurrency == c)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

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
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined, size: 12, color: Color(0xFF34D399)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Audited Ledger',
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
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${net >= 0 ? '+' : '-'}$displayCurr ${(net.abs() / 100).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
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
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                                        '$displayCurr ${(received / 100).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
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
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '-$sentCount',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$displayCurr ${(sent / 100).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
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
                ),

                // Filter Chips (Type & Categories)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    key: _filterBarKey,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        _FilterChipItem(
                          label: l10n?.all ?? 'All',
                          isSelected: _activeFilter == VaultFilter.all && _selectedCategory == null,
                          onTap: () => setState(() {
                            _activeFilter = VaultFilter.all;
                            _selectedCategory = null;
                          }),
                        ),
                        const SizedBox(width: 6),
                        _FilterChipItem(
                          label: '${l10n?.received ?? 'Received'} $receivedCount',
                          isSelected: _activeFilter == VaultFilter.received,
                          onTap: () => setState(() => _activeFilter = VaultFilter.received),
                        ),
                        const SizedBox(width: 6),
                        _FilterChipItem(
                          label: '${l10n?.sent ?? 'Sent'} $sentCount',
                          isSelected: _activeFilter == VaultFilter.sent,
                          onTap: () => setState(() => _activeFilter = VaultFilter.sent),
                        ),
                        const SizedBox(width: 6),
                        _FilterChipItem(
                          label: l10n?.needsReview ?? 'Needs Review',
                          isSelected: _activeFilter == VaultFilter.needsReview,
                          onTap: () => setState(() => _activeFilter = VaultFilter.needsReview),
                        ),
                        const SizedBox(width: 6),
                        // Quick Category Filters
                        ...SlipCategories.all.take(4).map((cat) {
                          final isSelected = _selectedCategory == cat.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.white : cat.color),
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (_) => setState(() {
                                _selectedCategory = isSelected ? null : cat.id;
                              }),
                              selectedColor: cat.color,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : null,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Filtered entries list or empty state
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                              l10n?.emptyVaultTitle ?? 'No slips found',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap Auto-Sync to fetch new screenshots from your gallery, or import manually.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isReceived = item.direction == Direction.received;
                                  final amt = item.amountMinor != null ? (item.amountMinor! / 100).toStringAsFixed(0) : '0';
                                  final curr = item.currency.isNotEmpty ? item.currency : 'PKR';
                                  final occurred = item.occurredAt ?? item.createdAt;
                                  final timeStr = '${occurred.hour.toString().padLeft(2, '0')}:${occurred.minute.toString().padLeft(2, '0')}';
                                  final isSelected = _selectedEntryIds.contains(item.id);
                                  final isDuplicate = item.transactionId != null && duplicateTids.contains(item.transactionId!.trim());
                                  final categoryItem = SlipCategories.get(item.category);

                                  return InkWell(
                                    onLongPress: () {
                                      setState(() {
                                        _selectedEntryIds.add(item.id);
                                      });
                                    },
                                    onTap: () {
                                      if (_isSelectionMode) {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedEntryIds.remove(item.id);
                                          } else {
                                            _selectedEntryIds.add(item.id);
                                          }
                                        });
                                      } else if (item.needsReview) {
                                        context.push('/review/${item.id}');
                                      } else {
                                        context.push('/detail/${item.id}');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      elevation: isSelected ? 3 : 1,
                                      color: isSelected
                                          ? AppColors.primaryContainer.withOpacity(isDark ? 0.25 : 0.1)
                                          : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: isSelected
                                              ? AppColors.primaryContainer
                                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                          width: isSelected ? 1.5 : 1.0,
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
                                                if (_isSelectionMode) ...[
                                                  Icon(
                                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                                    color: isSelected ? AppColors.primaryContainer : Colors.grey,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 10),
                                                ],
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
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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

                                                          // Category Pill
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: categoryItem.color.withOpacity(0.12),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(categoryItem.icon, size: 9, color: categoryItem.color),
                                                                const SizedBox(width: 3),
                                                                Text(
                                                                  categoryItem.name,
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: categoryItem.color,
                                                                  ),
                                                                ),
                                                              ],
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

                                            // Note Preview (if exists)
                                            if (item.note != null && item.note!.trim().isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.notes, size: 12, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      item.note!,
                                                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],

                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.only(top: 6),
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
                                                      // Duplicate Shield Badge
                                                      if (isDuplicate) ...[
                                                        Container(
                                                          margin: const EdgeInsets.only(right: 6),
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFEE2E2),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.shield_outlined, size: 10, color: Color(0xFFDC2626)),
                                                              SizedBox(width: 2),
                                                              Text(
                                                                'Duplicate',
                                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],

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
      bottomNavigationBar: const VaultBottomBar(currentIndex: 0),
    );
  }

  Widget _buildCurrencyPill(String currency, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCurrency = currency),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          currency,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F766E) : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBrandAvatar(String? provider, String? imagePath, bool isDark) {
    final prov = (provider ?? '').toLowerCase();
    Color bgColor = const Color(0xFF334155);
    String initials = 'SLIP';

    if (prov.contains('jazz')) {
      bgColor = const Color(0xFFDC2626);
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
