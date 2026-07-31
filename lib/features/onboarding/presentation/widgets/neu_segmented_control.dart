import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/neu_colors.dart';

/// A segmented control (e.g. Low / Moderate / Active). The selected segment
/// gets a white "pill" with a soft shadow over the muted track.
class NeuSegmentedControl extends StatelessWidget {
  const NeuSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final trackColor = s.isDark ? s.card : NeuColors.warmFill;
    final selectedColor = s.isDark ? NeuColors.primary : Colors.white;
    final selectedTextColor = s.isDark ? Colors.white : s.onSurface;

    return Container(
      padding: EdgeInsets.all(5.r),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(vertical: 11.h),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == value ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: (!s.isDark && option == value)
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: option == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: option == value ? selectedTextColor : s.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
