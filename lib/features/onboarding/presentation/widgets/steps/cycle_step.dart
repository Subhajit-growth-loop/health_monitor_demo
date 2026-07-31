import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/onboarding_draft.dart';
import '../../view_model/onboarding_view_model.dart';
import '../neu_radio_tile.dart';

// ── Option catalogues ─────────────────────────────────────────────────────────

const _cycleOptions = [
  ('regular', 'Regular cycles'),
  ('irregular', 'Irregular cycles'),
  ('perimenopause', 'Perimenopause'),
  ('post_menopause', 'Post-menopause'),
  ('other', 'Other'),
];

// ── Step 4: Menstrual cycle (female only) ─────────────────────────────────────

class CycleStep extends StatelessWidget {
  const CycleStep({super.key, required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (value, label) in _cycleOptions) ...[
          NeuRadioTile(
            label: label,
            selected: draft.menstrualCycle == value,
            onTap: () => ctrl.editDraft(draft.copyWith(menstrualCycle: value)),
          ),
          SizedBox(height: 14.h),
        ],
      ],
    );
  }
}
