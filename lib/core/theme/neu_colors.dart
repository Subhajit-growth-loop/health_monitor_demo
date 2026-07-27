import 'package:flutter/material.dart';

/// Neu brand palette. The six brand swatches come straight from the design
/// system; the remaining tokens are harmonized derivatives.
abstract final class NeuColors {
  // ── Brand swatches ──────────────────────────────────────────────────────────
  /// #F9F4F0 — app background (warm off-white).
  static const Color screenBackground = Color(0xFFF9F4F0);

  /// #F7EDD9 — pale accent (pill badges, chat hint bubble).
  static const Color accentYellow = Color(0xFFF7EDD9);

  /// #D87F5C — primary orange (CTAs, selection).
  static const Color primary = Color(0xFFD87F5C);

  /// #3D302B — primary text (near-black warm brown).
  static const Color textDark = Color(0xFF3D302B);

  /// #6D5319 — olive/gold accent (section eyebrows, badge text).
  static const Color olive = Color(0xFF6D5319);

  /// #8A756C — secondary/muted text.
  static const Color textSecondary = Color(0xFF8A756C);

  // ── Derived tokens ────────────────────────────────────────────────────────────
  /// Pressed / emphasis shade of [primary].
  static const Color primaryDark = Color(0xFFC06A48);

  /// Full-bleed splash background.
  static const Color splashBackground = Color(0xFFD87F5C);

  /// Dark surface for the intro feature carousel.
  static const Color featureBackground = Color(0xFF2A211C);

  /// Lighter muted text (placeholders, disabled).
  static const Color textMuted = Color(0xFFA89A90);

  static const Color success = Color(0xFF2E7D32);

  /// Input fill + border, tuned to the cream background.
  static const Color inputFill = Color(0xFFFDFAF6);
  static const Color inputBorder = Color(0xFFE7DBCE);
}
