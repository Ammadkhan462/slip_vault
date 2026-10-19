import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/export/presentation/screens/reports_screen.dart';
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
        home: ReportsScreen(),
      ),
    );
  }

  group('ReportsScreen Widget Tests', () {
    testWidgets('Renders month header and PDF/CSV export action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(buildTestableWidget(db));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Reports'), findsOneWidget);
      expect(find.text('Monthly Net Cash Flow'), findsOneWidget);
      expect(find.text('Export Statement as PDF'), findsOneWidget);
      expect(find.text('Export Spreadsheet as CSV'), findsOneWidget);

      await db.close();
    });
  });
}
