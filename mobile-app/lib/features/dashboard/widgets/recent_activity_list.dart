import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../models/dashboard.dart';
import '../../../shared/widgets/empty_state.dart';

/// "Recent Purchase" — 5 most recent purchase records, each tappable to
/// push the existing purchase detail route.
class RecentPurchaseList extends StatelessWidget {
  final List<RecentPurchase> items;

  const RecentPurchaseList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyState(title: 'No Purchase records yet.', icon: Icons.move_to_inbox_outlined);
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _RecentRow(
            referenceNo: items[i].referenceNo,
            date: items[i].purchaseDate,
            subLabel: items[i].supplierName ?? '—',
            amount: items[i].grandTotal,
            onTap: () => context.push('/purchases/${items[i].id}'),
          ),
        ],
      ],
    );
  }
}

/// "Recent Sales" — 5 most recent sale records, each tappable to
/// push the existing sale detail route.
class RecentSaleList extends StatelessWidget {
  final List<RecentSale> items;

  const RecentSaleList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyState(title: 'No Sales records yet.', icon: Icons.outbox_outlined);
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _RecentRow(
            referenceNo: items[i].referenceNo,
            date: items[i].saleDate,
            subLabel: items[i].customerName ?? '—',
            amount: items[i].grandTotal,
            onTap: () => context.push('/sales/${items[i].id}'),
          ),
        ],
      ],
    );
  }
}

/// Shared row shape for both recent-activity lists: reference no. + date on
/// top, supplier/customer name + amount below, full-width and tappable.
class _RecentRow extends StatelessWidget {
  final String referenceNo;
  final String date;
  final String subLabel;
  final double amount;
  final VoidCallback onTap;

  const _RecentRow({
    required this.referenceNo,
    required this.date,
    required this.subLabel,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    referenceNo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$subLabel  ·  ${formatDate(date)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatCurrency(amount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
