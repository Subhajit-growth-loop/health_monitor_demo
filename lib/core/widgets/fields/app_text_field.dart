import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../neu_text_field.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.errorText,
    this.hasError = false,
    this.enabled = true,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.suffixText,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.readOnly = false,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool hasError;
  final bool enabled;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffix;
  final String? suffixText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final bool readOnly;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return NeuTextField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      errorText: errorText,
      enabled: enabled,
      maxLength: maxLength,
      prefixIcon: prefixIcon,
      suffixIcon: suffix,
      onChanged: onChanged,
      onTap: onTap,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      readOnly: readOnly,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
    );
  }
}
