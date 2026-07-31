import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_api_services.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../dashboard/domain/entities/health_metric_type.dart';
import '../../../dashboard/presentation/view_model/health_view_model.dart';
import '../../data/datasources/remote/onboarding_api.dart';
import '../../data/repositories/onboarding_repository_impl.dart';
import '../../domain/entities/health_source.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../../domain/entities/onboarding_results.dart';
import '../../domain/entities/patient_profile_options.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/onboarding_repository.dart';

// ── DI graph (mirrors health_view_model.dart) ─────────────────────────────────

final onboardingApiProvider = Provider<OnboardingApi>(
  (ref) => OnboardingApi(ref.watch(dioProvider)),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepositoryImpl(ref.watch(onboardingApiProvider)),
);

// ── The ordered onboarding steps ─────────────────────────────────────────────

/// Logical steps in the guided flow. [cycle] is female-only and dropped from
/// the list when the profile gender is not female, so the "STEP x / N" count is
/// dynamic.
enum OnboardingStep {
  verifyInfo,
  motivation,
  rhythm,
  cycle,
  symptoms,
  feeling,
  note,
  connect,
  letter,
  firstAction,
}

/// The draft fields a step owns — "Save & next" sends only these, not the whole
/// draft, so one step can never overwrite another's answers.
///
/// [OnboardingStep.verifyInfo] contributes nothing: its fields live on the
/// profile and go to `PATCH /patient/me/details` instead. [OnboardingStep.letter]
/// is read-only.
Map<String, dynamic> answersForStep(OnboardingStep step, OnboardingDraft d) =>
    switch (step) {
      OnboardingStep.verifyInfo || OnboardingStep.letter =>
        const <String, dynamic>{},
      OnboardingStep.motivation => {
        'motivations': d.motivations,
        'supportTypes': d.supportTypes,
      },
      OnboardingStep.rhythm => {
        'activityLevel': d.activityLevel,
        'eatingRhythm': d.eatingRhythm,
        'sleepHours': d.sleepHours,
        'dietaryPrefs': d.dietaryPrefs,
      },
      OnboardingStep.cycle => {'menstrualCycle': d.menstrualCycle},
      OnboardingStep.symptoms => {'symptoms': d.symptoms},
      OnboardingStep.feeling => {'feeling': d.feeling.toJson()},
      // The chat is never persisted locally — the transcript and summary live
      // on the server for the life of the session, so this step contributes
      // nothing to the draft.
      OnboardingStep.note => const <String, dynamic>{},
      OnboardingStep.connect => {
        'connectChoice': d.connectChoice,
        'connectedSources': d.connectedSources,
      },
      OnboardingStep.firstAction => {'firstAction': d.firstAction},
    };

// ── Flow state ───────────────────────────────────────────────────────────────

class OnboardingState {
  const OnboardingState({
    required this.profile,
    required this.draft,
    required this.stepIndex,
  });

  final UserProfile profile;
  final OnboardingDraft draft;
  final int stepIndex;

  /// The steps that apply to this user (menstrual step only for female).
  List<OnboardingStep> get steps => [
    for (final s in OnboardingStep.values)
      if ((s != OnboardingStep.cycle && s != OnboardingStep.symptoms) || profile.isFemale) s,
  ];

  int get totalSteps => steps.length;
  OnboardingStep get currentStep => steps[stepIndex];
  bool get isFirst => stepIndex == 0;
  bool get isLast => stepIndex == steps.length - 1;
  double get progress => (stepIndex + 1) / totalSteps;

  OnboardingState copyWith({
    UserProfile? profile,
    OnboardingDraft? draft,
    int? stepIndex,
  }) => OnboardingState(
    profile: profile ?? this.profile,
    draft: draft ?? this.draft,
    stepIndex: stepIndex ?? this.stepIndex,
  );
}

/// Loads the onboarding snapshot from the API and drives step navigation.
/// Answers are edited locally as the user interacts, then persisted to the API
/// on "Save & next" — so going back re-shows exactly what was saved.
class OnboardingController extends AsyncNotifier<OnboardingState> {
  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  Future<OnboardingState> build() async {
    // Run both fetches concurrently — neither depends on the other.
    final results = await Future.wait([
      _repo.loadOnboarding(),
      _repo.loadPatientDetails(),
    ]);

    final snapshot = results[0] as OnboardingSnapshot;
    final patientDetails = results[1] as UserProfile?;

    // Patient-details API is authoritative for the medical profile fields;
    // fall back to whatever the onboarding snapshot returned.
    var profile = patientDetails ?? snapshot.profile;

    // Gender from auth (signup/login) overrides everything — it drives the
    // dynamic step count (female-only cycle/symptoms steps).
    final storedGender =
        ref.read(sharedPreferencesProvider).getString('neu_gender');
    if (storedGender != null && storedGender.isNotEmpty) {
      profile = profile.copyWith(gender: storedGender);
    }

    // Resume where this email left off. The step list length depends on gender,
    // so clamp rather than trust the stored index blindly.
    final probe = OnboardingState(
      profile: profile,
      draft: snapshot.draft,
      stepIndex: 0,
    );
    final resumeAt = snapshot.stepIndex.clamp(0, probe.steps.length - 1);

    return probe.copyWith(stepIndex: resumeAt);
  }

  OnboardingState get _s => state.value!;

  /// Local-only edit of the draft (as the user toggles options). Persisted on
  /// [saveAndNext].
  void editDraft(OnboardingDraft draft) {
    if (!state.hasValue) return;
    state = AsyncData(_s.copyWith(draft: draft));
  }

  /// Local-only profile field edit — merges [changes] into the current profile
  /// without any API call. Persisted on [savePatientProfile].
  void editProfile(Map<String, dynamic> changes) {
    if (!state.hasValue) return;
    final p = _s.profile;
    final updated = p.copyWith(
      fullName: changes['fullName'] as String? ?? p.fullName,
      dateOfBirth: changes['dateOfBirth'] as String? ?? p.dateOfBirth,
      gender: changes['gender'] as String? ?? p.gender,
      primaryDiagnosis:
          changes['primaryDiagnosis'] as String? ?? p.primaryDiagnosis,
      diagnosedDate: changes['diagnosedDate'] as String? ?? p.diagnosedDate,
      otherConditions:
          (changes['otherConditions'] as List?)?.cast<String>() ??
          p.otherConditions,
      currentMedications:
          (changes['currentMedications'] as List?)?.cast<String>() ??
          p.currentMedications,
      currentSupplements:
          (changes['currentSupplements'] as List?)?.cast<String>() ??
          p.currentSupplements,
    );
    state = AsyncData(_s.copyWith(profile: updated));
  }

  /// Persists **only the current screen's answers**, plus the step being moved
  /// to so a returning user lands here rather than back at step 1. The server
  /// merges the partial map into the stored draft.
  Future<void> saveAndNext() async {
    if (!state.hasValue) return;
    final answers = answersForStep(_s.currentStep, _s.draft);
    final next = (_s.stepIndex + 1).clamp(0, _s.steps.length - 1);
    final saved = await _repo.saveStep(answers, stepIndex: next);
    state = AsyncData(_s.copyWith(draft: saved, stepIndex: next));
  }

  /// Going back records the step so a mid-flow exit resumes in the right place,
  /// and keeps whatever was entered on the screen being left.
  Future<void> back() async {
    if (!state.hasValue || _s.isFirst) return;
    final answers = answersForStep(_s.currentStep, _s.draft);
    final prev = _s.stepIndex - 1;
    state = AsyncData(_s.copyWith(stepIndex: prev));
    await _repo.saveStep(answers, stepIndex: prev);
  }

  /// `PATCH /patient/me/details` — the Verify-your-information step's only
  /// write, fired by "Save & next". The step's fields live in memory purely so
  /// the form can be edited; this is where they are persisted, and the server's
  /// response replaces them so what the UI shows is what the server stored.
  Future<void> savePatientDetails() async {
    if (!state.hasValue) return;
    final p = _s.profile;
    // The multi-selects hold what the user sees, which can include free text
    // typed into an "Other" box. The API takes enum members only, so coerce at
    // the boundary: free text becomes `other`, and `none` drops everything else.
    // Applied to server-loaded values too, so one bad legacy row cannot make
    // every subsequent save fail.
    final saved = await _repo.savePatientDetails({
      'name': p.fullName,
      'date_of_birth': p.dateOfBirth,
      'gender': p.gender,
      'primary_diagnosis': p.primaryDiagnosis,
      'diagnosed_at': p.diagnosedDate,
      'other_conditions': PatientProfileOptions.forApi(
        p.otherConditions,
        PatientProfileOptions.otherConditions,
      ),
      'current_medications': PatientProfileOptions.forApi(
        p.currentMedications,
        PatientProfileOptions.medications,
      ),
      'current_supplements': PatientProfileOptions.forApi(
        p.currentSupplements,
        PatientProfileOptions.supplements,
      ),
    });
    if (!state.hasValue) return;
    // Keep the auth-derived gender, which drives the dynamic step count.
    state = AsyncData(
      _s.copyWith(
        profile: saved.gender.isEmpty
            ? saved.copyWith(gender: p.gender)
            : saved,
      ),
    );
  }

  /// Finalize: persist the last step's answers, then `POST /onboarding/complete`.
  Future<CompletionResult> complete() async {
    await _repo.saveStep(
      answersForStep(_s.currentStep, _s.draft),
      stepIndex: _s.stepIndex,
    );
    return _repo.complete();
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

// ── Connected-source detection (device step) ─────────────────────────────────

/// Maps raw platform health-data type strings to the display category key
/// used in the connect step UI ('vitals', 'activity', 'wellness').
const _kSourceTypeToCategory = <String, String>{
  'BLOOD_GLUCOSE': 'vitals',
  'HEART_RATE': 'vitals',
  'RESTING_HEART_RATE': 'vitals',
  'HEART_RATE_VARIABILITY_SDNN': 'vitals',
  'HEART_RATE_VARIABILITY_RMSSD': 'vitals',
  'BLOOD_OXYGEN': 'vitals',
  'RESPIRATORY_RATE': 'vitals',
  'BLOOD_PRESSURE_SYSTOLIC': 'vitals',
  'BLOOD_PRESSURE_DIASTOLIC': 'vitals',
  'BODY_TEMPERATURE': 'vitals',
  'STEPS': 'activity',
  'ACTIVE_ENERGY_BURNED': 'activity',
  'BASAL_ENERGY_BURNED': 'activity',
  'TOTAL_CALORIES_BURNED': 'activity',
  'FLIGHTS_CLIMBED': 'activity',
  'WEIGHT': 'wellness',
  'HEIGHT': 'wellness',
  'BODY_FAT_PERCENTAGE': 'wellness',
  'LEAN_BODY_MASS': 'wellness',
  'SLEEP_ASLEEP': 'wellness',
  'SLEEP_SESSION': 'wellness',
  'SLEEP_DEEP': 'wellness',
  'SLEEP_LIGHT': 'wellness',
  'SLEEP_REM': 'wellness',
  'SLEEP_AWAKE': 'wellness',
  'MENSTRUATION_FLOW': 'wellness',
};

/// Requests Health Connect / HealthKit permission (shows the OS dialog), reads
/// recent samples, and surfaces distinct source app/device names grouped by
/// display category. State is `null` before detection, `AsyncLoading` during,
/// and `AsyncData(list)` after (possibly empty).
class ConnectedSourcesController extends AsyncNotifier<List<HealthSource>?> {
  @override
  Future<List<HealthSource>?> build() async => null;

  Future<void> detect() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(healthRepositoryProvider);
      await repo.requestPermissions(HealthMetricType.collectible);

      final raw = await repo.exportRawPlatformJson(
        lookback: const Duration(days: 365),
      );

      final providerName = ref
          .read(platformDataSourceProvider)
          .providerName
          .toLowerCase();

      // Build per-source category → raw-type-strings mapping.
      final sourceData = <String, Map<String, Set<String>>>{};
      for (final m in raw) {
        final s = m['sourceName'];
        final t = m['type'];
        if (s is String &&
            s.trim().isNotEmpty &&
            s.trim().toLowerCase() != providerName) {
          final name = s.trim();
          sourceData.putIfAbsent(name, () => {});
          if (t is String && t.trim().isNotEmpty) {
            final rawType = t.trim();
            final cat = _kSourceTypeToCategory[rawType];
            if (cat != null) {
              sourceData[name]!.putIfAbsent(cat, () => {});
              sourceData[name]![cat]!.add(rawType);
            }
          }
        }
      }

      final sources = sourceData.entries
          .map((e) => HealthSource(e.key, rawTypesByCategory: e.value))
          .toList();
      state = AsyncData(sources);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() => state = const AsyncData(null);
}

final connectedSourcesProvider =
    AsyncNotifierProvider<ConnectedSourcesController, List<HealthSource>?>(
      ConnectedSourcesController.new,
    );
