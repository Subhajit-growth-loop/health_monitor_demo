import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../../../domain/entities/patient_profile_options.dart';
import '../../../domain/entities/user_profile.dart';
import '../../view_model/onboarding_view_model.dart';
import 'onboarding_step_helpers.dart';

// ── Option catalogues ─────────────────────────────────────────────────────────

const _primaryDiagnosisOptions = PatientProfileOptions.primaryDiagnosis;
const _otherConditionsOptions = PatientProfileOptions.otherConditions;
const _medicationsOptions = PatientProfileOptions.medications;
const _supplementsOptions = PatientProfileOptions.supplements;

const _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

// ── Step 1: Verify information (inline editing) ───────────────────────────────

class VerifyInfoStep extends ConsumerStatefulWidget {
  const VerifyInfoStep({super.key});
  @override
  ConsumerState<VerifyInfoStep> createState() => _VerifyInfoStepState();
}

class _VerifyInfoStepState extends ConsumerState<VerifyInfoStep> {
  String? _editingKey;
  final _textCtrl = TextEditingController();

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  void _saveText(String key) {
    ref.read(onboardingControllerProvider.notifier).editProfile({key: _textCtrl.text.trim()});
    if (mounted) setState(() => _editingKey = null);
  }

  Future<void> _openPicker(BuildContext context, UserProfile profile, String key) async {
    switch (key) {
      case 'dateOfBirth':
        final initial = DateTime.tryParse(profile.dateOfBirth) ?? DateTime(1990);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
        );
        if (picked != null && mounted) {
          ref.read(onboardingControllerProvider.notifier).editProfile({
            'dateOfBirth': '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}',
          });
        }
      case 'diagnosedDate':
        final initial = DateTime.tryParse(profile.diagnosedDate) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1980),
          lastDate: DateTime.now(),
        );
        if (picked != null && mounted) {
          ref.read(onboardingControllerProvider.notifier).editProfile({
            'diagnosedDate': '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}',
          });
        }
      case 'gender':
        if (!mounted) return;
        await _showSingleSelectSheet(
          context: context,
          title: 'Gender',
          options: _genderOptions.map((g) => (g.toLowerCase().replaceAll(' ', '_'), g)).toList(),
          selected: profile.gender,
          onSelected: (v) => ref.read(onboardingControllerProvider.notifier).editProfile({'gender': v}),
        );
      case 'primaryDiagnosis':
        if (!mounted) return;
        await _showSingleSelectSheet(
          context: context,
          title: 'Primary Diagnosis',
          options: _primaryDiagnosisOptions.toList(),
          selected: profile.primaryDiagnosis,
          onSelected: (v) => ref.read(onboardingControllerProvider.notifier).editProfile({'primaryDiagnosis': v}),
        );
      case 'otherConditions':
        if (!mounted) return;
        await _showMultiSelectSheet(
          context: context,
          title: 'Other Conditions',
          options: _otherConditionsOptions.toList(),
          selected: profile.otherConditions,
          onConfirm: (values) => ref.read(onboardingControllerProvider.notifier).editProfile({'otherConditions': values}),
        );
      case 'currentMedications':
        if (!mounted) return;
        await _showMultiSelectSheet(
          context: context,
          title: 'Current Medications',
          options: _medicationsOptions.toList(),
          selected: profile.currentMedications,
          onConfirm: (values) => ref.read(onboardingControllerProvider.notifier).editProfile({'currentMedications': values}),
        );
      case 'currentSupplements':
        if (!mounted) return;
        await _showMultiSelectSheet(
          context: context,
          title: 'Current Supplements',
          options: _supplementsOptions.toList(),
          selected: profile.currentSupplements,
          onConfirm: (values) => ref.read(onboardingControllerProvider.notifier).editProfile({'currentSupplements': values}),
        );
    }
  }

  Future<void> _showSingleSelectSheet({
    required BuildContext context,
    required String title,
    required List<(String, String)> options,
    required String selected,
    required void Function(String) onSelected,
  }) async {
    final s = NeuSurface.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: s.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => SingleSelectSheet(title: title, options: options, selected: selected, onSelected: onSelected),
    );
  }

  Future<void> _showMultiSelectSheet({
    required BuildContext context,
    required String title,
    required List<(String, String)> options,
    required List<String> selected,
    required void Function(List<String>) onConfirm,
  }) async {
    final s = NeuSurface.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: s.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => MultiSelectSheet(title: title, options: options, selected: selected, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final profile = ref.watch(onboardingControllerProvider).value!.profile;

    String labelOf(List<(String, String)> options, String value) {
      for (final (v, l) in options) { if (v == value) return l; }
      return value;
    }

    String labelsOf(List<(String, String)> options, List<String> values) {
      final labels = values.map((v) {
        for (final (ov, ol) in options) { if (ov == v) return ol; }
        return v;
      });
      return labels.join(', ').isEmpty ? '—' : labels.join(', ');
    }

    final rows = <({String key, String label, String display, bool isText})>[
      (key: 'fullName', label: 'Full Name', display: profile.fullName.isEmpty ? '—' : profile.fullName, isText: true),
      (key: 'dateOfBirth', label: 'Date of Birth', display: prettyDate(profile.dateOfBirth).isEmpty ? '—' : prettyDate(profile.dateOfBirth), isText: false),
      (key: 'gender', label: 'Gender', display: profile.gender.isEmpty ? '—' : titleCase(profile.gender), isText: false),
      (key: 'primaryDiagnosis', label: 'Primary Diagnosis', display: profile.primaryDiagnosis.isEmpty ? '—' : labelOf(_primaryDiagnosisOptions.toList(), profile.primaryDiagnosis), isText: false),
      (key: 'diagnosedDate', label: 'Diagnosed', display: prettyDate(profile.diagnosedDate).isEmpty ? '—' : prettyDate(profile.diagnosedDate), isText: false),
      (key: 'otherConditions', label: 'Other Conditions', display: profile.otherConditions.isEmpty ? '—' : labelsOf(_otherConditionsOptions.toList(), profile.otherConditions), isText: false),
      (key: 'currentMedications', label: 'Medications', display: profile.currentMedications.isEmpty ? '—' : labelsOf(_medicationsOptions.toList(), profile.currentMedications), isText: false),
      (key: 'currentSupplements', label: 'Supplements', display: profile.currentSupplements.isEmpty ? '—' : labelsOf(_supplementsOptions.toList(), profile.currentSupplements), isText: false),
    ];

    return Container(
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: s.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: s.border.withValues(alpha: 0.6)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].label, style: TextStyle(fontSize: 12.sp, color: s.textMuted)),
                        SizedBox(height: 4.h),
                        if (_editingKey == rows[i].key && rows[i].isText)
                          TextField(
                            controller: _textCtrl,
                            autofocus: true,
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: s.onSurface),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4), border: InputBorder.none),
                            onSubmitted: (_) => _saveText(rows[i].key),
                          )
                        else
                          Text(rows[i].display, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: s.onSurface)),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () {
                      if (rows[i].isText) {
                        if (_editingKey == rows[i].key) {
                          _saveText(rows[i].key);
                        } else {
                          setState(() { _editingKey = rows[i].key; _textCtrl.text = rows[i].display == '—' ? '' : rows[i].display; });
                        }
                      } else {
                        _openPicker(context, profile, rows[i].key);
                      }
                    },
                    child: _editingKey == rows[i].key && rows[i].isText
                        ? Icon(Icons.check_rounded, color: NeuColors.primary, size: 22.r)
                        : Icon(Icons.edit_outlined, color: s.textMuted, size: 20.r),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SingleSelectSheet extends StatefulWidget {
  const SingleSelectSheet({super.key, required this.title, required this.options, required this.selected, required this.onSelected});
  final String title;
  final List<(String, String)> options;
  final String selected;
  final void Function(String) onSelected;

  @override
  State<SingleSelectSheet> createState() => _SingleSelectSheetState();
}

class _SingleSelectSheetState extends State<SingleSelectSheet> {
  late String _current;

  @override
  void initState() { super.initState(); _current = widget.selected; }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: s.onSurface)),
            SizedBox(height: 16.h),
            for (final (value, label) in widget.options) ...[
              GestureDetector(
                onTap: () {
                  setState(() => _current = value);
                  widget.onSelected(value);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  margin: EdgeInsets.only(bottom: 8.h),
                  decoration: BoxDecoration(
                    color: _current == value ? NeuColors.primary.withValues(alpha: 0.15) : s.background,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: _current == value ? NeuColors.primary : s.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: TextStyle(fontSize: 14.sp, color: s.onSurface, fontWeight: FontWeight.w500))),
                      if (_current == value) Icon(Icons.check_rounded, color: NeuColors.primary, size: 18.r),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MultiSelectSheet extends StatefulWidget {
  const MultiSelectSheet({super.key, required this.title, required this.options, required this.selected, required this.onConfirm});
  final String title;
  final List<(String, String)> options;
  final List<String> selected;
  final void Function(List<String>) onConfirm;

  @override
  State<MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<MultiSelectSheet> {
  late List<String> _current;

  /// Values the user typed into the "Other" box. Rendered as chips after the
  /// built-in options, so a confirmed entry becomes a real, toggleable option.
  late List<String> _custom;

  final _otherCtrl = TextEditingController();

  /// Whether the "Other" text field is showing. Driven by tapping the Other
  /// chip, not by selection state — adding a value closes it, tapping Other
  /// again reopens it so several can be entered.
  bool _showOtherInput = false;

  @override
  void initState() {
    super.initState();
    _current = List.from(widget.selected);
    // Anything already selected that isn't a known option is a previously typed
    // value — restore all of them as chips, not just the first.
    final optionValues = widget.options.map((o) => o.$1).toSet();
    _custom = _current.where((v) => !optionValues.contains(v)).toList();
  }

  @override
  void dispose() { _otherCtrl.dispose(); super.dispose(); }

  void _toggle(String value) {
    setState(() {
      if (_current.contains(value)) {
        _current.remove(value);
        return;
      }
      // The server rejects `none` alongside anything else, so make it exclusive
      // here instead of letting the user build an invalid selection.
      if (value == PatientProfileOptions.noneValue) {
        _current = [value];
        _custom = [];
        _showOtherInput = false;
        _otherCtrl.clear();
      } else {
        _current
          ..remove(PatientProfileOptions.noneValue)
          ..add(value);
      }
    });
  }

  /// The Other chip is a trigger for the text field rather than a value to
  /// toggle — tapping it opens the box, tapping again closes it.
  void _tapOther() {
    setState(() {
      _showOtherInput = !_showOtherInput;
      if (!_showOtherInput) _otherCtrl.clear();
      if (_showOtherInput) {
        // Selecting anything clears an exclusive `none`.
        _current.remove(PatientProfileOptions.noneValue);
      }
    });
  }

  /// Commits what was typed: it becomes a selected chip and the box closes.
  void _addCustom() {
    final text = _otherCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      final known = widget.options.map((o) => o.$1.toLowerCase()).toSet();
      final existing = _custom.firstWhere(
        (c) => c.toLowerCase() == text.toLowerCase(),
        orElse: () => '',
      );

      if (known.contains(text.toLowerCase())) {
        // Typed the name of a built-in option — just select that instead of
        // creating a duplicate chip.
        final match = widget.options
            .firstWhere((o) => o.$1.toLowerCase() == text.toLowerCase());
        if (!_current.contains(match.$1)) _current.add(match.$1);
      } else if (existing.isNotEmpty) {
        // Already added — re-select rather than duplicating.
        if (!_current.contains(existing)) _current.add(existing);
      } else {
        _custom.add(text);
        _current.add(text);
      }

      _current.remove(PatientProfileOptions.noneValue);
      _otherCtrl.clear();
      _showOtherInput = false;
    });
  }

  /// Removes a typed value entirely (chip and selection).
  void _removeCustom(String value) {
    setState(() {
      _custom.remove(value);
      _current.remove(value);
    });
  }

  void _confirm() {
    // Custom values are already in _current; the API layer maps them to the
    // `other` enum member via PatientProfileOptions.forApi.
    widget.onConfirm(List<String>.from(_current));
    Navigator.pop(context);
  }

  bool get _hasOtherOption =>
      widget.options.any((o) => o.$1 == PatientProfileOptions.otherValue);

  /// One option chip. [onRemove] adds a small × for user-added values.
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onRemove,
  }) {
    final s = NeuSurface.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected
              ? NeuColors.primary.withValues(alpha: 0.15)
              : s.background,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: selected ? NeuColors.primary : s.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: selected ? NeuColors.primary : s.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (onRemove != null) ...[
              SizedBox(width: 6.w),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 15.r,
                  color: selected ? NeuColors.primary : s.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: s.onSurface)),
            SizedBox(height: 16.h),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: [
                        for (final (value, label) in widget.options)
                          // The Other chip opens the text box instead of
                          // toggling a value of its own.
                          if (value == PatientProfileOptions.otherValue)
                            _chip(
                              label: label,
                              selected: _showOtherInput ||
                                  _current.contains(value),
                              onTap: _tapOther,
                            )
                          else
                            _chip(
                              label: label,
                              selected: _current.contains(value),
                              onTap: () => _toggle(value),
                            ),
                        // Values the user typed, now first-class options.
                        for (final value in _custom)
                          _chip(
                            label: value,
                            selected: _current.contains(value),
                            onTap: () => _toggle(value),
                            onRemove: () => _removeCustom(value),
                          ),
                      ],
                    ),
                    if (_showOtherInput && _hasOtherOption) ...[
                      SizedBox(height: 14.h),
                      TextField(
                        controller: _otherCtrl,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        // Enter commits, same as the add button.
                        onSubmitted: (_) => _addCustom(),
                        style: TextStyle(color: s.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Type a name, then tap +',
                          hintStyle: TextStyle(color: s.textMuted),
                          filled: true,
                          fillColor: s.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide(color: s.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide(color: s.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: NeuColors.primary)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          isDense: true,
                          suffixIcon: IconButton(
                            onPressed: _addCustom,
                            icon: Icon(
                              Icons.add_circle_rounded,
                              color: NeuColors.primary,
                              size: 22.r,
                            ),
                            tooltip: 'Add',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(backgroundColor: NeuColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                child: Text('Confirm', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
