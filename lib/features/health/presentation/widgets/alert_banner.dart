import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../providers/foreground_alert_provider.dart';

/// Displays a dismissible warning banner for each active health alert.
/// Rendered above the metrics grid in DashboardScreen.
class AlertBanner extends ConsumerWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violations = ref.watch(foregroundAlertProvider);
    if (violations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final v in violations)
          Dismissible(
            key: ValueKey(v.type),
            direction: DismissDirection.endToStart,
            onDismissed: (_) =>
                ref.read(foregroundAlertProvider.notifier).dismiss(v.type),
            child: Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: v.type.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                    color: v.type.color.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: v.type.color, size: 22.r),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.title,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: v.type.color,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          v.body,
                          style: TextStyle(
                              fontSize: 11.sp,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18.r,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5)),
                    onPressed: () => ref
                        .read(foregroundAlertProvider.notifier)
                        .dismiss(v.type),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: 6.h),
      ],
    );
  }
}