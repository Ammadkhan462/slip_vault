import 'package:flutter/material.dart';

/// App-wide design system tokens aligned with the approved Slip Vault design specification.
abstract final class AppColors {
  // Brand & Accents
  static const primary = Color(0xFF005C55);
  static const primaryContainer = Color(0xFF0F766E);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFA3FAEF);

  static const secondary = Color(0xFF855300);
  static const secondaryContainer = Color(0xFFFEA619);
  static const onSecondary = Color(0xFFFFFFFF);
  static const onSecondaryContainer = Color(0xFF684000);

  // Inflow / Outflow Directional Colors
  static const tertiary = Color(0xFF005F26); // Inflow / Credited text
  static const tertiaryContainer = Color(0xFF007A33);
  static const tertiaryFixed = Color(0xFF7FFC97);
  static const onTertiaryFixed = Color(0xFF002109);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onError = Color(0xFFFFFFFF);
  static const onErrorContainer = Color(0xFF93000A);

  // Neutral Surfaces (Light)
  static const surfaceLight = Color(0xFFF8F9FF);
  static const surfaceDimLight = Color(0xFFCBDBF5);
  static const surfaceContainerLowestLight = Color(0xFFFFFFFF);
  static const surfaceContainerLowLight = Color(0xFFEFF4FF);
  static const surfaceContainerLight = Color(0xFFE5EEFF);
  static const surfaceContainerHighLight = Color(0xFFDCE9FF);
  static const surfaceContainerHighestLight = Color(0xFFD3E4FE);

  static const onSurfaceLight = Color(0xFF0B1C30);
  static const onSurfaceVariantLight = Color(0xFF3E4947);
  static const outlineLight = Color(0xFF6E7977);
  static const outlineVariantLight = Color(0xFFBDC9C6);

  // Neutral Surfaces (Dark)
  static const surfaceDark = Color(0xFF0B1220);
  static const surfaceDimDark = Color(0xFF0F172A);
  static const surfaceContainerLowestDark = Color(0xFF0F172A);
  static const surfaceContainerLowDark = Color(0xFF131F37);
  static const surfaceContainerDark = Color(0xFF1E293B);
  static const surfaceContainerHighDark = Color(0xFF27354E);
  static const surfaceContainerHighestDark = Color(0xFF334155);

  static const onSurfaceDark = Color(0xFFEAF1FF);
  static const onSurfaceVariantDark = Color(0xFF94A3B8);
  static const outlineDark = Color(0xFF64748B);
  static const outlineVariantDark = Color(0xFF334155);
}

/// Material 3 Themes for Slip Vault
abstract final class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: Colors.white,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowestLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.outlineVariantLight, width: 0.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF80D5CB),
      onPrimary: const Color(0xFF003732),
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: const Color(0xFFFFB95F),
      onSecondary: const Color(0xFF472A00),
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: const Color(0xFF7FFC97),
      onTertiary: const Color(0xFF003914),
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: Colors.white,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowestDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.outlineVariantDark, width: 0.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
      ),
    );
  }
}
