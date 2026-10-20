import 'package:slip_vault/features/import/domain/provider_detector.dart';
import 'package:slip_vault/features/import/domain/slip_parser.dart';

/// Pure Dart generic heuristic parser for slips across all banks, wallets and international currencies
class GenericParser implements SlipParser {
  static const double confidenceThreshold = 0.80;

  static const List<String> _receiptStopWords = [
    'avoid',
    'federal',
    'warrant',
    'unknown caller',
    'shield',
    'suspicious',
    'listening',
    'microphone',
  ];

  static const List<String> _financialKeywords = [
    'payment',
    'receipt',
    'transaction',
    'transfer',
    'transferred',
    'transferred to',
    'paid to',
    'sent to',
    'money sent',
    'money received',
    'debited',
    'credited',
    'cash in',
    'cash out',
    'balance',
    'subtotal',
    'grand total',
    'amount paid',
    'invoice',
    'bill payment',
    'tid',
    'trx id',
    'reference number',
    'ref no',
    'iban',
    'sender',
    'receiver',
    'beneficiary',
    'raast',
    'easypaisa',
    'jazzcash',
    'sadapay',
    'nayapay',
    'paypal',
    'zelle',
    'venmo',
    'cash app',
  ];

  @override
  ParsedSlip parse(String rawText) {
    final confidences = <String, double>{};

    // 1. Detect Provider (Local & Global)
    final provider = ProviderDetector.detect(rawText);
    if (provider != null) {
      confidences['provider'] = 0.95;
    }

    // 2. Detect Currency
    final currency = _detectCurrency(rawText);

    // 3. Extract Transaction ID (TID / Trx / Ref / Reference Number)
    final tid = _extractTransactionId(rawText, confidences);

    // 4. Sanity Check: Is this actually a payment receipt or financial screenshot?
    final isReceipt = _isReceiptViable(rawText, provider, tid);
    if (!isReceipt) {
      // Flag as non-receipt so it doesn't hallucinate fake transactions
      return ParsedSlip(
        amountMinor: null,
        currency: currency,
        direction: 'unknown',
        counterpartyName: null,
        counterpartyAccountMasked: null,
        transactionId: null,
        provider: provider,
        occurredAt: null,
        fieldConfidences: {
          'amount': 0.0,
          'direction': 0.0,
          'counterparty': 0.0,
          'transactionId': 0.0,
        },
        needsReview: true,
        isReceipt: false,
      );
    }

    // 5. Extract Amount
    final amountMinor = _extractAmount(rawText, currency, confidences);

    // 6. Extract Direction (received / sent / unknown)
    final direction = _extractDirection(rawText, confidences);

    // 7. Extract Counterparty Name & Masked Account
    final counterparty = _extractCounterparty(rawText, confidences);
    final account = _extractAccount(rawText, confidences);

    // 8. Extract Date & Time
    final occurredAt = _extractDate(rawText, confidences);

    // Check if any critical field is below confidence threshold
    bool needsReview = false;
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
      currency: currency,
      direction: direction,
      counterpartyName: counterparty,
      counterpartyAccountMasked: account,
      transactionId: tid,
      provider: provider,
      occurredAt: occurredAt,
      fieldConfidences: confidences,
      needsReview: needsReview,
      isReceipt: true,
    );
  }

  bool _isReceiptViable(String text, String? provider, String? tid) {
    if (provider != null) return true;
    if (tid != null) return true;

    final lower = text.toLowerCase();

    // Check for obvious non-receipt spam
    for (final stop in _receiptStopWords) {
      if (lower.contains(stop)) return false;
    }

    // Must contain at least two financial markers
    int hits = 0;
    for (final kw in _financialKeywords) {
      if (lower.contains(kw)) {
        hits++;
        if (hits >= 2) return true;
      }
    }
    return false;
  }

  String _detectCurrency(String text) {
    final lower = text.toLowerCase();
    if (text.contains(r'$') || lower.contains('usd')) return 'USD';
    if (text.contains('€') || lower.contains('eur')) return 'EUR';
    if (text.contains('£') || lower.contains('gbp')) return 'GBP';
    if (lower.contains('aed') || lower.contains('dirham')) return 'AED';
    if (lower.contains('sar') || lower.contains('riyal')) return 'SAR';
    if (text.contains('₹') || lower.contains('inr')) return 'INR';
    if (lower.contains('cad') || text.contains(r'c$')) return 'CAD';
    if (lower.contains('aud') || text.contains(r'a$')) return 'AUD';
    return 'PKR';
  }

  int? _extractAmount(String text, String currency, Map<String, double> conf) {
    // Matches: "Rs 5,000.00", "Rs. 400", "PKR 12,500", "$ 150.00", "€ 45", "AED 200", "Amount: 1,500"
    final regex = RegExp(
      r'(?:Rs\.?|PKR|\$|€|£|₹|AED|SAR|INR|CAD|AUD|Amount[:\s]*)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final str = match.group(1)!.replaceAll(',', '');
      final parsed = double.tryParse(str);
      if (parsed != null && parsed > 0) {
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
      if (parsed != null && parsed > 0) {
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
        if (val != null && val > 0 && val < 50000000) {
          if (i + 1 < lines.length && RegExp(r'^\.[0-9]{1,2}$').hasMatch(lines[i + 1])) {
            val += double.tryParse(lines[i + 1]) ?? 0;
          } else if (i + 2 < lines.length && RegExp(r'^\.[0-9]{1,2}$').hasMatch(lines[i + 2])) {
            val += double.tryParse(lines[i + 2]) ?? 0;
          }
          final lower = text.toLowerCase();
          if (lower.contains('rs') || lower.contains('pkr') || lower.contains('sent') ||
              lower.contains('received') || lower.contains('payment') || lower.contains('transfer') ||
              lower.contains(r'$') || lower.contains('usd')) {
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
        lower.contains('you have received') ||
        lower.contains('cash in') ||
        lower.contains('credited to') ||
        lower.contains('received from') ||
        lower.contains('money credited')) {
      conf['direction'] = 0.90;
      return 'received';
    }

    // Explicit Sent / Transfer
    if (lower.contains('successfully sent') ||
        lower.contains('money has been sent') ||
        lower.contains('paid to') ||
        lower.contains('sent to') ||
        lower.contains('transferred to') ||
        lower.contains('debited') ||
        lower.contains('payment successful') ||
        lower.contains('transaction status successful') ||
        lower.contains('transfer successful') ||
        lower.contains('transfer completed') ||
        lower.contains('payment completed') ||
        lower.contains('beneficiary')) {
      conf['direction'] = 0.90;
      return 'sent';
    }

    if (lower.contains('received') || lower.contains('credited')) {
      conf['direction'] = 0.90;
      return 'received';
    }

    // Check P2P sender to receiver e.g. "Ammad Ul Hassan Khan to IRFAN NAEEM"
    if (RegExp(r'[A-Za-z\s]+ to [A-Za-z\s]+', caseSensitive: false).hasMatch(text) &&
        (lower.contains('raast') || lower.contains('sadapay') || lower.contains('faysal') || lower.contains('transfer'))) {
      conf['direction'] = 0.85;
      return 'sent';
    }

    conf['direction'] = 0.50;
    return 'unknown';
  }

  String? _extractTransactionId(String text, Map<String, double> conf) {
    // Matches: "TID: 12345678", "Reference Number Raast-600453", "Trx ID: ABC123", "Ref No: 98214309", "Ref: SD-992182"
    final regex = RegExp(
      r'(?:TID|Trx\s*ID|Ref(?:erence)?(?:\s*(?:Number|No|ID))?|Transaction\s*ID)[:\s#\n]*([A-Z0-9_-]{5,30})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final tid = match.group(1)!.trim();
      if (tid.toLowerCase() != 'number' && tid.toLowerCase() != 'successful') {
        conf['transactionId'] = 0.90;
        return tid;
      }
    }
    conf['transactionId'] = 0.0;
    return null;
  }

  String? _extractCounterparty(String text, Map<String, double> conf) {
    // 1. Explicit transaction targets: "Successfully Sent to\nAmmad UI Hassan Khan", "Sent to: Ali", "Paid to: Kashif Electronics"
    final sentToPattern = RegExp(
      r'(?:successfully\s+sent\s+to|sent\s+to|paid\s+to|transferred\s+to|received\s+from|beneficiary)[:\s\n]+([^\n]{3,40})',
      caseSensitive: false,
    );
    final sentToMatch = sentToPattern.firstMatch(text);
    if (sentToMatch != null) {
      final name = sentToMatch.group(1)!.trim();
      if (_isValidName(name)) {
        conf['counterparty'] = 0.85;
        return name;
      }
    }

    // 2. Matches: "To: John Doe", "From: Kashif Electronics", "From\nSHAHID ABUBAKAR"
    final fromToPattern = RegExp(
      r'(?:^|\n|\s)\b(?:To|From)[:\s\n]+([^\n]{3,40})',
      caseSensitive: false,
    );
    for (final match in fromToPattern.allMatches(text)) {
      final candidate = match.group(1)!.trim();
      if (_isValidName(candidate)) {
        conf['counterparty'] = 0.85;
        return candidate;
      }
    }

    // 3. P2P single line: "Ammad Ul Hassan Khan to IRFAN NAEEM"
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      final p2pMatch = RegExp(
        r'^([A-Za-z\s]{3,30})\s+to\s+([A-Za-z0-9\s&.-]{3,30})$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (p2pMatch != null) {
        final name = p2pMatch.group(2)!.trim();
        if (_isValidName(name)) {
          conf['counterparty'] = 0.85;
          return name;
        }
      }
    }

    conf['counterparty'] = 0.0;
    return null;
  }

  bool _isValidName(String name) {
    final lower = name.toLowerCase();
    if (name.length < 3) return false;
    if (lower.contains('account') ||
        lower.contains('receiver') ||
        lower.contains('details') ||
        lower.contains('avoid') ||
        lower.contains('federal') ||
        lower.contains('warrant') ||
        lower.contains('date') ||
        lower.contains('time') ||
        lower.contains('number')) {
      return false;
    }
    return true;
  }

  String? _extractAccount(String text, Map<String, double> conf) {
    // 1. Label pattern: "Receiver's Account Mobilink Microfinance Bank *1274"
    final acctLabelRegex = RegExp(
      r"(?:Receiver'?s?\s*Account|Account(?:\s*Number)?|IBAN)[:\s\n]+([^\n]{3,45})",
      caseSensitive: false,
    );
    final labelMatch = acctLabelRegex.firstMatch(text);
    if (labelMatch != null) {
      final captured = labelMatch.group(1)!.trim();
      conf['account'] = 0.85;
      return captured;
    }

    // 2. IBAN Pattern (e.g. PK34MEZN0001234567890123)
    final ibanRegex = RegExp(r'\b([A-Z]{2}[0-9]{2}[A-Z0-9]{12,30})\b');
    final ibanMatch = ibanRegex.firstMatch(text);
    if (ibanMatch != null) {
      conf['account'] = 0.90;
      return ibanMatch.group(1);
    }

    // 3. Masked account (e.g. 0300-***9012 or ****-1234 or *1274)
    final maskedRegex = RegExp(r'\b([0-9*#-]{4,20})\b');
    final matches = maskedRegex.allMatches(text);
    for (final m in matches) {
      final str = m.group(1)!;
      if (str.contains('*') || str.contains('-')) {
        conf['account'] = 0.80;
        return str;
      }
    }

    conf['account'] = 0.0;
    return null;
  }

  DateTime? _extractDate(String text, Map<String, double> conf) {
    // 1. Pattern: "03 October 2026", "18-Oct-2026"
    final namedMonthRegex = RegExp(
      r'([0-9]{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|[A-Za-z]{3})\s+([0-9]{4})',
      caseSensitive: false,
    );
    final namedMatch = namedMonthRegex.firstMatch(text);
    if (namedMatch != null) {
      final day = int.tryParse(namedMatch.group(1)!);
      final monthStr = namedMatch.group(2)!.toLowerCase();
      final year = int.tryParse(namedMatch.group(3)!);
      final month = _monthNumber(monthStr);
      if (day != null && year != null && month != null) {
        conf['date'] = 0.90;
        return DateTime(year, month, day);
      }
    }

    // 2. Pattern: "YYYY-MM-DD" or "YYYY/MM/DD"
    final isoRegex = RegExp(r'\b([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})\b');
    final isoMatch = isoRegex.firstMatch(text);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      if (year != null && month != null && day != null) {
        conf['date'] = 0.90;
        return DateTime(year, month, day);
      }
    }

    // 3. Pattern: "DD-MM-YYYY" or "DD/MM/YYYY"
    final dmyRegex = RegExp(r'\b([0-9]{1,2})[-/]([0-9]{1,2})[-/]([0-9]{4})\b');
    final dmyMatch = dmyRegex.firstMatch(text);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      final year = int.tryParse(dmyMatch.group(3)!);
      if (year != null && month != null && day != null) {
        conf['date'] = 0.90;
        return DateTime(year, month, day);
      }
    }

    conf['date'] = 0.0;
    return null;
  }

  int? _monthNumber(String m) {
    if (m.startsWith('jan')) return 1;
    if (m.startsWith('feb')) return 2;
    if (m.startsWith('mar')) return 3;
    if (m.startsWith('apr')) return 4;
    if (m.startsWith('may')) return 5;
    if (m.startsWith('jun')) return 6;
    if (m.startsWith('jul')) return 7;
    if (m.startsWith('aug')) return 8;
    if (m.startsWith('sep')) return 9;
    if (m.startsWith('oct')) return 10;
    if (m.startsWith('nov')) return 11;
    if (m.startsWith('dec')) return 12;
    return null;
  }
}
