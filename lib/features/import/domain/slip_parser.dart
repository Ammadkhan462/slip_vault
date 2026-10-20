/// Represents the outcome of parsing a slip's OCR text
class ParsedSlip {
  final int? amountMinor; // In minor unit (e.g. 5000 = $50.00 or Rs 50.00)
  final String currency;
  final String direction; // 'received', 'sent', or 'unknown'
  final String? counterpartyName;
  final String? counterpartyAccountMasked;
  final String? transactionId;
  final String? provider;
  final int? feeMinor;
  final DateTime? occurredAt;
  final Map<String, double> fieldConfidences; // e.g. {'amount': 0.95, 'tid': 0.70}
  final bool needsReview;
  final bool isReceipt; // False if screenshot is not a financial payment receipt

  const ParsedSlip({
    this.amountMinor,
    this.currency = 'PKR',
    this.direction = 'unknown',
    this.counterpartyName,
    this.counterpartyAccountMasked,
    this.transactionId,
    this.provider,
    this.feeMinor,
    this.occurredAt,
    this.fieldConfidences = const {},
    this.needsReview = false,
    this.isReceipt = true,
  });

  ParsedSlip copyWith({
    int? amountMinor,
    String? currency,
    String? direction,
    String? counterpartyName,
    String? counterpartyAccountMasked,
    String? transactionId,
    String? provider,
    int? feeMinor,
    DateTime? occurredAt,
    Map<String, double>? fieldConfidences,
    bool? needsReview,
    bool? isReceipt,
  }) {
    return ParsedSlip(
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      direction: direction ?? this.direction,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      counterpartyAccountMasked: counterpartyAccountMasked ?? this.counterpartyAccountMasked,
      transactionId: transactionId ?? this.transactionId,
      provider: provider ?? this.provider,
      feeMinor: feeMinor ?? this.feeMinor,
      occurredAt: occurredAt ?? this.occurredAt,
      fieldConfidences: fieldConfidences ?? this.fieldConfidences,
      needsReview: needsReview ?? this.needsReview,
      isReceipt: isReceipt ?? this.isReceipt,
    );
  }
}

/// Abstract parser interface for specific providers and generic fallback
abstract class SlipParser {
  ParsedSlip parse(String rawText);
}
