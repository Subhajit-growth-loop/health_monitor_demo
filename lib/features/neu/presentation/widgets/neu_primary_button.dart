import 'package:flutter/material.dart';

import '../../../../../core/theme/neu_colors.dart';

/// Full-width primary CTA button used across all Neu screens.
class NeuPrimaryButton extends StatelessWidget {
  const NeuPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 56.0,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: NeuColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: NeuColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}
