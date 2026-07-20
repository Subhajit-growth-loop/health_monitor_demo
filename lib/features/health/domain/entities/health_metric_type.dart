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
/// The set covers every data type the `health` package exposes on BOTH iOS
/// (HealthKit) and Android (Health Connect) as a numeric time-series sample —
/// the maximum overlap that works identically on both platforms.
enum HealthMetricType {
  // ── Vitals ────────────────────────────────────────────────────────────
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
  bloodOxygen(
    id: 'blood_oxygen',
    label: 'Blood Oxygen',
    unit: '%',
    icon: Icons.bloodtype_rounded,
    color: Color(0xFF0984E3),
    aggregation: Aggregation.average,
    decimals: 0,
    category: HealthCategory.vitals,
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
  bodyTemperature(
    id: 'body_temperature',
    label: 'Body Temp',
    unit: '°C',
    icon: Icons.thermostat_rounded,
    color: Color(0xFFFF7043),
    aggregation: Aggregation.average,
    decimals: 1,
    category: HealthCategory.vitals,
  ),
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
  basalEnergy(
    id: 'basal_energy',
    label: 'Resting Energy',
    unit: 'kcal',
    icon: Icons.local_fire_department_outlined,
    color: Color(0xFFE67E22),
    aggregation: Aggregation.sum,
    decimals: 0,
    category: HealthCategory.activity,
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
  height(
    id: 'height',
    label: 'Height',
    unit: 'cm',
    icon: Icons.height_rounded,
    color: Color(0xFF0097A7),
    aggregation: Aggregation.latest,
    decimals: 0,
    category: HealthCategory.body,
  ),
  bmi(
    id: 'bmi',
    label: 'BMI',
    unit: '',
    icon: Icons.straighten_rounded,
    color: Color(0xFF00897B),
    aggregation: Aggregation.latest,
    decimals: 1,
    category: HealthCategory.body,
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
  sleepDeep(
    id: 'sleep_deep',
    label: 'Deep Sleep',
    unit: 'h',
    icon: Icons.dark_mode_rounded,
    color: Color(0xFF512DA8),
    aggregation: Aggregation.sum,
    decimals: 1,
    category: HealthCategory.sleep,
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
  ),

  // ── Wellness ──────────────────────────────────────────────────────────
  water(
    id: 'water',
    label: 'Water',
    unit: 'L',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF039BE5),
    aggregation: Aggregation.sum,
    decimals: 2,
    category: HealthCategory.wellness,
  ),
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
  final bool hiddenFromDashboard;

  static HealthMetricType fromId(String id) =>
      HealthMetricType.values.firstWhere((t) => t.id == id);

  static HealthMetricType? maybeFromId(String id) =>
      HealthMetricType.values.where((t) => t.id == id).firstOrNull;
}