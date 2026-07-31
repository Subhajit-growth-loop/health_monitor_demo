import 'package:flutter/material.dart';

/// Neu brand palette sourced from the official design system swatches.
abstract final class NeuColors {
  // ── Light screen tokens ──────────────────────────────────────────────────────
  /// #F9F4F0 — app background (warm off-white).
  static const Color screenBackground = Color(0xFFF9F4F0);

  /// #F7EDD9 — pale yellow accent (feature carousel badge).
  static const Color accentYellow = Color(0xFFF7EDD9);

  /// #EEE5DB — warm beige fill: Maya bubble, segmented control track, tinted panels.
  static const Color warmFill = Color(0xFFEEE5DB);

  /// #F18B5C — lighter orange (secondary accent, unselected warm tones).
  static const Color lightOrange = Color(0xFFF18B5C);

  /// #D57D5A — primary orange (CTAs, selection).
  static const Color primary = Color(0xFFD57D5A);

  /// #3C332F — primary text (near-black warm brown).
  static const Color textDark = Color(0xFF3C332F);

  /// #473C36 — olive/mid-brown (section eyebrows, badge text).
  static const Color olive = Color(0xFF473C36);

  /// #83746C — secondary / muted text.
  static const Color textSecondary = Color(0xFF83746C);

  // ── Derived tokens ────────────────────────────────────────────────────────────
  /// #D86E44 — pressed / emphasis shade of [primary].
  static const Color primaryDark = Color(0xFFD86E44);

  /// Full-bleed splash background.
  static const Color splashBackground = Color(0xFFD57D5A);

  /// Dark surface for the intro feature carousel.
  static const Color featureBackground = Color(0xFF27221F);

  /// #AA8E7F — lighter muted text (placeholders, disabled).
  static const Color textMuted = Color(0xFFAA8E7F);

  static const Color success = Color(0xFF2E7D32);

  /// Input fill: white so fields stand out against the cream background.
  static const Color inputFill = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFE6DED5);

  // ── Dark-screen tokens (auth + onboarding + dark dashboard) ─────────────────
  /// #1E1B19 — primary background for all dark screens.
  static const Color darkBackground = Color(0xFF1E1B19);

  /// #27221F — subtle elevated surface (nav bar, bottom sheets).
  static const Color darkSurface = Color(0xFF27221F);

  /// #342C28 — card / tile / input fill on dark screens.
  static const Color darkCard = Color(0xFF342C28);

  /// #473C36 — border / divider on dark screens.
  static const Color darkBorder = Color(0xFF473C36);

  /// #83746C — muted / secondary text on dark screens.
  static const Color darkTextMuted = Color(0xFF83746C);
}

/// The four surface colours the Neu auth + onboarding screens need, resolved for
/// the active theme.
///
/// Those screens were written against the dark tokens directly, so they stayed
/// dark in light mode. Reading them through [NeuSurface.of] makes a screen follow
/// the theme with a one-line change at the top of `build`, and the pairs match
/// what dashboard_screen.dart already does by hand for each `isDark` branch.
class NeuSurface {
  const NeuSurface({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textMuted,
    required this.onSurface,
    required this.accent,
    required this.emphasis,
    required this.isDark,
  });

  /// Screen background.
  final Color background;

  /// Slightly elevated background (nav bars, sheets).
  final Color surface;

  /// Cards, tiles, input fills.
  final Color card;

  /// Borders and dividers.
  final Color border;

  /// Secondary / muted text.
  final Color textMuted;

  /// Primary text and icons sitting on [background] or [card].
  final Color onSurface;

  /// Tinted callout fill — info messages, "what happens next" panels.
  final Color accent;

  /// Content colour on [accent], and for eyebrow labels.
  final Color emphasis;

  final bool isDark;

  /// Light values are the ones these screens shipped with before they were
  /// converted to dark (commit 4079093), so this restores the original design
  /// rather than approximating it.
  static const light = NeuSurface(
    background: NeuColors.screenBackground,
    surface: Colors.white,
    card: Colors.white,
    border: NeuColors.inputBorder,
    textMuted: NeuColors.textSecondary,
    onSurface: NeuColors.textDark,
    accent: NeuColors.warmFill,
    emphasis: NeuColors.olive,
    isDark: false,
  );

  static const dark = NeuSurface(
    background: NeuColors.darkBackground,
    surface: NeuColors.darkSurface,
    card: NeuColors.darkCard,
    border: NeuColors.darkBorder,
    textMuted: NeuColors.darkTextMuted,
    onSurface: Colors.white,
    // The dark pass collapsed the accent fill into the card colour and used
    // primary where light used olive.
    accent: NeuColors.darkCard,
    emphasis: NeuColors.primary,
    isDark: true,
  );

  static NeuSurface of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
