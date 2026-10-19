import 'package:slip_vault/features/import/domain/provider_detector.dart';
import 'package:slip_vault/features/import/domain/slip_parser.dart';

/// Pure Dart generic heuristic parser for slips across all banks and wallets
class GenericParser implements SlipParser {
  static const double confidenceThreshold = 0.80;

  @override
  ParsedSlip parse(String rawText) {
    final confidences = <String, double>{};
    bool needsReview = false;

    // 1. Detect Provider
    final provider = ProviderDetector.detect(rawText);
    if (provider != null) {
      confidences['provider'] = 0.95;
    }

    // 2. Extract Amount
    final amountMinor = _extractAmount(rawText, confidences);

    // 3. Extract Direction (received / sent / unknown)
    final direction = _extractDirection(rawText, confidences);

    // 4. Extract Transaction ID (TID / Trx / Ref)
    final tid = _extractTransactionId(rawText, confidences);

    // 5. Extract Counterparty Name & Masked Account
    final counterparty = _extractCounterparty(rawText, confidences);
    final account = _extractAccount(rawText, confidences);

    // 6. Extract Date & Time
    final occurredAt = _extractDate(rawText, confidences);

    // Check if any critical field is below confidence threshold
    for (final conf in confidences.values) {
      if (conf < confidenceThreshold) {
        needsReview = true;
        break;
      }
    }
    if (amountMinor == null || tid == null) {
      needsReview = true;
    }

    return ParsedSlip(
      amountMinor: amountMinor,
      currency: 'PKR',
      direction: direction,
      counterpartyName: counterparty,
      counterpartyAccountMasked: account,
      transactionId: tid,
      provider: provider,
      occurredAt: occurredAt,
      fieldConfidences: confidences,
      needsReview: needsReview,
    );
  }

  int? _extractAmount(String text, Map<String, double> conf) {
    // Matches: "Rs 5,000.00", "PKR 12,500", "Amount: 1,500"
    final regex = RegExp(
      r'(?:Rs\.?|PKR|Amount[:\s]*)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final str = match.group(1)!.replaceAll(',', '');
      final parsed = double.tryParse(str);
      if (parsed != null) {
        conf['amount'] = 0.95;
        return (parsed * 100).round();
      }
    }

    // Fallback: search for standalone numbers with decimal (e.g. 5000.00)
    final fallbackRegex = RegExp(r'\b([0-9]{1,3}(?:,[0-9]{3})+\.[0-9]{2})\b');
    final fallbackMatch = fallbackRegex.firstMatch(text);
    if (fallbackMatch != null) {
      final str = fallbackMatch.group(1)!.replaceAll(',', '');
      final parsed = double.tryParse(str);
      if (parsed != null) {
        conf['amount'] = 0.70; // Lower confidence
        return (parsed * 100).round();
      }
    }

    conf['amount'] = 0.0;
    return null;
  }

  String _extractDirection(String text, Map<String, double> conf) {
    final lower = text.toLowerCase();
    if (lower.contains('received') ||
        lower.contains('credited') ||
        lower.contains('money received') ||
        lower.contains('payment received') ||
        lower.contains('from:')) {
      conf['direction'] = 0.90;
      return 'received';
    }
    if (lower.contains('sent') ||
        lower.contains('debited') ||
        lower.contains('transferred to') ||
        lower.contains('payment successful') ||
        lower.contains('paid to')) {
      conf['direction'] = 0.90;
      return 'sent';
    }
    conf['direction'] = 0.50;
    return 'unknown';
  }

  String? _extractTransactionId(String text, Map<String, double> conf) {
    // Matches: "TID: 12345678", "Trx ID: ABC123", "Ref No: 98214309", "Transaction ID 9812"
    final regex = RegExp(
      r'(?:TID|Trx\s*ID|Ref(?:erence)?\s*(?:No|ID)?|Transaction\s*ID)[:\s#]*([A-Z0-9_-]{6,25})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      conf['transactionId'] = 0.90;
      return match.group(1)!.trim();
    }
    conf['transactionId'] = 0.0;
    return null;
  }

  String? _extractCounterparty(String text, Map<String, double> conf) {
    // Matches: "To: John Doe", "From: Kashif Electronics", "Sent to: Ali", "Paid to: K-Electric Ltd"
    final regex = RegExp(
      r'(?:To|From|Sent\s+to|Received\s+from|Paid\s+to)[:\s]+([A-Za-z0-9\s&.-]{3,40})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final name = match.group(1)!.trim().split('\n').first;
      if (name.length > 2) {
        conf['counterparty'] = 0.85;
        return name;
      }
    }
    conf['counterparty'] = 0.0;
    return null;
  }

  String? _extractAccount(String text, Map<String, double> conf) {
    // Matches: "0345-***9012" or "03001234567" or masked account "PK**...1234"
    final regex = RegExp(
      r'\b(03[0-9]{2}[-\s]?[*0-9]{7}|[0-9]{4}[-\s]?[*]{3,}[-\s]?[0-9]{3,4}|PK[0-9]{2}[A-Z]{4}[0-9*]{10,20})\b',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      conf['account'] = 0.85;
      return match.group(1)!.trim();
    }
    return null;
  }

  DateTime? _extractDate(String text, Map<String, double> conf) {
    // Common date patterns: "12 Oct 2026", "12-10-2026", "2026-10-12"
    final regex = RegExp(
      r'\b([0-9]{1,2}[-\/][0-9]{1,2}[-\/][0-9]{2,4}|[0-9]{4}[-\/][0-9]{1,2}[-\/][0-9]{1,2})\b',
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      conf['date'] = 0.80;
      try {
        final parts = match.group(1)!.split(RegExp(r'[-\/]'));
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else if (parts[2].length == 4) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
    }
    return null;
  }
}
