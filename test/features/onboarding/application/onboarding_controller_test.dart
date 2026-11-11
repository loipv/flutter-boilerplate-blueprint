import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/onboarding/application/onboarding_controller.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository authRepo;
  late MockUserRepository userRepo;

  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  setUp(() {
    authRepo = MockAuthRepository();
    userRepo = MockUserRepository();
    when(() => userRepo.savePreferences(any(), any())).thenAnswer((_) async {});
    when(() => userRepo.markOnboardingComplete(any())).thenAnswer((_) async {});
  });

  /// Creates a container with [initial] SharedPreferences values and waits
  /// for the controller to build.
  Future<ProviderContainer> buildContainer(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(userRepo),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onboardingControllerProvider.future);
    return container;
  }

  test(
    'Given nothing is stored, When the controller builds, Then onboarding is incomplete at step 0',
    () async {
      final container = await buildContainer({});

      final state = container.read(onboardingControllerProvider).requireValue;
      expect(state.isComplete, isFalse);
      expect(state.currentStep, 0);
    },
  );

  test(
    'Given the complete flag is stored, When the controller builds, Then onboarding is complete',
    () async {
      final container = await buildContainer({
        AppConstants.onboardingCompleteKey: true,
      });

      expect(
        container.read(onboardingControllerProvider).requireValue.isComplete,
        isTrue,
      );
    },
  );

  test(
    'Given step 0, When nextStep is called, Then currentStep is 1',
    () async {
      final container = await buildContainer({});

      container.read(onboardingControllerProvider.notifier).nextStep();

      expect(
        container.read(onboardingControllerProvider).requireValue.currentStep,
        1,
      );
    },
  );

  test(
    'Given incomplete onboarding, When markLocallyComplete is called, Then the flag is persisted',
    () async {
      final container = await buildContainer({});

      await container
          .read(onboardingControllerProvider.notifier)
          .markLocallyComplete();

      expect(
        container.read(onboardingControllerProvider).requireValue.isComplete,
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.onboardingCompleteKey), isTrue);
    },
  );

  test(
    'Given a signed-in user, When completeOnboarding is called, Then preferences and the flag are written for that user',
    () async {
      when(() => authRepo.currentUser).thenReturn(const UserEntity(id: 'u1'));
      final container = await buildContainer({});

      await container
          .read(onboardingControllerProvider.notifier)
          .completeOnboarding();

      verify(() => userRepo.savePreferences('u1', any())).called(1);
      verify(() => userRepo.markOnboardingComplete('u1')).called(1);
    },
  );

  test(
    'Given stored locale_code vi, When onboarding completes and persists, Then savePreferences receives languageCode vi',
    () async {
      when(() => authRepo.currentUser).thenReturn(const UserEntity(id: 'u1'));
      final container = await buildContainer({'locale_code': 'vi'});

      await container
          .read(onboardingControllerProvider.notifier)
          .completeOnboarding();

      final saved =
          verify(() => userRepo.savePreferences('u1', captureAny()))
                  .captured
                  .single
              as UserPreferences;
      expect(saved.languageCode, 'vi');
    },
  );

  test(
    'Given no user, When completeOnboarding is called, Then Firestore is skipped and onboarding is complete',
    () async {
      when(() => authRepo.currentUser).thenReturn(null);
      final container = await buildContainer({});

      await container
          .read(onboardingControllerProvider.notifier)
          .completeOnboarding();

      verifyNever(() => userRepo.savePreferences(any(), any()));
      verifyNever(() => userRepo.markOnboardingComplete(any()));
      expect(
        container.read(onboardingControllerProvider).requireValue.isComplete,
        isTrue,
      );
    },
  );

  test(
    'Given a stored complete flag, When resetOnboarding is called, Then the flag is cleared',
    () async {
      final container = await buildContainer({
        AppConstants.onboardingCompleteKey: true,
      });

      await container
          .read(onboardingControllerProvider.notifier)
          .resetOnboarding();

      expect(
        container.read(onboardingControllerProvider).requireValue.isComplete,
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppConstants.onboardingCompleteKey), isFalse);
    },
  );
}
