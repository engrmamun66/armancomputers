import 'package:flutter/material.dart';

/// Semantic status colors that are NOT part of ColorScheme, with light/dark
/// variants picked for contrast against each theme's card surface (mirrors
/// the web app's rose/amber/emerald badge palette).
class AppColors {
  static Color success(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF059669);

  static Color successBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);

  static Color danger(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);

  static Color dangerBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6);

  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

  static Color warningBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);

  static Color neutralBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
}

class AppTheme {
  static const _radius = 12.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF262626),
      brightness: Brightness.light,
    ).copyWith(primary: const Color(0xFF262626), onPrimary: Colors.white, surface: Colors.white);

    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF262626),
      brightness: Brightness.dark,
    ).copyWith(primary: Colors.white, onPrimary: const Color(0xFF262626));

    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      cardColor: scheme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: scheme.brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        labelStyle: TextStyle(color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 2,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
