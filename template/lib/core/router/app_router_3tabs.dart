import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:__APP_PACKAGE__/core/presentation/main_scaffold.dart';
import 'package:__APP_PACKAGE__/core/presentation/splash_screen.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';
import 'package:__APP_PACKAGE__/features/auth/application/auth_controller.dart';
import 'package:__APP_PACKAGE__/features/home/presentation/home_screen.dart';
import 'package:__APP_PACKAGE__/features/explore/presentation/explore_screen.dart';
import 'package:__APP_PACKAGE__/features/profile/presentation/profile_screen.dart';
import 'package:__APP_PACKAGE__/features/onboarding/application/onboarding_controller.dart';
import 'package:__APP_PACKAGE__/features/onboarding/presentation/intro_view.dart';
import 'package:__APP_PACKAGE__/features/onboarding/presentation/login_prompt_view.dart';
import 'package:__APP_PACKAGE__/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:__APP_PACKAGE__/features/onboarding/presentation/theme_selection_view.dart';
import 'package:__APP_PACKAGE__/features/settings/presentation/settings_screen.dart';

part 'app_router_3tabs.g.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

// keepAlive: true. The GoRouter instance must never be recreated on
// auth/onboarding state changes. Recreation resets navigation to
// initialLocation, losing the user's position in the app.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  const log = AppLogger('AppRouter');
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final notifier = _RouterRefreshNotifier();
  ref.onDispose(notifier.dispose);

  // ref.listen (not ref.watch); state changes trigger a redirect re-evaluation
  // without rebuilding the router provider itself.
  ref.listen(
    authControllerProvider.select((v) => v.whenData((u) => u != null)),
    (_, __) => notifier.notify(),
  );
  ref.listen(
    onboardingControllerProvider.select((v) => v.whenData((s) => s.isComplete)),
    (_, __) => notifier.notify(),
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    observers: [SentryNavigatorObserver(), PosthogObserver()],
    redirect: (context, state) {
      final authState = ref.read(
        authControllerProvider.select((v) => v.whenData((u) => u != null)),
      );
      final onboardingState = ref.read(
        onboardingControllerProvider.select(
          (v) => v.whenData((s) => s.isComplete),
        ),
      );

      final isOnboarding = state.uri.path.startsWith('/onboarding');
      final isLoggedIn = authState.asData?.value ?? false;

      if (authState.isLoading || onboardingState.isLoading) {
        if (!isOnboarding) return '/splash';
        return null;
      }

      final isSplash = state.uri.path == '/splash';

      if (!isLoggedIn && !isOnboarding) return '/onboarding/intro';

      if (isLoggedIn) {
        final isComplete = onboardingState.asData?.value ?? false;
        if (!isComplete && !isOnboarding) {
          log.info('Redirecting to onboarding');
          return '/onboarding/intro';
        }
        if (isComplete && (isOnboarding || isSplash)) return '/';
      }

      return null;
    },
    routes: [
      // Shell route: 3-tab layout
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) =>
            CustomTransitionPage<void>(
              key: state.pageKey,
              child: MainScaffold(navigationShell: navigationShell),
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (_, __) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, __) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Onboarding flow
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScaffold(child: IntroView()),
        routes: [
          GoRoute(
            path: 'intro',
            builder: (_, __) => const OnboardingScaffold(child: IntroView()),
          ),
          GoRoute(
            path: 'theme',
            builder: (_, __) =>
                const OnboardingScaffold(child: ThemeSelectionView()),
          ),
          GoRoute(
            path: 'login-prompt',
            builder: (_, __) =>
                const OnboardingScaffold(child: LoginPromptView()),
          ),
        ],
      ),

      // Settings (covers bottom nav)
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),

      // Splash
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
    ],
  );
}
