import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_shell.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/debts/debt_detail_page.dart';
import '../../features/debts/debt_form_page.dart';
import '../../features/debts/debts_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/savings/savings_detail_page.dart';
import '../../features/savings/savings_goal_form_page.dart';
import '../../features/savings/savings_page.dart';
import '../../features/settings/categories_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/transactions/transaction_form_page.dart';
import '../../features/transactions/transactions_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({required bool showOnboarding}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: showOnboarding ? '/onboarding' : '/dashboard',
    routes: [
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, __) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/savings',
                builder: (_, __) => const SavingsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/debts',
                builder: (_, __) => const DebtsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/transactions/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TransactionFormPage(
          initialType: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TransactionFormPage(
          transactionId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/savings/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SavingsGoalFormPage(),
      ),
      GoRoute(
        path: '/savings/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => SavingsDetailPage(
          goalId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/debts/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => DebtFormPage(
          initialType: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        path: '/debts/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => DebtDetailPage(
          debtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/categories',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const CategoriesPage(),
      ),
    ],
  );
}
