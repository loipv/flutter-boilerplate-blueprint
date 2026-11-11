import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// BEGIN_APPLE
import 'package:mocktail/mocktail.dart';
// END_APPLE
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
// BEGIN_APPLE
import 'package:blueprint_app/core/errors/failure.dart';
// END_APPLE
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/onboarding/application/onboarding_controller.dart';
import 'package:blueprint_app/features/onboarding/presentation/login_prompt_view.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../../helpers/fakes.dart';
// BEGIN_APPLE
import '../../../helpers/mocks.dart';
// END_APPLE
import '../../../helpers/pump_app.dart';

void main() {
  const anonUser = UserEntity(
    id: 'anon-1',
    isAnonymous: true,
    signInProvider: 'anonymous',
  );
  const signedInUser = UserEntity(
    id: 'g-1',
    displayName: 'Ada',
    signInProvider: 'google',
  );

  late FakeUserRepository userRepo;

  setUp(() {
    // Fresh SharedPreferences per test so the onboarding flag never leaks.
    SharedPreferences.setMockInitialValues({});
    userRepo = FakeUserRepository();
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LoginPromptView)));

  Future<void> pumpView(
    WidgetTester tester,
    FirebaseAuthRepository authRepo,
  ) async {
    await pumpApp(
      tester,
      const LoginPromptView(),
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(userRepo),
      ],
    );
    // In the app the router watches the onboarding controller, so it has
    // loaded before this view can complete onboarding. Mirror that here.
    containerOf(tester).read(onboardingControllerProvider);
    await tester.pumpAndSettle();
  }

  Future<void> expectOnboardingComplete(WidgetTester tester, String uid) async {
    final state = containerOf(tester).read(onboardingControllerProvider);
    expect(state.requireValue.isComplete, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConstants.onboardingCompleteKey), isTrue);
    expect(userRepo.calls, contains('markOnboardingComplete:$uid'));
  }

  group('LoginPromptView', () {
    testWidgets(
      'Given a signed-in user, When "Get Started" is tapped, Then onboarding completes',
      (tester) async {
        await pumpView(tester, FakeAuthRepository(initialUser: signedInUser));

        expect(find.text('Get Started'), findsOneWidget);

        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();

        await expectOnboardingComplete(tester, 'g-1');
      },
    );

    // BEGIN_APPLE
    testWidgets(
      'Given an anonymous user, When the view shows, Then the Apple button is shown',
      (tester) async {
        await pumpView(tester, FakeAuthRepository(initialUser: anonUser));

        expect(find.text('Continue with Apple'), findsOneWidget);
      },
    );

    testWidgets(
      'Given Apple sign-in fails with apple-unavailable, When the Apple button is tapped, Then a snackbar shows the Apple message',
      (tester) async {
        final authRepo = MockAuthRepository();
        when(
          () => authRepo.authStateChanges(),
        ).thenAnswer((_) => Stream.value(anonUser));
        when(() => authRepo.signInWithApple()).thenAnswer(
          (_) async => throw const Failure.auth('apple-unavailable'),
        );
        await pumpView(tester, authRepo);

        await tester.tap(find.text('Continue with Apple'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            "Sign in with Apple isn't available on this device. Try Google instead, or continue as a guest.",
          ),
          findsOneWidget,
        );
        expect(
          userRepo.calls,
          isNot(contains('markOnboardingComplete:anon-1')),
        );
      },
    );
    // END_APPLE

    // BEGIN_GOOGLE
    testWidgets(
      'Given an anonymous user, When the view shows, Then the Google button is shown',
      (tester) async {
        await pumpView(tester, FakeAuthRepository(initialUser: anonUser));

        expect(find.text('Continue with Google'), findsOneWidget);
      },
    );
    // END_GOOGLE

    // BEGIN_ANON
    testWidgets(
      'Given an anonymous user, When the view shows, Then "Continue as Guest" is shown',
      (tester) async {
        await pumpView(tester, FakeAuthRepository(initialUser: anonUser));

        expect(find.text('Continue as Guest'), findsOneWidget);
        expect(find.text('Get Started'), findsNothing);
      },
    );

    testWidgets(
      'Given an anonymous user, When "Continue as Guest" is tapped and the dialog is confirmed, Then onboarding completes',
      (tester) async {
        await pumpView(tester, FakeAuthRepository(initialUser: anonUser));

        await tester.tap(find.text('Continue as Guest'));
        await tester.pumpAndSettle();
        expect(find.text('Continue as Guest?'), findsOneWidget);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Continue as Guest?'), findsNothing);
        await expectOnboardingComplete(tester, 'anon-1');
      },
    );
    // END_ANON

    testWidgets(
      'Given locale vi, an anonymous user and a 320x640 surface, When pumped, Then no overflow is reported',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpApp(
          tester,
          const LoginPromptView(),
          locale: const Locale('vi'),
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(initialUser: anonUser),
            ),
            userRepositoryProvider.overrideWithValue(userRepo),
          ],
        );
        containerOf(tester).read(onboardingControllerProvider);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
