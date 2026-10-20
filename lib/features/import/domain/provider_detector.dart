/// Detects payment provider from OCR text keywords (Local & International)
class ProviderDetector {
  static const Map<String, List<String>> _providerKeywords = {
    // Pakistani Mobile Wallets & RAAST
    'JazzCash': ['jazzcash', 'jazz cash', 'mobilink microfinance'],
    'Easypaisa': ['easypaisa', 'easy paisa', 'telenor microfinance'],
    'SadaPay': ['sadapay', 'sada pay', 'sada biz'],
    'NayaPay': ['nayapay', 'naya pay'],
    'Raast': ['raast', 'state bank of pakistan', 'sbp raast'],

    // Pakistani Commercial Banks
    'Faysal Bank': ['faysalbank', 'faysal bank', 'faysal', 'fbl'],
    'HBL': ['hbl', 'habib bank', 'konnect'],
    'Meezan Bank': ['meezan', 'meezan bank'],
    'Bank Alfalah': ['bank alfalah', 'alfalah', 'alfa app'],
    'UBL': ['ubl', 'united bank limited', 'digital app'],
    'MCB': ['mcb', 'muslim commercial bank', 'mcb live'],
    'Allied Bank': ['allied bank', 'abl', 'myabl'],
    'Standard Chartered': ['standard chartered', 'sc mobile'],
    'Bank of Punjab': ['bank of punjab', 'bop'],
    'Askari Bank': ['askari bank', 'akbl'],

    // Global Wallets & P2P FinTech
    'PayPal': ['paypal', 'paypal balance'],
    'Cash App': ['cash app', 'cash tag', 'square inc'],
    'Venmo': ['venmo'],
    'Zelle': ['zelle', 'zelle pay'],
    'Wise': ['wise transfer', 'transferwise', 'wise.com'],
    'Revolut': ['revolut'],
    'Apple Pay': ['apple pay', 'apple cash'],
    'Google Pay': ['google pay', 'gpay'],
    'Stripe': ['stripe payment', 'stripe.com'],

    // US & UK Major Banks
    'Chase': ['jpmorgan chase', 'chase bank', 'chase quickpay'],
    'Bank of America': ['bank of america', 'bofa'],
    'Wells Fargo': ['wells fargo'],
    'Citibank': ['citibank', 'citi bank'],
    'Capital One': ['capital one'],
    'Barclays': ['barclays'],
    'HSBC': ['hsbc'],
    'Lloyds Bank': ['lloyds bank', 'lloyds'],
    'Monzo': ['monzo bank', 'monzo'],
    'Starling Bank': ['starling bank', 'starling'],

    // Middle East (UAE & Saudi Arabia)
    'Emirates NBD': ['emirates nbd', 'enbd', 'liv.'],
    'Al Rajhi Bank': ['al rajhi', 'alrajhi'],
    'ADCB': ['adcb', 'abu dhabi commercial bank'],
    'Dubai Islamic Bank': ['dubai islamic bank', 'dib'],
    'Mashreq': ['mashreq', 'mashreq neo'],
    'SNB AlAhli': ['snb', 'alahli', 'saudi national bank'],

    // India (UPI & Banks)
    'HDFC Bank': ['hdfc bank', 'hdfc'],
    'State Bank of India': ['state bank of india', 'sbi yono', 'sbi upi'],
    'ICICI Bank': ['icici bank', 'imobile'],
    'Axis Bank': ['axis bank'],
    'Paytm': ['paytm payments bank', 'paytm'],
    'PhonePe': ['phonepe'],
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
