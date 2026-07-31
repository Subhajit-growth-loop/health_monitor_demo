import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/onboarding_draft.dart';
import '../../view_model/onboarding_view_model.dart';
import '../neu_option_card.dart';

// ── Option catalogues ─────────────────────────────────────────────────────────

const _firstActions = [
  (
    'short_walk',
    'A short walk after your next meal',
    '10 minutes is plenty',
    Icons.directions_walk_rounded,
  ),
  (
    'masld_lesson',
    'Complete a MASLD lesson',
    'About 5 minutes',
    Icons.menu_book_rounded,
  ),
  (
    'water',
    'A glass of water first thing',
    'Tomorrow morning',
    Icons.local_drink_rounded,
  ),
];

// ── Step 10: First small action ───────────────────────────────────────────────

class FirstActionStep extends StatelessWidget {
  const FirstActionStep({super.key, required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (value, title, subtitle, icon) in _firstActions) ...[
          NeuOptionCard(
            icon: icon,
            title: title,
            subtitle: subtitle,
            selected: draft.firstAction == value,
            onTap: () => ctrl.editDraft(draft.copyWith(firstAction: value)),
          ),
          SizedBox(height: 14.h),
        ],
      ],
    );
  }
}
