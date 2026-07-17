import 'package:flutter/material.dart';

/// How a metric's samples should be combined over a period.
enum Aggregation { sum, average, latest }

/// The set of health metrics the app understands.
///
/// This is the "common internal schema" the Normalization layer maps
/// platform-specific HealthKit / Health Connect types into, so the rest of
/// the app stays completely platform-agnostic.
enum HealthMetricType {
  steps(
    id: 'steps',
    label: 'Steps',
    unit: 'steps',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF00A388),
    aggregation: Aggregation.sum,
    decimals: 0,
  ),
  heartRate(
    id: 'heart_rate',
    label: 'Heart Rate',
    unit: 'bpm',
    icon: Icons.favorite_rounded,
    color: Color(0xFFE0245E),
    aggregation: Aggregation.average,
    decimals: 0,
  ),
  sleep(
    id: 'sleep',
    label: 'Sleep',
    unit: 'h',
    icon: Icons.bedtime_rounded,
    color: Color(0xFF6C5CE7),
    aggregation: Aggregation.sum,
    decimals: 1,
  ),
  bloodOxygen(
    id: 'blood_oxygen',
    label: 'Blood Oxygen',
    unit: '%',
    icon: Icons.bloodtype_rounded,
    color: Color(0xFF0984E3),
    aggregation: Aggregation.average,
    decimals: 0,
  ),
  activeEnergy(
    id: 'active_energy',
    label: 'Active Energy',
    unit: 'kcal',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF39C12),
    aggregation: Aggregation.sum,
    decimals: 0,
  ),
  weight(
    id: 'weight',
    label: 'Weight',
    unit: 'kg',
    icon: Icons.monitor_weight_rounded,
    color: Color(0xFF00B894),
    aggregation: Aggregation.latest,
    decimals: 1,
  ),
  bloodGlucose(
    id: 'blood_glucose',
    label: 'Blood Glucose',
    unit: 'mg/dL',
    icon: Icons.water_drop_rounded,
    color: Color(0xFFD63031),
    aggregation: Aggregation.average,
    decimals: 0,
  );

  const HealthMetricType({
    required this.id,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.aggregation,
    required this.decimals,
  });

  final String id;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final Aggregation aggregation;
  final int decimals;

  static HealthMetricType fromId(String id) =>
      HealthMetricType.values.firstWhere((t) => t.id == id);

  static HealthMetricType? maybeFromId(String id) =>
      HealthMetricType.values.where((t) => t.id == id).firstOrNull;
}
