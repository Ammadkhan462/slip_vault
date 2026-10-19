import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/vault/presentation/screens/vault_screen.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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
  });
}
