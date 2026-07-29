import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';

/// A bordered radio option row (menstrual cycle, device options). Selected →
/// orange border + bold primaryDark label + filled ring.
class NeuRadioTile extends StatelessWidget {
  const NeuRadioTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.boxed = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When true the row is a bordered card; when false it's a bare radio + label.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        _RadioRing(selected: selected),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ],
    );

    if (!boxed) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: row,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: NeuColors.darkCard,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? NeuColors.primary : NeuColors.darkBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: row,
      ),
    );
  }
}

class _RadioRing extends StatelessWidget {
  const _RadioRing({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22.r,
      height: 22.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? NeuColors.primary : NeuColors.darkBorder,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10.r,
                height: 10.r,
                decoration: const BoxDecoration(
                  color: NeuColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
