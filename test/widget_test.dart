import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/vault/presentation/screens/vault_screen.dart';
import 'package:slip_vault/main.dart';

void main() {
  testWidgets('SlipVaultApp boots up to empty Vault screen', (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const SlipVaultApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VaultScreen), findsOneWidget);
    expect(find.text('Slip Vault'), findsWidgets);
    expect(find.text('Net Cash Flow'), findsOneWidget);

    await testDb.close();
  });
}
