import 'package:flutter/material.dart';

class AppThemes {
  static const List<Color> accentSeeds = [
    Color(0xFF5E35B1),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFF00ACC1),
    Color(0xFF6D4C41),
    Color(0xFFF6BF26),
    Color(0xFF3949AB),
    Color(0xFFE53935),
    Color(0xFFB4652F),
    Color(0xFF8C6A3F),
  ];

  /// Couleur des nouvelles installations : le cuivre de l'atelier.
  static const int defaultAccent = 10;

  static const List<String> accentNames = [
    'Violet',
    'Turquoise',
    'Ambre',
    'Rose',
    'Vert',
    'Cyan',
    'Brun',
    'Or',
    'Indigo',
    'Rouge',
    'Cuivre',
    'Bronze',
  ];

  static ThemeData light(Color seed) => _build(Brightness.light, seed);

  static ThemeData dark(Color seed) => _build(Brightness.dark, seed);

  static ThemeData _build(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .englishLike
          .apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          )
          .copyWith(
            titleLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
            titleMedium: const TextStyle(fontWeight: FontWeight.w700),
          ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: brightness == Brightness.light
            ? scheme.surface
            : scheme.surfaceContainerLow,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        color: brightness == Brightness.light ? scheme.surface : scheme.surfaceContainerLow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }
}