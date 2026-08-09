import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/dashboard.dart';
import '../../../shared/widgets/empty_state.dart';
import 'chart_axis.dart';
import 'chart_legend.dart';
import 'dashboard_chart_colors.dart';

/// Grouped bar chart: Stock In qty vs Stock Out qty per day.
///
/// Sized with a [LayoutBuilder] so bar width / group spacing shrink as the
/// number of days grows (e.g. "This Year" can return ~366 daily points) —
/// this keeps every group inside the given width so the chart never needs
/// (and never gets) horizontal scrolling, per the hard no-horizontal-scroll
/// requirement.
class StockMovementChart extends StatelessWidget {
  final List<StockMovementPoint> points;

  const StockMovementChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppEmptyState(
        title: 'No stock movement in this period.',
        icon: Icons.bar_chart_outlined,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final stockInColor = DashboardChartColors.slot1(context);
    final stockOutColor = DashboardChartColors.slot2(context);
    final labelInterval = chartLabelInterval(points.length);

    double maxQty = 0;
    for (final p in points) {
      maxQty = [maxQty, p.stockInQty.toDouble(), p.stockOutQty.toDouble()].reduce((a, b) => a > b ? a : b);
    }
    final maxY = maxQty <= 0 ? 4.0 : maxQty * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartLegend(items: [
          ChartLegendItem(color: stockInColor, label: 'Stock In'),
          ChartLegendItem(color: stockOutColor, label: 'Stock Out'),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 240,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = chartBarWidth(points.length, constraints.maxWidth);
              final groupsSpace = chartGroupsSpace(points.length, constraints.maxWidth);

              return BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceEvenly,
                  groupsSpace: groupsSpace,
                  gridData: FlGridData(
                    horizontalInterval: (maxY / 4).clamp(1, double.infinity),
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: labelInterval,
                        getTitlesWidget: (value, meta) {
                          final index = value.round().clamp(0, points.length - 1);
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              chartShortDate(points[index].date),
                              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final point = points[group.x.toInt()];
                        final label = rodIndex == 0 ? 'Stock In' : 'Stock Out';
                        return BarTooltipItem(
                          '${chartShortDate(point.date)}\n$label: ${rod.toY.toInt()}',
                          TextStyle(color: scheme.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: barWidth * 0.4,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].stockInQty.toDouble(),
                            color: stockInColor,
                            width: barWidth,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(barWidth < 3 ? 0 : 2)),
                          ),
                          BarChartRodData(
                            toY: points[i].stockOutQty.toDouble(),
                            color: stockOutColor,
                            width: barWidth,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(barWidth < 3 ? 0 : 2)),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
