import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/onboarding_draft.dart';
import '../../view_model/onboarding_view_model.dart';
import '../neu_slider_row.dart';

// ── Step 6: Feeling sliders ───────────────────────────────────────────────────

class FeelingStep extends StatelessWidget {
  const FeelingStep({super.key, required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  Widget build(BuildContext context) {
    final f = draft.feeling;
    return Column(
      children: [
        NeuSliderRow(
          icon: Icons.nightlight_round,
          question: 'How do you generally sleep?',
          emoji: '😴',
          value: f.sleep,
          minLabel: 'Poor Sleep',
          maxLabel: 'Great Sleep',
          onChanged: (v) =>
              ctrl.editDraft(draft.copyWith(feeling: f.copyWith(sleep: v))),
        ),
        SizedBox(height: 16.h),
        NeuSliderRow(
          icon: Icons.bolt_rounded,
          question: "How's your overall energy?",
          emoji: '🚶',
          value: f.energy,
          minLabel: 'Very Low',
          maxLabel: 'High Energy',
          onChanged: (v) =>
              ctrl.editDraft(draft.copyWith(feeling: f.copyWith(energy: v))),
        ),
        SizedBox(height: 16.h),
        NeuSliderRow(
          icon: Icons.psychology_rounded,
          question: "How's your overall stress?",
          emoji: '😰',
          value: f.stress,
          minLabel: 'Very Stressed',
          maxLabel: 'Very Calm',
          onChanged: (v) =>
              ctrl.editDraft(draft.copyWith(feeling: f.copyWith(stress: v))),
        ),
        SizedBox(height: 16.h),
        NeuSliderRow(
          icon: Icons.favorite_rounded,
          question: "How's your overall mood?",
          emoji: '🙂',
          value: f.mood,
          minLabel: 'Very Low',
          maxLabel: 'Excellent',
          onChanged: (v) =>
              ctrl.editDraft(draft.copyWith(feeling: f.copyWith(mood: v))),
        ),
      ],
    );
  }
}
