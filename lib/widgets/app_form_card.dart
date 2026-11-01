import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Clean, elevated card container for grouping form fields into breathable sections.
/// Modeled after modern registration cards:
/// - Soft shadow and subtle border.
/// - Prominent section title with thematic icon and badge.
/// - Clean separator divider.
class AppFormCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final bool isRequired;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppFormCard({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.isRequired = false,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEFF3), width: 1.0),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x0A000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primaryGold),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const Divider(height: 22, color: Color(0xFFECEFF3)),
          child,
        ],
      ),
    );
  }
}

