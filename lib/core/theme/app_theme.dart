import 'package:flutter/material.dart';

import 'neu_colors.dart';

/// Central theme for the Neu Health app. Light + dark, Material 3.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: NeuColors.primary,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? NeuColors.darkBackground : NeuColors.screenBackground,
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? NeuColors.darkBackground : NeuColors.screenBackground,
        foregroundColor: isDark ? Colors.white : NeuColors.textDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? NeuColors.darkCard
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
