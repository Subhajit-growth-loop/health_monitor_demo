import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/neu_colors.dart';
import '../../domain/entities/onboarding_results.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import 'onboarding_base_screen.dart';

// ── Completion screen ─────────────────────────────────────────────────────────

class OnboardingCompleteScreen extends ConsumerWidget {
  const OnboardingCompleteScreen({super.key, required this.result});

  final CompletionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = NeuSurface.of(context);
    return NeuOnboardingShell(
      progress: 1,
      stepLabel: 'COMPLETE',
      heading: 'Welcome to Neu, ${result.userName}',
      ctaLabel: 'Go to my dashboard',
      onCta: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "I'm so glad you're here. Everything from now on is built around "
            'your body — not a generic plan. This week I\'ll be quietly '
            'watching how your glucose, movement and sleep move together. '
            "There's nothing to get perfect. Just live your days, and let the "
            'data tell your story.',
            style: TextStyle(
              fontSize: 15.sp,
              height: 1.5,
              color: s.onSurface.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: s.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT HAPPENS NEXT',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: s.emphasis,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 16.h),
                for (var i = 0; i < result.whatHappensNext.length; i++) ...[
                  if (i > 0) SizedBox(height: 16.h),
                  _NextRow(index: i + 1, text: result.whatHappensNext[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28.r,
          height: 28.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NeuColors.primary.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: NeuColors.primary,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15.sp,
                height: 1.4,
                color: s.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
