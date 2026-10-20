import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/core/theme/app_theme.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final int entryId;

  const ReviewScreen({super.key, required this.entryId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  Entry? _entry;
  late TextEditingController _amountController;
  late TextEditingController _counterpartyController;
  late TextEditingController _accountController;
  late TextEditingController _tidController;
  String _direction = 'received';
  String? _provider;
  String _currency = 'PKR';
  bool _isReceipt = true;
  Map<String, double> _confidences = {};

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _counterpartyController = TextEditingController();
    _accountController = TextEditingController();
    _tidController = TextEditingController();
    _loadEntry();
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
      _isReceipt = parsed.isReceipt;
      _confidences = parsed.fieldConfidences;

      final amount = entry.amountMinor ?? parsed.amountMinor;
      if (amount != null) {
        _amountController.text = (amount / 100).toStringAsFixed(2);
      }
      _counterpartyController.text = entry.counterpartyName ?? parsed.counterpartyName ?? '';
      _accountController.text = entry.counterpartyAccountMasked ?? parsed.counterpartyAccountMasked ?? '';
      _tidController.text = entry.transactionId ?? parsed.transactionId ?? '';
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
        content: const Text('This will delete this screenshot from your vault.'),
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

  @override
  void dispose() {
    _amountController.dispose();
    _counterpartyController.dispose();
    _accountController.dispose();
    _tidController.dispose();
    super.dispose();
  }

  String _getCurrencySymbol(String curr) {
    switch (curr.toUpperCase()) {
      case 'USD':
        return r'$ ';
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
      case 'CAD':
        return r'C$ ';
      case 'AUD':
        return r'A$ ';
      default:
        return 'Rs ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_entry == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Slip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _deleteEntry,
            tooltip: 'Discard',
          ),
          TextButton(
            onPressed: _saveEntry,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image Preview Container
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 200,
                color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight,
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.file(
                    File(_entry!.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Non-Receipt Warning Banner if photo is not a receipt
            if (!_isReceipt) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Non-Payment Screenshot Detected',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
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
            _ConfidenceLabel(label: 'TRANSACTION ID (TID)', confidence: _confidences['transactionId'] ?? 0.0),
            const SizedBox(height: 4),
            TextField(
              controller: _tidController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saveEntry,
              child: const Text('Confirm & Save Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
    final isHigh = confidence >= 0.80;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isHigh ? AppColors.tertiary : AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${(confidence * 100).toInt()}% confidence',
              style: TextStyle(
                fontSize: 11,
                color: isHigh ? AppColors.tertiary : AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
