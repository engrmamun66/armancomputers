import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/permissions.dart';
import '../../providers/auth_provider.dart';
import 'confirm_dialog.dart';

class _MoreItem {
  final IconData icon;
  final String label;
  final String route;
  const _MoreItem(this.icon, this.label, this.route);
}

void showMoreSheet(BuildContext context, WidgetRef ref) {
  final role = ref.read(authProvider).roleSlug;

  final items = <_MoreItem>[
    if (can(role, 'brands.manage')) const _MoreItem(Icons.local_offer_outlined, 'Brands', '/brands'),
    const _MoreItem(Icons.people_outline, 'Customers', '/customers'),
    const _MoreItem(Icons.receipt_long_outlined, 'Invoices', '/invoices'),
    if (can(role, 'users')) const _MoreItem(Icons.manage_accounts_outlined, 'Users', '/users'),
  ];

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.05,
                children: [
                  ...items.map((item) => _tile(sheetContext, item.icon, item.label, () {
                        Navigator.of(sheetContext).pop();
                        sheetContext.push(item.route);
                      })),
                  _tile(sheetContext, Icons.person_outline, 'Profile', () {
                    Navigator.of(sheetContext).pop();
                    sheetContext.push('/profile');
                  }),
                  _tile(sheetContext, Icons.call_outlined, 'Contact', () {
                    Navigator.of(sheetContext).pop();
                    sheetContext.push('/contact');
                  }),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: Icon(Icons.logout, color: Theme.of(sheetContext).colorScheme.error),
                title: Text('Logout', style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await showAppConfirmDialog(
                    context,
                    title: 'Logout?',
                    message: 'You will need to sign in again to continue.',
                    confirmText: 'Logout',
                    danger: true,
                  );
                  if (confirmed) await ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _tile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
  final scheme = Theme.of(context).colorScheme;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: scheme.onSurfaceVariant),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
      ],
    ),
  );
}
