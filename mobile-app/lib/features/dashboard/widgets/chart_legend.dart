import 'package:flutter/material.dart';

/// One entry in a [ChartLegend]: a colored swatch + its series label.
class ChartLegendItem {
  final Color color;
  final String label;

  const ChartLegendItem({required this.color, required this.label});
}

/// A small wrapping legend row used above multi-series charts, per the
/// dataviz rule that identity is never color-alone: every series with 2+
/// entries gets a legend that pairs the swatch with a text label.
///
/// Uses [Wrap] (not a [Row]) so it degrades to a second line instead of
/// overflowing horizontally on narrow phone widths.
class ChartLegend extends StatelessWidget {
  final List<ChartLegendItem> items;

  const ChartLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(item.label, style: textStyle),
            ],
          ),
      ],
    );
  }
}
