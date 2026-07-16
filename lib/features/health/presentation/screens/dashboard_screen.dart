import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/permission_state.dart';
import '../providers/dashboard_providers.dart';
import '../providers/permission_controller.dart';
import '../providers/sync_controller.dart';
import '../widgets/alert_banner.dart';
import '../widgets/metric_card.dart';
import '../widgets/sync_status_bar.dart';
import 'metric_detail_screen.dart';

Future<void> _handleGrantPermission(
  WidgetRef ref,
  HealthPermissionState perms,
) async {
  final anyDenied = perms.grants.values.any((g) => g == PermissionGrant.denied);

  // On iOS, once the user has denied, the OS will never show the dialog again.
  // We must send them to system Settings instead.
  if (Platform.isIOS && anyDenied) {
    await launchUrl(Uri.parse('app-settings:'));
    return;
  }
  await ref.read(permissionControllerProvider.notifier).requestAll();
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final permsAsync = ref.watch(permissionControllerProvider);
    final perms =
        permsAsync.valueOrNull ?? HealthPermissionState.allNotRequested();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16.w,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
            ),
            Text(
              'Your health at a glance',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh from Health platform',
            onPressed: () =>
                ref.read(syncControllerProvider.notifier).refreshData(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(syncControllerProvider.notifier).refreshData(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
            children: [
              const SyncStatusBar(),
              SizedBox(height: 12.h),
              const AlertBanner(),
              SizedBox(height: 8.h),
              if (!perms.anyGranted)
                _PermissionPrompt(
                  onGrant: () => ref
                      .read(permissionControllerProvider.notifier)
                      .requestAll(),
                ),
              summary.when(
                loading: () => Padding(
                  padding: EdgeInsets.only(top: 80.h),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: EdgeInsets.only(top: 40.h),
                  child: Center(child: Text('Could not load data: $e')),
                ),
                data: (values) => GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12.r,
                  crossAxisSpacing: 12.r,
                  childAspectRatio: 1.12,
                  children: [
                    for (final type in HealthMetricType.values)
                      MetricCard(
                        type: type,
                        value: values[type] ?? 0,
                        granted: perms.isGranted(type),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MetricDetailScreen(type: type),
                          ),
                        ),
                        onRequestPermission: () =>
                            _handleGrantPermission(ref, perms),
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

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.onGrant});
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Icon(Icons.privacy_tip_rounded, color: scheme.primary, size: 24.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Allow access to your health data to see your metrics.',
              style: TextStyle(fontSize: 13.sp),
            ),
          ),
          FilledButton(onPressed: onGrant, child: const Text('Allow')),
        ],
      ),
    );
  }
}
