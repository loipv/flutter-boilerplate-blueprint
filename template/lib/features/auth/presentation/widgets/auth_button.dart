import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:__APP_PACKAGE__/core/theme/app_spacing.dart';
import 'package:__APP_PACKAGE__/core/theme/app_typography.dart';

enum AuthProvider { apple, google }

/// Branded sign-in button for Apple and Google.
///
/// Uses official brand SVGs from `assets/icons/ic_apple.svg` and
/// `assets/icons/ic_google.svg`. Both are included in the template.
///
/// Usage:
/// ```dart
/// AuthButton(
///   provider: AuthProvider.apple,
///   onTap: () => ref.read(authControllerProvider.notifier).signInWithApple(),
/// )
/// ```
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.provider,
    required this.onTap,
    this.isLoading = false,
  });

  final AuthProvider provider;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (label, iconAsset, bg, fg, colorFilter) = switch (provider) {
      AuthProvider.apple => (
        'Continue with Apple',
        'assets/icons/ic_apple.svg',
        isDark ? Colors.white : Colors.black,
        isDark ? Colors.black : Colors.white,
        // Invert the black Apple logo on dark bg so it shows white
        isDark
            ? const ColorFilter.matrix(<double>[
                -1,
                0,
                0,
                0,
                255,
                0,
                -1,
                0,
                0,
                255,
                0,
                0,
                -1,
                0,
                255,
                0,
                0,
                0,
                1,
                0,
              ])
            : null,
      ),
      AuthProvider.google => (
        'Continue with Google',
        'assets/icons/ic_google.svg',
        isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8F8F8),
        isDark ? Colors.white : Colors.black87,
        // Google logo is always full-colour — no filter needed
        null,
      ),
    };

    return AnimatedOpacity(
      opacity: isLoading ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.p4),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        iconAsset,
                        width: 20,
                        height: 20,
                        colorFilter: colorFilter,
                      ),
                      const Gap(AppSpacing.p2),
                      Text(
                        label,
                        style: AppTypography.labelLarge.copyWith(color: fg),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
