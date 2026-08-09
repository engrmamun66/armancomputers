import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/permissions.dart';
import '../../providers/auth_provider.dart';
import 'more_sheet.dart';

/// Bottom-nav shell for the highest-frequency screens; everything else is
/// reached through "More" (see more_sheet.dart) as a full-screen push. The
/// "Purchase" tab is capability-gated (admin/manager only, same rule as the
/// web sidebar) so the tab list — and therefore each index — shifts for staff.
class HomeShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const HomeShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).roleSlug;
    final canPurchase = can(role, 'purchases.manage');

    final routes = ['/dashboard', '/products', if (canPurchase) '/purchases', '/sales'];
    final selectedIndex = routes.indexWhere((r) => location.startsWith(r));

    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      const NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
      if (canPurchase)
        const NavigationDestination(icon: Icon(Icons.arrow_circle_down_outlined), selectedIcon: Icon(Icons.arrow_circle_down), label: 'Purchase'),
      const NavigationDestination(icon: Icon(Icons.upload_outlined), selectedIcon: Icon(Icons.upload), label: 'Sales'),
      const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          onDestinationSelected: (index) {
            if (index == routes.length) {
              showMoreSheet(context, ref);
              return;
            }
            context.go(routes[index]);
          },
          destinations: destinations,
        ),
      ),
    );
  }
}
