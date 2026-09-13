import 'package:flutter/material.dart';

class AppColors {
  // Official Department of Consumer Affairs / Government of India Palette
  static const navy = Color(0xFF0B2545);
  static const navyDark = Color(0xFF061426);
  static const navyLight = Color(0xFF133A6B);
  static const navySurface = Color(0xFF0E2A4D);

  static const slate = Color(0xFF334155);
  static const slateMuted = Color(0xFF64748B);
  static const slateLight = Color(0xFF94A3B8);

  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const borderSubtle = Color(0xFFEDF2F7);

  // National Accents (Restrained & Dignified)
  static const saffron = Color(0xFFD97706);
  static const gold = Color(0xFFB45309);
  static const goldLight = Color(0xFFFFFBEB);
  static const goldBorder = Color(0xFFFDE68A);
  static const indiaGreen = Color(0xFF15803D);

  // Legal Metrology Verdict Colors (Clean, high-contrast, accessible)
  static const compliant = Color(0xFF166534);
  static const compliantBg = Color(0xFFF0FDF4);
  static const compliantBorder = Color(0xFFBBF7D0);

  static const nonCompliant = Color(0xFF991B1B);
  static const nonCompliantBg = Color(0xFFFEF2F2);
  static const nonCompliantBorder = Color(0xFFFECACA);

  static const needsVerify = Color(0xFF92400E);
  static const needsVerifyBg = Color(0xFFFFFBEB);
  static const needsVerifyBorder = Color(0xFFFDE68A);
}

class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.navy,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE9EFF7),
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.slate,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF1F5F9),
      onSecondaryContainer: AppColors.slate,
      tertiary: AppColors.gold,
      onTertiary: Colors.white,
      error: AppColors.nonCompliant,
      onError: Colors.white,
      errorContainer: AppColors.nonCompliantBg,
      onErrorContainer: AppColors.nonCompliant,
      surface: AppColors.surface,
      onSurface: Color(0xFF0F172A),
      onSurfaceVariant: AppColors.slateMuted,
      outline: Color(0xFFCBD5E1),
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
          height: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        color: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        height: 64,
        indicatorColor: const Color(0xFFE2EBF5),
        backgroundColor: Colors.white,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              letterSpacing: 0.2,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.slateMuted,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.navy, size: 22);
          }
          return const IconThemeData(color: AppColors.slateMuted, size: 22);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bg,
        selectedColor: const Color(0xFFE2EBF5),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.slate,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}


