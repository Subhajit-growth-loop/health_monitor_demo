import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/health_metric_type.dart';

/// A single metric tile on the dashboard grid.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.type,
    required this.value,
    required this.granted,
    this.onTap,
  });

  final HealthMetricType type;
  final double value;
  final bool granted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: granted ? onTap : null,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(type.icon, color: type.color, size: 20.r),
                  ),
                  const Spacer(),
                  if (granted)
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant, size: 20.r),
                ],
              ),
              const Spacer(),
              Text(type.label,
                  style: TextStyle(
                      fontSize: 13.sp, color: scheme.onSurfaceVariant)),
              SizedBox(height: 4.h),
              if (!granted)
                Text('Permission needed',
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: scheme.outline))
              else
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: Fmt.metricValue(type, value),
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      TextSpan(
                        text: ' ${type.unit}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
