import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/settings/app_settings.dart';
import '../providers/sync_controller.dart';

/// Settings + manual sync page. Also the destination of the 48h catch-up
/// notification: when [autoLookBack] is true it kicks off a trailing-window
/// re-sync on open.
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key, this.autoLookBack = false});

  final bool autoLookBack;

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLookBack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(syncControllerProvider.notifier)
            .lookBackSync(window: kCatchUpThreshold);
      });
    }
  }

  String _relative(DateTime? t) {
    if (t == null) return 'never';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(syncSettingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final busy = sync.phase == SyncPhase.syncing;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
          children: [
            // ── Status card ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sync.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: sync.online ? scheme.primary : scheme.error,
                        size: 22.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        sync.online ? 'Online' : 'Offline',
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (busy)
                        SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _statRow('Last synced', _relative(sync.lastSyncedAt)),
                  _statRow('Pending upload', '${sync.pending} records'),
                  if (sync.message != null) ...[
                    SizedBox(height: 6.h),
                    Text(sync.message!,
                        style: TextStyle(
                            fontSize: 12.sp, color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // ── Manual actions ─────────────────────────────────────────────
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () =>
                      ref.read(syncControllerProvider.notifier).refreshData(),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sync now'),
            ),
            SizedBox(height: 10.h),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => ref
                      .read(syncControllerProvider.notifier)
                      .lookBackSync(window: kCatchUpThreshold),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Catch up last 48 hours'),
            ),
            SizedBox(height: 24.h),
            Divider(color: scheme.outlineVariant),
            SizedBox(height: 8.h),

            // ── Auto-sync settings ─────────────────────────────────────────
            Text('Automatic sync',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 4.h),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-sync in foreground'),
              subtitle: Text(
                'Fetch from Health and upload periodically while the app is open',
                style: TextStyle(fontSize: 12.sp),
              ),
              value: settings.autoSync,
              onChanged: (v) =>
                  ref.read(syncSettingsProvider.notifier).setAutoSync(v),
            ),
            Opacity(
              opacity: settings.autoSync ? 1 : 0.4,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sync every'),
                trailing: DropdownButton<int>(
                  value: settings.intervalMinutes,
                  onChanged: settings.autoSync
                      ? (v) {
                          if (v != null) {
                            ref
                                .read(syncSettingsProvider.notifier)
                                .setIntervalMinutes(v);
                          }
                        }
                      : null,
                  items: [
                    for (final m in kSyncIntervalOptions)
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Background sync runs separately about every 15 minutes and once '
              'daily, even when auto-sync is off.',
              style: TextStyle(fontSize: 11.sp, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13.sp)),
            Text(value,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
