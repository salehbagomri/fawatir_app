import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fawatir/features/clients/presentation/clients_screen.dart';
import 'package:fawatir/features/invoices/presentation/invoices_screen.dart';
import 'package:fawatir/features/settings/presentation/settings_screen.dart';
import 'package:fawatir/features/company/presentation/company_form_screen.dart';
import 'package:fawatir/features/clients/presentation/client_form_screen.dart';
import 'package:fawatir/features/clients/presentation/client_detail_screen.dart';
import 'package:fawatir/features/invoices/presentation/invoice_form_screen.dart';
import 'package:fawatir/features/invoices/presentation/invoice_detail_screen.dart';


final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  debugLogDiagnostics: true,
  routes: [
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
                  path: ':id',
                  builder: (context, state) {
                    final idStr = state.pathParameters['id'];
                    final id = int.tryParse(idStr ?? '') ?? 0;
                    return InvoiceDetailScreen(invoiceId: id);
                  },
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

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'لوحة المعلومات',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'العملاء',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'الفواتير',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
