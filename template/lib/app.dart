import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// BEGIN_NOTIFICATIONS
import 'package:__APP_PACKAGE__/core/providers/shared_preferences_provider.dart';
import 'package:__APP_PACKAGE__/core/services/notification_service.dart';
import 'package:__APP_PACKAGE__/core/router/app_router.dart';
import 'package:__APP_PACKAGE__/core/services/session_lifecycle_observer.dart';
import 'package:__APP_PACKAGE__/core/services/timezone_lifecycle_observer.dart';
import 'package:__APP_PACKAGE__/features/notifications/application/notification_scheduler.dart';
// END_NOTIFICATIONS
import 'package:__APP_PACKAGE__/core/theme/app_theme.dart';
import 'package:__APP_PACKAGE__/core/theme/theme_provider.dart';
import 'package:__APP_PACKAGE__/features/auth/application/auth_controller.dart';
import 'package:__APP_PACKAGE__/features/auth/data/firebase_auth_repository.dart';
import 'package:__APP_PACKAGE__/features/user_profile/data/firebase_user_repository.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  // BEGIN_NOTIFICATIONS
  TimezoneLifecycleObserver? _timezoneObserver;
  // END_NOTIFICATIONS
  SessionLifecycleObserver? _sessionObserver;

  @override
  void initState() {
    super.initState();

    // BEGIN_NOTIFICATIONS
    ref.read(notificationServiceProvider).init();

    _timezoneObserver = TimezoneLifecycleObserver(
      notificationService: ref.read(notificationServiceProvider),
      getPrefs: () => ref.read(sharedPreferencesProvider.future),
    );
    WidgetsBinding.instance.addObserver(_timezoneObserver!);
    // END_NOTIFICATIONS

    _sessionObserver = SessionLifecycleObserver(
      getRepository: () => ref.read(userRepositoryProvider),
      getCurrentUser: () => ref.read(authControllerProvider).value,
    );
    WidgetsBinding.instance.addObserver(_sessionObserver!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Remove native splash overlay; SplashScreen widget provides the
      // visual continuity while auth state loads.
      FlutterNativeSplash.remove();
      _checkAuth();
    });
  }

  @override
  void dispose() {
    // BEGIN_NOTIFICATIONS
    if (_timezoneObserver != null) {
      WidgetsBinding.instance.removeObserver(_timezoneObserver!);
    }
    // END_NOTIFICATIONS
    if (_sessionObserver != null) {
      WidgetsBinding.instance.removeObserver(_sessionObserver!);
    }
    super.dispose();
  }

  void _checkAuth() {
    // BEGIN_ANON
    // Create an anonymous session only if no auth session exists.
    // Using the synchronous currentUser prevents overwriting a signed-in
    // Apple/Google session on hot restart.
    final hasUser = ref.read(authRepositoryProvider).currentUser != null;
    if (!hasUser) {
      ref.read(authControllerProvider.notifier).signInAnonymously();
    }
    // END_ANON
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode =
        ref.watch(themeNotifierProvider).value ?? ThemeMode.system;

    Widget app = MaterialApp.router(
      title: '__APP_TITLE__',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );

    // BEGIN_NOTIFICATIONS
    app = NotificationScheduler(child: app);
    // END_NOTIFICATIONS
    return app;
  }
}
