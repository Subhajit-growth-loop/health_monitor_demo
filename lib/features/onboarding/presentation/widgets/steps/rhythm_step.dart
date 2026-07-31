import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/onboarding_draft.dart';
import '../../view_model/onboarding_view_model.dart';
import '../neu_checkbox_tile.dart';
import '../neu_choice_chip.dart';
import '../neu_segmented_control.dart';
import '../neu_stepper.dart';
import 'onboarding_step_helpers.dart';

// ── Option catalogues ─────────────────────────────────────────────────────────

const _activityLevels = ['Low', 'Moderate', 'Active'];

const _eatingRhythms = [
  ('three_meals', 'Three meals a day'),
  ('grazer', 'Grazer'),
  ('intermittent', 'Intermittent'),
];

const _dietaryPrefs = [
  ('low_carb', 'Low-carb / keto'),
  ('vegetarian', 'Vegetarian'),
  ('gluten_free', 'Gluten-free'),
  ('mediterranean', 'Mediterranean'),
  ('vegan', 'Vegan'),
  ('dairy_free', 'Dairy-free'),
];

// ── Step 3: Everyday rhythm ───────────────────────────────────────────────────

class RhythmStep extends StatelessWidget {
  const RhythmStep({super.key, required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Activity level'),
        NeuSegmentedControl(
          options: _activityLevels,
          value: draft.activityLevel == null
              ? null
              : titleCase(draft.activityLevel!),
          onChanged: (v) =>
              ctrl.editDraft(draft.copyWith(activityLevel: v.toLowerCase())),
        ),
        SizedBox(height: 24.h),
        SectionLabel('Eating rhythm'),
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: [
            for (final (value, label) in _eatingRhythms)
              NeuChoiceChip(
                label: label,
                selected: draft.eatingRhythm == value,
                onTap: () =>
                    ctrl.editDraft(draft.copyWith(eatingRhythm: value)),
              ),
          ],
        ),
        SizedBox(height: 24.h),
        NeuStepper(
          label: 'Typical Sleep',
          value: draft.sleepHours,
          min: 0,
          max: 14,
          unit: 'hrs',
          onChanged: (v) => ctrl.editDraft(draft.copyWith(sleepHours: v)),
        ),
        SizedBox(height: 24.h),
        SectionLabel('Dietary preference'),
        Column(
          children: [
            for (var i = 0; i < _dietaryPrefs.length; i += 2)
              Row(
                children: [
                  Expanded(child: _dietaryTile(i)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: i + 1 < _dietaryPrefs.length
                        ? _dietaryTile(i + 1)
                        : const SizedBox(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _dietaryTile(int i) {
    final (value, label) = _dietaryPrefs[i];
    return NeuCheckboxTile(
      label: label,
      selected: draft.dietaryPrefs.contains(value),
      onChanged: (_) => ctrl.editDraft(
        draft.copyWith(dietaryPrefs: toggleSelection(draft.dietaryPrefs, value)),
      ),
    );
  }
}
