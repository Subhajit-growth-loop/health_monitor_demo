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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: NeuColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.5.sp,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: NeuColors.primaryDark,
        ),
      ),
    );
  }
}
