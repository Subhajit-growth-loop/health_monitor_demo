import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../../../domain/entities/health_source.dart';
import '../../view_model/onboarding_view_model.dart';
import '../neu_radio_tile.dart';

// ── Option catalogues ─────────────────────────────────────────────────────────

/// Maps raw platform health-data type strings to the short display label shown
/// in brackets under each connect-step category header.
const _kRawTypeLabel = <String, String>{
  'BLOOD_GLUCOSE': 'Glucose',
  'HEART_RATE': 'Heart Rate',
  'RESTING_HEART_RATE': 'Resting HR',
  'HEART_RATE_VARIABILITY_SDNN': 'HRV',
  'HEART_RATE_VARIABILITY_RMSSD': 'HRV',
  'BLOOD_OXYGEN': 'SpO₂',
  'RESPIRATORY_RATE': 'Resp. Rate',
  'BLOOD_PRESSURE_SYSTOLIC': 'Blood Pressure',
  'BLOOD_PRESSURE_DIASTOLIC': 'Blood Pressure',
  'BODY_TEMPERATURE': 'Body Temp',
  'STEPS': 'Steps',
  'ACTIVE_ENERGY_BURNED': 'Active Energy',
  'BASAL_ENERGY_BURNED': 'Resting Energy',
  'TOTAL_CALORIES_BURNED': 'Total Calories',
  'FLIGHTS_CLIMBED': 'Floors',
  'WEIGHT': 'Weight',
  'HEIGHT': 'Height',
  'BODY_FAT_PERCENTAGE': 'Body Fat',
  'LEAN_BODY_MASS': 'Lean Mass',
  'SLEEP_ASLEEP': 'Sleep',
  'SLEEP_SESSION': 'Sleep',
  'SLEEP_DEEP': 'Deep Sleep',
  'SLEEP_LIGHT': 'Light Sleep',
  'SLEEP_REM': 'REM Sleep',
  'SLEEP_AWAKE': 'Awake',
  'MENSTRUATION_FLOW': 'Menstruation',
};

// ── Step 8: Connect devices ───────────────────────────────────────────────────

class ConnectStep extends ConsumerStatefulWidget {
  const ConnectStep({super.key});

  @override
  ConsumerState<ConnectStep> createState() => _ConnectStepState();
}

class _ConnectStepState extends ConsumerState<ConnectStep> {
  static const _cats = [
    ('vitals', 'Vitals', Icons.favorite_rounded),
    ('activity', 'Activity', Icons.directions_walk_rounded),
    ('wellness', 'Wellness', Icons.self_improvement_rounded),
  ];

  /// User-chosen source per display category.
  final Map<String, String?> _selectedByCategory = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reset connect completion so the CTA is disabled while detection runs.
      final ctrl = ref.read(onboardingControllerProvider.notifier);
      final state = ref.read(onboardingControllerProvider).valueOrNull;
      if (state != null) {
        ctrl.editDraft(state.draft.copyWith(connectChoice: null));
      }
      ref.read(connectedSourcesProvider.notifier).detect();
    });
  }

  /// True when every category that has at least one source has a selection.
  /// Categories with 0 sources are skipped.
  bool _isComplete() {
    final async = ref.read(connectedSourcesProvider);
    if (async.isLoading) return false;
    if (async.hasError) return true; // let user proceed past errors
    final sources = async.value;
    if (sources == null) return false;
    for (final (cat, _, _) in _cats) {
      final n = sources.where((s) => s.hasCategory(cat)).length;
      if (n >= 1 && _selectedByCategory[cat] == null) return false;
    }
    return true;
  }

  /// Writes the current selection + completion flag into the draft.
  void _syncToDraft() {
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final state = ref.read(onboardingControllerProvider).valueOrNull;
    if (state == null) return;
    final selected =
        _selectedByCategory.values.whereType<String>().toSet().toList();
    ctrl.editDraft(state.draft.copyWith(
      connectChoice: _isComplete() ? 'done' : null,
      connectedSources: selected,
    ));
  }

  void _selectSource(String catKey, String sourceName) {
    setState(() {
      _selectedByCategory[catKey] =
          _selectedByCategory[catKey] == sourceName ? null : sourceName;
    });
    _syncToDraft();
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final sourcesAsync = ref.watch(connectedSourcesProvider);

    // When sources load: auto-select single-source categories, then sync.
    ref.listen(connectedSourcesProvider, (_, next) {
      if (next.hasError) {
        _syncToDraft();
        return;
      }
      if (!next.hasValue || next.value == null) return;
      final sources = next.value!;
      for (final (cat, _, _) in _cats) {
        final catSources =
            sources.where((s) => s.hasCategory(cat)).toList();
        if (catSources.length == 1 && _selectedByCategory[cat] == null) {
          _selectedByCategory[cat] = catSources.first.name;
        }
      }
      _syncToDraft();
      // setState not needed — _syncToDraft triggers a provider update which
      // rebuilds this widget via ref.watch(connectedSourcesProvider).
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sourcesAsync.when(
          loading: () => const DetectingRow(),
          error: (e, _) => const ConnectMessage(
            'Could not read your health sources. '
            'You can connect from Settings later.',
          ),
          data: (sources) {
            if (sources == null) return const DetectingRow();
            return _buildGroupedSources(sources);
          },
        ),
        SizedBox(height: 16.h),
        Center(
          child: Text(
            'You can connect additional sources from Settings at any time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: s.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedSources(List<HealthSource> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _cats.length; i++) ...[
          if (i > 0) SizedBox(height: 20.h),
          _buildCategorySection(_cats[i].$1, _cats[i].$2, _cats[i].$3, sources),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
    String catKey,
    String label,
    IconData icon,
    List<HealthSource> allSources,
  ) {
    final surface = NeuSurface.of(context);
    final catSources =
        allSources.where((s) => s.hasCategory(catKey)).toList();

    final typeLabels = catSources
        .expand((s) => s.rawTypesByCategory[catKey] ?? const <String>{})
        .map((t) => _kRawTypeLabel[t])
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final selected = _selectedByCategory[catKey];
    final needsChoice = catSources.isNotEmpty && selected == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18.r, color: NeuColors.primary),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: surface.onSurface,
              ),
            ),
            if (typeLabels.isNotEmpty) ...[
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  '(${typeLabels.join(', ')})',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: surface.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (needsChoice) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: NeuColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: NeuColors.primary,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    catSources.length > 1
                        ? 'Multiple sources found — select one to continue'
                        : 'Select a source to connect your $label data',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: NeuColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 10.h),
        if (catSources.isEmpty)
          NoSourceMessage(category: label)
        else
          Column(
            children: [
              for (final s in catSources) ...[
                NeuRadioTile(
                  label: s.name,
                  selected: selected == s.name,
                  onTap: () => _selectSource(catKey, s.name),
                ),
                SizedBox(height: 8.h),
              ],
            ],
          ),
      ],
    );
  }
}

class DetectingRow extends StatelessWidget {
  const DetectingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: NeuColors.primary,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          'Checking your connected apps…',
          style: TextStyle(fontSize: 15.sp, color: s.textMuted),
        ),
      ],
    );
  }
}

class ConnectMessage extends StatelessWidget {
  const ConnectMessage(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: s.accent,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: s.emphasis,
            size: 20,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: s.emphasis,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoSourceMessage extends StatelessWidget {
  const NoSourceMessage({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: s.textMuted,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'No $category source found currently. You can choose a source '
              'from Settings later.',
              style: TextStyle(
                fontSize: 13.sp,
                color: s.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
