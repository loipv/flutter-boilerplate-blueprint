import 'package:flutter/material.dart';

/// Brand color palette.
///
/// These are the default brand colors. To rebrand, edit the hex constants
/// below and re-run `make run-staging`.
///
/// Usage in widgets: prefer `Theme.of(context).colorScheme.primary` over
/// `AppColors.primary` directly; this ensures dark mode uses `primaryDark`
/// automatically via the `ColorScheme` defined in `AppTheme`.
class AppColors {
  // Primary
  static const Color primary = Color(0xFF3C5A4D);
  static const Color primaryDark = Color(0xFF7CA692);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Accent / secondary
  static const Color secondary = Color(0xFF5BA87F);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color success = secondary;

  // Error
  static const Color error = Color(0xFFD9534F);
  static const Color errorDark = Color(0xFFE57875);

  // Backgrounds
  static const Color lightBackground = Color(0xFFF9F9F6);
  static const Color darkBackground = Color(0xFF121614);

  // Surfaces
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF1B221E);

  // Text
  static const Color textLightPrimary = Color(0xFF1E2420);
  static const Color textDarkPrimary = Color(0xFFF0F2F1);
  static const Color textLightSecondary = Color(0xFF5C6B63);
  static const Color textDarkSecondary = Color(0xFFA9B5AE);
  static const Color textLightTertiary = Color(0xFF93A199);
  static const Color textDarkTertiary = Color(0xFF73827A);

  // Borders & shadows
  static final Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static final Color borderDark = Colors.white.withValues(alpha: 0.10);

  // Context-aware helpers
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? textLightSecondary
      : textDarkSecondary;

  static Color textTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? textLightTertiary
      : textDarkTertiary;
}
