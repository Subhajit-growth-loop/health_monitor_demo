import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';

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
    return Container(
      padding: EdgeInsets.all(5.r),
      decoration: BoxDecoration(
        color: NeuColors.inputBorder.withValues(alpha: 0.5),
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
                    color: option == value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: option == value
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
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
                      color: option == value
                          ? NeuColors.textDark
                          : NeuColors.textSecondary,
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
