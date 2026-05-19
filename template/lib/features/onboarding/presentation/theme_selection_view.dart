import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:__APP_PACKAGE__/core/theme/app_spacing.dart';
import 'package:__APP_PACKAGE__/core/theme/app_typography.dart';
import 'package:__APP_PACKAGE__/core/theme/app_colors.dart';
import 'package:__APP_PACKAGE__/core/theme/theme_provider.dart';
import 'package:__APP_PACKAGE__/features/onboarding/application/onboarding_controller.dart';

/// Step 2 of onboarding: theme selection.
///
/// Shows Dawn (light) / Auto (system) / Dusk (dark) options with
/// a live preview that updates immediately on selection.
class ThemeSelectionView extends ConsumerStatefulWidget {
  const ThemeSelectionView({super.key});

  @override
  ConsumerState<ThemeSelectionView> createState() => _ThemeSelectionViewState();
}

class _ThemeSelectionViewState extends ConsumerState<ThemeSelectionView> {
  late ThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(themeNotifierProvider).value ?? ThemeMode.system;
  }

  void _selectTheme(ThemeMode mode) {
    setState(() => _selected = mode);
    ref.read(themeNotifierProvider.notifier).setTheme(mode);
  }

  void _confirm() {
    ref.read(onboardingControllerProvider.notifier).setTheme(_selected);
    context.go('/onboarding/login-prompt');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.p6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Vibe',
            style: AppTypography.displayMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Gap(AppSpacing.p2),
          Text(
            'Pick a look that feels right. You can change this later.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const Gap(AppSpacing.p8),

          _ThemeOption(
            label: 'Dawn',
            subtitle: 'Light mode',
            icon: LucideIcons.sun,
            mode: ThemeMode.light,
            selected: _selected == ThemeMode.light,
            onTap: () => _selectTheme(ThemeMode.light),
          ),
          const Gap(AppSpacing.p3),
          _ThemeOption(
            label: 'Auto',
            subtitle: 'Follows system',
            icon: LucideIcons.monitor,
            mode: ThemeMode.system,
            selected: _selected == ThemeMode.system,
            onTap: () => _selectTheme(ThemeMode.system),
          ),
          const Gap(AppSpacing.p3),
          _ThemeOption(
            label: 'Dusk',
            subtitle: 'Dark mode',
            icon: LucideIcons.moon,
            mode: ThemeMode.dark,
            selected: _selected == ThemeMode.dark,
            onTap: () => _selectTheme(ThemeMode.dark),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _confirm,
              child: Text(
                'Confirm',
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

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? primary : Theme.of(context).dividerColor,
          width: selected ? 2 : 1,
        ),
        color: selected
            ? primary.withValues(alpha: 0.06)
            : Theme.of(context).colorScheme.surface,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: selected ? primary : null),
        title: Text(label, style: AppTypography.titleMedium),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        trailing: selected
            ? Icon(LucideIcons.circleCheck, color: primary)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
