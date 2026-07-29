import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';

/// A labelled checkbox row. Selected label turns [NeuColors.primaryDark] and
/// bold, matching the onboarding checklist design.
class NeuCheckboxTile extends StatelessWidget {
  const NeuCheckboxTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            Container(
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                color: selected ? NeuColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: selected ? NeuColors.primary : NeuColors.darkBorder,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
