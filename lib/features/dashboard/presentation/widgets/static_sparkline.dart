import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/neu_colors.dart';
import '../../domain/entities/health_metric_type.dart';

enum _SparklineStyle { wavyLine, barChart, ecgLine, greenLine, sleepBars }

/// A purely decorative static sparkline. Values shown in the parent card are
/// real (from HealthKit); this chart shape is a fixed visual placeholder.
class StaticSparkline extends StatelessWidget {
  const StaticSparkline({
    super.key,
    required this.type,
    this.height,
  });

  final HealthMetricType type;
  final double? height;

  _SparklineStyle get _style => switch (type) {
        HealthMetricType.steps ||
        HealthMetricType.activeEnergy ||
        HealthMetricType.basalEnergy ||
        HealthMetricType.totalCalories ||
        HealthMetricType.flightsClimbed =>
          _SparklineStyle.barChart,
        HealthMetricType.heartRate ||
        HealthMetricType.restingHeartRate ||
        HealthMetricType.heartRateVariability ||
        HealthMetricType.bloodPressureSystolic ||
        HealthMetricType.bloodPressureDiastolic =>
          _SparklineStyle.ecgLine,
        HealthMetricType.weight ||
        HealthMetricType.height ||
        HealthMetricType.bodyFat ||
        HealthMetricType.leanBodyMass =>
          _SparklineStyle.greenLine,
        HealthMetricType.sleep ||
        HealthMetricType.sleepDeep ||
        HealthMetricType.sleepLight ||
        HealthMetricType.sleepRem ||
        HealthMetricType.sleepAwake =>
          _SparklineStyle.sleepBars,
        _ => _SparklineStyle.wavyLine,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height ?? 54.h,
      child: CustomPaint(
        painter: _SparklinePainter(style: _style),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.style});
  final _SparklineStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case _SparklineStyle.wavyLine:
        _drawWavyLine(canvas, size, NeuColors.primary);
      case _SparklineStyle.barChart:
        _drawBarChart(canvas, size);
      case _SparklineStyle.ecgLine:
        _drawEcgLine(canvas, size);
      case _SparklineStyle.greenLine:
        _drawWavyLine(canvas, size, const Color(0xFF4A7C59));
      case _SparklineStyle.sleepBars:
        _drawSleepBars(canvas, size);
    }
  }

  void _drawWavyLine(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Relative Y positions (0 = top, 1 = bottom) for a gentle wave
    const yRatios = [0.70, 0.40, 0.60, 0.25, 0.55, 0.30, 0.50];
    final pts = List.generate(
      yRatios.length,
      (i) => Offset(i * size.width / (yRatios.length - 1), yRatios[i] * size.height),
    );

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final midX = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(midX, pts[i].dy, midX, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawBarChart(Canvas canvas, Size size) {
    const hRatios = [0.30, 0.45, 0.35, 0.55, 0.65, 0.50, 0.70];
    final barW = size.width / hRatios.length * 0.60;
    final step = size.width / hRatios.length;
    final gap = step * 0.20;

    for (var i = 0; i < hRatios.length; i++) {
      final barH = hRatios[i] * size.height;
      final opacity = 0.45 + 0.55 * (i / (hRatios.length - 1));
      final paint = Paint()
        ..color = NeuColors.primary.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * step + gap, size.height - barH, barW, barH),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  void _drawEcgLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NeuColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final mid = size.height * 0.55;
    final spike = size.height * 0.75;

    final path = Path()
      ..moveTo(0, mid)
      ..lineTo(w * 0.20, mid)
      ..lineTo(w * 0.25, mid - size.height * 0.12)
      ..lineTo(w * 0.30, mid)
      ..lineTo(w * 0.36, mid)
      ..lineTo(w * 0.42, mid - spike)
      ..lineTo(w * 0.47, mid + size.height * 0.22)
      ..lineTo(w * 0.52, mid)
      ..lineTo(w * 0.58, mid)
      ..lineTo(w * 0.63, mid - size.height * 0.09)
      ..lineTo(w * 0.68, mid)
      ..lineTo(w, mid);

    canvas.drawPath(path, paint);
  }

  void _drawSleepBars(Canvas canvas, Size size) {
    const hRatios = [0.60, 0.28, 0.65, 0.80, 0.68, 0.85, 0.74];
    const salmon = Color(0xFFD57D5A);
    const green = Color(0xFF4A7C59);

    final barW = size.width / hRatios.length * 0.62;
    final step = size.width / hRatios.length;
    final gap = step * 0.19;

    for (var i = 0; i < hRatios.length; i++) {
      final barH = hRatios[i] * size.height;
      final color = i.isOdd ? salmon.withValues(alpha: 0.65) : green;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * step + gap, size.height - barH, barW, barH),
          const Radius.circular(3),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.style != style;
}
