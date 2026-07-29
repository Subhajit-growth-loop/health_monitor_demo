import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../health/domain/entities/health_metric_type.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../data/datasources/remote/onboarding_api.dart';
import '../../data/repositories/onboarding_repository_impl.dart';
import '../../domain/entities/health_source.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../../domain/entities/onboarding_results.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/onboarding_repository.dart';

// ── DI graph (mirrors health_providers.dart) ─────────────────────────────────

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
      if (s != OnboardingStep.cycle || profile.isFemale) s,
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
    final snapshot = await _repo.loadOnboarding();

    // Gender captured from the auth API (signup/login) is authoritative for the
    // dynamic step count; fall back to the profile the onboarding API returned.
    final storedGender =
        ref.read(sharedPreferencesProvider).getString('neu_gender');
    final profile = (storedGender != null && storedGender.isNotEmpty)
        ? snapshot.profile.copyWith(gender: storedGender)
        : snapshot.profile;

    return OnboardingState(
      profile: profile,
      draft: snapshot.draft,
      stepIndex: 0,
    );
  }

  OnboardingState get _s => state.value!;

  /// Local-only edit of the draft (as the user toggles options). Persisted on
  /// [saveAndNext].
  void editDraft(OnboardingDraft draft) {
    if (!state.hasValue) return;
    state = AsyncData(_s.copyWith(draft: draft));
  }

  /// Inline profile edit — persists immediately via `PATCH /profile`.
  Future<void> updateProfile(Map<String, dynamic> changes) async {
    if (!state.hasValue) return;
    final updated = await _repo.updateProfile(changes);
    state = AsyncData(_s.copyWith(profile: updated));
  }

  /// Persist the current draft and advance to the next step.
  Future<void> saveAndNext() async {
    if (!state.hasValue) return;
    final saved = await _repo.saveStep(_s.draft.toJson());
    state = AsyncData(
      _s.copyWith(
        draft: saved,
        stepIndex: (_s.stepIndex + 1).clamp(0, _s.steps.length - 1),
      ),
    );
  }

  void back() {
    if (!state.hasValue || _s.isFirst) return;
    state = AsyncData(_s.copyWith(stepIndex: _s.stepIndex - 1));
  }

  /// Finalize: persist the last step's answers, then `POST /onboarding/complete`.
  Future<CompletionResult> complete() async {
    await _repo.saveStep(_s.draft.toJson());
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
