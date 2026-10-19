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
      _direction = parsed.direction;
      _provider = parsed.provider ?? 'JazzCash';
      _confidences = parsed.fieldConfidences;

      if (parsed.amountMinor != null) {
        _amountController.text = (parsed.amountMinor! / 100).toStringAsFixed(2);
      }
      _counterpartyController.text = parsed.counterpartyName ?? '';
      _accountController.text = parsed.counterpartyAccountMasked ?? '';
      _tidController.text = parsed.transactionId ?? '';
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

  @override
  void dispose() {
    _amountController.dispose();
    _counterpartyController.dispose();
    _accountController.dispose();
    _tidController.dispose();
    super.dispose();
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
            _ConfidenceLabel(label: 'AMOUNT (PKR)', confidence: _confidences['amount'] ?? 0.0),
            const SizedBox(height: 4),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: 'Rs ',
                border: OutlineInputBorder(),
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
