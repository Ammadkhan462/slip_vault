import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/core/widgets/vault_bottom_bar.dart';
import 'package:slip_vault/features/search/presentation/providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  final List<String> _quickFilters = [
    '#jazzcash',
    '#easypaisa',
    '#sadapay',
    '#raast',
    '#received',
    '#sent',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyFilter(String tag) {
    // Strip '#' for query
    final term = tag.replaceAll('#', '');
    _controller.text = term;
    ref.read(searchQueryProvider.notifier).updateQuery(term);
  }

  (String, Color, Color) _getProviderBadge(String? provider) {
    final p = (provider ?? '').toLowerCase();
    if (p.contains('jazzcash')) {
      return ('JC', const Color(0xFFDC2626), const Color(0xFFFEF2F2));
    } else if (p.contains('easypaisa')) {
      return ('EP', const Color(0xFF059669), const Color(0xFFECFDF5));
    } else if (p.contains('sada') || p.contains('sadapay')) {
      return ('SP', const Color(0xFF0F766E), const Color(0xFFF0FDFA));
    } else if (p.contains('nayapay')) {
      return ('NP', const Color(0xFFEA580C), const Color(0xFFFFF7ED));
    } else if (p.contains('raast')) {
      return ('RAAST', const Color(0xFF0284C7), const Color(0xFFF0F9FF));
    } else if (p.contains('faysal')) {
      return ('FB', const Color(0xFFD97706), const Color(0xFFFFFBEB));
    } else if (p.contains('meezan')) {
      return ('MB', const Color(0xFF0D9488), const Color(0xFFF0FDFA));
    } else if (p.contains('hbl')) {
      return ('HBL', const Color(0xFF0F766E), const Color(0xFFF0FDFA));
    }
    return ('TX', const Color(0xFF64748B), const Color(0xFFF8FAFC));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resultsAsync = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search Wi-Fi, passwords, TID, text...',
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).updateQuery('');
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            ref.read(searchQueryProvider.notifier).updateQuery(val);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick Filter Tag Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: _quickFilters.map((tag) {
                  final isSelected = query.toLowerCase() == tag.replaceAll('#', '').toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryContainer,
                      backgroundColor: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      side: BorderSide.none,
                      onSelected: (_) => _applyFilter(tag),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Engine status row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Instant OCR Search',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerHighDark : const Color(0xFFE6FFFA),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: const Color(0xFF10B981).withAlpha(50),
                      ),
                    ),
                    child: Text(
                      'FTS5 SQLite Engine',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Results or Empty Guidance
            Expanded(
              child: resultsAsync.when(
                data: (results) {
                  if (query.trim().isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 48,
                            color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                          ),
                          const SizedBox(height: 12),
                          Text('Search any text inside your screenshots', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    );
                  }

                  if (results.isEmpty) {
                    return Center(
                      child: Text('No screenshots match "$query"', style: theme.textTheme.bodyMedium),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      final badge = _getProviderBadge(item.provider);
                      final isReceived = item.direction == Direction.received;
                      final isSent = item.direction == Direction.sent;
                      final dateStr = item.occurredAt != null
                          ? DateFormat('dd MMM, h:mm a').format(item.occurredAt!)
                          : DateFormat('dd MMM, h:mm a').format(item.createdAt);

                      return InkWell(
                        onTap: () => context.push('/detail/${item.id}'),
                        borderRadius: BorderRadius.circular(14),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail with error fallback
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 64,
                                    height: 80,
                                    child: Image.file(
                                      File(item.imagePath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: isDark
                                            ? AppColors.surfaceContainerHighDark
                                            : AppColors.surfaceContainerHighLight,
                                        child: const Icon(Icons.receipt_long, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Details column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: badge.$3,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: badge.$2.withAlpha(50)),
                                                ),
                                                child: Text(
                                                  badge.$1,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: badge.$2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                item.provider ?? 'Screenshot OCR',
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (item.amountMinor != null)
                                            Text(
                                              'Rs ${(item.amountMinor! / 100).toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: isReceived
                                                    ? AppColors.tertiary
                                                    : (isSent ? AppColors.error : AppColors.primaryContainer),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.onSurfaceVariantDark
                                              : AppColors.onSurfaceVariantLight,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.surfaceContainerLowDark
                                              : AppColors.surfaceContainerLowLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.ocrText.isNotEmpty ? item.ocrText : 'No text recognized',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                          ),
                                        ),
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
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Search error: $err')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const VaultBottomBar(currentIndex: 1),
    );
  }
}
