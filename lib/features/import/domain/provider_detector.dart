/// Detects payment provider from OCR text keywords
class ProviderDetector {
  static const Map<String, List<String>> _providerKeywords = {
    'JazzCash': ['jazzcash', 'jazz cash', 'mobilink microfinance'],
    'Easypaisa': ['easypaisa', 'easy paisa', 'telenor microfinance'],
    'SadaPay': ['sadapay', 'sada pay', 'sada biz'],
    'NayaPay': ['nayapay', 'naya pay'],
    'Raast': ['raast', 'state bank of pakistan', 'sbp raast'],
    'Faysal Bank': ['faysalbank', 'faysal bank', 'faysal', 'fbl'],
    'HBL': ['hbl', 'habib bank', 'konnect'],
    'Meezan Bank': ['meezan', 'meezan bank'],
    'Bank Alfalah': ['bank alfalah', 'alfalah'],
    'UBL': ['ubl', 'united bank limited', 'digital app'],
    'MCB': ['mcb', 'muslim commercial bank', 'mcb live'],
    'Allied Bank': ['allied bank', 'abl', 'myabl'],
  };

  /// Returns detected provider name based on earliest appearance in receipt
  static String? detect(String text) {
    final lower = text.toLowerCase();

    // Prioritize explicit sender: "sent from easypaisa to receiver"
    final sentFromMatch = RegExp(r'sent\s+from\s+([A-Za-z0-9\s]+?)\s+to', caseSensitive: false).firstMatch(text);
    if (sentFromMatch != null) {
      final senderPhrase = sentFromMatch.group(1)!.toLowerCase();
      for (final entry in _providerKeywords.entries) {
        for (final kw in entry.value) {
          if (senderPhrase.contains(kw)) return entry.key;
        }
      }
    }

    String? bestProvider;
    int earliestIndex = 999999;

    for (final entry in _providerKeywords.entries) {
      for (final keyword in entry.value) {
        final idx = lower.indexOf(keyword);
        if (idx != -1 && idx < earliestIndex) {
          earliestIndex = idx;
          bestProvider = entry.key;
        }
      }
    }
    return bestProvider;
  }
}
