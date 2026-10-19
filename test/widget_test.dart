import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/features/vault/presentation/screens/vault_screen.dart';
import 'package:slip_vault/main.dart';

void main() {
  testWidgets('SlipVaultApp boots up to empty Vault screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SlipVaultApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VaultScreen), findsOneWidget);
    expect(find.text('Slip Vault'), findsWidgets);
    expect(find.text('Net Cash Flow'), findsOneWidget);
    expect(find.text('Rs 0'), findsWidgets);
  });
}
