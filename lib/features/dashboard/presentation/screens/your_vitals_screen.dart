import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/health_metric_type.dart';
import '../view_model/dashboard_view_model.dart';
import '../widgets/static_sparkline.dart';
import 'metric_detail_screen.dart';

// Fixed metric lists per display section.
// Blood pressure is represented by the systolic type; the card shows both values.
const _vitalsMetrics = [
  HealthMetricType.bloodGlucose,
  HealthMetricType.steps,
  HealthMetricType.bloodPressureSystolic,
  HealthMetricType.weight,
  HealthMetricType.heartRate,
];

const _activityMetrics = [
  HealthMetricType.sleep,
];

const _wellnessMetrics = [
  HealthMetricType.menstruationFlow, // shown only for female users
];

class YourVitalsScreen extends ConsumerWidget {
  const YourVitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final fg = isDark ? Colors.white : NeuColors.textDark;

    final gender =
        ref.read(sharedPreferencesProvider).getString('neu_gender') ?? '';
    final isFemale = gender.trim().toLowerCase() == 'female';

    return Scaffold(
      backgroundColor:
          isDark ? NeuColors.darkBackground : NeuColors.screenBackground,
      body: SafeArea(
        child: ListView(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: isDark ? NeuColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isDark
                              ? NeuColors.darkBorder
                              : NeuColors.inputBorder,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? Colors.white : NeuColors.textDark,
                        size: 20.r,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'Your vitals',
                    style: NeuTypography.serif(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder),
            SizedBox(height: 8.h),

            _VitalsSection(
              label: 'VITALS',
              metrics: _vitalsMetrics,
              isDark: isDark,
            ),
            _VitalsSection(
              label: 'ACTIVITY',
              metrics: _activityMetrics,
              isDark: isDark,
            ),
            if (isFemale)
              _VitalsSection(
                label: 'WELLNESS',
                metrics: _wellnessMetrics,
                isDark: isDark,
              ),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}

class _VitalsSection extends ConsumerWidget {
  const _VitalsSection({
    required this.label,
    required this.metrics,
    required this.isDark,
  });

  final String label;
  final List<HealthMetricType> metrics;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    final summary = ref.watch(todaySummaryProvider).valueOrNull ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          child: Text(
            label,
            style: NeuTypography.sans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? NeuColors.darkTextMuted : NeuColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 0.9,
            mainAxisSpacing: 12.r,
            crossAxisSpacing: 12.r,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final type in metrics)
                _VitalsCard(
                  type: type,
                  value: summary[type] ?? 0.0,
                  diastolicValue: type == HealthMetricType.bloodPressureSystolic
                      ? (summary[HealthMetricType.bloodPressureDiastolic] ?? 0.0)
                      : null,
                  isDark: isDark,
                ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
      ],
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({
    required this.type,
    required this.value,
    required this.isDark,
    this.diastolicValue,
  });

  final HealthMetricType type;
  final double value;
  final double? diastolicValue;
  final bool isDark;

  String _sleepLabel(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m avg';
  }

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MetricDetailScreen(type: type)),
      ),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: isDark ? NeuColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Container(
                  width: 32.r,
                  height: 32.r,
                  decoration: BoxDecoration(
                    color: NeuColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9.r),
                  ),
                  child: Icon(type.icon,
                      color: NeuColors.primary, size: 18.r),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    type == HealthMetricType.bloodPressureSystolic
                        ? 'Blood Pressure'
                        : type.label,
                    style: NeuTypography.sans(
                      fontSize: 12.sp,
                      color: fg,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: subtle,
                  size: 16.r,
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Static sparkline
            StaticSparkline(type: type),

            SizedBox(height: 6.h),

            // Value
            if (value == 0)
              Text('—', style: NeuTypography.serif(fontSize: 18.sp, color: fg))
            else if (type == HealthMetricType.sleep)
              Text(
                _sleepLabel(value),
                style: NeuTypography.serif(
                    fontSize: 18.sp, fontWeight: FontWeight.w700, color: fg),
              )
            else if (type == HealthMetricType.bloodPressureSystolic &&
                diastolicValue != null &&
                diastolicValue! > 0)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${Fmt.metricValue(type, value)}/${Fmt.metricValue(HealthMetricType.bloodPressureDiastolic, diastolicValue!)}',
                    style: NeuTypography.serif(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: fg),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    type.unit,
                    style: NeuTypography.sans(fontSize: 11.sp, color: subtle),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    Fmt.metricValue(type, value),
                    style: NeuTypography.serif(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: fg),
                  ),
                  if (type.unit.isNotEmpty) ...[
                    SizedBox(width: 4.w),
                    Text(
                      type.unit,
                      style:
                          NeuTypography.sans(fontSize: 11.sp, color: subtle),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
