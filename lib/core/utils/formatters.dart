import 'package:intl/intl.dart';

import '../../features/health/domain/entities/health_metric_type.dart';

/// Presentation-layer value formatting.
class Fmt {
  Fmt._();

  static String metricValue(HealthMetricType type, double value) {
    if (type.decimals == 0) {
      return NumberFormat.decimalPattern().format(value.round());
    }
    return value.toStringAsFixed(type.decimals);
  }

  /// Compact label for Y-axis ticks: no locale separators, "k" suffix for
  /// values ≥ 1000, respects the type's decimal precision otherwise.
  static String yAxisLabel(HealthMetricType type, double value) {
    if (type.decimals == 0) {
      final n = value.round();
      if (n >= 1000) {
        final k = n / 1000;
        return '${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)}k';
      }
      return '$n';
    }
    return value.toStringAsFixed(type.decimals);
  }

  static String time(DateTime dt) => DateFormat.jm().format(dt);
  static String dayShort(DateTime dt) => DateFormat.E().format(dt); // Mon
  static String dayNum(DateTime dt) => DateFormat.d().format(dt); // 1
  static String monthShort(DateTime dt) => DateFormat.MMM().format(dt); // Jan
  static String dateShort(DateTime dt) => DateFormat('MMM d, yyyy').format(dt);
  static String dateTime(DateTime dt) => DateFormat('MMM d, h:mm a').format(dt);

  static String relative(DateTime? dt) {
    if (dt == null) return 'never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return DateFormat.MMMd().format(dt);
  }
}
