import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/session/app_error_handler.dart';
import '../../../../../core/session/current_user.dart';
import '../../../../../core/session/onboarding_progress.dart';
import '../../../../../core/settings/app_settings.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../../../onboarding/domain/entities/onboarding_draft.dart';
import '../../../onboarding/domain/entities/onboarding_results.dart';
import '../../../onboarding/domain/entities/user_profile.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../health/presentation/screens/dashboard_screen.dart';
import '../../../onboarding/domain/entities/health_source.dart';
import '../widgets/neu_base_screen.dart';
import '../widgets/neu_checkbox_tile.dart';
import '../widgets/neu_choice_chip.dart';
import '../widgets/neu_option_card.dart';
import '../widgets/neu_radio_tile.dart';
import '../widgets/neu_segmented_control.dart';
import '../widgets/neu_slider_row.dart';
import '../widgets/neu_stepper.dart';
import 'neu_onboarding_base_screen.dart';

// ── Option catalogues (value ⇄ label) ────────────────────────────────────────

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

const _cycleOptions = [
  ('regular', 'Regular cycles'),
  ('irregular', 'Irregular cycles'),
  ('perimenopause', 'Perimenopause'),
  ('post_menopause', 'Post-menopause'),
  ('other', 'Other'),
];

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

const _primaryDiagnosisOptions = [
  ('masld', 'MASLD'), ('mash', 'MASH'), ('prediabetes', 'Prediabetes'),
  ('type_2_diabetes', 'Type 2 Diabetes'), ('obesity', 'Obesity'),
  ('metabolic_syndrome', 'Metabolic Syndrome'), ('pcos', 'PCOS'),
  ('hypertension', 'Hypertension'), ('high_cholesterol', 'High Cholesterol'),
  ('none', 'None of the above'),
];

const _otherConditionsOptions = [
  ('prediabetes', 'Prediabetes'), ('type_2_diabetes', 'Type 2 Diabetes'),
  ('hypertension', 'Hypertension'), ('high_cholesterol', 'High Cholesterol'),
  ('obesity', 'Obesity'), ('pcos', 'PCOS'), ('sleep_apnea', 'Sleep Apnea'),
  ('hypothyroidism', 'Hypothyroidism'), ('depression', 'Depression'),
  ('anxiety', 'Anxiety'), ('none', 'None'),
];

const _medicationsOptions = [
  ('metformin', 'Metformin'), ('ozempic', 'Ozempic (Semaglutide)'),
  ('mounjaro', 'Mounjaro (Tirzepatide)'), ('wegovy', 'Wegovy'),
  ('jardiance', 'Jardiance'), ('insulin', 'Insulin'), ('statin', 'Statin'),
  ('blood_pressure_medication', 'Blood Pressure Medication'),
  ('none', 'None'), ('other', 'Other'),
];

const _supplementsOptions = [
  ('vitamin_d', 'Vitamin D'), ('vitamin_b12', 'Vitamin B12'),
  ('omega_3', 'Omega-3'), ('magnesium', 'Magnesium'),
  ('probiotics', 'Probiotics'), ('milk_thistle', 'Milk Thistle'),
  ('turmeric', 'Turmeric / Curcumin'), ('multivitamin', 'Multivitamin'),
  ('none', 'None'), ('other', 'Other'),
];

const _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

/// Maps raw platform health-data type strings to the short display label shown
/// in brackets under each connect-step category header.
const _kRawTypeLabel = <String, String>{
  'BLOOD_GLUCOSE': 'Glucose',
  'HEART_RATE': 'Heart Rate',
  'RESTING_HEART_RATE': 'Resting HR',
  'HEART_RATE_VARIABILITY_SDNN': 'HRV',
  'HEART_RATE_VARIABILITY_RMSSD': 'HRV',
  'BLOOD_OXYGEN': 'SpO₂',
  'RESPIRATORY_RATE': 'Resp. Rate',
  'BLOOD_PRESSURE_SYSTOLIC': 'Blood Pressure',
  'BLOOD_PRESSURE_DIASTOLIC': 'Blood Pressure',
  'BODY_TEMPERATURE': 'Body Temp',
  'STEPS': 'Steps',
  'ACTIVE_ENERGY_BURNED': 'Active Energy',
  'BASAL_ENERGY_BURNED': 'Resting Energy',
  'TOTAL_CALORIES_BURNED': 'Total Calories',
  'FLIGHTS_CLIMBED': 'Floors',
  'WEIGHT': 'Weight',
  'HEIGHT': 'Height',
  'BODY_FAT_PERCENTAGE': 'Body Fat',
  'LEAN_BODY_MASS': 'Lean Mass',
  'SLEEP_ASLEEP': 'Sleep',
  'SLEEP_SESSION': 'Sleep',
  'SLEEP_DEEP': 'Deep Sleep',
  'SLEEP_LIGHT': 'Light Sleep',
  'SLEEP_REM': 'REM Sleep',
  'SLEEP_AWAKE': 'Awake',
  'MENSTRUATION_FLOW': 'Menstruation',
};

// ── Flow screen ──────────────────────────────────────────────────────────────

class NeuOnboardingFlowScreen extends ConsumerStatefulWidget {
  const NeuOnboardingFlowScreen({super.key});

  @override
  ConsumerState<NeuOnboardingFlowScreen> createState() =>
      _NeuOnboardingFlowScreenState();
}

class _NeuOnboardingFlowScreenState
    extends ConsumerState<NeuOnboardingFlowScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingControllerProvider, (_, next) {
      if (next.hasError && mounted) {
        final msg = AppErrorHandler.instance.handle(
              next.error!,
              stackTrace: next.stackTrace,
              context: 'Load onboarding',
            ) ??
            'Could not load onboarding';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    final async = ref.watch(onboardingControllerProvider);
    return async.when(
      loading: () => const _CenteredMessage(
        child: CircularProgressIndicator(color: NeuColors.primary),
      ),
      error: (e, _) => _CenteredMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: NeuColors.darkTextMuted, size: 48),
            SizedBox(height: 16.h),
            Text(
              'Could not load your onboarding data.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14.sp, color: NeuColors.darkTextMuted, height: 1.5),
            ),
            SizedBox(height: 24.h),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(onboardingControllerProvider),
              style: FilledButton.styleFrom(
                backgroundColor: NeuColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: _buildStep,
    );
  }

  Widget _buildStep(OnboardingState state) {
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final draft = state.draft;

    String? heading;
    String? prompt;
    final Widget body;

    switch (state.currentStep) {
      case OnboardingStep.verifyInfo:
        heading = 'Verify your information';
        prompt =
            "Before we start, let's confirm the records your care team shared with me.";
        body = const _VerifyInfoStep();
      case OnboardingStep.motivation:
        heading = 'What brought you to Neu?';
        prompt =
            'What brought you to Neu, and what kind of support are you '
            'hoping for?';
        body = _MotivationStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.rhythm:
        // No serif heading on this step per design — just the Maya prompt.
        prompt = 'A few details about your everyday rhythm.';
        body = _RhythmStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.cycle:
        heading = 'Which best describes your menstrual cycle?';
        prompt =
            'This helps me read your glucose and symptoms in the right context.';
        body = _CycleStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.symptoms:
        heading = 'Recent symptoms';
        prompt = "Select any changes you've noticed lately.";
        body = _SymptomsStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.feeling:
        heading = 'How are you feeling?';
        prompt =
            "Share how you're feeling today to help us personalize your journey.";
        body = _FeelingStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.note:
        // Chatbot step — Maya prompt only, no serif heading.
        prompt =
            "Share how you're feeling today to help us personalize your journey.";
        body = const _NoteStep();
      case OnboardingStep.connect:
        heading = 'Connect your data';
        prompt =
            'Connect an app or device you already use so Neu can read your '
            'data automatically.';
        body = const _ConnectStep();
      case OnboardingStep.letter:
        heading = 'A letter from your AI coach';
        body = const _LetterStep();
      case OnboardingStep.firstAction:
        heading = 'Your first small action';
        prompt =
            "Let's pick one small thing to start with — just one. Small is "
            'how change lasts.';
        body = _FirstActionStep(draft: draft, ctrl: ctrl);
    }

    return NeuOnboardingShell(
      progress: state.progress,
      stepLabel: 'STEP ${state.stepIndex + 1} / ${state.totalSteps}',
      heading: heading,
      mayaPrompt: prompt,
      showBack: !state.isFirst,
      onBack: ctrl.back,
      body: body,
      ctaLabel: state.isLast ? 'Set my first action' : 'Save & next',
      ctaLoading: _saving,
      ctaEnabled: _isStepComplete(state),
      onCta: () => _onCta(state, ctrl),
    );
  }

  /// A step's CTA stays disabled until its required inputs are answered.
  bool _isStepComplete(OnboardingState state) {
    final d = state.draft;
    switch (state.currentStep) {
      case OnboardingStep.verifyInfo:
        final p = state.profile;
        return p.dateOfBirth.isNotEmpty &&
            p.gender.isNotEmpty &&
            p.primaryDiagnosis.isNotEmpty &&
            p.diagnosedDate.isNotEmpty &&
            p.otherConditions.isNotEmpty &&
            p.currentMedications.isNotEmpty &&
            p.currentSupplements.isNotEmpty;
      case OnboardingStep.feeling: // sliders always carry a value
      case OnboardingStep.letter: // read-only
        return true;
      case OnboardingStep.motivation:
        return d.motivations.isNotEmpty && d.supportTypes.isNotEmpty;
      case OnboardingStep.rhythm:
        return d.activityLevel != null &&
            d.eatingRhythm != null &&
            d.dietaryPrefs.isNotEmpty;
      case OnboardingStep.cycle:
        return d.menstrualCycle != null;
      case OnboardingStep.symptoms:
        return d.symptoms.isNotEmpty;
      case OnboardingStep.note:
        return d.note.trim().isNotEmpty;
      case OnboardingStep.connect:
        return d.connectChoice != null;
      case OnboardingStep.firstAction:
        return d.firstAction != null;
    }
  }

  Future<void> _onCta(OnboardingState state, OnboardingController ctrl) async {
    setState(() => _saving = true);
    try {
      if (state.isLast) {
        final result = await ctrl.complete();
        await OnboardingProgress.markComplete(
          ref.read(sharedPreferencesProvider),
          CurrentUser.instance.email,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NeuOnboardingCompleteScreen(result: result),
          ),
        );
      } else if (state.currentStep == OnboardingStep.verifyInfo) {
        // PATCH /patient/me/details — see savePatientDetails() in
        // onboarding_providers.dart. Must succeed before advancing.
        await ctrl.savePatientDetails();
        await ctrl.saveAndNext();
      } else {
        await ctrl.saveAndNext();
      }
    } catch (e, st) {
      if (mounted) {
        final msg = AppErrorHandler.instance.handle(
              e,
              stackTrace: st,
              context: 'Onboarding · ${state.currentStep.name}',
            ) ??
            'Something went wrong';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Step 1: Verify information (inline editing) ──────────────────────────────

class _VerifyInfoStep extends ConsumerStatefulWidget {
  const _VerifyInfoStep();
  @override
  ConsumerState<_VerifyInfoStep> createState() => _VerifyInfoStepState();
}

class _VerifyInfoStepState extends ConsumerState<_VerifyInfoStep> {
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeuColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _SingleSelectSheet(title: title, options: options, selected: selected, onSelected: onSelected),
    );
  }

  Future<void> _showMultiSelectSheet({
    required BuildContext context,
    required String title,
    required List<(String, String)> options,
    required List<String> selected,
    required void Function(List<String>) onConfirm,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeuColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _MultiSelectSheet(title: title, options: options, selected: selected, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      (key: 'dateOfBirth', label: 'Date of Birth', display: _prettyDob(profile.dateOfBirth).isEmpty ? '—' : _prettyDob(profile.dateOfBirth), isText: false),
      (key: 'gender', label: 'Gender', display: profile.gender.isEmpty ? '—' : _titleCase(profile.gender), isText: false),
      (key: 'primaryDiagnosis', label: 'Primary Diagnosis', display: profile.primaryDiagnosis.isEmpty ? '—' : labelOf(_primaryDiagnosisOptions.toList(), profile.primaryDiagnosis), isText: false),
      (key: 'diagnosedDate', label: 'Diagnosed', display: _prettyDob(profile.diagnosedDate).isEmpty ? '—' : _prettyDob(profile.diagnosedDate), isText: false),
      (key: 'otherConditions', label: 'Other Conditions', display: profile.otherConditions.isEmpty ? '—' : labelsOf(_otherConditionsOptions.toList(), profile.otherConditions), isText: false),
      (key: 'currentMedications', label: 'Medications', display: profile.currentMedications.isEmpty ? '—' : labelsOf(_medicationsOptions.toList(), profile.currentMedications), isText: false),
      (key: 'currentSupplements', label: 'Supplements', display: profile.currentSupplements.isEmpty ? '—' : labelsOf(_supplementsOptions.toList(), profile.currentSupplements), isText: false),
    ];

    return Container(
      decoration: BoxDecoration(
        color: NeuColors.darkCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: NeuColors.darkBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: NeuColors.darkBorder.withValues(alpha: 0.6)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].label, style: TextStyle(fontSize: 12.sp, color: NeuColors.darkTextMuted)),
                        SizedBox(height: 4.h),
                        if (_editingKey == rows[i].key && rows[i].isText)
                          TextField(
                            controller: _textCtrl,
                            autofocus: true,
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4), border: InputBorder.none),
                            onSubmitted: (_) => _saveText(rows[i].key),
                          )
                        else
                          Text(rows[i].display, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white)),
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
                        : Icon(Icons.edit_outlined, color: NeuColors.darkTextMuted, size: 20.r),
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

class _SingleSelectSheet extends StatefulWidget {
  const _SingleSelectSheet({required this.title, required this.options, required this.selected, required this.onSelected});
  final String title;
  final List<(String, String)> options;
  final String selected;
  final void Function(String) onSelected;

  @override
  State<_SingleSelectSheet> createState() => _SingleSelectSheetState();
}

class _SingleSelectSheetState extends State<_SingleSelectSheet> {
  late String _current;

  @override
  void initState() { super.initState(); _current = widget.selected; }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white)),
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
                    color: _current == value ? NeuColors.primary.withValues(alpha: 0.15) : NeuColors.darkBackground,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: _current == value ? NeuColors.primary : NeuColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.w500))),
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

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({required this.title, required this.options, required this.selected, required this.onConfirm});
  final String title;
  final List<(String, String)> options;
  final List<String> selected;
  final void Function(List<String>) onConfirm;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late List<String> _current;
  final _otherCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _current = List.from(widget.selected);
    final optionValues = widget.options.map((o) => o.$1).toSet();
    final custom = _current.where((v) => !optionValues.contains(v)).firstOrNull;
    if (custom != null) _otherCtrl.text = custom;
  }

  @override
  void dispose() { _otherCtrl.dispose(); super.dispose(); }

  void _toggle(String value) {
    setState(() {
      if (_current.contains(value)) {
        _current.remove(value);
      } else {
        _current.add(value);
      }
    });
  }

  void _confirm() {
    var values = List<String>.from(_current);
    if (values.contains('other') && _otherCtrl.text.trim().isNotEmpty) {
      values.remove('other');
      values.add(_otherCtrl.text.trim());
    }
    widget.onConfirm(values);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final showOtherInput = _current.contains('other');
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white)),
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
                          GestureDetector(
                            onTap: () => _toggle(value),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: _current.contains(value) ? NeuColors.primary.withValues(alpha: 0.15) : NeuColors.darkBackground,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: _current.contains(value) ? NeuColors.primary : NeuColors.darkBorder),
                              ),
                              child: Text(label, style: TextStyle(fontSize: 13.sp, color: _current.contains(value) ? NeuColors.primary : Colors.white, fontWeight: _current.contains(value) ? FontWeight.w600 : FontWeight.w400)),
                            ),
                          ),
                      ],
                    ),
                    if (showOtherInput) ...[
                      SizedBox(height: 14.h),
                      TextField(
                        controller: _otherCtrl,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Describe...',
                          hintStyle: const TextStyle(color: NeuColors.darkTextMuted),
                          filled: true,
                          fillColor: NeuColors.darkBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide(color: NeuColors.darkBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide(color: NeuColors.darkBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: NeuColors.primary)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          isDense: true,
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

// ── Step 2: Motivation + support ─────────────────────────────────────────────

class _MotivationStep extends StatefulWidget {
  const _MotivationStep({required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  State<_MotivationStep> createState() => _MotivationStepState();
}

class _MotivationStepState extends State<_MotivationStep> {
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
          motivations: _toggle(widget.draft.motivations, value),
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
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Describe your reason…',
                  hintStyle: const TextStyle(color: NeuColors.darkTextMuted),
                  filled: true,
                  fillColor: NeuColors.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: NeuColors.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: NeuColors.darkBorder),
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
            color: Colors.white,
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
                    supportTypes: _toggle(widget.draft.supportTypes, value),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Step 3: Everyday rhythm ──────────────────────────────────────────────────

class _RhythmStep extends StatelessWidget {
  const _RhythmStep({required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Activity level'),
        NeuSegmentedControl(
          options: _activityLevels,
          value: draft.activityLevel == null
              ? null
              : _titleCase(draft.activityLevel!),
          onChanged: (v) =>
              ctrl.editDraft(draft.copyWith(activityLevel: v.toLowerCase())),
        ),
        SizedBox(height: 24.h),
        _SectionLabel('Eating rhythm'),
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
        _SectionLabel('Dietary preference'),
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
        draft.copyWith(dietaryPrefs: _toggle(draft.dietaryPrefs, value)),
      ),
    );
  }
}

// ── Step 4: Menstrual cycle (female only) ────────────────────────────────────

class _CycleStep extends StatelessWidget {
  const _CycleStep({required this.draft, required this.ctrl});
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

// ── Step 5: Recent symptoms ──────────────────────────────────────────────────

class _SymptomsStep extends StatelessWidget {
  const _SymptomsStep({required this.draft, required this.ctrl});
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
              draft.copyWith(symptoms: _toggle(draft.symptoms, value)),
            ),
          ),
      ],
    );
  }
}

// ── Step 6: Feeling sliders ──────────────────────────────────────────────────

class _FeelingStep extends StatelessWidget {
  const _FeelingStep({required this.draft, required this.ctrl});
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

// ── Step 7: Chatbot ──────────────────────────────────────────────────────────

class _NoteStep extends ConsumerStatefulWidget {
  const _NoteStep();

  @override
  ConsumerState<_NoteStep> createState() => _NoteStepState();
}

class _NoteStepState extends ConsumerState<_NoteStep> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// The conversation, persisted into `draft.note` (newline-joined).
  late List<String> _messages;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingControllerProvider).value!.draft;
    _messages = draft.note
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _controller.clear();
    });
    ref
        .read(onboardingControllerProvider.notifier)
        .editDraft(
          ref
              .read(onboardingControllerProvider)
              .value!
              .draft
              .copyWith(note: _messages.join('\n')),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380.h,
      decoration: BoxDecoration(
        color: NeuColors.darkCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: NeuColors.darkBorder),
      ),
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const SizedBox.expand()
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(14.r),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 10.h,
                        ),
                        constraints: BoxConstraints(maxWidth: 240.w),
                        decoration: BoxDecoration(
                          color: NeuColors.primary,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          _messages[i],
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Divider(
            height: 1,
            color: NeuColors.darkBorder,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 8.h),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: const TextStyle(color: NeuColors.darkTextMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Icon(
                  Icons.mic_none_rounded,
                  color: NeuColors.darkTextMuted,
                  size: 22,
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: const BoxDecoration(
                      color: NeuColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 8: Connect devices ───────────────────────────────────────────────────

class _ConnectStep extends ConsumerStatefulWidget {
  const _ConnectStep();

  @override
  ConsumerState<_ConnectStep> createState() => _ConnectStepState();
}

class _ConnectStepState extends ConsumerState<_ConnectStep> {
  static const _cats = [
    ('vitals', 'Vitals', Icons.favorite_rounded),
    ('activity', 'Activity', Icons.directions_walk_rounded),
    ('wellness', 'Wellness', Icons.self_improvement_rounded),
  ];

  /// User-chosen source per display category.
  final Map<String, String?> _selectedByCategory = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reset connect completion so the CTA is disabled while detection runs.
      final ctrl = ref.read(onboardingControllerProvider.notifier);
      final state = ref.read(onboardingControllerProvider).valueOrNull;
      if (state != null) {
        ctrl.editDraft(state.draft.copyWith(connectChoice: null));
      }
      ref.read(connectedSourcesProvider.notifier).detect();
    });
  }

  /// True when every category that has at least one source has a selection.
  /// Categories with 0 sources are skipped.
  bool _isComplete() {
    final async = ref.read(connectedSourcesProvider);
    if (async.isLoading) return false;
    if (async.hasError) return true; // let user proceed past errors
    final sources = async.value;
    if (sources == null) return false;
    for (final (cat, _, _) in _cats) {
      final n = sources.where((s) => s.hasCategory(cat)).length;
      if (n >= 1 && _selectedByCategory[cat] == null) return false;
    }
    return true;
  }

  /// Writes the current selection + completion flag into the draft.
  void _syncToDraft() {
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final state = ref.read(onboardingControllerProvider).valueOrNull;
    if (state == null) return;
    final selected =
        _selectedByCategory.values.whereType<String>().toSet().toList();
    ctrl.editDraft(state.draft.copyWith(
      connectChoice: _isComplete() ? 'done' : null,
      connectedSources: selected,
    ));
  }

  void _selectSource(String catKey, String sourceName) {
    setState(() {
      _selectedByCategory[catKey] =
          _selectedByCategory[catKey] == sourceName ? null : sourceName;
    });
    _syncToDraft();
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(connectedSourcesProvider);

    // When sources load: auto-select single-source categories, then sync.
    ref.listen(connectedSourcesProvider, (_, next) {
      if (next.hasError) {
        _syncToDraft();
        return;
      }
      if (!next.hasValue || next.value == null) return;
      final sources = next.value!;
      for (final (cat, _, _) in _cats) {
        final catSources =
            sources.where((s) => s.hasCategory(cat)).toList();
        if (catSources.length == 1 && _selectedByCategory[cat] == null) {
          _selectedByCategory[cat] = catSources.first.name;
        }
      }
      _syncToDraft();
      // setState not needed — _syncToDraft triggers a provider update which
      // rebuilds this widget via ref.watch(connectedSourcesProvider).
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sourcesAsync.when(
          loading: () => const _DetectingRow(),
          error: (e, _) => const _ConnectMessage(
            'Could not read your health sources. '
            'You can connect from Settings later.',
          ),
          data: (sources) {
            if (sources == null) return const _DetectingRow();
            return _buildGroupedSources(sources);
          },
        ),
        SizedBox(height: 16.h),
        Center(
          child: Text(
            'You can connect additional sources from Settings at any time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: NeuColors.darkTextMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedSources(List<HealthSource> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _cats.length; i++) ...[
          if (i > 0) SizedBox(height: 20.h),
          _buildCategorySection(_cats[i].$1, _cats[i].$2, _cats[i].$3, sources),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
    String catKey,
    String label,
    IconData icon,
    List<HealthSource> allSources,
  ) {
    final catSources =
        allSources.where((s) => s.hasCategory(catKey)).toList();

    final typeLabels = catSources
        .expand((s) => s.rawTypesByCategory[catKey] ?? const <String>{})
        .map((t) => _kRawTypeLabel[t])
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final selected = _selectedByCategory[catKey];
    final needsChoice = catSources.isNotEmpty && selected == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18.r, color: NeuColors.primary),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (typeLabels.isNotEmpty) ...[
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  '(${typeLabels.join(', ')})',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: NeuColors.darkTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (needsChoice) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: NeuColors.darkCard,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: NeuColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: NeuColors.primary,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    catSources.length > 1
                        ? 'Multiple sources found — select one to continue'
                        : 'Select a source to connect your $label data',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: NeuColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 10.h),
        if (catSources.isEmpty)
          _NoSourceMessage(category: label)
        else
          Column(
            children: [
              for (final s in catSources) ...[
                NeuRadioTile(
                  label: s.name,
                  selected: selected == s.name,
                  onTap: () => _selectSource(catKey, s.name),
                ),
                SizedBox(height: 8.h),
              ],
            ],
          ),
      ],
    );
  }
}

class _DetectingRow extends StatelessWidget {
  const _DetectingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: NeuColors.primary,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          'Checking your connected apps…',
          style: TextStyle(fontSize: 15.sp, color: Colors.white60),
        ),
      ],
    );
  }
}

class _ConnectMessage extends StatelessWidget {
  const _ConnectMessage(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: NeuColors.darkCard,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: NeuColors.primary,
            size: 20,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: NeuColors.primary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSourceMessage extends StatelessWidget {
  const _NoSourceMessage({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: NeuColors.darkCard,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: NeuColors.darkTextMuted,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'No $category source found currently. You can choose a source '
              'from Settings later.',
              style: TextStyle(
                fontSize: 13.sp,
                color: NeuColors.darkTextMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 9: Letter ───────────────────────────────────────────────────────────

class _LetterStep extends StatelessWidget {
  const _LetterStep();

  static const _letter =
      "Hi, I'm Maya — your AI-enabled wellness coach. ✨\n\n"
      "If you've been diagnosed with MASLD, insulin resistance, or metabolic "
      "dysfunction, you're not alone. Millions of people are navigating "
      "fatigue, inflammation, weight changes, cravings, poor sleep, and "
      "changing labs without truly understanding what's happening in their "
      "bodies. Neu Health was built to support you between doctor visits — "
      "where real health change actually happens.\n\n"
      "Together, we'll use your health patterns, daily routines, movement, "
      "meals, and recovery to build small, sustainable shifts that help your "
      "body feel steadier, stronger, and healthier over time. This is "
      "intelligent support designed for real life.\n\n"
      "You've carried a lot through the years — and now it's time for some of "
      "that care to come back to you. I'll be here to guide, encourage, and "
      "adjust alongside you, one day at a time. I'm so glad you're here and "
      "honored to be on your journey to better health.\n\n"
      "With warmth,\nMaya ✨";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: NeuColors.darkCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: NeuColors.darkBorder),
      ),
      child: Text(
        _letter,
        style: TextStyle(
          fontSize: 14.5.sp,
          height: 1.5,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

// ── Step 10: First small action ──────────────────────────────────────────────

class _FirstActionStep extends StatelessWidget {
  const _FirstActionStep({required this.draft, required this.ctrl});
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

// ── Completion screen ─────────────────────────────────────────────────────────

class NeuOnboardingCompleteScreen extends ConsumerWidget {
  const NeuOnboardingCompleteScreen({super.key, required this.result});

  final CompletionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: NeuColors.darkCard,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: NeuColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT HAPPENS NEXT',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.primary,
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
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Small shared helpers ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        text,
        style: NeuTypography.serif(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NeuBaseScreen(
      backgroundColor: NeuColors.darkBackground,
      lightStatusIcons: true,
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Center(child: child),
      ),
    );
  }
}

List<String> _toggle(List<String> list, String value) {
  final next = List<String>.from(list);
  next.contains(value) ? next.remove(value) : next.add(value);
  return next;
}


String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
/// `yyyy-MM-dd` → `14 March, 1974` (falls back to the raw string).
String _prettyDob(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_monthsLong[d.month - 1]}, ${d.year}';
}

