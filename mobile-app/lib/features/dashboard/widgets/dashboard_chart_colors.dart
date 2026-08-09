import 'package:flutter/material.dart';

/// Chart series colors for the dashboard, picked from a validated
/// categorical palette (checked for CVD-safe separation and contrast
/// against both the app's light and dark card surfaces — see the `dataviz`
/// color-formula: fixed hue order, never cycled/hardcoded per-chart).
///
/// These are deliberately separate from `AppColors` in `home_shell.dart`
/// (the foundation's success/warning/danger *status* palette) — chart
/// series encode identity (which metric a bar/line represents), not state,
/// so they stay out of the reserved status roles.
class DashboardChartColors {
  /// Categorical slot 1 (blue) — used for "inflow" style series: Stock In
  /// bars and the single-series Sales line.
  static Color slot1(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);

  /// Categorical slot 2 (orange) — used for the complementary "outflow"
  /// series: Stock Out bars.
  static Color slot2(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD95926) : const Color(0xFFEB6834);

  /// Categorical slot 3 (aqua/green) — used for the single-series Top
  /// Selling Products proportional bars, kept visually distinct from the
  /// blue/orange pair used above it on the same screen.
  static Color slot3(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF199E70) : const Color(0xFF1BAF7A);
}
