/// The four wellbeing sliders on the "how are you feeling" step, each 0..1.
class Feeling {
  const Feeling({
    this.sleep = 0.5,
    this.energy = 0.5,
    this.stress = 0.5,
    this.mood = 0.5,
  });

  final double sleep;
  final double energy;
  final double stress;
  final double mood;

  factory Feeling.fromJson(Map<String, dynamic> json) => Feeling(
    sleep: (json['sleep'] as num?)?.toDouble() ?? 0.5,
    energy: (json['energy'] as num?)?.toDouble() ?? 0.5,
    stress: (json['stress'] as num?)?.toDouble() ?? 0.5,
    mood: (json['mood'] as num?)?.toDouble() ?? 0.5,
  );

  Map<String, dynamic> toJson() => {
    'sleep': sleep,
    'energy': energy,
    'stress': stress,
    'mood': mood,
  };

  Feeling copyWith({
    double? sleep,
    double? energy,
    double? stress,
    double? mood,
  }) => Feeling(
    sleep: sleep ?? this.sleep,
    energy: energy ?? this.energy,
    stress: stress ?? this.stress,
    mood: mood ?? this.mood,
  );
}

/// All of the user's onboarding answers. Persisted to the API after every step
/// so navigating back re-hydrates exactly what was saved.
class OnboardingDraft {
  const OnboardingDraft({
    this.motivations = const [],
    this.supportTypes = const [],
    this.activityLevel,
    this.eatingRhythm,
    this.sleepHours = 7,
    this.dietaryPrefs = const [],
    this.menstrualCycle,
    this.symptoms = const [],
    this.feeling = const Feeling(),
    this.note = '',
    this.connectChoice,
    this.connectedSources = const [],
    this.firstAction,
  });

  /// Step 2 — "What brought you to Neu?" (multi).
  final List<String> motivations;

  /// Step 2 — "What kind of support…" chips (multi).
  final List<String> supportTypes;

  /// Step 3 — activity level / eating rhythm / sleep / dietary prefs.
  final String? activityLevel;
  final String? eatingRhythm;
  final int sleepHours;
  final List<String> dietaryPrefs;

  /// Step 4 — menstrual cycle (female only).
  final String? menstrualCycle;

  /// Step 5 — recent symptoms (multi).
  final List<String> symptoms;

  /// Step 6 — wellbeing sliders.
  final Feeling feeling;

  /// Step 7 — free-text note.
  final String note;

  /// Step 8 — 'connected' | 'later'.
  final String? connectChoice;
  final List<String> connectedSources;

  /// Step 10 — chosen first small action.
  final String? firstAction;

  static List<String> _strList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  factory OnboardingDraft.fromJson(Map<String, dynamic> json) =>
      OnboardingDraft(
        motivations: _strList(json['motivations']),
        supportTypes: _strList(json['supportTypes']),
        activityLevel: json['activityLevel'] as String?,
        eatingRhythm: json['eatingRhythm'] as String?,
        sleepHours: (json['sleepHours'] as num?)?.toInt() ?? 7,
        dietaryPrefs: _strList(json['dietaryPrefs']),
        menstrualCycle: json['menstrualCycle'] as String?,
        symptoms: _strList(json['symptoms']),
        feeling: json['feeling'] is Map
            ? Feeling.fromJson(
                Map<String, dynamic>.from(json['feeling'] as Map),
              )
            : const Feeling(),
        note: json['note'] as String? ?? '',
        connectChoice: json['connectChoice'] as String?,
        connectedSources: _strList(json['connectedSources']),
        firstAction: json['firstAction'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'motivations': motivations,
    'supportTypes': supportTypes,
    'activityLevel': activityLevel,
    'eatingRhythm': eatingRhythm,
    'sleepHours': sleepHours,
    'dietaryPrefs': dietaryPrefs,
    'menstrualCycle': menstrualCycle,
    'symptoms': symptoms,
    'feeling': feeling.toJson(),
    'note': note,
    'connectChoice': connectChoice,
    'connectedSources': connectedSources,
    'firstAction': firstAction,
  };

  OnboardingDraft copyWith({
    List<String>? motivations,
    List<String>? supportTypes,
    String? activityLevel,
    String? eatingRhythm,
    int? sleepHours,
    List<String>? dietaryPrefs,
    String? menstrualCycle,
    List<String>? symptoms,
    Feeling? feeling,
    String? note,
    String? connectChoice,
    List<String>? connectedSources,
    String? firstAction,
  }) => OnboardingDraft(
    motivations: motivations ?? this.motivations,
    supportTypes: supportTypes ?? this.supportTypes,
    activityLevel: activityLevel ?? this.activityLevel,
    eatingRhythm: eatingRhythm ?? this.eatingRhythm,
    sleepHours: sleepHours ?? this.sleepHours,
    dietaryPrefs: dietaryPrefs ?? this.dietaryPrefs,
    menstrualCycle: menstrualCycle ?? this.menstrualCycle,
    symptoms: symptoms ?? this.symptoms,
    feeling: feeling ?? this.feeling,
    note: note ?? this.note,
    connectChoice: connectChoice ?? this.connectChoice,
    connectedSources: connectedSources ?? this.connectedSources,
    firstAction: firstAction ?? this.firstAction,
  );
}
