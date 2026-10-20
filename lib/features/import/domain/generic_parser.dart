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

    // 4. Extract Transaction ID (TID / Trx / Ref / Reference Number)
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
    // Matches: "Rs 5,000.00", "Rs. 400", "PKR 12,500", "Amount: 1,500"
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
        conf['amount'] = 0.70;
        return (parsed * 100).round();
      }
    }

    // Multi-line fallback: line with digits (e.g. "700" then ".00" in Easypaisa)
    final lines = text.split('\n').map((l) => l.trim()).toList();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains(':') || line.length > 10) continue;
      final numMatch = RegExp(r'^([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)$').firstMatch(line);
      if (numMatch != null) {
        double? val = double.tryParse(numMatch.group(1)!.replaceAll(',', ''));
        if (val != null && val > 0 && val < 5000000) {
          if (i + 1 < lines.length && RegExp(r'^\.[0-9]{1,2}$').hasMatch(lines[i + 1])) {
            val += double.tryParse(lines[i + 1]) ?? 0;
          } else if (i + 2 < lines.length && RegExp(r'^\.[0-9]{1,2}$').hasMatch(lines[i + 2])) {
            val += double.tryParse(lines[i + 2]) ?? 0;
          }
          final lower = text.toLowerCase();
          if (lower.contains('rs') || lower.contains('pkr') || lower.contains('sent') ||
              lower.contains('received') || lower.contains('payment') || lower.contains('transfer')) {
            conf['amount'] = 0.85;
            return (val * 100).round();
          }
        }
      }
    }

    conf['amount'] = 0.0;
    return null;
  }

  String _extractDirection(String text, Map<String, double> conf) {
    final lower = text.toLowerCase();

    // Explicit Received
    if (lower.contains('money received') ||
        lower.contains('payment received') ||
        lower.contains('cash in') ||
        lower.contains('credited to') ||
        lower.contains('received from')) {
      conf['direction'] = 0.90;
      return 'received';
    }

    // Explicit Sent / Transfer
    if (lower.contains('successfully sent') ||
        lower.contains('money has been sent') ||
        lower.contains('paid to') ||
        lower.contains('sent to') ||
        lower.contains('debited') ||
        lower.contains('transferred') ||
        lower.contains('payment successful') ||
        lower.contains('transaction status successful') ||
        RegExp(r'\bto\b', caseSensitive: false).hasMatch(text) ||
        RegExp(r'\bsent\b', caseSensitive: false).hasMatch(text)) {
      conf['direction'] = 0.90;
      return 'sent';
    }

    if (lower.contains('received') || lower.contains('credited')) {
      conf['direction'] = 0.90;
      return 'received';
    }

    conf['direction'] = 0.50;
    return 'unknown';
  }

  String? _extractTransactionId(String text, Map<String, double> conf) {
    // Matches: "TID: 12345678", "Reference Number Raast-600453", "Trx ID: ABC123", "Ref No: 98214309"
    final regex = RegExp(
      r'(?:TID|Trx\s*ID|Ref(?:erence)?(?:\s*(?:Number|No|ID))?|Transaction\s*ID)[:\s#\n]*([A-Z0-9_-]{5,30})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final tid = match.group(1)!.trim();
      // Ensure we didn't capture the word "number"
      if (tid.toLowerCase() != 'number') {
        conf['transactionId'] = 0.90;
        return tid;
      }
    }
    conf['transactionId'] = 0.0;
    return null;
  }

  String? _extractCounterparty(String text, Map<String, double> conf) {
    // 1. Matches: "Sender to Receiver" e.g. "Ammad Ul Hassan Khan to IRFAN NAEEM"
    final toPattern = RegExp(
      r'[A-Za-z\s]+ to[\s\n]+([A-Za-z0-9\s&.-]{3,35})',
      caseSensitive: false,
    );
    final toMatch = toPattern.firstMatch(text);
    if (toMatch != null) {
      final name = toMatch.group(1)!.trim().split('\n').first.trim();
      if (name.length > 2 && !name.toLowerCase().contains('account') && !name.toLowerCase().contains('receiver')) {
        conf['counterparty'] = 0.85;
        return name;
      }
    }

    // 2. Matches: "Successfully Sent to\nAmmad UI Hassan Khan" or "Sent to: Ali"
    final sentToPattern = RegExp(
      r'(?:successfully\s+sent\s+to|sent\s+to|paid\s+to|received\s+from)[:\s\n]+([A-Za-z0-9\s&.-]{3,40})',
      caseSensitive: false,
    );
    final sentToMatch = sentToPattern.firstMatch(text);
    if (sentToMatch != null) {
      final name = sentToMatch.group(1)!.trim().split('\n').first.trim();
      if (name.length > 2 && !name.toLowerCase().contains('receiver') && !name.toLowerCase().contains('account')) {
        conf['counterparty'] = 0.85;
        return name;
      }
    }

    // 3. Matches: "To: John Doe", "From: Kashif Electronics", "From\nSHAHID ABUBAKAR"
    final regex = RegExp(
      r'(?:To|From)[:\s\n]+([A-Za-z0-9\s&.-]{3,40})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final name = match.group(1)!.trim().split('\n').first.trim();
      if (name.length > 2 && !name.toLowerCase().contains('receiver') && !name.toLowerCase().contains('account')) {
        conf['counterparty'] = 0.85;
        return name;
      }
    }
    conf['counterparty'] = 0.0;
    return null;
  }

  String? _extractAccount(String text, Map<String, double> conf) {
    // 1. Label pattern: "Receiver's Account Mobilink Microfinance Bank *1274"
    final acctLabelRegex = RegExp(
      r"(?:Account|Receiver's\s*Account|Sender's\s*Account)[:\s]*([^\n]+)",
      caseSensitive: false,
    );
    final acctMatch = acctLabelRegex.firstMatch(text);
    if (acctMatch != null) {
      final val = acctMatch.group(1)!.trim();
      if (val.isNotEmpty && val.length < 50) {
        conf['account'] = 0.85;
        return val;
      }
    }

    // 2. Mobile or masked account: "0345-***9012" or "03001234567" or "*1234"
    final regex = RegExp(
      r'\b(03[0-9]{2}[-\s]?[*0-9]{7}|[0-9]{4}[-\s]?[*]{3,}[-\s]?[0-9]{3,4}|\*[0-9]{4}|PK[0-9]{2}[A-Z]{4}[0-9*]{10,20})\b',
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
    // 1. Textual month format: "03 October 2026" or "12 Oct 2026"
    final textualRegex = RegExp(
      r'\b([0-9]{1,2})\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+([0-9]{4})\b',
      caseSensitive: false,
    );
    final textMatch = textualRegex.firstMatch(text);
    if (textMatch != null) {
      final day = int.tryParse(textMatch.group(1)!);
      final monthStr = textMatch.group(2)!.toLowerCase();
      final year = int.tryParse(textMatch.group(3)!);
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final m = months[monthStr.substring(0, 3)];
      if (day != null && year != null && m != null) {
        conf['date'] = 0.90;
        return DateTime(year, m, day);
      }
    }

    // 2. Numeric formats: "12-10-2026", "2026-10-12"
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
