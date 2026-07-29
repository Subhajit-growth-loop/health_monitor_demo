import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/settings/app_settings.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../../../onboarding/domain/entities/onboarding_draft.dart';
import '../../../onboarding/domain/entities/onboarding_results.dart';
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
    final async = ref.watch(onboardingControllerProvider);
    return async.when(
      loading: () => const _CenteredMessage(
        child: CircularProgressIndicator(color: NeuColors.primary),
      ),
      error: (e, _) => _CenteredMessage(
        child: Text(
          'Could not load onboarding.\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: NeuColors.textSecondary),
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
        await ref
            .read(sharedPreferencesProvider)
            .setBool('neu_onboarding_complete', true);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NeuOnboardingCompleteScreen(result: result),
          ),
        );
      } else {
        await ctrl.saveAndNext();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
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
  /// The profile field currently being edited (null = none).
  String? _editingKey;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEdit(String key, String currentValue) {
    setState(() {
      _editingKey = key;
      _controller.text = currentValue;
    });
  }

  Future<void> _save(String key) async {
    await ref.read(onboardingControllerProvider.notifier).updateProfile({
      key: _controller.text.trim(),
    });
    if (mounted) setState(() => _editingKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingControllerProvider).value!.profile;
    final rows = <({String key, String label, String value})>[
      (key: 'fullName', label: 'Full Name', value: profile.fullName),
      (
        key: 'dateOfBirth',
        label: 'Date of birth',
        value: _prettyDob(profile.dateOfBirth),
      ),
      (key: 'gender', label: 'Gender', value: _titleCase(profile.gender)),
      (
        key: 'primaryDiagnosis',
        label: 'Primary diagnosis',
        value: profile.primaryDiagnosis,
      ),
      (
        key: 'diagnosedDate',
        label: 'Diagnosed',
        value: _prettyMonth(profile.diagnosedDate),
      ),
      (
        key: 'otherConditions',
        label: 'Other conditions',
        value: profile.otherConditions,
      ),
      (
        key: 'currentMedications',
        label: 'Current medications',
        value: profile.currentMedications.isEmpty
            ? '—'
            : profile.currentMedications,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: NeuColors.inputBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: NeuColors.inputBorder.withValues(alpha: 0.6),
              ),
            _InfoRow(
              label: rows[i].label,
              value: rows[i].value,
              editing: _editingKey == rows[i].key,
              controller: _controller,
              onEdit: () => _startEdit(rows[i].key, rows[i].value),
              onSave: () => _save(rows[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.editing,
    required this.controller,
    required this.onEdit,
    required this.onSave,
  });

  final String label;
  final String value;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: NeuColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                if (editing)
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                      color: NeuColors.textDark,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onSubmitted: (_) => onSave(),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                      color: NeuColors.textDark,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: editing ? onSave : onEdit,
            child: Text(
              editing ? 'Save' : 'Change',
              style: TextStyle(
                fontSize: 14.sp,
                color: NeuColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Motivation + support ─────────────────────────────────────────────

class _MotivationStep extends StatelessWidget {
  const _MotivationStep({required this.draft, required this.ctrl});
  final OnboardingDraft draft;
  final OnboardingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (value, label) in _motivations)
          NeuCheckboxTile(
            label: label,
            selected: draft.motivations.contains(value),
            onChanged: (_) => ctrl.editDraft(
              draft.copyWith(motivations: _toggle(draft.motivations, value)),
            ),
          ),
        SizedBox(height: 24.h),
        Text(
          'What kind of support are you hoping for?',
          style: NeuTypography.serif(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
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
                selected: draft.supportTypes.contains(value),
                onTap: () => ctrl.editDraft(
                  draft.copyWith(
                    supportTypes: _toggle(draft.supportTypes, value),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: NeuColors.inputBorder),
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
            color: NeuColors.inputBorder.withValues(alpha: 0.6),
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
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Icon(
                  Icons.mic_none_rounded,
                  color: NeuColors.textMuted,
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
            style:
                TextStyle(fontSize: 13.sp, color: NeuColors.textSecondary),
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
                color: NeuColors.textDark,
              ),
            ),
            if (typeLabels.isNotEmpty) ...[
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  '(${typeLabels.join(', ')})',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: NeuColors.textSecondary,
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
              color: NeuColors.accentYellow,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: NeuColors.olive,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    catSources.length > 1
                        ? 'Multiple sources found — select one to continue'
                        : 'Select a source to connect your $label data',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: NeuColors.olive,
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
          style: TextStyle(fontSize: 15.sp, color: NeuColors.textSecondary),
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
        color: NeuColors.accentYellow,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: NeuColors.olive,
            size: 20,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: NeuColors.olive,
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
        color: NeuColors.inputBorder.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: NeuColors.textSecondary,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'No $category source found currently. You can choose a source '
              'from Settings later.',
              style: TextStyle(
                fontSize: 13.sp,
                color: NeuColors.textSecondary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: NeuColors.inputBorder),
      ),
      child: Text(
        _letter,
        style: TextStyle(
          fontSize: 14.5.sp,
          height: 1.5,
          color: NeuColors.textDark,
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
              color: NeuColors.textDark,
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: NeuColors.inputBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT HAPPENS NEXT',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.olive,
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
            color: NeuColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: NeuColors.primaryDark,
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
                color: NeuColors.textDark,
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
      backgroundColor: NeuColors.screenBackground,
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
const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `yyyy-MM-dd` → `14 March, 1974` (falls back to the raw string).
String _prettyDob(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_monthsLong[d.month - 1]}, ${d.year}';
}

/// `yyyy-MM` → `Jan, 2025` (falls back to the raw string).
String _prettyMonth(String ym) {
  final parts = ym.split('-');
  if (parts.length < 2) return ym;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return ym;
  return '${_monthsShort[m - 1]}, ${parts[0]}';
}
