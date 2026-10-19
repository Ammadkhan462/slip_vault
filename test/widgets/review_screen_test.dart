import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/import/presentation/screens/review_screen.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Widget buildTestableWidget({required AppDatabase db, required int entryId}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
          Locale('ur', ''),
        ],
        home: ReviewScreen(entryId: entryId),
      ),
    );
  }

  group('ReviewScreen Widget Tests', () {
    testWidgets('Renders extracted fields and confidence indicators', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = AppDatabase(NativeDatabase.memory());

      final id = await db.into(db.entries).insert(
            EntriesCompanion.insert(
              imagePath: '/path/mock.jpg',
              imageHash: 'mock_hash_review',
              ocrText: const drift.Value('''
                JazzCash
                Payment Successful
                Amount: Rs 15,000.00
                Paid to: Karachi Electronics
                Account: 0300-1234567
                TID: JC987654321
                Date: 2026-10-19
              '''),
            ),
          );

      await tester.pumpWidget(buildTestableWidget(db: db, entryId: id));
      await tester.pumpAndSettle();

      expect(find.text('Review Slip'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '15000.00'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'Karachi Electronics'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'JC987654321'),
        findsOneWidget,
      );
      expect(find.text('Confirm & Save Entry'), findsOneWidget);

      await db.close();
    });
  });
}
