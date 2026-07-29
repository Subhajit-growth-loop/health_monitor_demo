import 'package:flutter/material.dart';

/// Neu brand palette sourced from the official design system swatches.
abstract final class NeuColors {
  // ── Light screen tokens ──────────────────────────────────────────────────────
  /// #F9F4F0 — app background (warm off-white).
  static const Color screenBackground = Color(0xFFF9F4F0);

  /// #F7EDD9 — pale accent (pill badges, chat hint bubble).
  static const Color accentYellow = Color(0xFFF7EDD9);

  /// #D57D5A — primary orange (CTAs, selection).
  static const Color primary = Color(0xFFD57D5A);

  /// #342C28 — primary text (near-black warm brown).
  static const Color textDark = Color(0xFF342C28);

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

  /// Input fill + border, tuned to the cream background.
  static const Color inputFill = Color(0xFFF9F4F0);
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
