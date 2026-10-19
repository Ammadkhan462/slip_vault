import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/import/presentation/providers/batch_import_provider.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _showGuide = false;

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      final files = images.map((x) => File(x.path)).toList();
      ref.read(batchImportProvider.notifier).processImages(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final importState = ref.watch(batchImportProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.importScreenshots ?? 'Import Slip'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scoped Sandbox Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Payment Slips',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select slips via secure photo picker or system share.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.shield, size: 16, color: AppColors.primaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          'Zero gallery permissions required',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Open Photo Picker Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library, color: AppColors.primaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose from Photos',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select transaction slips or receipts from your phone gallery.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: importState.isProcessing ? null : _pickImages,
                            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                            label: const Text('Open Photo Picker'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Share Target Guide
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.share, size: 18, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Text(
                              'Instant Share Target',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => setState(() => _showGuide = !_showGuide),
                          child: Text(_showGuide ? 'Hide' : 'Guide'),
                        ),
                      ],
                    ),
                    if (_showGuide) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _GuideStep(icon: Icons.screenshot, title: '1. Snap Slip', subtitle: 'Any bank or wallet'),
                          _GuideStep(icon: Icons.ios_share, title: '2. Tap Share', subtitle: 'Choose Slip Vault'),
                          _GuideStep(icon: Icons.check_circle, title: '3. Auto-OCR', subtitle: 'Stored in vault'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Live Queue if processing or has items
            if (importState.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Parsing Queue (${importState.completedCount}/${importState.totalCount})',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (importState.isProcessing)
                            TextButton(
                              onPressed: () => ref.read(batchImportProvider.notifier).cancel(),
                              child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: importState.totalCount > 0 ? (importState.completedCount / importState.totalCount) : 0,
                        backgroundColor: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primaryContainer),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: importState.items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = importState.items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              item.isDuplicate
                                  ? Icons.content_copy
                                  : item.isDone
                                      ? Icons.check_circle
                                      : item.isFailed
                                          ? Icons.error
                                          : Icons.hourglass_top,
                              color: item.isDuplicate
                                  ? AppColors.secondary
                                  : item.isDone
                                      ? AppColors.tertiary
                                      : item.isFailed
                                          ? AppColors.error
                                          : null,
                            ),
                            title: Text(item.filename, style: theme.textTheme.bodyMedium),
                            subtitle: Text(
                              item.isDuplicate
                                  ? 'Duplicate screenshot detected (skipped)'
                                  : item.isDone
                                      ? 'OCR extracted successfully'
                                      : item.isFailed
                                          ? 'Processing error'
                                          : 'Recognizing text...',
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: 24),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
