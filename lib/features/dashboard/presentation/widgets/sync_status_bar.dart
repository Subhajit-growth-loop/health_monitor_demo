import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/formatters.dart';
import '../view_model/health_view_model.dart';
import '../view_model/sync_controller.dart';

/// The small sync-status indicator described in the architecture doc: shows
/// online/offline state, pending-backup count and last sync time. Tapping the
/// offline chip toggles a simulated offline mode.
class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, Color color, String label) = switch (sync) {
      _ when !sync.online => (
          Icons.cloud_off_rounded,
          scheme.error,
          'Offline'
        ),
      _ when sync.phase == SyncPhase.syncing => (
          Icons.sync_rounded,
          scheme.primary,
          'Syncing…'
        ),
      _ when sync.phase == SyncPhase.error => (
          Icons.sync_problem_rounded,
          Colors.orange,
          'Retrying'
        ),
      _ when sync.hasPending => (
          Icons.cloud_upload_rounded,
          Colors.orange,
          '${sync.pending} pending'
        ),
      _ => (Icons.cloud_done_rounded, scheme.primary, 'Backed up'),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          if (sync.phase == SyncPhase.syncing)
            SizedBox(
              width: 16.r,
              height: 16.r,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 18.r, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp)),
                Text(
                  sync.online
                      ? 'Last sync ${Fmt.relative(sync.lastSyncedAt)}'
                      : 'Data saved locally · will sync when online',
                  style: TextStyle(
                      fontSize: 11.sp, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _offlineToggle(context, ref),
        ],
      ),
    );
  }

  // Rebuilds via the parent's watch on syncControllerProvider, whose `online`
  // field updates from the connectivity stream when the toggle fires.
  Widget _offlineToggle(BuildContext context, WidgetRef ref) {
    final conn = ref.read(connectivityServiceProvider);
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () {
        conn.setManualOffline(!conn.manualOffline);
        // Attempt a sync immediately if we just came back online.
        ref.read(syncControllerProvider.notifier).syncNow();
      },
      icon: Icon(
          conn.manualOffline
              ? Icons.airplanemode_active_rounded
              : Icons.airplanemode_inactive_rounded,
          size: 16.r),
      label: Text(conn.manualOffline ? 'Go online' : 'Go offline',
          style: TextStyle(fontSize: 11.sp)),
    );
  }
}
