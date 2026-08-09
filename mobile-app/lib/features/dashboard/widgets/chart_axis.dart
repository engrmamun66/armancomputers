import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Small, chart-only formatting/sizing helpers shared by the bar and line
/// charts. Kept separate from `core/format.dart` because these are axis
/// chrome concerns (short labels, compact ticks, dynamic bar sizing) rather
/// than the app-wide display formatting the foundation already provides.
final _shortDateFmt = DateFormat('dd MMM');

/// Formats an ISO 'yyyy-MM-dd' date string as a short axis label ('09 Aug').
/// Falls back to the raw string if it isn't parseable.
String chartShortDate(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  return _shortDateFmt.format(date);
}

/// Picks a label interval (in x-axis index units) so that at most
/// [maxLabels] bottom titles are ever drawn — avoids overlapping text when
/// a range has many days (e.g. "This Year" can return up to ~366 points,
/// and a wide custom range can return even more).
double chartLabelInterval(int pointCount, {int maxLabels = 6}) {
  if (pointCount <= maxLabels) return 1;
  return (pointCount / maxLabels).ceilToDouble();
}

/// A bar's pixel width that shrinks as the number of groups grows, so that
/// many daily bars never visually overlap their neighboring group — fl_chart
/// spaces groups evenly across the given width but does not auto-shrink rod
/// width for you.
double chartBarWidth(int groupCount, double availableWidth) {
  if (groupCount <= 0 || availableWidth <= 0) return 12;
  final perGroup = availableWidth / groupCount;
  return math.max(1.2, math.min(14, perGroup * 0.28));
}

/// Space between bar groups, scaled the same way as [chartBarWidth].
double chartGroupsSpace(int groupCount, double availableWidth) {
  if (groupCount <= 0 || availableWidth <= 0) return 8;
  final perGroup = availableWidth / groupCount;
  return math.max(0.5, math.min(16, perGroup * 0.24));
}

/// Compact Y-axis tick formatter for currency magnitudes ('৳1.2k'). The
/// foundation's `formatCurrency` (e.g. '৳12,345.00') is too wide to use as a
/// repeating axis tick, so this is a chart-local, shorter variant.
String chartCompactCurrency(num value) {
  final abs = value.abs();
  if (abs >= 1000000) return '৳${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '৳${(value / 1000).toStringAsFixed(1)}k';
  return '৳${value.toStringAsFixed(0)}';
}
