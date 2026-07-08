import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';

/// A weekly trend chart. Sum-based metrics (steps, energy, sleep) render as
/// bars; continuous metrics (heart rate, SpO2) render as a line.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.type, required this.points});

  final HealthMetricType type;
  final List<DailyPoint> points;

  bool get _isBar => type.aggregation == Aggregation.sum;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
          height: 200.h, child: const Center(child: Text('No data yet')));
    }
    return SizedBox(
      height: 220.h,
      child: _isBar ? _buildBars(context) : _buildLine(context),
    );
  }

  double get _maxValue {
    final m = points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b);
    return m == 0 ? 1 : m * 1.25;
  }

  Widget _bottomTitle(BuildContext context, double value) {
    final i = value.toInt();
    if (i < 0 || i >= points.length) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Text(Fmt.dayShort(points[i].day),
          style: TextStyle(
              fontSize: 11.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  FlTitlesData _titles(BuildContext context) => FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40.w,
            getTitlesWidget: (v, _) => Text(
              Fmt.metricValue(type, v),
              style: TextStyle(
                  fontSize: 10.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28.h,
            getTitlesWidget: (v, _) => _bottomTitle(context, v),
          ),
        ),
      );

  Widget _buildBars(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: _maxValue,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _titles(context),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: points[i].value,
                color: type.color,
                width: 16.w,
                borderRadius: BorderRadius.circular(6.r),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildLine(BuildContext context) {
    return LineChart(
      LineChartData(
        maxY: _maxValue,
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _titles(context),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            color: type.color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: type.color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
