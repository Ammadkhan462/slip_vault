import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/categories/domain/category_model.dart';
import 'package:slip_vault/features/import/domain/duplicate_detector.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final int entryId;

  const ReviewScreen({super.key, required this.entryId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  Entry? _entry;
  DuplicateMatch? _duplicateMatch;
  late TextEditingController _amountController;
  late TextEditingController _counterpartyController;
  late TextEditingController _accountController;
  late TextEditingController _tidController;
  late TextEditingController _noteController;
  String _direction = 'received';
  String? _provider;
  String _currency = 'PKR';
  String _category = 'General';
  bool _isReceipt = true;
  Map<String, double> _confidences = {};

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _counterpartyController = TextEditingController();
    _accountController = TextEditingController();
    _tidController = TextEditingController();
    _noteController = TextEditingController();
    _loadEntry();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _counterpartyController.dispose();
    _accountController.dispose();
    _tidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final db = ref.read(databaseProvider);
    final entry = await (db.select(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).getSingleOrNull();

    if (entry != null) {
      _entry = entry;
      // Parse OCR text using GenericParser
      final parsed = GenericParser().parse(entry.ocrText);
      _direction = entry.direction != Direction.unknown ? entry.direction.name : parsed.direction;
      _provider = entry.provider ?? parsed.provider ?? 'JazzCash';
      _currency = entry.currency.isNotEmpty ? entry.currency : parsed.currency;
      _category = entry.category ??
          SlipCategories.detect(
            ocrText: entry.ocrText,
            counterparty: parsed.counterpartyName,
            provider: parsed.provider,
            direction: _direction,
          );
      _isReceipt = parsed.isReceipt;
      _confidences = parsed.fieldConfidences;

      final amount = entry.amountMinor ?? parsed.amountMinor;
      if (amount != null) {
        _amountController.text = (amount / 100).toStringAsFixed(2);
      }
      _counterpartyController.text = entry.counterpartyName ?? parsed.counterpartyName ?? '';
      _accountController.text = entry.counterpartyAccountMasked ?? parsed.counterpartyAccountMasked ?? '';
      _tidController.text = entry.transactionId ?? parsed.transactionId ?? '';
      _noteController.text = entry.note ?? '';

      _duplicateMatch = await DuplicateDetector.checkDuplicate(
        db,
        transactionId: entry.transactionId ?? parsed.transactionId,
        amountMinor: amount,
        counterpartyName: entry.counterpartyName ?? parsed.counterpartyName,
        occurredAt: entry.occurredAt,
        excludeId: entry.id,
      );

      if (mounted) setState(() {});
    }
  }

  Future<void> _saveEntry() async {
    if (_entry == null) return;
    final db = ref.read(databaseProvider);

    final amountDouble = double.tryParse(_amountController.text.replaceAll(',', ''));
    final amountMinor = amountDouble != null ? (amountDouble * 100).round() : null;

    final directionEnum = _direction == 'received'
        ? Direction.received
        : _direction == 'sent'
            ? Direction.sent
            : Direction.unknown;

    await (db.update(db.entries)..where((tbl) => tbl.id.equals(widget.entryId))).write(
      EntriesCompanion(
        amountMinor: drift.Value(amountMinor),
        currency: drift.Value(_currency),
        direction: drift.Value(directionEnum),
        counterpartyName: drift.Value(_counterpartyController.text.trim()),
        counterpartyAccountMasked: drift.Value(_accountController.text.trim()),
        transactionId: drift.Value(_tidController.text.trim()),
        provider: drift.Value(_provider),
        category: drift.Value(_category),
        note: drift.Value(_noteController.text.trim()),
        needsReview: const drift.Value(false),
      ),
    );

    if (mounted) context.pop();
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Slip?'),
        content: const Text('This will permanently delete this non-receipt screenshot and remove it from your vault.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
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

  String _getCurrencySymbol(String curr) {
    switch (curr.toUpperCase()) {
      case 'USD':
      case 'CAD':
      case 'AUD':
        return '\$ ';
      case 'EUR':
        return '€ ';
      case 'GBP':
        return '£ ';
      case 'AED':
        return 'AED ';
      case 'SAR':
        return 'SAR ';
      case 'INR':
        return '₹ ';
      default:
        return 'Rs ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_entry == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Slip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _deleteEntry,
          ),
          TextButton(
            onPressed: _saveEntry,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Slip Image Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 220,
                color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.file(
                    File(_entry!.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Duplicate Alert Banner
            if (_duplicateMatch != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DUPLICATE SLIP DETECTED',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _duplicateMatch!.reason,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Non-Receipt Warning Banner
            if (!_isReceipt) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Non-Payment Screenshot Detected',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This image does not appear to be a financial receipt or payment slip (no transaction ID or bank confirmation found). You can discard it, or edit the fields manually below.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF78350F),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Discard This Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: _deleteEntry,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Category Selector
            Text('CATEGORY', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: SlipCategories.all.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Icon(cat.icon, color: cat.color, size: 18),
                          const SizedBox(width: 10),
                          Text(cat.name, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Direction Selector
            Text('PAYMENT DIRECTION', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'received', label: Text('Received'), icon: Icon(Icons.arrow_downward)),
                ButtonSegment(value: 'sent', label: Text('Sent'), icon: Icon(Icons.arrow_upward)),
                ButtonSegment(value: 'unknown', label: Text('Unknown'), icon: Icon(Icons.help_outline)),
              ],
              selected: {_direction},
              onSelectionChanged: (val) => setState(() => _direction = val.first),
            ),
            const SizedBox(height: 16),

            // Amount Field
            _ConfidenceLabel(
              label: 'AMOUNT ($_currency)',
              confidence: _confidences['amount'] ?? 0.0,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: _getCurrencySymbol(_currency),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Counterparty Name
            _ConfidenceLabel(label: 'COUNTERPARTY NAME', confidence: _confidences['counterparty'] ?? 0.0),
            const SizedBox(height: 4),
            TextField(
              controller: _counterpartyController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Masked Account
            _ConfidenceLabel(label: 'ACCOUNT / MOBILE', confidence: _confidences['account'] ?? 0.0),
            const SizedBox(height: 4),
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(height: 16),

            // Transaction ID
            _ConfidenceLabel(label: 'TRANSACTION ID', confidence: _confidences['tid'] ?? 0.0),
            const SizedBox(height: 4),
            TextField(
              controller: _tidController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 16),

            // Slip Memo / Note Field
            Text('SLIP MEMO & NOTES', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add an optional note (e.g. Freelance invoice #44, Rent for October)',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_note),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saveEntry,
              child: const Text('Confirm & Save Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceLabel extends StatelessWidget {
  final String label;
  final double confidence;

  const _ConfidenceLabel({required this.label, required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    if (confidence >= 0.8) {
      color = AppColors.tertiary;
      text = '${(confidence * 100).toInt()}% confidence';
    } else if (confidence >= 0.5) {
      color = const Color(0xFFF59E0B);
      text = '${(confidence * 100).toInt()}% confidence';
    } else {
      color = AppColors.error;
      text = '${(confidence * 100).toInt()}% confidence';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
