import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/features/paywall/presentation/screens/paywall_screen.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

void main() {
  Widget buildTestableWidget() {
    return const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en', ''),
          Locale('ur', ''),
        ],
        home: PaywallScreen(),
      ),
    );
  }

  group('PaywallScreen Widget Tests', () {
    testWidgets('Renders Pro banner, lifetime access value proposition and buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Slip Vault Pro'), findsOneWidget);
      expect(find.text('LIFETIME ACCESS'), findsOneWidget);
      expect(find.text('Invest Once. Own Your Vault Forever.'), findsOneWidget);
      expect(find.text('Ad-Free Instant Exports'), findsOneWidget);
      expect(find.text('Clean Unbranded Share Cards'), findsOneWidget);
      expect(find.text('Biometric App Lock'), findsOneWidget);
      expect(find.text('Automated Local Zip Backups'), findsOneWidget);
      expect(find.text('Unlock Pro Lifetime'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);
    });
  });
}
