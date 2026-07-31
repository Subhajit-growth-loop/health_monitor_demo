import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';

// ── Shared utility functions ──────────────────────────────────────────────────

List<String> toggleSelection(List<String> list, String value) {
  final next = List<String>.from(list);
  next.contains(value) ? next.remove(value) : next.add(value);
  return next;
}

String titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `yyyy-MM-dd` → `14 March, 1974` (falls back to the raw string).
String prettyDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${monthsLong[d.month - 1]}, ${d.year}';
}

// ── Shared widget ─────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        text,
        style: NeuTypography.serif(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: s.onSurface,
        ),
      ),
    );
  }
}
