import 'package:flutter/material.dart';
import 'package:__APP_PACKAGE__/core/theme/app_colors.dart';
import 'package:__APP_PACKAGE__/core/theme/app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.textLightPrimary,
      error: AppColors.error,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(
        color: AppColors.textLightPrimary,
      ),
      displayMedium: AppTypography.displayMedium.copyWith(
        color: AppColors.textLightPrimary,
      ),
      bodyLarge: AppTypography.bodyLarge.copyWith(
        color: AppColors.textLightPrimary,
      ),
      bodyMedium: AppTypography.bodyMedium.copyWith(
        color: AppColors.textLightPrimary,
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryDark,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textDarkPrimary,
      error: AppColors.errorDark,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(
        color: AppColors.textDarkPrimary,
      ),
      displayMedium: AppTypography.displayMedium.copyWith(
        color: AppColors.textDarkPrimary,
      ),
      bodyLarge: AppTypography.bodyLarge.copyWith(
        color: AppColors.textDarkPrimary,
      ),
      bodyMedium: AppTypography.bodyMedium.copyWith(
        color: AppColors.textDarkPrimary,
      ),
    ),
  );
}
