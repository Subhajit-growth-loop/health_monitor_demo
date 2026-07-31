import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../../core/widgets/neu_base_screen.dart';
import '../../../../core/widgets/neu_logo.dart';
import '../../../../core/widgets/neu_primary_button.dart';
import '../widgets/neu_maya_bubble.dart';

/// Shared shell for every guided onboarding step, matching the Maya design:
/// optional top-left back button, a full-width progress bar, the Maya coach
/// row with a "STEP x / N" (or "COMPLETE") marker, a peach prompt bubble, a
/// serif (Newsreader) heading, the step [body], and a single bottom CTA.
class NeuOnboardingShell extends StatelessWidget {
  const NeuOnboardingShell({
    super.key,
    required this.progress,
    required this.stepLabel,
    this.heading,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    this.mayaPrompt,
    this.showBack = false,
    this.onBack,
    this.ctaLoading = false,
    this.ctaEnabled = true,
    this.backgroundImage,
  });

  /// Optional background image asset (`.svg` or `.jpg`/`.png`) painted behind
  /// the whole step. See [NeuBaseScreen.backgroundImage].
  final String? backgroundImage;

  /// 0..1 progress-bar fill.
  final double progress;

  /// Right-hand marker, e.g. "STEP 2 / 10" or "COMPLETE".
  final String stepLabel;

  /// Optional serif heading; omitted (null) when the step shows none.
  final String? heading;
  final Widget body;
  final String ctaLabel;
  final VoidCallback? onCta;
  final String? mayaPrompt;
  final bool showBack;
  final VoidCallback? onBack;
  final bool ctaLoading;
  final bool ctaEnabled;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return NeuBaseScreen(
      backgroundColor: s.background,
      backgroundImage: backgroundImage,
      lightStatusIcons: s.isDark,
      // Let the dark CTA bar reach the physical bottom edge and tint the
      // Android system nav bar to match.
      bottomSafeArea: false,
      // Matches the CTA bar behind it, so the system nav area blends in.
      navigationBarColor: s.surface,
      child: Column(
        children: [
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18.w, 2.h, 0, 10.h),
                child: _BackButton(
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            )
          else
            SizedBox(height: 12.h),
          // Full-width progress bar.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: s.border,
                color: NeuColors.primary,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          _CoachRow(stepLabel: stepLabel),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mayaPrompt != null) ...[
                    NeuMayaBubble(mayaPrompt!),
                    SizedBox(height: 18.h),
                  ],
                  if (heading != null) ...[
                    Text(
                      heading!,
                      style: NeuTypography.serif(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: s.onSurface,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 10.h),
                  ],
                  body,
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            // White in light mode, as in the original design (4079093): it lifts
            // the CTA bar off the warm off-white page background.
            color: s.surface,
            padding: EdgeInsets.fromLTRB(
              18.w,
              10.h,
              18.w,
              // Own bottom padding since bottomSafeArea is off, so the fill
              // extends through the home-indicator inset.
              16.h + MediaQuery.of(context).padding.bottom,
            ),
            child: NeuPrimaryButton(
              label: ctaLabel,
              onPressed: ctaEnabled ? onCta : null,
              isLoading: ctaLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachRow extends StatelessWidget {
  const _CoachRow({required this.stepLabel});
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Row(
        children: [
          NeuLogo(
            size: 38.r,
            color: NeuColors.primary,
            asset: 'assets/icons/logo_primary.png',
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maya',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface,
                  ),
                ),
                Text(
                  'Your health coach',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: s.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            stepLabel,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: s.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42.w,
        height: 34.h,
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(11.r),
          border: Border.all(color: s.border),
        ),
        child: Icon(
          Icons.chevron_left_rounded,
          color: s.onSurface,
          size: 22,
        ),
      ),
    );
  }
}
