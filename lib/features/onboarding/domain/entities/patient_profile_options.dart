/// Canonical option values for the patient medical profile.
///
/// Verified against the backend enum lists for `PATCH /patient/me/details` —
/// values, labels and order all match. A value the server doesn't recognise
/// comes back as a 422 naming the offending array index, e.g.
/// `current_supplements.6 — Input should be 'vitamin_d', … 'none' or 'other'`.
///
/// Three server-side rules are encoded here so the client can honour them:
///
///  * `none` is exclusive — it cannot be combined with any other value.
///  * [medications] and [supplements] accept **free text**: `other` is only a UI
///    affordance, and sending it bare is rejected with
///    *"'other' is not an answer on its own — send the name of what the patient
///    takes instead"*. So a typed name travels as typed, and a bare `other` is
///    dropped.
///  * [primaryDiagnosis] and [otherConditions] are strict enums with no `other`
///    member, so an unrecognised value has nowhere to go and is dropped.
///
/// The distinction is derived from whether a list defines an `other` member,
/// which is exactly the set of fields that take free text.
abstract final class PatientProfileOptions {
  /// `(value sent to the API, label shown to the user)`.
  static const List<(String, String)> primaryDiagnosis = [
    ('masld', 'MASLD'), ('mash', 'MASH'), ('prediabetes', 'Prediabetes'),
    ('type_2_diabetes', 'Type 2 Diabetes'), ('obesity', 'Obesity'),
    ('metabolic_syndrome', 'Metabolic Syndrome'), ('pcos', 'PCOS'),
    ('hypertension', 'Hypertension'), ('high_cholesterol', 'High Cholesterol'),
    ('none', 'None of the above'),
  ];

  static const List<(String, String)> otherConditions = [
    ('prediabetes', 'Prediabetes'), ('type_2_diabetes', 'Type 2 Diabetes'),
    ('hypertension', 'Hypertension'), ('high_cholesterol', 'High Cholesterol'),
    ('obesity', 'Obesity'), ('pcos', 'PCOS'), ('sleep_apnea', 'Sleep Apnea'),
    ('hypothyroidism', 'Hypothyroidism'), ('depression', 'Depression'),
    ('anxiety', 'Anxiety'), ('none', 'None'),
  ];

  static const List<(String, String)> medications = [
    ('metformin', 'Metformin'), ('ozempic', 'Ozempic (Semaglutide)'),
    ('mounjaro', 'Mounjaro (Tirzepatide)'), ('wegovy', 'Wegovy'),
    ('jardiance', 'Jardiance'), ('insulin', 'Insulin'), ('statin', 'Statin'),
    ('blood_pressure_medication', 'Blood Pressure Medication'),
    ('none', 'None'), ('other', 'Other'),
  ];

  static const List<(String, String)> supplements = [
    ('vitamin_d', 'Vitamin D'), ('vitamin_b12', 'Vitamin B12'),
    ('omega_3', 'Omega-3'), ('magnesium', 'Magnesium'),
    ('probiotics', 'Probiotics'), ('milk_thistle', 'Milk Thistle'),
    ('turmeric', 'Turmeric / Curcumin'), ('multivitamin', 'Multivitamin'),
    ('none', 'None'), ('other', 'Other'),
  ];

  /// The value the server uses for "none of these".
  static const String noneValue = 'none';

  /// The value the server uses for "something not listed".
  static const String otherValue = 'other';

  static Set<String> valuesOf(List<(String, String)> options) =>
      {for (final (value, _) in options) value};

  /// Coerces [selected] into something the API will accept, without changing
  /// what the user sees on screen.
  ///
  /// * A bare `other` is always dropped — the server treats it as a non-answer.
  /// * Free text survives on the lists that accept it (those defining an `other`
  ///   member) and is dropped on the strict-enum lists.
  /// * `none` wins outright over everything else.
  ///
  /// Also applied to values loaded from the server, so one bad row can't make
  /// every later save fail. Order is preserved and duplicates dropped.
  static List<String> forApi(
    List<String> selected,
    List<(String, String)> options,
  ) {
    if (selected.isEmpty) return const [];

    final allowed = valuesOf(options);
    // A list offering "Other" is one the server expects a typed name on.
    final acceptsFreeText = allowed.contains(otherValue);

    final out = <String>[];
    for (final value in selected) {
      // "'other' is not an answer on its own" — the typed name carries it.
      if (value == otherValue) continue;

      final keep = allowed.contains(value) || acceptsFreeText;
      if (keep && !out.contains(value)) out.add(value);
    }

    // `none` cannot travel with anything else.
    if (out.contains(noneValue)) return const [noneValue];
    return out;
  }
}