import 'package:flutter/material.dart';

import '../../models/paginated.dart';

/// Deliberately Previous/Next only (never a row of page-number links) so
/// this can never overflow into horizontal scrolling on a narrow screen.
class PaginationControls extends StatelessWidget {
  final PageMeta meta;
  final ValueChanged<int> onPageChange;

  const PaginationControls({super.key, required this.meta, required this.onPageChange});

  @override
  Widget build(BuildContext context) {
    if (meta.lastPage <= 1) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: meta.currentPage > 1 ? () => onPageChange(meta.currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              'Page ${meta.currentPage} of ${meta.lastPage} · ${meta.total} total',
              style: TextStyle(color: muted, fontSize: 12),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: meta.hasMore ? () => onPageChange(meta.currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
