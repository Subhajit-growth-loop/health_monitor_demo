import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Set this once to your brand logo asset (e.g. `'assets/images/neu_logo.svg'`
/// or `'.../neu_logo.png'`) and every [NeuLogo] that doesn't pass its own
/// [NeuLogo.asset] will use it. Leave `null` to keep the painted placeholder.
// Nullable by design: set to null to fall back to the painted placeholder.
// The brand asset is a monochrome silhouette (transparent PNG), so it is tinted
// with [NeuLogo.color] — see [NeuLogo.tint], which defaults to true.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? kNeuLogoAsset = 'assets/icons/logo_primary.png';

/// Brand logo. Renders, in order of preference:
/// 1. an explicit [asset] (SVG via flutter_svg, or PNG/JPG via [Image.asset]),
/// 2. the global [kNeuLogoAsset],
/// 3. the built-in painted placeholder ([_NeuLogoPainter]).
///
/// Set [tint] to recolor a monochrome asset with [color] (e.g. white on the
/// splash). The placeholder is always drawn in [color].
class NeuLogo extends StatelessWidget {
  const NeuLogo({
    super.key,
    this.size = 80.0,
    this.color = Colors.white,
    this.asset,
    this.tint = true,
  });

  final double size;
  final Color color;

  /// Overrides [kNeuLogoAsset] for this instance.
  final String? asset;

  /// When true (default), the asset is recolored with [color] using its alpha —
  /// correct for the monochrome brand silhouette. Set false for a full-color
  /// logo you want to keep as-is.
  final bool tint;

  @override
  Widget build(BuildContext context) {
    final path = asset ?? kNeuLogoAsset;

    if (path != null) {
      if (path.toLowerCase().endsWith('.svg')) {
        return SvgPicture.asset(
          path,
          width: size,
          height: size,
          colorFilter:
              tint ? ColorFilter.mode(color, BlendMode.srcIn) : null,
        );
      }
      return Image.asset(
        path,
        width: size,
        height: size,
        color: tint ? color : null,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NeuLogoPainter(color: color)),
    );
  }
}

class _NeuLogoPainter extends CustomPainter {
  _NeuLogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final sw = size.width * 0.055;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), r - sw / 2, strokePaint);

    // Central teardrop leaf
    final lh = r * 0.52;
    final lw = r * 0.26;
    final leaf = Path()
      ..moveTo(cx, cy - lh)
      ..cubicTo(
        cx + lw,
        cy - lh * 0.5,
        cx + lw,
        cy + lh * 0.15,
        cx,
        cy + lh * 0.28,
      )
      ..cubicTo(cx - lw, cy + lh * 0.15, cx - lw, cy - lh * 0.5, cx, cy - lh)
      ..close();
    canvas.drawPath(leaf, fillPaint);

    // Left wing petal
    final leftPetal = Path()
      ..moveTo(cx, cy + lh * 0.08)
      ..cubicTo(
        cx - lw * 2.1,
        cy - lh * 0.15,
        cx - lw * 2.1,
        cy + lh * 0.85,
        cx,
        cy + lh * 0.55,
      )
      ..cubicTo(
        cx - lw * 0.45,
        cy + lh * 0.48,
        cx - lw * 0.28,
        cy + lh * 0.28,
        cx,
        cy + lh * 0.08,
      )
      ..close();
    canvas.drawPath(leftPetal, fillPaint);

    // Right wing petal (mirrored)
    final rightPetal = Path()
      ..moveTo(cx, cy + lh * 0.08)
      ..cubicTo(
        cx + lw * 2.1,
        cy - lh * 0.15,
        cx + lw * 2.1,
        cy + lh * 0.85,
        cx,
        cy + lh * 0.55,
      )
      ..cubicTo(
        cx + lw * 0.45,
        cy + lh * 0.48,
        cx + lw * 0.28,
        cy + lh * 0.28,
        cx,
        cy + lh * 0.08,
      )
      ..close();
    canvas.drawPath(rightPetal, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _NeuLogoPainter old) => old.color != color;
}
