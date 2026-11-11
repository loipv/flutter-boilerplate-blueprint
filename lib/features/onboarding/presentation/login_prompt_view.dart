import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/core/l10n/l10n_extension.dart';
import 'package:blueprint_app/core/theme/app_colors.dart';
import 'package:blueprint_app/core/theme/app_spacing.dart';
import 'package:blueprint_app/core/theme/app_typography.dart';
import 'package:blueprint_app/core/presentation/utils/app_snack_bar.dart';
import 'package:blueprint_app/features/auth/application/auth_controller.dart';
import 'package:blueprint_app/features/auth/presentation/auth_failure_message.dart';
// Unused only when both Apple and Google sign-in are removed.
// ignore: unused_import
import 'package:blueprint_app/features/auth/presentation/widgets/auth_button.dart';
import 'package:blueprint_app/features/onboarding/application/onboarding_controller.dart';

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
  // BEGIN_APPLE
  bool _isLoadingApple = false;
  // END_APPLE
  // BEGIN_GOOGLE
  bool _isLoadingGoogle = false;
  // END_GOOGLE

  // Unused only when both Apple and Google sign-in are removed.
  // ignore: unused_element
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
      final isCanceled = e.maybeWhen(
        auth: (code) => code == 'canceled',
        orElse: () => false,
      );
      if (!mounted || isCanceled) return;
      final l10n = context.l10n;
      final message = authFailureMessage(e, method: signInMethod, l10n: l10n);
      AppSnackBar.error(context, message ?? l10n.authSignInFailed);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, context.l10n.authSignInFailed);
      }
    } finally {
      if (mounted) setLoading(false);
    }
  }

  // BEGIN_ANON
  Future<void> _continueAsGuest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.anonConfirmTitle),
        content: Text(context.l10n.anonConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.anonConfirmContinue),
          ),
        ],
      ),
    );
    if (confirmed == true) await _completeOnboarding();
  }
  // END_ANON

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
            context.l10n.onboardingLoginHeadline,
            style: AppTypography.displayMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Gap(AppSpacing.p2),
          Text(
            context.l10n.onboardingLoginBody,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const Spacer(),

          // Sign-in buttons (shown only for anonymous / signed-out users)
          if (isAnon) ...[
            // BEGIN_APPLE
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
            // END_APPLE
            // BEGIN_GOOGLE
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
            // END_GOOGLE
            const Gap(AppSpacing.p6),
          ],

          // Continue as guest / complete onboarding
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _buildBottomButton(isAnon),
          ),
          const Gap(AppSpacing.p4),
        ],
      ),
    );
  }

  Widget _buildBottomButton(bool isAnon) {
    // BEGIN_ANON
    if (isAnon) {
      return OutlinedButton(
        onPressed: _continueAsGuest,
        child: Text(context.l10n.anonContinueAsGuest),
      );
    }
    // END_ANON
    return FilledButton(
      onPressed: _completeOnboarding,
      child: Text(context.l10n.onboardingGetStarted),
    );
  }
}
