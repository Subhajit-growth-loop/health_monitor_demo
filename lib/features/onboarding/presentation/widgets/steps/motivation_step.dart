import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../../../domain/entities/onboarding_draft.dart';
import '../../view_model/onboarding_view_model.dart';
import '../neu_checkbox_tile.dart';
import '../neu_choice_chip.dart';
import 'onboarding_step_helpers.dart';

// ── Option catalogues ─────────────────────────────────────────────────────────

const _motivations = [
  ('recently_diagnosed', 'Recently diagnosed with fatty liver'),
  ('insulin_resistance', 'Managing insulin resistance or prediabetes'),
  ('family_history', 'Getting ahead of a family history'),
  ('doctor_metabolic', 'My doctor suggested focusing on metabolic health'),
  ('figuring_out', 'Still figuring it out'),
  ('other', 'Other'),
];

const _supportTypes = [
  ('accountability', 'Accountability'),
  ('education', 'Education'),
  ('hands_on', 'Hands-on guidance'),
  ('tracking', 'Tracking my data'),
  ('other', 'Other'),
];

// ── Step 2: Motivation + support ──────────────────────────────────────────────

class MotivationStep extends StatefulWidget {
  const MotivationStep({super.key, required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  State<MotivationStep> createState() => _MotivationStepState();
}

class _MotivationStepState extends State<MotivationStep> {
  late final TextEditingController _otherCtrl;

  static final _definedValues = _motivations.map((m) => m.$1).toSet();

  @override
  void initState() {
    super.initState();
    final custom = widget.draft.motivations
        .where((v) => !_definedValues.contains(v))
        .firstOrNull;
    _otherCtrl = TextEditingController(text: custom ?? '');
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  bool get _otherSelected =>
      widget.draft.motivations.contains('other') ||
      widget.draft.motivations.any((v) => !_definedValues.contains(v));

  void _toggleMotivation(String value) {
    if (value == 'other') {
      if (_otherSelected) {
        final updated = widget.draft.motivations
            .where((v) => _definedValues.contains(v) && v != 'other')
            .toList();
        widget.ctrl.editDraft(widget.draft.copyWith(motivations: updated));
        setState(() => _otherCtrl.clear());
      } else {
        widget.ctrl.editDraft(widget.draft.copyWith(
          motivations: [...widget.draft.motivations, 'other'],
        ));
      }
    } else {
      widget.ctrl.editDraft(
        widget.draft.copyWith(
          motivations: toggleSelection(widget.draft.motivations, value),
        ),
      );
    }
  }

  void _onOtherTextChanged(String text) {
    final base = widget.draft.motivations
        .where((v) => _definedValues.contains(v) && v != 'other')
        .toList();
    widget.ctrl.editDraft(widget.draft.copyWith(
      motivations: [...base, text.trim().isNotEmpty ? text.trim() : 'other'],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (value, label) in _motivations) ...[
          NeuCheckboxTile(
            label: label,
            selected: value == 'other'
                ? _otherSelected
                : widget.draft.motivations.contains(value),
            onChanged: (_) => _toggleMotivation(value),
          ),
          if (value == 'other' && _otherSelected) ...[
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 4.w, bottom: 4.h),
              child: TextField(
                controller: _otherCtrl,
                autofocus: true,
                onChanged: _onOtherTextChanged,
                style: TextStyle(color: s.onSurface, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Describe your reason…',
                  hintStyle: TextStyle(color: s.textMuted),
                  filled: true,
                  fillColor: s.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: s.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: s.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: NeuColors.primary),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ],
        ],
        SizedBox(height: 24.h),
        Text(
          'What kind of support are you hoping for?',
          style: NeuTypography.serif(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: s.onSurface,
          ),
        ),
        SizedBox(height: 16.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: [
            for (final (value, label) in _supportTypes)
              NeuChoiceChip(
                label: label,
                selected: widget.draft.supportTypes.contains(value),
                onTap: () => widget.ctrl.editDraft(
                  widget.draft.copyWith(
                    supportTypes: toggleSelection(widget.draft.supportTypes, value),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
