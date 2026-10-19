import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/features/vault/presentation/screens/vault_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'vault',
        builder: (context, state) => const VaultScreen(),
      ),
    ],
  );
});
