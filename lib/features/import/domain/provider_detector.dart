/// Detects payment provider from OCR text keywords
class ProviderDetector {
  static const Map<String, List<String>> _providerKeywords = {
    'JazzCash': ['jazzcash', 'jazz cash', 'mobilink microfinance'],
    'Easypaisa': ['easypaisa', 'easy paisa', 'telenor microfinance'],
    'SadaPay': ['sadapay', 'sada pay', 'sada biz'],
    'NayaPay': ['nayapay', 'naya pay'],
    'Raast': ['raast', 'state bank of pakistan', 'sbp raast'],
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
