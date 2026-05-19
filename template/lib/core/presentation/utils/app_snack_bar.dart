import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:__APP_PACKAGE__/core/theme/app_colors.dart';
import 'package:__APP_PACKAGE__/core/theme/app_spacing.dart';

class AppSnackBar {
  static void success(BuildContext context, String message) {
    show(
      context,
      message,
      icon: LucideIcons.circleCheck,
      iconColor: AppColors.success,
    );
  }

  static void error(BuildContext context, String message) {
    show(
      context,
      message,
      icon: LucideIcons.circleX,
      iconColor: AppColors.errorDark,
    );
  }

  static void show(
    BuildContext context,
    String message, {
    double marginBottom = 16.0,
    IconData? icon,
    Color? iconColor,
  }) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? Colors.white, size: 20),
                const Gap(AppSpacing.p3),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isDark
              ? const Color(0xFF333333)
              : const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: marginBottom, left: 16, right: 16),
        ),
      );
  }
}
