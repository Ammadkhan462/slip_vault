import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/search/presentation/screens/search_screen.dart';
import 'package:slip_vault/l10n/app_localizations.dart';

void main() {
  Widget buildTestableWidget(AppDatabase db) {
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
        home: SearchScreen(),
      ),
    );
  }

  group('SearchScreen Widget Tests', () {
    testWidgets('Renders search input and interacts with query', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(buildTestableWidget(db));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search Wi-Fi, passwords, TID, text...'), findsOneWidget);
      expect(find.text('Instant OCR Search'), findsOneWidget);
      expect(find.text('FTS5 SQLite Engine'), findsOneWidget);

      // Enter query
      await tester.enterText(find.byType(TextField), 'JazzCash');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear icon
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('JazzCash'), findsNothing);

      await db.close();
    });
  });
}
