import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/transactions/presentation/add_transaction_page.dart';
import '../../features/transactions/presentation/categories_page.dart';
import '../../features/transactions/presentation/category_form_page.dart';
import '../../features/transactions/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/wallets/presentation/wallets_page.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../core/constants/constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLanding = state.matchedLocation == '/welcome';

      if (!isAuthenticated && !isLanding) return '/welcome';
      if (isAuthenticated && isLanding) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (context, state) => const AuthPage()),
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddTransactionPage(),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) => AddTransactionPage(
                  transactionId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsPage(),
          ),
          GoRoute(
            path: '/wallets',
            builder: (context, state) => const WalletsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesPage(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const CategoryFormPage(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    builder: (context, state) => CategoryFormPage(
                      categoryId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: AppStrings.analytics,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: AppStrings.wallets,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location.startsWith('/analytics')) return 1;
    if (location.startsWith('/wallets')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/analytics');
        break;
      case 2:
        context.go('/wallets');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}
