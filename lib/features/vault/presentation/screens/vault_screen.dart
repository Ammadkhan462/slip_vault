import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

/// Filter options for the Vault screen ledger stream
enum VaultFilter { all, received, sent, needsReview, other }

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  VaultFilter _activeFilter = VaultFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.vaultTitle ?? 'Slip Vault',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n?.vaultSubtitle ?? 'Receipt Vault',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n?.offlineVault ?? 'Offline Vault',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                        const Icon(Icons.chevron_left, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          'October 2026',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 20),
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

            // Cash Flow Hero Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n?.netCashFlow ?? 'Net Cash Flow',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet, size: 18, color: AppColors.primaryContainer),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs 0',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.totalReceived ?? 'Total Received',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs 0',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: AppColors.tertiary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.totalSent ?? 'Total Sent',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs 0',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                                      fontWeight: FontWeight.bold,
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
                    label: l10n?.received ?? 'Received',
                    isSelected: _activeFilter == VaultFilter.received,
                    onTap: () => setState(() => _activeFilter = VaultFilter.received),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: l10n?.sent ?? 'Sent',
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

            // Empty State
            Expanded(
              child: Center(
                child: Padding(
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
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/import'),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(l10n?.importScreenshots ?? 'Import'),
      ),
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
