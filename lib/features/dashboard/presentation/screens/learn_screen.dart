import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';

// ── Learn Screen ──────────────────────────────────────────────────────────────

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle =
        isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learn',
              style: NeuTypography.serif(fontSize: 24.sp, color: fg),
            ),
            SizedBox(height: 40.h),
            Center(
              child: Text(
                'Articles and insights coming soon.',
                style: TextStyle(color: subtle, fontSize: 14.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
