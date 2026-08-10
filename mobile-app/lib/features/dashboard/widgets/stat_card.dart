import 'package:flutter/material.dart';

/// Plain data holder so [DashboardScreen] can build the 9-card grid with a
/// simple list literal instead of repeating [StatCard] boilerplate 9 times.
class StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color? tint;
  final bool emphasize;

  const StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
    this.emphasize = false,
  });
}

/// A single stat tile used in the dashboard's 2-column grid. Mirrors the
/// web app's StatCard.vue: icon chip on the left, label + value stacked on
/// the right, with an optional semantic tint (warning/danger) for the
/// low-stock / out-of-stock cards.
class StatCard extends StatelessWidget {
  final StatCardData data;

  const StatCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = data.tint ?? scheme.primary;
    final chipSize = data.emphasize ? 46.0 : 40.0;

    return Card(
      shape: data.emphasize
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: tint.withValues(alpha: 0.35), width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: chipSize,
              width: chipSize,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: tint, size: data.emphasize ? 22 : 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.value,
                    style: (data.emphasize ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(fontWeight: FontWeight.bold, color: data.emphasize ? tint : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
