import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/features/splash/presentation/splash_screen.dart';
import 'package:fawatir/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fawatir/features/dashboard/data/dashboard_repository.dart';
import 'package:fawatir/features/clients/presentation/clients_screen.dart';
import 'package:fawatir/features/invoices/presentation/invoices_screen.dart';
import 'package:fawatir/features/settings/presentation/settings_screen.dart';
import 'package:fawatir/features/company/presentation/company_form_screen.dart';
import 'package:fawatir/features/clients/presentation/client_form_screen.dart';
import 'package:fawatir/features/clients/presentation/client_detail_screen.dart';
import 'package:fawatir/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:fawatir/features/subscriptions/presentation/subscription_form_screen.dart';
import 'package:fawatir/features/invoices/presentation/invoice_form_screen.dart';
import 'package:fawatir/features/invoices/presentation/invoice_detail_screen.dart';
import 'package:fawatir/features/payments/presentation/payment_form_screen.dart';
import 'package:fawatir/features/subscriptions/presentation/generated_drafts_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/clients',
              builder: (context, state) => const ClientsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const ClientFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (context, state) {
                    final idStr = state.pathParameters['id'];
                    final id = int.tryParse(idStr ?? '');
                    return ClientFormScreen(clientId: id);
                  },
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final idStr = state.pathParameters['id'];
                    final id = int.tryParse(idStr ?? '') ?? 0;
                    return ClientDetailScreen(clientId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'subscriptions',
                      builder: (context, state) {
                        final idStr = state.pathParameters['id'];
                        final id = int.tryParse(idStr ?? '') ?? 0;
                        return SubscriptionsScreen(clientId: id);
                      },
                      routes: [
                        GoRoute(
                          path: 'add',
                          builder: (context, state) {
                            final idStr = state.pathParameters['id'];
                            final id = int.tryParse(idStr ?? '') ?? 0;
                            return SubscriptionFormScreen(clientId: id);
                          },
                        ),
                        GoRoute(
                          path: 'edit/:subId',
                          builder: (context, state) {
                            final idStr = state.pathParameters['id'];
                            final id = int.tryParse(idStr ?? '') ?? 0;
                            final subIdStr = state.pathParameters['subId'];
                            final subId = int.tryParse(subIdStr ?? '') ?? 0;
                            return SubscriptionFormScreen(clientId: id, subscriptionId: subId);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/invoices',
              builder: (context, state) => const InvoicesScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const InvoiceFormScreen(),
                ),
                GoRoute(
                  path: 'drafts-review',
                  builder: (context, state) {
                    final ids = state.extra as List<int>? ?? [];
                    return GeneratedDraftsScreen(invoiceIds: ids);
                  },
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final idStr = state.pathParameters['id'];
                    final id = int.tryParse(idStr ?? '') ?? 0;
                    return InvoiceDetailScreen(invoiceId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'pay',
                      builder: (context, state) {
                        final idStr = state.pathParameters['id'];
                        final id = int.tryParse(idStr ?? '') ?? 0;
                        return PaymentFormScreen(invoiceId: id);
                      },
                    ),
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) {
                        final idStr = state.pathParameters['id'];
                        final id = int.tryParse(idStr ?? '') ?? 0;
                        return InvoiceFormScreen(invoiceId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'company-setup',
                  builder: (context, state) => const CompanyFormScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider).value;
    final overdueCount = stats?.overdueInvoiceCount ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          elevation: 3,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.accent.withValues(alpha: 0.15),
          onDestinationSelected: (int index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.accent),
              label: 'الرئيسية',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded, color: AppColors.accent),
              label: 'العملاء',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: overdueCount > 0,
                label: Text(
                  '$overdueCount',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                backgroundColor: Colors.red.shade700,
                child: const Icon(Icons.receipt_long_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: overdueCount > 0,
                label: Text(
                  '$overdueCount',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                backgroundColor: Colors.red.shade700,
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent),
              ),
              label: 'الفواتير',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: AppColors.accent),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
