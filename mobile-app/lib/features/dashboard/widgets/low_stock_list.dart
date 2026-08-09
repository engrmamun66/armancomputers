import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart' show AppColors;
import '../../../models/dashboard.dart';
import '../../../shared/widgets/empty_state.dart';

/// Vertical list of low/out-of-stock products, visually flagged with the
/// foundation's semantic warning/danger colors (out-of-stock gets the
/// stronger danger tint). Tapping a row opens the product detail screen
/// (route already registered app-wide), mirroring the web dashboard's
/// RouterLink-to-product behavior.
class LowStockList extends StatelessWidget {
  final List<LowStockProduct> products;

  const LowStockList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AppEmptyState(
        title: 'Nothing needs restocking.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _LowStockRow(product: products[i]),
        ],
      ],
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final LowStockProduct product;

  const _LowStockRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final isOut = product.currentStock <= 0;
    final tint = isOut ? AppColors.danger(context) : AppColors.warning(context);
    final tintBg = isOut ? AppColors.dangerBg(context) : AppColors.warningBg(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/products/${product.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isOut ? Icons.remove_shopping_cart_outlined : Icons.warning_amber_rounded,
              size: 18,
              color: tint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: tintBg, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${product.currentStock} / ${product.minimumStock}',
                style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
