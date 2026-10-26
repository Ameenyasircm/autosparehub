import 'package:flutter/material.dart';

/// Centralized branding colors and theme configurations for Auto Spare Hub.
class AppColors {
  // Brand colors specified in requirements & user app mockup theme
  static const Color primaryGold = Color(0xFFE5A93C); // Vibrant warm gold from mockups
  static const Color darkCharcoal = Color(0xFF242834); // Softened obsidian charcoal for buttons & cards
  static const Color darkHeader = Color(0xFF1E222B); // Softened deep slate dark for top app bar header
  static const Color darkButton = Color(0xFF242834); // Softened charcoal for primary action buttons
  static const Color secondaryGold = Color(0xFFC3903C);
  static const Color lightGold = Color(0xFFF0CA7A);
  static const Color warmGold = Color(0xFFE5A93C);

  // Suggested UI & background colors matching mockups
  static const Color backgroundLight = Color(0xFFF4F6F9); // Clean cool off-white
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF222733); // Softened deep slate text
  static const Color secondaryText = Color(0xFF6B7280);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);

  // Mockup pill badges & stepper colors
  static const Color badgeGoldBg = Color(0xFFFFF9EE);
  static const Color badgeGoldBorder = Color(0xFFE5A93C);
  static const Color badgeGoldText = Color(0xFFC3903C);
  static const Color stepperBg = Color(0xFFFDE8C7);
  static const Color borderLight = Color(0xFFDDE1E6);
  static const Color cardBorder = Color(0xFFEDEFF2);
  static const Color borderSoft = Color(0xFFCBD2DD); // Gentle outline border
  static const Color dividerLight = Color(0xFFEDEFF3); // Soft, clean light divider

  // Dark palette accents for Admin portal
  static const Color darkSurface = Color(0xFF1A1C20);
  static const Color darkCard = Color(0xFF22262B);
  static const Color darkCardBorder = Color(0xFF333840);
  static const Color textLight = Color(0xFFF7F7F5);
  static const Color textMuted = Color(0xFF9EA3AC);
  static const Color goldBorder = Color(0x40C3903C);
  static const Color goldHighlight = Color(0x1AC3903C);
}

class AppTheme {
  /// User Storefront Theme matching the provided design system mockups
  static ThemeData get userTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.warmGold,
        onPrimary: AppColors.darkButton,
        secondary: AppColors.secondaryGold,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.cardLight,
        onSurface: AppColors.primaryText,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkButton,
          foregroundColor: AppColors.warmGold,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkButton,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.borderLight, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9EA3AC),
          fontSize: 13.5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.warmGold, width: 1.6),
        ),
      ),
      dividerColor: AppColors.dividerLight,
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Admin Portal Light Theme with dark charcoal and gold highlights
  static ThemeData get adminTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryGold,
        onPrimary: AppColors.darkCharcoal,
        secondary: AppColors.secondaryGold,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.cardLight,
        onSurface: AppColors.primaryText,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.lightGold),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          foregroundColor: AppColors.darkCharcoal,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: AppColors.secondaryText.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        prefixIconColor: AppColors.primaryGold,
        suffixIconColor: AppColors.secondaryText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E4E8), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E4E8), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 2,
        shadowColor: AppColors.darkCharcoal.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCharcoal,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: AppColors.dividerLight,
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
