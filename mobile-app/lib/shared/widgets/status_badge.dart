import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Mirrors resources/js/components/common/StatusBadge.vue's slug->color map.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final slug = status.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    final label = status
        .split(RegExp(r'[\s-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');

    Color bg;
    Color fg;
    switch (slug) {
      case 'active':
      case 'paid':
      case 'completed':
        bg = AppColors.successBg(context);
        fg = AppColors.success(context);
        break;
      case 'partial':
      case 'low-stock':
      case 'pending':
        bg = AppColors.warningBg(context);
        fg = AppColors.warning(context);
        break;
      case 'due':
      case 'out-of-stock':
        bg = AppColors.dangerBg(context);
        fg = AppColors.danger(context);
        break;
      default:
        bg = AppColors.neutralBg(context);
        fg = AppColors.muted(context);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
