import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'more_sheet.dart';

/// Bottom-nav shell for the 3 highest-frequency screens; everything else is
/// reached through "More" (see more_sheet.dart) as a full-screen push, which
/// keeps this shell simple and avoids role-conditional tab branches.
class HomeShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const HomeShell({super.key, required this.location, required this.child});

  int get _index {
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/sales')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/products');
              break;
            case 2:
              context.go('/sales');
              break;
            case 3:
              showMoreSheet(context, ref);
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.upload_outlined), selectedIcon: Icon(Icons.upload), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
