import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../models/dashboard.dart';
import '../../../shared/widgets/empty_state.dart';
import 'chart_axis.dart';
import 'dashboard_chart_colors.dart';

/// Single-series line chart of daily sales totals. A single series names
/// itself via the section title ("Sales Overview"), so per the dataviz
/// legend rule it doesn't need its own legend box.
class SalesOverviewChart extends StatelessWidget {
  final List<SalesPoint> points;

  const SalesOverviewChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppEmptyState(
        title: 'No sales in this period yet.',
        icon: Icons.show_chart_outlined,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final lineColor = DashboardChartColors.slot1(context);
    final labelInterval = chartLabelInterval(points.length);

    var maxTotal = 0.0;
    for (final p in points) {
      if (p.total > maxTotal) maxTotal = p.total;
    }
    final maxY = maxTotal <= 0 ? 100.0 : maxTotal * 1.2;

    return SizedBox(
      width: double.infinity,
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  chartCompactCurrency(value),
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
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => spots.map((spot) {
                final index = spot.x.round().clamp(0, points.length - 1);
                return LineTooltipItem(
                  '${chartShortDate(points[index].date)}\n${formatCurrency(spot.y)}',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].total)],
              isCurved: true,
              curveSmoothness: 0.25,
              color: lineColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: points.length <= 31),
              belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
