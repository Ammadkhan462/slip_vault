import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/features/import/presentation/screens/import_screen.dart';
import 'package:slip_vault/features/import/presentation/screens/review_screen.dart';
import 'package:slip_vault/features/search/presentation/screens/search_screen.dart';
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
      GoRoute(
        path: '/import',
        name: 'import',
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/review/:id',
        name: 'review',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return ReviewScreen(entryId: id);
        },
      ),
    ],
  );
});
