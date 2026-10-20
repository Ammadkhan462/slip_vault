import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/tour/data/vault_tour_service.dart';
import 'package:slip_vault/features/vault/presentation/screens/vault_screen.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    VaultTourService.testOverride = true;
  });

  tearDown(() {
    VaultTourService.testOverride = null;
  });

  Widget buildTestableWidget({required AppDatabase db}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
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
        home: VaultScreen(),
      ),
    );
  }

  group('VaultScreen Widget Tests', () {
    testWidgets('Displays empty state message when no transactions exist', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(buildTestableWidget(db: db));
      await tester.pumpAndSettle();

      expect(find.text('No slips or screenshots yet'), findsOneWidget);
      expect(find.text('Net Cash Flow'), findsOneWidget);

      await db.close();
    });

    testWidgets('Renders seeded transaction list items and totals', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();

      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/test.jpg',
              imageHash: 'vault_hash_1',
              amountMinor: const drift.Value(750000), // Rs 7,500
              direction: const drift.Value(Direction.received),
              counterpartyName: const drift.Value('Ali Merchant'),
              provider: const drift.Value('JazzCash'),
              transactionId: const drift.Value('JC-100200'),
              occurredAt: drift.Value(now),
              ocrText: const drift.Value('JazzCash Rs 7500 Ali Merchant'),
            ),
          );

      await tester.pumpWidget(buildTestableWidget(db: db));
      await tester.pumpAndSettle();

      expect(find.text('Ali Merchant'), findsOneWidget);
      expect(find.text('JazzCash'), findsOneWidget);
      expect(find.text('+PKR 7500'), findsWidgets);

      await db.close();
    });

    testWidgets('Interactive Vault Coach Mark displays bubble guidance and can navigate or skip', (tester) async {
      VaultTourService.testOverride = false;
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(buildTestableWidget(db: db));
      // Pump initial render
      await tester.pump();
      // Advance past the 700ms tour timer
      await tester.pump(const Duration(milliseconds: 750));

      // Coach mark bubble 1 (Auto-Sync) should appear
      expect(find.text('1-Tap Auto-Sync Scanner'), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('Skip Tour'), findsOneWidget);

      // Tap Next to advance to Hero Card step
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 100));

      // Coach mark bubble 2 (Net Cash Flow) should appear
      expect(find.text('Net Cash Flow & Currencies'), findsOneWidget);
      expect(find.text('STEP 2 OF 3'), findsOneWidget);

      // Tap Next to advance to Filters step
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 100));

      // Coach mark bubble 3 (Smart Filters) should appear
      expect(find.text('Smart Filters & Categories'), findsOneWidget);
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Got it!'), findsOneWidget);

      // Tap 'Got it!' to complete the tour
      await tester.tap(find.text('Got it!'));
      await tester.pump(const Duration(milliseconds: 100));

      // Coach mark overlay should be dismissed
      expect(find.text('Smart Filters & Categories'), findsNothing);

      await db.close();
    });
  });
}
