import '../../features/dashboard/domain/entities/health_metric_type.dart';

/// A violated threshold produces this record, used by both the foreground
/// banner and the background notification.
class AlertViolation {
  const AlertViolation({
    required this.type,
    required this.title,
    required this.body,
  });

  final HealthMetricType type;
  final String title;
  final String body;
}

class AlertThreshold {
  const AlertThreshold({
    required this.type,
    this.min,
    this.max,
    required this.title,
    required this.body,
    this.activeAfterHour,
  });

  final HealthMetricType type;

  /// Alert if value < min (null = no lower bound).
  final double? min;

  /// Alert if value > max (null = no upper bound).
  final double? max;

  final String title;
  final String body;

  /// Only fire this alert after this hour of day (24h). Null = always check.
  /// Used for daily-total metrics (steps, energy) to avoid false positives
  /// early in the day.
  final int? activeAfterHour;

  bool isViolated(double value) {
    if (activeAfterHour != null && DateTime.now().hour < activeAfterHour!) {
      return false;
    }
    if (min != null && value < min!) return true;
    if (max != null && value > max!) return true;
    return false;
  }

  AlertViolation toViolation() =>
      AlertViolation(type: type, title: title, body: body);
}

/// Default health alert thresholds.
abstract final class AlertThresholds {
  static const List<AlertThreshold> defaults = [
    AlertThreshold(
      type: HealthMetricType.heartRate,
      min: 50,
      max: 100,
      title: 'Heart Rate Alert',
      body:
          'Your resting heart rate is outside the normal range (50–100 bpm). '
          'Consider checking with a healthcare provider.',
    ),
    AlertThreshold(
      type: HealthMetricType.bloodOxygen,
      min: 95,
      title: 'Low Blood Oxygen',
      body:
          'Your blood oxygen level is below 95%. '
          'If this persists, seek medical advice.',
    ),
    AlertThreshold(
      type: HealthMetricType.steps,
      min: 5000,
      title: 'Low Activity Today',
      body:
          'You have fewer than 5,000 steps today. '
          'Try a short walk to stay active.',
      activeAfterHour: 20, // only alert after 8 PM
    ),
    AlertThreshold(
      type: HealthMetricType.sleep,
      min: 6,
      title: 'Low Sleep Detected',
      body:
          'You slept less than 6 hours last night. '
          'Aim for 7–9 hours for optimal health.',
    ),
    AlertThreshold(
      type: HealthMetricType.activeEnergy,
      min: 200,
      title: 'Low Activity Energy',
      body:
          'You have burned fewer than 200 kcal of active energy today. '
          'Try to move more throughout the day.',
      activeAfterHour: 18, // only alert after 6 PM
    ),
  ];

  /// Check a today-summary map and return all violated thresholds.
  static List<AlertViolation> check(Map<HealthMetricType, double> summary) {
    final violations = <AlertViolation>[];
    for (final threshold in defaults) {
      final value = summary[threshold.type] ?? 0;
      if (threshold.isViolated(value)) {
        violations.add(threshold.toViolation());
      }
    }
    return violations;
  }
}
