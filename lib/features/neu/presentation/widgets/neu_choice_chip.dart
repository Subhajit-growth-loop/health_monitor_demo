import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';

/// A pill choice chip. Selected → filled [NeuColors.primary] with white text;
/// unselected → white with a subtle border. Used for support types, eating
/// rhythm, and recent symptoms.
class NeuChoiceChip extends StatelessWidget {
  const NeuChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: selected ? NeuColors.primary : NeuColors.darkCard,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? NeuColors.primary : NeuColors.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }
}
