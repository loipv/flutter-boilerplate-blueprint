import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

/// Wraps every onboarding step with an animated progress bar.
///
/// Add or remove steps by updating the [_steps] list to match your routes.
///
/// [path] is the current location (`state.uri.path` from the route builder).
/// It is passed in rather than read via `GoRouterState.of`, which throws when
/// a page builds during a redirect after its state left go_router's registry.
class OnboardingScaffold extends ConsumerWidget {
  const OnboardingScaffold({
    super.key,
    required this.path,
    required this.child,
  });
  final String path;
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
