import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'neu_colors.dart';

/// Neu brand typography.
///
/// Primary (serif) = **Newsreader** — used for editorial headings.
/// Secondary (sans) = **Hanken Grotesk** — used for body copy and UI chrome.
///
/// Both are fetched via `google_fonts`. Body text does not need to call these
/// helpers directly: [NeuBaseScreen] installs Hanken Grotesk as the ambient
/// `DefaultTextStyle`, so any `Text` without an explicit `fontFamily` inherits
/// it. Reach for [serif] whenever a heading should render in Newsreader.
abstract final class NeuTypography {
  /// Newsreader serif — headings / display.
  static TextStyle serif({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color color = NeuColors.textDark,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.newsreader(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// Hanken Grotesk sans — body / UI.
  static TextStyle sans({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color color = NeuColors.textDark,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.hankenGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// The ambient sans base installed by [NeuBaseScreen].
  static TextStyle get baseSans =>
      GoogleFonts.hankenGrotesk(color: NeuColors.textDark);
}
