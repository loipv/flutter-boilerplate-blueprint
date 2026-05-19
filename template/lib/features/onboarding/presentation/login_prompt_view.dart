import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:__APP_PACKAGE__/core/errors/failure.dart';
import 'package:__APP_PACKAGE__/core/theme/app_colors.dart';
import 'package:__APP_PACKAGE__/core/theme/app_spacing.dart';
import 'package:__APP_PACKAGE__/core/theme/app_typography.dart';
import 'package:__APP_PACKAGE__/core/presentation/utils/app_snack_bar.dart';
import 'package:__APP_PACKAGE__/features/auth/application/auth_controller.dart';
import 'package:__APP_PACKAGE__/features/auth/presentation/auth_failure_message.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_entity.dart';
import 'package:__APP_PACKAGE__/features/auth/presentation/widgets/auth_button.dart';
import 'package:__APP_PACKAGE__/features/onboarding/application/onboarding_controller.dart';

/// Step 3 (final) of onboarding: optional Google/Apple sign-in.
///
/// "Continue as Guest" creates an anonymous session. The user can always
/// upgrade to a full account later from Settings.
class LoginPromptView extends ConsumerStatefulWidget {
  const LoginPromptView({super.key});

  @override
  ConsumerState<LoginPromptView> createState() => _LoginPromptViewState();
}

class _LoginPromptViewState extends ConsumerState<LoginPromptView> {
  bool _isLoadingApple = false;
  bool _isLoadingGoogle = false;

  Future<void> _signIn(
    Future<void> Function() method, {
    required void Function(bool) setLoading,
    required SignInMethod signInMethod,
  }) async {
    setLoading(true);
    try {
      await method();
      await _completeOnboarding();
    } on Failure catch (e) {
      final message = authFailureMessage(e, method: signInMethod);
      final isCanceled = e.maybeWhen(
        auth: (code) => code == 'canceled',
        orElse: () => false,
      );
      if (!mounted || isCanceled) return;
      AppSnackBar.error(
        context,
        message ?? 'Sign-in failed. Please try again.',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setLoading(false);
    }
  }

  Future<void> _continueAsGuest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continue as Guest?'),
        content: const Text(
          'Your data won\'t sync across devices. '
          'You can sign in later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
    // Router redirect handles navigation to '/' automatically
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final isAnon = user?.isAnonymous ?? true;

    // If the user somehow already signed in (e.g. from Settings deep link),
    // still show this screen; it completes onboarding.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.p6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create your account',
            style: AppTypography.displayMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Gap(AppSpacing.p2),
          Text(
            'Sign in to sync your data across devices. '
            'You can always skip this and sign in later.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const Spacer(),

          // Sign-in buttons (shown only for anonymous / signed-out users)
          if (isAnon) ...[
            AuthButton(
              provider: AuthProvider.apple,
              isLoading: _isLoadingApple,
              onTap: () => _signIn(
                () =>
                    ref.read(authControllerProvider.notifier).signInWithApple(),
                setLoading: (v) => setState(() => _isLoadingApple = v),
                signInMethod: SignInMethod.apple,
              ),
            ),
            const Gap(AppSpacing.p3),
            AuthButton(
              provider: AuthProvider.google,
              isLoading: _isLoadingGoogle,
              onTap: () => _signIn(
                () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithGoogle(),
                setLoading: (v) => setState(() => _isLoadingGoogle = v),
                signInMethod: SignInMethod.google,
              ),
            ),
            const Gap(AppSpacing.p6),
          ],

          // Continue as guest / complete onboarding
          SizedBox(
            width: double.infinity,
            height: 52,
            child: isAnon
                ? OutlinedButton(
                    onPressed: _continueAsGuest,
                    child: const Text('Continue as Guest'),
                  )
                : FilledButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Get Started'),
                  ),
          ),
          const Gap(AppSpacing.p4),
        ],
      ),
    );
  }
}
