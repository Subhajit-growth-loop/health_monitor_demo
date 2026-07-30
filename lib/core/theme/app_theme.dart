import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'neu_colors.dart';

/// Central theme for the Neu Health app. Light + dark, Material 3.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  /// Status-bar / navigation-bar styling that follows the active theme:
  /// black status-bar text on light, white on dark.
  ///
  /// The two brightness fields mean opposite things by platform — on Android
  /// [SystemUiOverlayStyle.statusBarIconBrightness] describes the *icons*, while
  /// on iOS [SystemUiOverlayStyle.statusBarBrightness] describes the *background*
  /// behind them. They are therefore always set to opposite values.
  static SystemUiOverlayStyle overlayStyle(bool isDark) => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Android: icons/text.
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    // iOS: the background the icons sit on.
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor:
        isDark ? NeuColors.darkBackground : NeuColors.screenBackground,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  );

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
        // An AppBar overrides the ambient overlay style, so it needs its own.
        systemOverlayStyle: overlayStyle(isDark),
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
