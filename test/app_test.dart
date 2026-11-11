// BEGIN_NOTIFICATIONS
import 'package:flutter/material.dart' show TimeOfDay;
// END_NOTIFICATIONS
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/app.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
import 'package:blueprint_app/core/data/posthog_analytics_repository.dart';
// BEGIN_NOTIFICATIONS
import 'package:blueprint_app/core/services/notification_service.dart';
// END_NOTIFICATIONS
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/home/presentation/home_screen.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import 'helpers/fakes.dart';

// analyticsRepositoryProvider exposes the concrete PostHog type, so the mock
// implements it (and through it, AnalyticsRepository).
class _MockAnalyticsRepository extends Mock
    implements PostHogAnalyticsRepository {}

// BEGIN_NOTIFICATIONS
class _MockNotificationService extends Mock implements NotificationService {}

class _FakeSharedPreferences extends Fake implements SharedPreferences {}
// END_NOTIFICATIONS

void main() {
  const signedInUser = UserEntity(
    id: 'u1',
    displayName: 'Ada',
    signInProvider: 'google',
  );

  // BEGIN_NOTIFICATIONS
  setUpAll(() {
    registerFallbackValue(const TimeOfDay(hour: 0, minute: 0));
    registerFallbackValue(_FakeSharedPreferences());
  });
  // END_NOTIFICATIONS

  late FakeUserRepository userRepo;
  late _MockAnalyticsRepository analytics;
  // BEGIN_NOTIFICATIONS
  late _MockNotificationService notifications;
  // END_NOTIFICATIONS

  setUp(() {
    userRepo = FakeUserRepository();

    analytics = _MockAnalyticsRepository();
    when(
      () => analytics.captureEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => analytics.captureScreen(any())).thenAnswer((_) async {});
    when(() => analytics.reset()).thenAnswer((_) async {});

    // BEGIN_NOTIFICATIONS
    notifications = _MockNotificationService();
    when(() => notifications.init()).thenAnswer((_) async {});
    when(
      () => notifications.onNotificationTap,
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(
      () => notifications.rescheduleIfTimezoneChanged(any()),
    ).thenAnswer((_) async {});
    when(
      () => notifications.scheduleDailyNotification(time: any(named: 'time')),
    ).thenAnswer((_) async {});
    when(
      () => notifications.cancelDailyNotification(),
    ).thenAnswer((_) async {});
    // END_NOTIFICATIONS
  });

  /// Seeds SharedPreferences, pumps [App] with [authRepo] and settles.
  Future<void> pumpWholeApp(
    WidgetTester tester,
    FakeAuthRepository authRepo, {
    bool onboardingComplete = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (onboardingComplete) AppConstants.onboardingCompleteKey: true,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          userRepositoryProvider.overrideWithValue(userRepo),
          analyticsRepositoryProvider.overrideWithValue(analytics),
          // BEGIN_NOTIFICATIONS
          notificationServiceProvider.overrideWithValue(notifications),
          // END_NOTIFICATIONS
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('App', () {
    testWidgets(
      'Given a signed-in user with onboarding complete, When the app starts, Then HomeScreen is shown',
      (tester) async {
        final authRepo = FakeAuthRepository(initialUser: signedInUser);

        await pumpWholeApp(tester, authRepo, onboardingComplete: true);

        expect(find.byType(HomeScreen), findsOneWidget);
        // An existing session is never replaced by an anonymous one.
        expect(authRepo.currentUser, signedInUser);
        expect(userRepo.calls, isNot(contains(startsWith('recordLogin:'))));
        // BEGIN_NOTIFICATIONS
        verify(() => notifications.init()).called(1);
        // END_NOTIFICATIONS
      },
    );

    testWidgets(
      'Given a signed-in user whose stored hapticsEnabled is false, When they switch tabs, Then no haptic feedback fires',
      (tester) async {
        // AppHaptics only reads hapticsEnabled; App's listener is what keeps
        // the profile stream delivering, whatever else is (not) listening.
        userRepo.users['u1'] = signedInUser.copyWith(
          preferences: const UserPreferences(hapticsEnabled: false),
        );
        final hapticCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final authRepo = FakeAuthRepository(initialUser: signedInUser);

        await pumpWholeApp(tester, authRepo, onboardingComplete: true);
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();

        expect(hapticCalls, isEmpty);
      },
    );

    // BEGIN_ANON
    testWidgets(
      'Given no user, When the app starts and the guest completes onboarding, Then it signs in anonymously and shows HomeScreen',
      (tester) async {
        final authRepo = FakeAuthRepository();

        await pumpWholeApp(tester, authRepo);

        // App._checkAuth signs in anonymously; the router lands on the intro.
        expect(authRepo.currentUser, FakeAuthRepository.anonymousUser);
        expect(userRepo.calls, contains('recordLogin:anon-1'));
        expect(find.text('Welcome to\nBlueprint App'), findsOneWidget);

        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        expect(find.text('Choose Your Vibe'), findsOneWidget);

        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(find.text('Create your account'), findsOneWidget);

        await tester.tap(find.text('Continue as Guest'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(userRepo.calls, contains('markOnboardingComplete:anon-1'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(AppConstants.onboardingCompleteKey), isTrue);
      },
    );
    // END_ANON
  });
}
