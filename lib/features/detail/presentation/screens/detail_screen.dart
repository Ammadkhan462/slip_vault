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
  static const bool _hideWatermark = false;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    final db = ref.read(databaseProvider);
    var entry = await (db.select(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).getSingleOrNull();

    if (entry != null && (entry.amountMinor == null || entry.direction == Direction.unknown) && entry.ocrText.isNotEmpty) {
      final parsed = GenericParser().parse(entry.ocrText);
      Direction dir = Direction.unknown;
      if (parsed.direction == 'received') dir = Direction.received;
      if (parsed.direction == 'sent') dir = Direction.sent;

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
          needsReview: drift.Value(parsed.needsReview),
        ),
      );
      entry = await (db.select(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).getSingleOrNull();
    }

    if (mounted) setState(() => _entry = entry);
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
                        'PKR $amount',
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
