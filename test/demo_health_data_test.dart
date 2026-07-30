import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/features/health/data/demo/demo_health_data.dart';
import 'package:health_monitor_demo/features/health/domain/entities/daily_point.dart';
import 'package:health_monitor_demo/features/health/domain/entities/health_metric_type.dart';

void main() {
  // Fixed "now" so day-boundary arithmetic is not time-of-run dependent.
  final now = DateTime(2026, 7, 30, 22, 0);

  group('shape of the generated data', () {
    test('every metric type produces readings', () {
      for (final type in HealthMetricType.values) {
        expect(
          DemoHealthData.records(type, now: now),
          isNotEmpty,
          reason: '${type.id} generated nothing',
        );
      }
    });

    test('covers 6 days with 2-3 readings each', () {
      for (final type in HealthMetricType.values) {
        final byDay = <DateTime, int>{};
        for (final r in DemoHealthData.records(type, now: now)) {
          final day = DateTime(
            r.timestamp.year,
            r.timestamp.month,
            r.timestamp.day,
          );
          byDay[day] = (byDay[day] ?? 0) + 1;
        }
        expect(byDay.keys, hasLength(6), reason: type.id);
        for (final count in byDay.values) {
          expect(count, inInclusiveRange(2, 3), reason: type.id);
        }
      }
    });

    test('no reading is in the future', () {
      for (final type in HealthMetricType.values) {
        for (final r in DemoHealthData.records(type, now: now)) {
          expect(r.timestamp.isAfter(now), isFalse, reason: type.id);
        }
      }
    });

    test('values are positive and carry the metric unit', () {
      for (final type in HealthMetricType.values) {
        for (final r in DemoHealthData.records(type, now: now)) {
          expect(r.value, greaterThan(0), reason: type.id);
          expect(r.unit, type.unit);
        }
      }
    });

    test('whole-number metrics get whole numbers', () {
      for (final type in HealthMetricType.values.where((t) => t.decimals == 0)) {
        for (final r in DemoHealthData.records(type, now: now)) {
          expect(r.value, r.value.roundToDouble(), reason: type.id);
        }
      }
    });

    test('records are newest-first, matching the repository', () {
      final records = DemoHealthData.records(HealthMetricType.steps, now: now);
      for (var i = 1; i < records.length; i++) {
        expect(
          records[i - 1].timestamp.isAfter(records[i].timestamp) ||
              records[i - 1].timestamp == records[i].timestamp,
          isTrue,
        );
      }
    });

    test('generated records are tagged as sample data, not a real device', () {
      for (final r in DemoHealthData.records(HealthMetricType.weight)) {
        expect(r.source, 'Sample data');
      }
    });
  });

  group('determinism', () {
    test('the same type yields identical values across calls', () {
      final a = DemoHealthData.records(HealthMetricType.bloodGlucose, now: now);
      final b = DemoHealthData.records(HealthMetricType.bloodGlucose, now: now);
      expect(a.map((r) => r.value).toList(), b.map((r) => r.value).toList());
    });

    test('different types yield different values', () {
      final glucose = DemoHealthData.summaryValue(HealthMetricType.bloodGlucose);
      final hr = DemoHealthData.summaryValue(HealthMetricType.heartRate);
      expect(glucose, isNot(hr));
    });
  });

  group('plausibility of the headline metrics', () {
    test('glucose sits in a believable mg/dL band', () {
      final v = DemoHealthData.summaryValue(HealthMetricType.bloodGlucose);
      expect(v, inInclusiveRange(60, 180));
    });

    test('daily steps land in a believable range', () {
      final v = DemoHealthData.summaryValue(HealthMetricType.steps);
      expect(v, inInclusiveRange(2000, 15000));
    });

    test('sleep totals a plausible number of hours', () {
      final v = DemoHealthData.summaryValue(HealthMetricType.sleep);
      expect(v, inInclusiveRange(3, 12));
    });

    test('summed metrics exceed any single reading, averaged ones do not', () {
      Iterable<double> todaysReadings(HealthMetricType type) =>
          DemoHealthData.records(type, now: now)
              .where((r) => r.timestamp.day == now.day)
              .map((r) => r.value);

      final stepsMax = todaysReadings(HealthMetricType.steps)
          .reduce((a, b) => a > b ? a : b);
      expect(
        DemoHealthData.summaryValue(HealthMetricType.steps),
        greaterThan(stepsMax),
      );

      final hrMax = todaysReadings(HealthMetricType.heartRate)
          .reduce((a, b) => a > b ? a : b);
      expect(
        DemoHealthData.summaryValue(HealthMetricType.heartRate),
        lessThanOrEqualTo(hrMax),
      );
    });
  });

  group('daily series', () {
    test('returns the requested length, newest first', () {
      final series = DemoHealthData.dailySeries(
        HealthMetricType.steps,
        length: 14,
        now: now,
      );
      expect(series, hasLength(14));
      expect(series.first.day.isAfter(series.last.day), isTrue);
    });

    test('only the trailing 6 days carry values', () {
      final series = DemoHealthData.dailySeries(
        HealthMetricType.steps,
        length: 14,
        now: now,
      );
      expect(series.take(6).every((p) => p.value > 0), isTrue);
      expect(series.skip(6).every((p) => p.value == 0), isTrue);
    });

    test('a shorter request is not padded past its length', () {
      expect(
        DemoHealthData.dailySeries(HealthMetricType.sleep, length: 3, now: now),
        hasLength(3),
      );
    });
  });

  group('isSeriesEmpty decides when the fallback kicks in', () {
    final day = DateTime(2026, 7, 30);

    test('an empty list counts as empty', () {
      expect(DemoHealthData.isSeriesEmpty(const []), isTrue);
    });

    test('all-zero values count as empty', () {
      expect(
        DemoHealthData.isSeriesEmpty([
          DailyPoint(day: day, value: 0),
          DailyPoint(day: day, value: 0),
        ]),
        isTrue,
      );
    });

    test('one real value is enough to keep the real series', () {
      expect(
        DemoHealthData.isSeriesEmpty([
          DailyPoint(day: day, value: 0),
          DailyPoint(day: day, value: 42),
        ]),
        isFalse,
      );
    });
  });
}