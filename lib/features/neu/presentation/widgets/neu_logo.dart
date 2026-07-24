import 'package:flutter/material.dart';

/// Placeholder logo widget. Replace the [_NeuLogoPainter] with an SvgPicture
/// (or Image.asset) once the final asset is ready — the widget API stays the same.
class NeuLogo extends StatelessWidget {
  const NeuLogo({super.key, this.size = 80.0, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
      ..cubicTo(cx + lw, cy - lh * 0.5, cx + lw, cy + lh * 0.15, cx, cy + lh * 0.28)
      ..cubicTo(cx - lw, cy + lh * 0.15, cx - lw, cy - lh * 0.5, cx, cy - lh)
      ..close();
    canvas.drawPath(leaf, fillPaint);

    // Left wing petal
    final leftPetal = Path()
      ..moveTo(cx, cy + lh * 0.08)
      ..cubicTo(cx - lw * 2.1, cy - lh * 0.15, cx - lw * 2.1, cy + lh * 0.85, cx, cy + lh * 0.55)
      ..cubicTo(cx - lw * 0.45, cy + lh * 0.48, cx - lw * 0.28, cy + lh * 0.28, cx, cy + lh * 0.08)
      ..close();
    canvas.drawPath(leftPetal, fillPaint);

    // Right wing petal (mirrored)
    final rightPetal = Path()
      ..moveTo(cx, cy + lh * 0.08)
      ..cubicTo(cx + lw * 2.1, cy - lh * 0.15, cx + lw * 2.1, cy + lh * 0.85, cx, cy + lh * 0.55)
      ..cubicTo(cx + lw * 0.45, cy + lh * 0.48, cx + lw * 0.28, cy + lh * 0.28, cx, cy + lh * 0.08)
      ..close();
    canvas.drawPath(rightPetal, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _NeuLogoPainter old) => old.color != color;
}
