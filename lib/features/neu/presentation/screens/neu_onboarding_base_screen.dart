import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../widgets/neu_base_screen.dart';
import '../widgets/neu_image_placeholder.dart';
import '../widgets/neu_primary_button.dart';

/// Base shell for all step-guided onboarding screens (Maya-led intake).
///
/// Each onboarding step widget should wrap its content inside this shell,
/// passing [stepIndex], [totalSteps], [title], [body], and [onNext].
/// The header, progress bar, and navigation buttons are handled here.
class NeuOnboardingBaseScreen extends StatefulWidget {
  const NeuOnboardingBaseScreen({
    super.key,
    this.stepIndex = 0,
    this.totalSteps = 12,
    this.title = 'Verify your information',
    this.nextLabel = 'Validate & continue',
    this.onNext,
    this.onBack,
    this.child,
  });

  final int stepIndex;
  final int totalSteps;
  final String title;
  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final Widget? child;

  @override
  State<NeuOnboardingBaseScreen> createState() =>
      _NeuOnboardingBaseScreenState();
}

class _NeuOnboardingBaseScreenState extends State<NeuOnboardingBaseScreen> {
  @override
  Widget build(BuildContext context) {
    final progress =
        (widget.stepIndex + 1) / widget.totalSteps;

    return NeuBaseScreen(
      backgroundColor: NeuColors.screenBackground,
      child: Column(
        children: [
          _Header(stepIndex: widget.stepIndex, totalSteps: widget.totalSteps),
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: NeuColors.inputBorder,
            color: NeuColors.primary,
            minHeight: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: NeuColors.textDark,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  widget.child ?? _PlaceholderContent(),
                ],
              ),
            ),
          ),
          _BottomNav(
            stepIndex: widget.stepIndex,
            nextLabel: widget.nextLabel,
            onNext: widget.onNext ?? _defaultNext,
            onBack: widget.onBack,
          ),
        ],
      ),
    );
  }

  void _defaultNext() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Onboarding steps coming soon!')),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.stepIndex, required this.totalSteps});

  final int stepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      child: Row(
        children: [
          NeuImagePlaceholder(
            width: 40.r,
            height: 40.r,
            icon: Icons.person_rounded,
            backgroundColor: NeuColors.primary.withValues(alpha: 0.12),
            iconColor: NeuColors.primary,
            borderRadius: BorderRadius.circular(20.r),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maya',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.textDark,
                  ),
                ),
                Text(
                  'Your health coach',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: NeuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: NeuColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'STEP ${stepIndex + 1} / $totalSteps',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: NeuColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.stepIndex,
    required this.nextLabel,
    required this.onNext,
    this.onBack,
  });

  final int stepIndex;
  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: NeuColors.screenBackground,
        border: Border(
          top: BorderSide(color: NeuColors.inputBorder, width: 1),
        ),
      ),
      child: stepIndex == 0
          ? NeuPrimaryButton(label: nextLabel, onPressed: onNext)
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NeuColors.textDark,
                      side: const BorderSide(color: NeuColors.inputBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onNext,
                    icon: const Text('Next'),
                    label: const Icon(Icons.arrow_forward_rounded, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NeuColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Placeholder content ───────────────────────────────────────────────────────

class _PlaceholderContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Full Name', value: 'William Harry'),
        _InfoRow(label: 'Date of birth', value: '14 March, 1974'),
        _InfoRow(label: 'Gender', value: 'Female'),
        _InfoRow(label: 'Primary diagnosis', value: 'MASLD'),
        _InfoRow(label: 'Diagnosed', value: 'Jan, 2025'),
        _InfoRow(label: 'Other conditions', value: 'Metformin 500mg'),
        _InfoRow(label: 'Current medications', value: '—'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: NeuColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NeuColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Change',
              style: TextStyle(
                fontSize: 13,
                color: NeuColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
