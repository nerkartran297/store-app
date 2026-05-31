import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customer_groups/customer_groups_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/discounts/discounts_screen.dart';
import '../../features/invoices/invoices_screen.dart';
import '../../features/packages/package_export_screen.dart';
import '../../features/packages/packages_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/sales/sales_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loggedIn = ref.read(isLoggedInProvider);
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(path: '/sales', builder: (_, _) => const SalesScreen()),
      GoRoute(path: '/products', builder: (_, _) => const ProductsScreen()),
      GoRoute(path: '/discounts', builder: (_, _) => const DiscountsScreen()),
      GoRoute(
          path: '/groups', builder: (_, _) => const CustomerGroupsScreen()),
      GoRoute(path: '/customers', builder: (_, _) => const CustomersScreen()),
      GoRoute(
        path: '/customers/:id',
        builder: (_, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/packages', builder: (_, _) => const PackagesScreen()),
      GoRoute(
          path: '/packages/export',
          builder: (_, _) => const PackageExportScreen()),
      GoRoute(path: '/invoices', builder: (_, _) => const InvoicesScreen()),
      GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
    ],
  );
});

/// Cầu nối: rebuild router khi auth state đổi.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
