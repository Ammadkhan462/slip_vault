import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slip_vault/features/detail/presentation/screens/detail_screen.dart';
import 'package:slip_vault/features/export/presentation/screens/reports_screen.dart';
import 'package:slip_vault/features/import/presentation/screens/import_screen.dart';
import 'package:slip_vault/features/import/presentation/screens/review_screen.dart';
import 'package:slip_vault/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:slip_vault/features/paywall/presentation/screens/paywall_screen.dart';
import 'package:slip_vault/features/search/presentation/screens/search_screen.dart';
import 'package:slip_vault/features/settings/presentation/screens/settings_screen.dart';
import 'package:slip_vault/features/vault/presentation/screens/vault_screen.dart';

final initialLocationProvider = Provider<String>((ref) => '/');

final routerProvider = Provider<GoRouter>((ref) {
  final initialLoc = ref.watch(initialLocationProvider);
  return GoRouter(
    initialLocation: initialLoc,
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
      GoRoute(
        path: '/detail/:id',
        name: 'detail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return DetailScreen(entryId: id);
        },
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/paywall',
        name: 'paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
});
