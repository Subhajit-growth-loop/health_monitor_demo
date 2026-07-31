import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/neu_colors.dart';

/// One wellbeing slider row: leading icon + question (+help), a trailing emoji
/// chip, the slider, and left/right end labels.
class NeuSliderRow extends StatelessWidget {
  const NeuSliderRow({
    super.key,
    required this.icon,
    required this.question,
    required this.emoji,
    required this.value,
    required this.onChanged,
    required this.minLabel,
    required this.maxLabel,
  });

  final IconData icon;
  final String question;
  final String emoji;
  final double value;
  final ValueChanged<double> onChanged;
  final String minLabel;
  final String maxLabel;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: NeuColors.primary),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                question,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface,
                ),
              ),
            ),
            Container(
              width: 46.w,
              height: 36.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.card,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(20.r)),
                border: Border.all(color: s.border),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: NeuColors.primary,
            inactiveTrackColor: s.border,
            thumbColor: Colors.white,
            overlayColor: NeuColors.primary.withValues(alpha: 0.12),
            thumbShape: const _NeuThumbShape(radius: 11, ringWidth: 2.5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          // Constrain the slider's tall default tap target so it sits closer to
          // the question row (the track is vertically centred in this height).
          child: SizedBox(
            height: 28.h,
            child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: s.textMuted,
                ),
              ),
              Text(
                maxLabel,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: s.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// White slider thumb with a primary-colored ring (and a soft shadow), matching
/// the brand's radio/selection styling.
class _NeuThumbShape extends SliderComponentShape {
  const _NeuThumbShape({this.radius = 11, this.ringWidth = 2.5});

  final double radius;
  final double ringWidth;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Soft drop shadow.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // White fill.
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    // Primary ring on top of the thumb.
    canvas.drawCircle(
      center,
      radius - ringWidth / 2,
      Paint()
        ..color = NeuColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth,
    );
  }
}
