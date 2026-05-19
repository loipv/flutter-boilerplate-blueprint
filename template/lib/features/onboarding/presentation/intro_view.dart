import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:__APP_PACKAGE__/core/theme/app_spacing.dart';
import 'package:__APP_PACKAGE__/core/theme/app_typography.dart';
import 'package:__APP_PACKAGE__/core/theme/app_colors.dart';

/// Step 1 of onboarding: the "hook" screen.
///
/// Customise the headline, body copy, and logo to match your app's
/// value proposition. This is the first thing new users see.
class IntroView extends ConsumerWidget {
  const IntroView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.p6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),

          // Logo / hero illustration
          // TODO: Replace with your app logo or hero illustration
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Gap(AppSpacing.p8),

          // Headline: replace with your value proposition
          Text(
            'Welcome to\n__APP_TITLE__',
            style: AppTypography.displayLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Gap(AppSpacing.p4),

          // Subheadline: replace with your app description
          Text(
            '__APP_DESC__',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const Spacer(flex: 2),

          // CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => context.go('/onboarding/theme'),
              child: Text(
                'Get Started',
                style: AppTypography.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const Gap(AppSpacing.p4),
        ],
      ),
    );
  }
}
