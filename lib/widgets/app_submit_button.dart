import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable action & submission button for Auto Spare Hub forms.
/// Modeled directly after the high-conversion clean button pattern:
/// - Prominent height (50px) with 12px rounded borders.
/// - Integrated spinner and informative status text during loading.
/// - Clear iconography and bold label when ready for action.
class AppSubmitButton extends StatelessWidget {
  final String label;
  final String? loadingLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;
  final double borderRadius;
  final bool isSecondary;

  const AppSubmitButton({
    super.key,
    required this.label,
    this.loadingLabel,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ??
        (isSecondary ? Colors.white : AppColors.darkButton);
    final effectiveFg = foregroundColor ??
        (isSecondary ? AppColors.darkButton : AppColors.warmGold);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBg,
          foregroundColor: effectiveFg,
          disabledBackgroundColor: effectiveBg.withValues(alpha: 0.65),
          disabledForegroundColor: effectiveFg.withValues(alpha: 0.8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: isSecondary
                ? const BorderSide(color: Color(0xFFDDE1E6), width: 1.2)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      loadingLabel ?? 'Please wait...',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: effectiveFg,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: effectiveFg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: effectiveFg,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

