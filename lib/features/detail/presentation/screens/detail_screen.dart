import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/categories/domain/category_model.dart';
import 'package:slip_vault/features/import/domain/duplicate_detector.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final int entryId;

  const DetailScreen({super.key, required this.entryId});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  final GlobalKey _cardKey = GlobalKey();
  Entry? _entry;
  DuplicateMatch? _duplicateMatch;
  late TextEditingController _noteController;
  bool _isSavingNote = false;
  static const bool _hideWatermark = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _loadEntry();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final db = ref.read(databaseProvider);
    var entry = await (db.select(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).getSingleOrNull();

    if (entry != null && (entry.amountMinor == null || entry.direction == Direction.unknown) && entry.ocrText.isNotEmpty) {
      final parsed = GenericParser().parse(entry.ocrText);
      Direction dir = Direction.unknown;
      if (parsed.direction == 'received') dir = Direction.received;
      if (parsed.direction == 'sent') dir = Direction.sent;

      final detectedCat = SlipCategories.detect(
        ocrText: entry.ocrText,
        counterparty: parsed.counterpartyName,
        provider: parsed.provider,
        direction: parsed.direction,
      );

      await (db.update(db.entries)..where((tbl) => tbl.id.equals(entry!.id))).write(
        EntriesCompanion(
          amountMinor: drift.Value(parsed.amountMinor),
          currency: drift.Value(parsed.currency),
          direction: drift.Value(dir),
          counterpartyName: drift.Value(parsed.counterpartyName),
          counterpartyAccountMasked: drift.Value(parsed.counterpartyAccountMasked),
          transactionId: drift.Value(parsed.transactionId),
          provider: drift.Value(parsed.provider),
          occurredAt: drift.Value(parsed.occurredAt ?? entry.createdAt),
          category: drift.Value(entry.category ?? detectedCat),
          needsReview: drift.Value(parsed.needsReview),
        ),
      );
      entry = await (db.select(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).getSingleOrNull();
    }

    if (entry != null) {
      _noteController.text = entry.note ?? '';

      // Check for duplicates
      _duplicateMatch = await DuplicateDetector.checkDuplicate(
        db,
        transactionId: entry.transactionId,
        amountMinor: entry.amountMinor,
        counterpartyName: entry.counterpartyName,
        occurredAt: entry.occurredAt,
        excludeId: entry.id,
      );
    }

    if (mounted) setState(() => _entry = entry);
  }

  Future<void> _updateCategory(String category) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).write(
      EntriesCompanion(category: drift.Value(category)),
    );
    await _loadEntry();
  }

  Future<void> _saveNote() async {
    setState(() => _isSavingNote = true);
    final db = ref.read(databaseProvider);
    await (db.update(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).write(
      EntriesCompanion(note: drift.Value(_noteController.text.trim())),
    );
    await _loadEntry();
    setState(() => _isSavingNote = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved to vault and indexed for search!')),
      );
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Slip?'),
        content: const Text('This will permanently delete this entry and its image.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = ref.read(databaseProvider);
      await (db.delete(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).go();
      if (mounted) context.pop();
    }
  }

  Future<void> _shareAsCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/payment_card_${widget.entryId}.png');
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Payment Receipt via Slip Vault',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share card: $e')));
      }
    }
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.label_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Select Category',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: SlipCategories.all.length,
                    itemBuilder: (ctx, index) {
                      final cat = SlipCategories.all[index];
                      final isSelected = (_entry?.category ?? 'General') == cat.id;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        title: Text(cat.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? Icon(Icons.check, color: cat.color) : null,
                        onTap: () {
                          ctx.pop();
                          _updateCategory(cat.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_entry == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entry = _entry!;
    final amount = entry.amountMinor != null ? (entry.amountMinor! / 100).toStringAsFixed(2) : '0.00';
    final isReceived = entry.direction == Direction.received;
    final categoryItem = SlipCategories.get(entry.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/review/${entry.id}').then((_) => _loadEntry()),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _deleteEntry,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Duplicate / Fraud Warning Banner
            if (_duplicateMatch != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'DUPLICATE / FRAUD SHIELD ALERT',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _duplicateMatch!.reason,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => context.push('/detail/${_duplicateMatch!.existingEntry.id}'),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Original Saved Slip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // RepaintBoundary for WhatsApp Summary Card Export
            RepaintBoundary(
              key: _cardKey,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.verified, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PAYMENT RECEIPT',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    entry.provider ?? 'Slip Vault',
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isReceived ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              isReceived ? 'Received' : 'Sent',
                              style: TextStyle(
                                color: isReceived ? AppColors.tertiary : AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Amount Verified', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.currency.isNotEmpty ? entry.currency : 'PKR'} $amount',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isReceived ? AppColors.tertiary : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _RowDetail(label: 'To / From', value: entry.counterpartyName ?? '-'),
                      const SizedBox(height: 8),
                      _RowDetail(label: 'Account / Mobile', value: entry.counterpartyAccountMasked ?? '-'),
                      const SizedBox(height: 8),
                      _RowDetail(label: 'Transaction ID', value: entry.transactionId ?? '-'),
                      const SizedBox(height: 8),
                      _RowDetail(label: 'Category', value: categoryItem.name),
                      if (entry.note != null && entry.note!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _RowDetail(label: 'Memo / Note', value: entry.note!),
                      ],
                      const SizedBox(height: 12),
                      if (!_hideWatermark) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_outlined, size: 14, color: AppColors.primaryContainer),
                            const SizedBox(width: 4),
                            Text(
                              'Saved with Slip Vault (Offline)',
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector Pill Card
            InkWell(
              onTap: () => _showCategoryPicker(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: categoryItem.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(categoryItem.icon, color: categoryItem.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(categoryItem.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryContainer)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Slip Memos & Itemized Notes
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note, size: 20, color: AppColors.primaryContainer),
                          SizedBox(width: 6),
                          Text(
                            'Slip Memo & Notes',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _isSavingNote ? null : _saveNote,
                        child: _isSavingNote
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add context (e.g. Project milestone 2, Laptop purchase, Advance payment)',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (entry.needsReview) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This slip needs manual review.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => context.push('/review/${entry.id}').then((_) => _loadEntry()),
                      child: const Text('Review Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Share Card to WhatsApp Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _shareAsCard,
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Share Card to WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 16),

            // Original Slip Image with Pinch Zoom
            Text('ORIGINAL SLIP SCREENSHOT', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 280,
                color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: Image.file(
                    File(entry.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDetail extends StatelessWidget {
  final String label;
  final String value;

  const _RowDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
