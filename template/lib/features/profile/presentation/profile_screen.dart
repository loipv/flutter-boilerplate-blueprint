import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:__APP_PACKAGE__/core/theme/app_spacing.dart';
import 'package:__APP_PACKAGE__/core/theme/app_typography.dart';
import 'package:__APP_PACKAGE__/features/auth/application/auth_controller.dart';
import 'package:__APP_PACKAGE__/features/user_profile/application/user_profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: AppTypography.titleLarge),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/profile/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.p4),
          child: userAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(
              child: Text('Could not load profile. Please try again.'),
            ),
            data: (user) => user == null
                ? const Center(child: Text('Not signed in'))
                : _ProfileBody(
                    displayName: user.displayName,
                    email: user.email,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.displayName, required this.email});

  final String? displayName;
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              LucideIcons.circleUserRound,
              size: 40,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const Gap(AppSpacing.p4),
        if (displayName != null) ...[
          Center(child: Text(displayName!, style: AppTypography.titleLarge)),
          const Gap(AppSpacing.p1),
        ],
        if (email != null)
          Center(
            child: Text(
              email!,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const Gap(AppSpacing.p8),
        // Sign-out tile
        ListTile(
          leading: const Icon(LucideIcons.logOut),
          title: const Text('Sign out'),
          onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
