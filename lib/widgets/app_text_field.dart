import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Reusable, clean, and elegant form text field for Auto Spare Hub.
/// Follows the modern form UX pattern:
/// - Prominent label row with separate red asterisk for mandatory fields.
/// - Uncongested, instructional placeholder hint.
/// - Clean 12px rounded borders with soft default border and vibrant theme focus.
/// - Integrated prefix and suffix icons with brand styling.
class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final IconData? suffixIcon;
  final Widget? suffixWidget;
  final bool isRequired;
  final String? Function(String?)? validator;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final String? helperText;
  final Widget? badge;
  final bool isDarkTheme;
  final FocusNode? focusNode;
  final bool readOnly;
  final VoidCallback? onTap;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.suffixWidget,
    this.isRequired = false,
    this.validator,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.helperText,
    this.badge,
    this.isDarkTheme = false,
    this.focusNode,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeFocusColor = isDarkTheme ? AppColors.primaryGold : AppColors.warmGold;
    final iconColor = isDarkTheme ? AppColors.primaryGold : AppColors.warmGold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Label Row with red asterisk for mandatory fields
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: enabled ? AppColors.darkCharcoal : AppColors.secondaryText,
                letterSpacing: 0.1,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
            if (badge != null) ...[
              const Spacer(),
              badge!,
            ],
          ],
        ),
        const SizedBox(height: 6),

        // 2. Text Form Field with clean, spacious styling
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          enabled: enabled,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.darkCharcoal : AppColors.secondaryText,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText.withValues(alpha: 0.65),
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF7F8FA),
            prefixIcon: prefixWidget ??
                (prefixIcon != null
                    ? Icon(prefixIcon, color: iconColor, size: 20)
                    : null),
            suffixIcon: suffixWidget ??
                (suffixIcon != null
                    ? Icon(suffixIcon, color: AppColors.secondaryText, size: 20)
                    : null),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE1E6), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE1E6), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: activeFocusColor, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFECEFF3), width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.8),
            ),
          ),
        ),

        // 3. Optional helper text below field
        if (helperText != null && helperText!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            helperText!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

