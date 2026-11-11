import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable dropdown form field matching the clean label and border design system.
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;
  final bool isRequired;
  final bool enabled;
  final bool isDarkTheme;
  final String? helperText;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.isRequired = false,
    this.enabled = true,
    this.isDarkTheme = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final activeFocusColor = isDarkTheme ? AppColors.primaryGold : AppColors.warmGold;
    final iconColor = isDarkTheme ? AppColors.primaryGold : AppColors.warmGold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Row with red asterisk for mandatory fields
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppColors.darkCharcoal : AppColors.secondaryText,
                  letterSpacing: 0.1,
                ),
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
          ],
        ),
        const SizedBox(height: 6),

        DropdownButtonFormField<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.secondaryText,
            size: 22,
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.darkCharcoal : AppColors.secondaryText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText.withValues(alpha: 0.65),
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF7F8FA),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: iconColor, size: 20)
                : null,
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

