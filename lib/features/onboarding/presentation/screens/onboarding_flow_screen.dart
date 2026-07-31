import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/session/app_error_handler.dart';
import '../../../../core/session/current_user.dart';
import '../../../../core/session/onboarding_progress.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../../core/widgets/neu_base_screen.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../../domain/entities/onboarding_chat.dart';
import '../../domain/entities/onboarding_results.dart';
import '../../domain/entities/patient_profile_options.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/health_source.dart';
import '../view_model/onboarding_chat_controller.dart';
import '../view_model/onboarding_view_model.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../widgets/neu_checkbox_tile.dart';
import '../widgets/neu_choice_chip.dart';
import '../widgets/neu_option_card.dart';
import '../widgets/neu_radio_tile.dart';
import '../widgets/neu_segmented_control.dart';
import '../widgets/neu_slider_row.dart';
import '../widgets/neu_stepper.dart';
import 'onboarding_base_screen.dart';

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

// The medical-profile option lists live in PatientProfileOptions, which is the
// single source of truth shared with the API layer — the values are backend
// enums, so a copy here would drift into 422s.
const _primaryDiagnosisOptions = PatientProfileOptions.primaryDiagnosis;
const _otherConditionsOptions = PatientProfileOptions.otherConditions;
const _medicationsOptions = PatientProfileOptions.medications;
const _supplementsOptions = PatientProfileOptions.supplements;

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

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState
    extends ConsumerState<OnboardingFlowScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
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
            Icon(Icons.wifi_off_rounded,
                color: s.textMuted, size: 48),
            SizedBox(height: 16.h),
            Text(
              'Could not load your onboarding data.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14.sp, color: s.textMuted, height: 1.5),
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
        // Check what will actually be *sent*, not what is selected locally:
        // picking only "Other" without typing a name sanitizes to an empty
        // array, so the CTA must stay locked until there's a real answer.
        return p.dateOfBirth.isNotEmpty &&
            p.gender.isNotEmpty &&
            p.primaryDiagnosis.isNotEmpty &&
            p.diagnosedDate.isNotEmpty &&
            PatientProfileOptions.forApi(
              p.otherConditions,
              PatientProfileOptions.otherConditions,
            ).isNotEmpty &&
            PatientProfileOptions.forApi(
              p.currentMedications,
              PatientProfileOptions.medications,
            ).isNotEmpty &&
            PatientProfileOptions.forApi(
              p.currentSupplements,
              PatientProfileOptions.supplements,
            ).isNotEmpty;
      case OnboardingStep.feeling:
        // No validation by design. The four sliders always hold a value (they
        // default to 0.5), so there is nothing the user could fail to answer —
        // leaving them untouched is itself a valid answer.
        return true;
      case OnboardingStep.letter:
        // Read-only — nothing to answer.
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
        // Always enabled: the chat is optional context, so the patient can move
        // on mid-conversation. Gating on `done` also meant a server-side chat
        // failure blocked onboarding entirely, with no way past this step.
        return true;
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
            builder: (_) => OnboardingCompleteScreen(result: result),
          ),
        );
      } else if (state.currentStep == OnboardingStep.verifyInfo) {
        // PATCH /patient/me/details — see savePatientDetails() in
        // onboarding_view_model.dart. Must succeed before advancing.
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
    final s = NeuSurface.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: s.card,
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
    final s = NeuSurface.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: s.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _MultiSelectSheet(title: title, options: options, selected: selected, onConfirm: onConfirm),
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

// ── Step 7: AI follow-up chat ────────────────────────────────────────────────

/// The AI onboarding conversation: `/onboarding-chat/start` on open, then
/// `/onboarding-chat/turn` per answer. The step's CTA stays locked until the
/// server reports `done: true`.
class _NoteStep extends ConsumerStatefulWidget {
  const _NoteStep();

  @override
  ConsumerState<_NoteStep> createState() => _NoteStepState();
}

class _NoteStepState extends ConsumerState<_NoteStep> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// Whether the field holds something other than whitespace. Tracked as state
  /// rather than read inline so the send button repaints as the user types.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Open the conversation as soon as the step is shown. start() no-ops if a
    // session already exists, so navigating back and forth won't restart it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(onboardingChatControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Only rebuilds when the empty/non-empty state actually flips, not on every
  /// keystroke.
  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(onboardingChatControllerProvider.notifier).send(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final chat = ref.watch(onboardingChatControllerProvider);
    // Keep the newest bubble in view as the conversation grows.
    ref.listen(onboardingChatControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) _scrollToEnd();
    });

    return Container(
      height: 380.h,
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: s.border),
      ),
      child: Column(
        children: [
          Expanded(child: _body(chat)),
          Divider(height: 1, color: s.border),
          _composer(chat),
        ],
      ),
    );
  }

  Widget _body(OnboardingChatState chat) {
    final s = NeuSurface.of(context);
    if (chat.starting && chat.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22.r,
              height: 22.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: NeuColors.primary,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Reading your answers…',
              style: TextStyle(
                fontSize: 12.sp,
                color: s.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // Opening call failed — nothing to talk to yet, so offer a retry.
    if (chat.messages.isEmpty && chat.error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: s.textMuted,
                size: 32.r,
              ),
              SizedBox(height: 12.h),
              Text(
                chat.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: s.textMuted,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16.h),
              FilledButton(
                onPressed: () => ref
                    .read(onboardingChatControllerProvider.notifier)
                    .retryStart(),
                style: FilledButton.styleFrom(
                  backgroundColor: NeuColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    // One trailing slot for the typing indicator, then one for an inline error.
    final extra = (chat.sending ? 1 : 0) + (chat.error != null ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(14.r),
      itemCount: chat.messages.length + extra,
      itemBuilder: (_, i) {
        if (i < chat.messages.length) {
          return _Bubble(message: chat.messages[i]);
        }
        if (chat.sending && i == chat.messages.length) {
          return const _TypingBubble();
        }
        // No session left means it expired server-side — a retry of the same
        // turn would 404 again, so offer a fresh conversation instead.
        return _InlineError(
          message: chat.error!,
          actionLabel: chat.sessionId == null ? 'Start a new conversation' : null,
          onRetry: chat.sessionId == null
              ? () => ref
                  .read(onboardingChatControllerProvider.notifier)
                  .restart()
              : null,
        );
      },
    );
  }

  Widget _composer(OnboardingChatState chat) {
    final s = NeuSurface.of(context);
    // Typing is allowed whenever the session is open…
    final canType = chat.canAnswer;
    // …but sending needs something to send.
    final canSend = canType && _hasText;
    final String hint;
    if (chat.done) {
      hint = 'Conversation complete';
    } else if (chat.sessionId == null) {
      // "Connecting…" would be a lie once the session is gone — the field only
      // wakes up after the patient taps "Start a new conversation".
      hint = chat.error != null ? 'Not connected' : 'Connecting…';
    } else {
      hint = 'Type a message…';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: canType,
              textInputAction: TextInputAction.send,
              // 4000 is the server's documented ceiling for `answer`.
              maxLength: 4000,
              maxLines: 4,
              minLines: 1,
              onSubmitted: (_) => _send(),
              style: TextStyle(color: s.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: s.textMuted),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: canSend ? _send : null,
            child: Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: canSend
                    ? NeuColors.primary
                    : s.border.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              // No spinner here — the wait is shown by the "Thinking…" bubble in
              // the transcript, so the button just stays put.
              child: Icon(
                chat.done ? Icons.check_rounded : Icons.send_rounded,
                color: canSend
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single conversation bubble — the coach on the left, the patient on the
/// right.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final fromPatient = message.fromPatient;
    return Align(
      alignment: fromPatient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        constraints: BoxConstraints(maxWidth: 250.w),
        decoration: BoxDecoration(
          color: fromPatient ? NeuColors.primary : s.background,
          borderRadius: BorderRadius.circular(16.r),
          border: fromPatient
              ? null
              : Border.all(color: s.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14.sp,
            color: fromPatient ? Colors.white : s.onSurface,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

/// Shown while a `/turn` call is in flight — the API documents 2-5s latency, so
/// the wait needs to be visible. Reads as "Maya is thinking" rather than a
/// generic spinner: three dots pulse in sequence, which suits a conversation
/// better than a progress indicator that implies measurable progress.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opacity for dot [i], staggered so the wave travels left to right.
  double _dotOpacity(int i) {
    const dots = 3;
    final phase = (_controller.value - (i / dots)) % 1.0;
    // Ramp up over the first third of each dot's slot, then fade back.
    final eased = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + 0.7 * eased.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: s.background,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: s.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thinking',
              style: TextStyle(
                fontSize: 13.sp,
                color: s.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(width: 8.w),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) SizedBox(width: 4.w),
                    Container(
                      width: 6.r,
                      height: 6.r,
                      decoration: BoxDecoration(
                        color: NeuColors.primary.withValues(
                          alpha: _dotOpacity(i),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A failed turn, shown in the transcript so the patient's typed answer isn't
/// silently lost.
class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    this.onRetry,
    this.actionLabel,
  });
  final String message;
  final VoidCallback? onRetry;

  /// Defaults to a plain retry; an expired session says "start a new one"
  /// instead, since retrying the same turn cannot succeed.
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        constraints: BoxConstraints(maxWidth: 260.w),
        decoration: BoxDecoration(
          color: const Color(0xFFD63031).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFFD63031).withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFFFF7675),
                height: 1.35,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 6.h),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  actionLabel ?? 'Try again',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: NeuColors.primary,
                    fontWeight: FontWeight.w600,
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
    final s = NeuSurface.of(context);
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
            style: TextStyle(fontSize: 13.sp, color: s.textMuted),
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
    final surface = NeuSurface.of(context);
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
                color: surface.onSurface,
              ),
            ),
            if (typeLabels.isNotEmpty) ...[
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  '(${typeLabels.join(', ')})',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: surface.textMuted,
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
              color: surface.card,
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
    final s = NeuSurface.of(context);
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
          style: TextStyle(fontSize: 15.sp, color: s.textMuted),
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
    final s = NeuSurface.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: s.accent,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: s.emphasis,
            size: 20,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: s.emphasis,
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
    final s = NeuSurface.of(context);
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: s.textMuted,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'No $category source found currently. You can choose a source '
              'from Settings later.',
              style: TextStyle(
                fontSize: 13.sp,
                color: s.textMuted,
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

class _LetterStep extends ConsumerWidget {
  const _LetterStep();

  static const _body =
      "I'm Maya — your AI-enabled wellness coach. ✨\n\n"
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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = NeuSurface.of(context);
    // Prefer the name on the verified profile (the user may have corrected it on
    // step 1); fall back to the name the auth response stored. Greets without a
    // name rather than showing a placeholder if neither is set.
    final profileName =
        ref.watch(onboardingControllerProvider).valueOrNull?.profile.firstName ??
            '';
    final firstName =
        profileName.isNotEmpty ? profileName : CurrentUser.instance.firstName;
    final greeting = firstName.isEmpty ? 'Hi, ' : 'Hi $firstName, ';

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: s.border),
      ),
      child: Text(
        '$greeting$_body',
        style: TextStyle(
          fontSize: 14.5.sp,
          height: 1.5,
          color: s.onSurface.withValues(alpha: 0.9),
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

class OnboardingCompleteScreen extends ConsumerWidget {
  const OnboardingCompleteScreen({super.key, required this.result});

  final CompletionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = NeuSurface.of(context);
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
              color: s.onSurface.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: s.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT HAPPENS NEXT',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: s.emphasis,
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
    final s = NeuSurface.of(context);
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
                color: s.onSurface.withValues(alpha: 0.9),
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
    final s = NeuSurface.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        text,
        style: NeuTypography.serif(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: s.onSurface,
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
    final s = NeuSurface.of(context);
    return NeuBaseScreen(
      backgroundColor: s.background,
      lightStatusIcons: s.isDark,
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
