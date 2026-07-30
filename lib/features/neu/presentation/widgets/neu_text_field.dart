import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/neu_colors.dart';

/// Labelled text field styled for the Neu brand.
///
/// Set [dark] to `true` on dark-background screens (auth, onboarding).
class NeuTextField extends StatelessWidget {
  const NeuTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
    this.errorText,
    this.dark,
    this.maxLength,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final int? maxLength;

  /// Applied on every edit, including paste.
  final List<TextInputFormatter>? inputFormatters;

  /// Keyboard casing hint (the formatter still enforces the real casing).
  final TextCapitalization textCapitalization;

  /// Forces dark-theme colours. Null (the default) follows the active theme.
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final dark = this.dark ?? s.isDark;
    final hasError = errorText != null && errorText!.isNotEmpty;

    final labelColor = dark
        ? Colors.white.withValues(alpha: 0.87)
        : NeuColors.textDark;
    final inputTextColor = dark ? Colors.white : NeuColors.textDark;
    final hintColor = dark ? s.textMuted : NeuColors.textMuted;
    final fillColor = dark ? s.card : NeuColors.inputFill;
    final borderColor = dark ? s.border : NeuColors.inputBorder;
    const focusedBorderColor = NeuColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 7),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          focusNode: focusNode,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLengthEnforcement: maxLength != null ? MaxLengthEnforcement.enforced : null,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: inputTextColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: hintColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red : borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red : focusedBorderColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        // Error line rendered flush-left under the field (with a leading icon),
        // instead of the indented Material error subtext.
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
