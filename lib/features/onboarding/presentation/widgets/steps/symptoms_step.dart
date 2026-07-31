import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/onboarding_draft.dart';
import '../../view_model/onboarding_view_model.dart';
import '../neu_choice_chip.dart';
import 'onboarding_step_helpers.dart';

// ── Option catalogues ─────────────────────────────────────────────────────────

const _symptoms = [
  ('fatigue', 'Fatigue'),
  ('poor_sleep', 'Poor sleep'),
  ('hot_flashes', 'Hot flashes'),
  ('bloating', 'Bloating'),
  ('mood_shifts', 'Mood shifts'),
  ('brain_fog', 'Brain fog'),
  ('sugar_cravings', 'Sugar cravings'),
  ('none', 'None right now'),
];

// ── Step 5: Recent symptoms ───────────────────────────────────────────────────

class SymptomsStep extends StatelessWidget {
  const SymptomsStep({super.key, required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: [
        for (final (value, label) in _symptoms)
          NeuChoiceChip(
            label: label,
            selected: draft.symptoms.contains(value),
            onTap: () => ctrl.editDraft(
              draft.copyWith(symptoms: toggleSelection(draft.symptoms, value)),
            ),
          ),
      ],
    );
  }
}
