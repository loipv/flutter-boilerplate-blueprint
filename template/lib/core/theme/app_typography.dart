import 'package:flutter/material.dart';

/// Type scale backed by bundled Inter (body/label) + Inter_24pt (display/heading).
///
/// Use `TextStyle(fontFamily: 'Inter')` for sizes ≤17px,
/// `TextStyle(fontFamily: 'Inter_24pt')` for sizes ≥20px,
/// `TextStyle(fontFamily: 'JetBrainsMono')` for monospace / code / IPA.
class AppTypography {
  static TextStyle get displayLarge => const TextStyle(
    fontFamily: 'Inter_24pt',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static TextStyle get displayMedium => const TextStyle(
    fontFamily: 'Inter_24pt',
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get displaySmall => const TextStyle(
    fontFamily: 'Inter_24pt',
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get titleLarge => const TextStyle(
    fontFamily: 'Inter_24pt',
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get headlineMedium => const TextStyle(
    fontFamily: 'Inter_24pt',
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get titleMedium => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get bodySmall => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get labelLarge => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get labelMedium => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static TextStyle get labelSmall => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get mono => const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}
