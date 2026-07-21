import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/permission_state.dart';
import '../providers/dashboard_providers.dart';
import '../providers/health_providers.dart';
import '../providers/permission_controller.dart';
import '../providers/sync_controller.dart';
import '../widgets/alert_banner.dart';
import '../widgets/metric_card.dart';
import '../widgets/sync_status_bar.dart';
import 'metric_detail_screen.dart';
import 'sync_settings_screen.dart';

Future<void> _handleGrantPermission(
  WidgetRef ref,
  HealthPermissionState perms,
) async {
  final anyDenied = perms.grants.values.any((g) => g == PermissionGrant.denied);

  if (Platform.isIOS && anyDenied) {
    await launchUrl(Uri.parse('app-settings:'));
    return;
  }
  await ref.read(permissionControllerProvider.notifier).requestAll();
}

/// Bottom sheet offering the two export delivery modes, then runs the chosen
/// one and reports the outcome. Writes a JSON file in the `health` package's
/// own record shape (works on both HealthKit and Health Connect).
Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
  final mode = await showModalBottomSheet<_ExportMode>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Export health data (JSON)',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Share'),
            subtitle: const Text('Send via the share sheet or Save to Files'),
            onTap: () => Navigator.of(sheetContext).pop(_ExportMode.share),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Save to device'),
            subtitle: const Text('Write the file to your device storage'),
            onTap: () => Navigator.of(sheetContext).pop(_ExportMode.save),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    ),
  );

  if (mode == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(healthExportServiceProvider);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing export…')),
  );

  try {
    final export = mode == _ExportMode.share
        ? await service.share()
        : await service.save();
    messenger.hideCurrentSnackBar();
    if (export == null) {
      // User dismissed the save picker — nothing to report.
      return;
    }
    if (export.recordCount == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No health data to export. Grant access and refresh first.',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mode == _ExportMode.save
                ? 'Saved ${export.recordCount} records to device.'
                : 'Exported ${export.recordCount} records.',
          ),
        ),
      );
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Export failed: $e')),
    );
  }
}

enum _ExportMode { share, save }

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (_isSameDay(date, today)) return 'Today';
  if (_isSameDay(date, yesterday)) return 'Yesterday';
  return Fmt.dateShort(date);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final summary = ref.watch(todaySummaryProvider);
    final permsAsync = ref.watch(permissionControllerProvider);
    final perms =
        permsAsync.valueOrNull ?? HealthPermissionState.allNotRequested();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _isSameDay(selectedDate, today);
    final dateLabel = _dateLabel(selectedDate);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            SizedBox(width: 4.w),
            IconButton(
              icon: Icon(Icons.chevron_left_rounded, size: 24.r),
              tooltip: 'Previous day',
              onPressed: () {
                ref.read(selectedDateProvider.notifier).state =
                    selectedDate.subtract(const Duration(days: 1));
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: today,
                  );
                  if (picked != null && context.mounted) {
                    ref.read(selectedDateProvider.notifier).state =
                        DateTime(picked.year, picked.month, picked.day);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down_rounded, size: 20.r),
                      ],
                    ),
                    Text(
                      'Your health at a glance',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 24.r,
                color: isToday
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3)
                    : null,
              ),
              tooltip: 'Next day',
              onPressed: isToday
                  ? null
                  : () {
                      ref.read(selectedDateProvider.notifier).state =
                          selectedDate.add(const Duration(days: 1));
                    },
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export health data as JSON',
            onPressed: () => _handleExport(context, ref),
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Refresh from Health platform',
            onPressed: () =>
                ref.read(syncControllerProvider.notifier).refreshData(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sync settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
            ),
            icon: const Icon(Icons.sync_rounded),
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
                data: (values) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in HealthCategory.values)
                      _CategorySection(
                        category: category,
                        values: values,
                        perms: perms,
                        onOpen: (type) => Navigator.of(context).push(
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

/// One dashboard section per [HealthCategory]: a header followed by a grid of
/// that category's (non-hidden) metric cards.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.values,
    required this.perms,
    required this.onOpen,
    required this.onRequestPermission,
  });

  final HealthCategory category;
  final Map<HealthMetricType, double> values;
  final HealthPermissionState perms;
  final void Function(HealthMetricType) onOpen;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final types = HealthMetricType.values
        .where((t) => t.category == category && !t.hiddenFromDashboard)
        .toList(growable: false);
    if (types.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 8.h, 4.w, 12.h),
          child: Text(
            category.label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12.r,
          crossAxisSpacing: 12.r,
          childAspectRatio: 1.12,
          children: [
            for (final type in types)
              MetricCard(
                type: type,
                value: values[type] ?? 0,
                secondaryValue:
                    type == HealthMetricType.bloodPressureSystolic
                        ? values[HealthMetricType.bloodPressureDiastolic]
                        : null,
                granted: perms.isGranted(type),
                onTap: () => onOpen(type),
                onRequestPermission: onRequestPermission,
              ),
          ],
        ),
        SizedBox(height: 8.h),
      ],
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
