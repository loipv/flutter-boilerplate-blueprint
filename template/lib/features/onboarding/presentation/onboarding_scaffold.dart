import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Wraps every onboarding step with an animated progress bar.
///
/// Add or remove steps by updating the [_steps] list to match your routes.
class OnboardingScaffold extends ConsumerWidget {
  const OnboardingScaffold({super.key, required this.child});
  final Widget child;

  // Must mirror the routes defined in app_router.dart
  static const _steps = [
    '/onboarding',
    '/onboarding/intro',
    '/onboarding/theme',
    '/onboarding/login-prompt',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final index = _steps.indexOf(path);
    final progress = index < 0 ? 0.0 : (index + 1) / _steps.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Gap(16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
