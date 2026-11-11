import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
import 'package:blueprint_app/core/router/app_router.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/onboarding/application/onboarding_controller.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockUserRepository userRepo;
  late StreamController<UserEntity?> authStates;

  const user = UserEntity(id: 'u1', displayName: 'Ada');

  setUp(() {
    authRepo = MockAuthRepository();
    userRepo = MockUserRepository();
    authStates = StreamController<UserEntity?>();
    // Not awaited: close() only completes once a listener drains the stream.
    addTearDown(() => unawaited(authStates.close()));
    when(
      () => authRepo.authStateChanges(),
    ).thenAnswer((_) => authStates.stream);
    when(
      () => userRepo.getUserStream(any()),
    ).thenAnswer((_) => Stream.value(null));
  });

  /// Seeds SharedPreferences, pumps the app on [routerProvider] and returns
  /// the router. The tree and container are torn down after the test.
  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    UserEntity? signedInAs,
    bool emitAuth = true,
    bool onboardingComplete = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (onboardingComplete) AppConstants.onboardingCompleteKey: true,
    });
    if (emitAuth) authStates.add(signedInAs);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(userRepo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.pumpWidget(Container()));

    // The app watches routerProvider; an unlistened provider is paused and
    // would never receive auth or onboarding updates.
    final router = container.listen(routerProvider, (_, _) {}).read();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  group('routerProvider', () {
    testWidgets(
      'Given auth is still loading, When the app starts, Then the location is /splash',
      (tester) async {
        final router = await pumpRouter(tester, emitAuth: false);

        expect(location(router), '/splash');
      },
    );

    testWidgets(
      'Given auth is still loading, When navigating to /explore, Then it redirects to /splash',
      (tester) async {
        final router = await pumpRouter(tester, emitAuth: false);

        router.go('/explore');
        await tester.pumpAndSettle();

        expect(location(router), '/splash');
      },
    );

    testWidgets(
      'Given auth is still loading, When navigating to /onboarding/intro, Then it stays on onboarding',
      (tester) async {
        final router = await pumpRouter(tester, emitAuth: false);

        router.go('/onboarding/intro');
        await tester.pumpAndSettle();

        expect(location(router), '/onboarding/intro');
      },
    );

    testWidgets(
      'Given the user is signed out, When the app starts, Then the location is /onboarding/intro',
      (tester) async {
        final router = await pumpRouter(tester);

        expect(location(router), '/onboarding/intro');
      },
    );

    testWidgets(
      'Given the user is signed out and onboarding is complete, When navigating to /, Then it redirects to /onboarding/intro',
      (tester) async {
        final router = await pumpRouter(tester, onboardingComplete: true);

        router.go('/');
        await tester.pumpAndSettle();

        expect(location(router), '/onboarding/intro');
      },
    );

    testWidgets(
      'Given a signed-in user with onboarding incomplete, When the app starts, Then the location is /onboarding/intro',
      (tester) async {
        final router = await pumpRouter(tester, signedInAs: user);

        expect(location(router), '/onboarding/intro');
      },
    );

    testWidgets(
      'Given a signed-in user with onboarding incomplete, When navigating to /explore, Then it redirects to /onboarding/intro',
      (tester) async {
        final router = await pumpRouter(tester, signedInAs: user);

        router.go('/explore');
        await tester.pumpAndSettle();

        expect(location(router), '/onboarding/intro');
      },
    );

    testWidgets(
      'Given a signed-in user with onboarding complete, When the app starts at /splash, Then the location is /',
      (tester) async {
        final router = await pumpRouter(
          tester,
          signedInAs: user,
          onboardingComplete: true,
        );

        expect(location(router), '/');
      },
    );

    testWidgets(
      'Given a signed-in user with onboarding complete, When navigating to /onboarding/intro, Then it redirects to /',
      (tester) async {
        final router = await pumpRouter(
          tester,
          signedInAs: user,
          onboardingComplete: true,
        );

        router.go('/onboarding/intro');
        await tester.pumpAndSettle();

        expect(location(router), '/');
      },
    );

    testWidgets(
      'Given a signed-in user with onboarding complete, When navigating to /explore, Then it stays on /explore',
      (tester) async {
        final router = await pumpRouter(
          tester,
          signedInAs: user,
          onboardingComplete: true,
        );

        router.go('/explore');
        await tester.pumpAndSettle();

        expect(location(router), '/explore');
      },
    );

    testWidgets(
      'Given auth is loading at /splash with onboarding complete, When the user signs in, Then the router refreshes to /',
      (tester) async {
        final router = await pumpRouter(
          tester,
          emitAuth: false,
          onboardingComplete: true,
        );
        expect(location(router), '/splash');

        authStates.add(user);
        await tester.pumpAndSettle();

        expect(location(router), '/');
      },
    );

    testWidgets(
      'Given a signed-in user on /onboarding/intro, When onboarding is marked complete, Then the router refreshes to /',
      (tester) async {
        final router = await pumpRouter(tester, signedInAs: user);
        expect(location(router), '/onboarding/intro');

        final container = ProviderScope.containerOf(
          tester.element(find.byType(Navigator).first),
        );
        await tester.runAsync(
          () => container
              .read(onboardingControllerProvider.notifier)
              .markLocallyComplete(),
        );
        await tester.pumpAndSettle();

        expect(location(router), '/');
      },
    );
  });
}
