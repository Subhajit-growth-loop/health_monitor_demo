import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/session/app_error_handler.dart';
import '../../../../core/session/current_user.dart';
import '../../../../core/session/token_manager.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../view_model/health_view_model.dart';
import 'sync_settings_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../onboarding/presentation/view_model/onboarding_view_model.dart';

// ── Export helpers ────────────────────────────────────────────────────────────

Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
  final mode = await showModalBottomSheet<_ExportMode>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Export health data (JSON)',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Share'),
            subtitle: const Text('Send via the share sheet or Save to Files'),
            onTap: () => Navigator.of(ctx).pop(_ExportMode.share),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Save to device'),
            subtitle: const Text('Write the file to your device storage'),
            onTap: () => Navigator.of(ctx).pop(_ExportMode.save),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    ),
  );

  if (mode == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(healthExportServiceProvider);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing export…')));
  try {
    final export = mode == _ExportMode.share
        ? await service.share()
        : await service.save();
    messenger.hideCurrentSnackBar();
    if (export == null) return;
    if (export.recordCount == 0) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'No health data to export. Grant access and refresh first.'),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(
          mode == _ExportMode.save
              ? 'Saved ${export.recordCount} records (${export.sizeLabel}) to device.'
              : 'Exported ${export.recordCount} records (${export.sizeLabel}).',
        ),
      ));
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

enum _ExportMode { share, save }

// ── Logout ────────────────────────────────────────────────────────────────────

/// Ends the session: `POST /auth/logout` with the stored refresh token, then
/// clears local credentials and returns to the login screen.
///
/// The local session is cleared even when the network call fails — a user who
/// asked to log out must not stay signed in on the device because the server
/// was unreachable. The API error is still surfaced.
Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
          "You'll need to sign in again to see your health data."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: NeuColors.primary),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(onboardingRepositoryProvider);
  final refreshToken = TokenManager.instance.refreshToken;

  String? apiError;
  try {
    if (refreshToken != null) {
      await repo.logout(refreshToken);
    }
    // No refresh token stored — nothing for the server to revoke, so the local
    // clear below is the whole logout.
  } catch (e) {
    apiError = AppErrorHandler.instance.handle(e, context: 'Logout');
  }

  await TokenManager.instance.clearToken();
  await CurrentUser.instance.clear();
  final prefs = ref.read(sharedPreferencesProvider);
  await Future.wait<void>([
    clearSyncPrefsOnLogout(prefs),
    prefs.remove('neu_health_permissions_requested'),
    ref.read(localDataSourceProvider).clearAll(),
  ]);

  if (!context.mounted) return;
  if (apiError != null) {
    messenger.showSnackBar(
      SnackBar(content: Text('Signed out locally — $apiError')),
    );
  }
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

// ── Profile Screen ────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final isDarkMode = isDark;
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final cardBg = isDark ? NeuColors.darkCard : Colors.white;
    final cardBorder =
        isDark ? NeuColors.darkBorder : NeuColors.inputBorder;
    final subtle =
        isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 40.h),
        children: [
          Text(
            'Profile',
            style: NeuTypography.serif(fontSize: 24.sp, color: fg),
          ),
          SizedBox(height: 24.h),
          _SectionLabel(label: 'Appearance', isDark: isDark),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: cardBorder),
            ),
            child: _ProfileTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark mode',
              isDark: isDark,
              trailing: Switch(
                value: isDarkMode,
                onChanged: (v) => ref
                    .read(themeModeProvider.notifier)
                    .setMode(v ? ThemeMode.dark : ThemeMode.light),
                activeThumbColor: NeuColors.primary,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          _SectionLabel(label: 'Data', isDark: isDark),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.sync_rounded,
                  title: 'Sync settings',
                  isDark: isDark,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: subtle,
                    size: 20.r,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SyncSettingsScreen()),
                  ),
                ),
                Divider(height: 0, color: cardBorder, indent: 52.w),
                _ProfileTile(
                  icon: Icons.download_rounded,
                  title: 'Export health data',
                  isDark: isDark,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: subtle,
                    size: 20.r,
                  ),
                  onTap: () => _handleExport(context, ref),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _SectionLabel(label: 'Account', isDark: isDark),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                if (CurrentUser.instance.email.isNotEmpty)
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            color: NeuColors.primary, size: 20.r),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (CurrentUser.instance.name.isNotEmpty)
                                Text(
                                  CurrentUser.instance.name,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: fg,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              Text(
                                CurrentUser.instance.email,
                                style:
                                    TextStyle(fontSize: 12.sp, color: subtle),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (CurrentUser.instance.email.isNotEmpty)
                  Divider(height: 0, color: cardBorder, indent: 52.w),
                _ProfileTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  isDark: isDark,
                  titleColor: const Color(0xFFD63031),
                  iconColor: const Color(0xFFD63031),
                  onTap: () => _handleLogout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: isDark ? NeuColors.darkTextMuted : NeuColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.isDark,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Overrides for destructive actions (log out).
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = titleColor ?? (isDark ? Colors.white : NeuColors.textDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? NeuColors.primary, size: 20.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
