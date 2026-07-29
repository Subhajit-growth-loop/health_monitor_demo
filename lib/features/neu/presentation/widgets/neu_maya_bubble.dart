import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';

/// The peach chat bubble carrying Maya's prompt at the top of each onboarding
/// step.
class NeuMayaBubble extends StatelessWidget {
  const NeuMayaBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Dark surface box with an orange left-border strip.
    return Container(
      decoration: BoxDecoration(
        color: NeuColors.darkCard,
        borderRadius: BorderRadius.all(
          Radius.circular(16.r),
        ),
        border: Border(
          left: BorderSide(
            color: NeuColors.primary, // or whatever color you want
            width: 4.w,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 14.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.5.sp,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: NeuColors.primary,
        ),
      ),
    );
  }
}
