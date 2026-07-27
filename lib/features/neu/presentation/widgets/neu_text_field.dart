import 'package:flutter/material.dart';

import '../../../../../core/theme/neu_colors.dart';

/// Labelled text field styled for the Neu brand.
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

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: NeuColors.textDark,
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: NeuColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: NeuColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: NeuColors.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: NeuColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red : NeuColors.inputBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red : NeuColors.primary,
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
