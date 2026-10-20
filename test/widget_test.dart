import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/onboarding/data/onboarding_service.dart';
import 'package:slip_vault/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:slip_vault/features/vault/presentation/screens/vault_screen.dart';
import 'package:slip_vault/main.dart';

void main() {
  tearDown(() {
    OnboardingService.testOverride = null;
  });

  testWidgets('SlipVaultApp boots up to empty Vault screen when onboarding is completed', (WidgetTester tester) async {
    OnboardingService.testOverride = true;
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

  testWidgets('SlipVaultApp boots to Onboarding walkthrough for first-time users', (WidgetTester tester) async {
    OnboardingService.testOverride = false;
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const SlipVaultApp(),
      ),
    );
    // Onboarding contains continuous repeating animations; pump frames without waiting for infinite loops
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('1-Tap Auto-Sync & Instant Slip Detection'), findsOneWidget);

    await testDb.close();
  });
}
