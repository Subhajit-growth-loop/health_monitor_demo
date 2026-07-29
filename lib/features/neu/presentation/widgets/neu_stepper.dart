import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';

/// A white card with a label and a `− value +` stepper (e.g. Typical Sleep).
class NeuStepper extends StatelessWidget {
  const NeuStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 24,
    this.unit = '',
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: NeuColors.darkCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: NeuColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14.sp, color: Colors.white),
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 60.w,
            child: Text(
              unit.isEmpty ? '$value' : '$value $unit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: NeuColors.primary,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.r,
        height: 36.r,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.white : Colors.white38,
        ),
      ),
    );
  }
}
