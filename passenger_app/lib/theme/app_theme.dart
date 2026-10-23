import 'package:flutter/material.dart';

class AppColors {
  // Vibrant Electric Orange & Obsidian Dark Palette (matching reference UI)
  static const Color primary = Color(0xFFFF5E18);        // Vibrant Electric Orange
  static const Color primaryLight = Color(0xFFFF7A3D);   // Lighter Orange
  static const Color primaryDark = Color(0xFFCC440A);    // Deep Burnt Orange
  static const Color accent = Color(0xFFFF641A);         // Bright Orange Accent

  // Backgrounds & Surfaces
  static const Color background = Color(0xFF0B0E14);     // Deep Obsidian Black
  static const Color surface = Color(0xFF131720);        // Dark Layer 1
  static const Color cardBg = Color(0xFF171B24);         // Dark Container Layer 2
  static const Color cardBgLight = Color(0xFF1F2430);    // Hover / Highlight Container
  static const Color cardBorder = Color(0xFF282E3D);     // Subtle Stroke Border

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);    // Pure White
  static const Color textSecondary = Color(0xFF8E95A5);  // Soft Muted Grey
  static const Color textTertiary = Color(0xFF5D6578);   // Darker Grey

  // Crowd status colors
  static const Color crowdLow = Color(0xFF10B981);       // Emerald Green
  static const Color crowdMedium = Color(0xFFF59E0B);    // Warm Amber
  static const Color crowdHigh = Color(0xFFEF4444);      // Vivid Red
  static const Color crowdUnknown = Color(0xFF6B7280);   // Neutral Grey

  // General Coach highlighting
  static const Color generalBadgeBg = Color(0xFF2A201A);
  static const Color generalBadgeText = Color(0xFFFF7A3D);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardBg,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 1,
      ),
    );
  }

  static Color getCrowdColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return AppColors.crowdLow;
      case 'medium':
        return AppColors.crowdMedium;
      case 'high':
        return AppColors.crowdHigh;
      default:
        return AppColors.crowdUnknown;
    }
  }
}
