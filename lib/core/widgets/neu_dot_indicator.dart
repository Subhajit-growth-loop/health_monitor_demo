import 'package:flutter/material.dart';

/// Animated dot progress indicator used on splash and feature screens.
///
/// The active dot expands into a pill; inactive dots shrink to circles.
class NeuDotIndicator extends StatelessWidget {
  const NeuDotIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.activeColor = Colors.white,
    this.inactiveColor,
    this.dotSize = 7.0,
    this.spacing = 5.0,
  });

  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color? inactiveColor;
  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final inactive = inactiveColor ?? activeColor.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          width: isActive ? dotSize * 2.4 : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactive,
            borderRadius: BorderRadius.circular(dotSize),
          ),
        );
      }),
    );
  }
}
