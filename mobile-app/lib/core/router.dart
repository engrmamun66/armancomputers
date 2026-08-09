import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/brands/brand_list_screen.dart';
import '../features/customers/customer_detail_screen.dart';
import '../features/customers/customer_list_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/invoices/invoice_detail_screen.dart';
import '../features/invoices/invoice_list_screen.dart';
import '../features/products/product_detail_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/products/product_list_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/static/contact_screen.dart';
import '../features/static/privacy_screen.dart';
import '../features/stock_in/stock_in_detail_screen.dart';
import '../features/stock_in/stock_in_form_screen.dart';
import '../features/stock_in/stock_in_list_screen.dart';
import '../features/stock_out/stock_out_detail_screen.dart';
import '../features/stock_out/stock_out_form_screen.dart';
import '../features/stock_out/stock_out_list_screen.dart';
import '../features/users/user_list_screen.dart';
import '../shared/widgets/home_shell.dart';
import '../providers/auth_provider.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated || previous?.isLoading != next.isLoading) {
        notifyListeners();
      }
    });
  }
}

int _intParam(GoRouterState state, String name) => int.parse(state.pathParameters[name]!);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final goingToLogin = state.matchedLocation == '/login';

      if (auth.isLoading) return null;
      if (!auth.isAuthenticated && !goingToLogin) return '/login';
      if (auth.isAuthenticated && goingToLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      ShellRoute(
        builder: (context, state, child) => HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/products', builder: (context, state) => const ProductListScreen()),
          GoRoute(path: '/stock-out', builder: (context, state) => const StockOutListScreen()),
        ],
      ),

      // Products — detail/form pushed full-screen (outside the bottom-nav shell).
      GoRoute(path: '/products/create', builder: (context, state) => const ProductFormScreen()),
      GoRoute(path: '/products/:id', builder: (context, state) => ProductDetailScreen(id: _intParam(state, 'id'))),
      GoRoute(
        path: '/products/:id/edit',
        builder: (context, state) => ProductFormScreen(id: _intParam(state, 'id')),
      ),

      // Brands
      GoRoute(path: '/brands', builder: (context, state) => const BrandListScreen()),

      // Customers
      GoRoute(path: '/customers', builder: (context, state) => const CustomerListScreen()),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) => CustomerDetailScreen(id: _intParam(state, 'id')),
      ),

      // Stock In
      GoRoute(path: '/stock-in', builder: (context, state) => const StockInListScreen()),
      GoRoute(path: '/stock-in/create', builder: (context, state) => const StockInFormScreen()),
      GoRoute(
        path: '/stock-in/:id',
        builder: (context, state) => StockInDetailScreen(id: _intParam(state, 'id')),
      ),
      GoRoute(
        path: '/stock-in/:id/edit',
        builder: (context, state) => StockInFormScreen(id: _intParam(state, 'id')),
      ),

      // Stock Out — detail/form pushed full-screen (list itself is a shell tab).
      GoRoute(path: '/stock-out/create', builder: (context, state) => const StockOutFormScreen()),
      GoRoute(
        path: '/stock-out/:id',
        builder: (context, state) => StockOutDetailScreen(id: _intParam(state, 'id')),
      ),
      GoRoute(
        path: '/stock-out/:id/edit',
        builder: (context, state) => StockOutFormScreen(id: _intParam(state, 'id')),
      ),

      // Invoices
      GoRoute(path: '/invoices', builder: (context, state) => const InvoiceListScreen()),
      GoRoute(
        path: '/invoices/:id',
        builder: (context, state) => InvoiceDetailScreen(id: _intParam(state, 'id')),
      ),

      // Users (admin only — enforced inside UserListScreen + backend policy)
      GoRoute(path: '/users', builder: (context, state) => const UserListScreen()),

      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/contact', builder: (context, state) => const ContactScreen()),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
    ],
  );
});
