import 'package:flutter/material.dart';

/// How a metric's samples should be combined over a period.
enum Aggregation { sum, average, latest }

/// Logical grouping used to organise the dashboard into sections.
enum HealthCategory {
  vitals('Vitals'),
  activity('Activity'),
  body('Body'),
  sleep('Sleep'),
  wellness('Wellness');

  const HealthCategory(this.label);
  final String label;
}

/// The set of health metrics the app understands.
///
/// This is the "common internal schema" the Normalization layer maps
/// platform-specific HealthKit / Health Connect types into, so the rest of
/// the app stays completely platform-agnostic.
///
/// Metrics are triaged for a glucose-first metabolic twin (MASLD + midlife
/// women) across three tiers:
///
///  * **Headline** — `collect: true`, `hiddenFromDashboard: false`: the core
///    metabolic/liver story, shown on the dashboard.
///  * **Collect, quiet** — `collect: true`, `hiddenFromDashboard: true`:
///    clinically useful context (OSA proxies, sleep stages, body composition)
///    that earns a consent-sheet row but is only surfaced on drill-down or
///    when abnormal.
///  * **Not requested** — `collect: false`: defined for future use but never
///    added to the permission request, so it never costs a consent-sheet row.
///    Every requested type is another row on the HealthKit/Health Connect
///    consent sheet, and grant rates fall sharply past ~10–12 permissions —
///    fatal for a product that lives on data completeness.
enum HealthMetricType {
  // ── Vitals ────────────────────────────────────────────────────────────
  bloodGlucose(
    id: 'blood_glucose',
    label: 'Blood Glucose',
    unit: 'mg/dL',
    icon: Icons.water_drop_rounded,
    color: Color(0xFFD63031),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
  ),
  heartRate(
    id: 'heart_rate',
    label: 'Heart Rate',
    unit: 'bpm',
    icon: Icons.favorite_rounded,
    color: Color(0xFFE0245E),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
  ),
  restingHeartRate(
    id: 'resting_heart_rate',
    label: 'Resting HR',
    unit: 'bpm',
    icon: Icons.monitor_heart_outlined,
    color: Color(0xFFC2185B),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
  ),
  // HRV underlying measure DIFFERS by platform: SDNN on HealthKit, RMSSD on
  // Health Connect (see RealHealthPlatformDataSource._dataTypes). A single
  // user's series is internally consistent; cohort-level comparison across
  // platforms must account for the SDNN vs RMSSD difference.
  heartRateVariability(
    id: 'hrv',
    label: 'HRV',
    unit: 'ms',
    icon: Icons.stacked_line_chart_rounded,
    color: Color(0xFF26A69A),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
  ),
  bloodPressureSystolic(
    id: 'bp_systolic',
    label: 'Blood Pressure',
    unit: 'mmHg',
    icon: Icons.monitor_heart_rounded,
    color: Color(0xFF6C5CE7),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
  ),
  bloodPressureDiastolic(
    id: 'bp_diastolic',
    label: 'BP Diastolic',
    unit: 'mmHg',
    icon: Icons.monitor_heart_rounded,
    color: Color(0xFF6C5CE7),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
    hiddenFromDashboard: true,
  ),
  // OSA proxies (OSA ↔ MASLD) — collected, surfaced only when abnormal.
  bloodOxygen(
    id: 'blood_oxygen',
    label: 'Blood Oxygen',
    unit: '%',
    icon: Icons.bloodtype_rounded,
    color: Color(0xFF0984E3),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
    hiddenFromDashboard: true,
  ),
  respiratoryRate(
    id: 'respiratory_rate',
    label: 'Respiratory Rate',
    unit: 'br/min',
    icon: Icons.air_rounded,
    color: Color(0xFF00BCD4),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
    hiddenFromDashboard: true,
  ),
  // Cycle-tracking context — noisy otherwise.
  bodyTemperature(
    id: 'body_temperature',
    label: 'Body Temp',
    unit: '°C',
    icon: Icons.thermostat_rounded,
    color: Color(0xFFFF7043),
    aggregation: Aggregation.average,
    decimals: 1,
    category: HealthCategory.vitals,
    hiddenFromDashboard: true,
  ),

  // ── Activity ──────────────────────────────────────────────────────────
  steps(
    id: 'steps',
    label: 'Steps',
    unit: 'steps',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF00A388),
    aggregation: Aggregation.sum,
    decimals: 0,
    category: HealthCategory.activity,
  ),
  activeEnergy(
    id: 'active_energy',
    label: 'Active Energy',
    unit: 'kcal',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF39C12),
    aggregation: Aggregation.sum,
    decimals: 0,
    category: HealthCategory.activity,
  ),
  // Not requested — redundant with activeEnergy + weight until energy-balance
  // math exists. Defined for future use; costs no consent-sheet row.
  basalEnergy(
    id: 'basal_energy',
    label: 'Resting Energy',
    unit: 'kcal',
    icon: Icons.local_fire_department_outlined,
    color: Color(0xFFE67E22),
    aggregation: Aggregation.sum,
    decimals: 0,
    category: HealthCategory.activity,
    collect: false,
    hiddenFromDashboard: true,
  ),
  totalCalories(
    id: 'total_calories',
    label: 'Total Energy',
    unit: 'kcal',
    icon: Icons.whatshot_rounded,
    color: Color(0xFFD35400),
    aggregation: Aggregation.sum,
    decimals: 0,
    category: HealthCategory.activity,
    collect: false,
    hiddenFromDashboard: true,
  ),
  flightsClimbed(
    id: 'flights_climbed',
    label: 'Flights Climbed',
    unit: 'floors',
    icon: Icons.stairs_rounded,
    color: Color(0xFF16A085),
    aggregation: Aggregation.sum,
    decimals: 0,
    category: HealthCategory.activity,
    collect: false,
    hiddenFromDashboard: true,
  ),

  // ── Body ──────────────────────────────────────────────────────────────
  weight(
    id: 'weight',
    label: 'Weight',
    unit: 'kg',
    icon: Icons.monitor_weight_rounded,
    color: Color(0xFF00B894),
    aggregation: Aggregation.latest,
    decimals: 1,
    category: HealthCategory.body,
  ),
  // Collected as a profile-style latest value (needed to derive BMI); not a
  // headline time series. BMI itself is derived (weight / height²), not
  // collected — it has no Health Connect record type anyway.
  height(
    id: 'height',
    label: 'Height',
    unit: 'cm',
    icon: Icons.height_rounded,
    color: Color(0xFF0097A7),
    aggregation: Aggregation.latest,
    decimals: 0,
    category: HealthCategory.body,
    hiddenFromDashboard: true,
  ),
  bodyFat(
    id: 'body_fat',
    label: 'Body Fat',
    unit: '%',
    icon: Icons.percent_rounded,
    color: Color(0xFFF57C00),
    aggregation: Aggregation.latest,
    decimals: 1,
    category: HealthCategory.body,
    hiddenFromDashboard: true,
  ),
  leanBodyMass(
    id: 'lean_body_mass',
    label: 'Lean Mass',
    unit: 'kg',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFF7CB342),
    aggregation: Aggregation.latest,
    decimals: 1,
    category: HealthCategory.body,
    hiddenFromDashboard: true,
  ),

  // ── Sleep ─────────────────────────────────────────────────────────────
  sleep(
    id: 'sleep',
    label: 'Sleep',
    unit: 'h',
    icon: Icons.bedtime_rounded,
    color: Color(0xFF6C5CE7),
    aggregation: Aggregation.sum,
    decimals: 1,
    category: HealthCategory.sleep,
  ),
  // Stage breakdown — for the sleep detail view, not the dashboard.
  sleepDeep(
    id: 'sleep_deep',
    label: 'Deep Sleep',
    unit: 'h',
    icon: Icons.dark_mode_rounded,
    color: Color(0xFF512DA8),
    aggregation: Aggregation.sum,
    decimals: 1,
    category: HealthCategory.sleep,
    hiddenFromDashboard: true,
  ),
  sleepLight(
    id: 'sleep_light',
    label: 'Light Sleep',
    unit: 'h',
    icon: Icons.nightlight_rounded,
    color: Color(0xFF7E57C2),
    aggregation: Aggregation.sum,
    decimals: 1,
    category: HealthCategory.sleep,
    hiddenFromDashboard: true,
  ),
  sleepRem(
    id: 'sleep_rem',
    label: 'REM Sleep',
    unit: 'h',
    icon: Icons.bedtime_outlined,
    color: Color(0xFF9575CD),
    aggregation: Aggregation.sum,
    decimals: 1,
    category: HealthCategory.sleep,
    hiddenFromDashboard: true,
  ),
  sleepAwake(
    id: 'sleep_awake',
    label: 'Awake',
    unit: 'h',
    icon: Icons.wb_twilight_rounded,
    color: Color(0xFFB39DDB),
    aggregation: Aggregation.sum,
    decimals: 1,
    category: HealthCategory.sleep,
    hiddenFromDashboard: true,
  ),

  // ── Wellness ──────────────────────────────────────────────────────────
  // Needed for the perimenopause / cycle overlay in onboarding.
  menstruationFlow(
    id: 'menstruation_flow',
    label: 'Menstruation',
    unit: '',
    icon: Icons.female_rounded,
    color: Color(0xFFEC407A),
    aggregation: Aggregation.latest,
    decimals: 0,
    category: HealthCategory.wellness,
  );

  const HealthMetricType({
    required this.id,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.aggregation,
    required this.decimals,
    required this.category,
    this.collect = true,
    this.hiddenFromDashboard = false,
  });

  final String id;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final Aggregation aggregation;
  final int decimals;
  final HealthCategory category;

  /// Whether this type is included in the platform permission request and the
  /// acquisition sweep. `false` types are defined but never requested, so they
  /// add no row to the consent sheet.
  final bool collect;

  /// Whether this type is kept off the dashboard grid (still collected if
  /// [collect] is true — surfaced on drill-down / detail views only).
  final bool hiddenFromDashboard;

  /// The types actually requested from HealthKit / Health Connect and swept
  /// during acquisition — the headline + collect-quiet tiers.
  static List<HealthMetricType> get collectible =>
      values.where((t) => t.collect).toList(growable: false);

  static HealthMetricType fromId(String id) =>
      HealthMetricType.values.firstWhere((t) => t.id == id);

  static HealthMetricType? maybeFromId(String id) =>
      HealthMetricType.values.where((t) => t.id == id).firstOrNull;
}