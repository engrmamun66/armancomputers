import 'package:flutter/material.dart';

import '../../../models/dashboard.dart';
import '../../../shared/widgets/empty_state.dart';
import 'dashboard_chart_colors.dart';

/// Vertical list of top-selling products, each row showing its name, qty
/// sold, and a proportional horizontal bar (width relative to the row with
/// the highest qtySold). Built from plain Container/Stack widgets — never a
/// horizontal chart or scroll view — per the no-horizontal-scroll rule.
class TopProductsList extends StatelessWidget {
  final List<TopProduct> products;

  const TopProductsList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AppEmptyState(
        title: 'No sales in this period yet.',
        icon: Icons.trending_up_outlined,
      );
    }

    final barColor = DashboardChartColors.slot3(context);
    var maxQty = 0;
    for (final p in products) {
      if (p.qtySold > maxQty) maxQty = p.qtySold;
    }

    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _TopProductRow(product: products[i], maxQty: maxQty, barColor: barColor),
        ],
      ],
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final TopProduct product;
  final int maxQty;
  final Color barColor;

  const _TopProductRow({required this.product, required this.maxQty, required this.barColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = maxQty <= 0 ? 0.0 : product.qtySold / maxQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${product.qtySold} sold',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0.03, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
