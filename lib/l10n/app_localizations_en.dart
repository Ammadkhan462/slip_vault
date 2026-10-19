// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Slip Vault';

  @override
  String get vaultTitle => 'Slip Vault';

  @override
  String get vaultSubtitle => 'Receipt Vault';

  @override
  String get offlineVault => 'Offline Vault';

  @override
  String get all => 'All';

  @override
  String get received => 'Received';

  @override
  String get sent => 'Sent';

  @override
  String get needsReview => 'Needs Review';

  @override
  String get otherScreenshots => 'Other Screenshots';

  @override
  String get netCashFlow => 'Net Cash Flow';

  @override
  String get allOnDevice => 'All on-device';

  @override
  String get totalReceived => 'Total Received';

  @override
  String get totalSent => 'Total Sent';

  @override
  String get searchPlaceholder => 'Search text, names, TID, amounts...';

  @override
  String get emptyVaultTitle => 'No slips or screenshots yet';

  @override
  String get emptyVaultSubtitle =>
      'Tap the + button or share screenshots from your gallery directly to Slip Vault.';

  @override
  String get importScreenshots => 'Import Screenshots';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get settings => 'Settings';

  @override
  String get exportReport => 'Export Report';

  @override
  String get monthlyReport => 'Monthly Report';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get appLock => 'App Lock';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get about => 'About';

  @override
  String get save => 'Save';

  @override
  String get discard => 'Discard';

  @override
  String get delete => 'Delete';
}
