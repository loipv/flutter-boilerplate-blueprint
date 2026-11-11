import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/features/auth/application/auth_controller.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockUserRepository userRepo;
  late ProviderContainer container;

  const anon = UserEntity(
    id: 'anon1',
    isAnonymous: true,
    signInProvider: 'anonymous',
    preferences: UserPreferences(hapticsEnabled: false),
  );
  const google = UserEntity(
    id: 'g1',
    displayName: 'Ada',
    signInProvider: 'google',
  );

  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  setUp(() {
    authRepo = MockAuthRepository();
    userRepo = MockUserRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(userRepo),
      ],
    );
    addTearDown(container.dispose);

    when(
      () => userRepo.recordLogin(
        any(),
        signInProvider: any(named: 'signInProvider'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => userRepo.updateProfile(any(), name: any(named: 'name')),
    ).thenAnswer((_) async {});
    when(() => userRepo.savePreferences(any(), any())).thenAnswer((_) async {});
  });

  /// Builds the controller with [anon] as the already-signed-in user.
  Future<void> startSignedInAsAnon() async {
    when(
      () => authRepo.authStateChanges(),
    ).thenAnswer((_) => Stream.value(anon));
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
  }

  test(
    'Given no session, When signInAnonymously is called, Then it records the login and emits the user',
    () async {
      when(
        () => authRepo.authStateChanges(),
      ).thenAnswer((_) => const Stream<UserEntity?>.empty());
      when(
        () => authRepo.signInAnonymously(name: any(named: 'name')),
      ).thenAnswer((_) async => anon);
      container.listen(authControllerProvider, (_, _) {});

      await container.read(authControllerProvider.notifier).signInAnonymously();

      expect(container.read(authControllerProvider).value, anon);
      verify(
        () => userRepo.recordLogin('anon1', signInProvider: 'anonymous'),
      ).called(1);
    },
  );

  test(
    'Given an anonymous user, When signInWithGoogle yields a new uid, Then preferences are migrated',
    () async {
      await startSignedInAsAnon();
      when(() => authRepo.signInWithGoogle()).thenAnswer((_) async => google);

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      verify(() => userRepo.savePreferences('g1', anon.preferences)).called(1);
      verify(() => userRepo.updateProfile('g1', name: 'Ada')).called(1);
      expect(container.read(authControllerProvider).value, google);
    },
  );

  test(
    'Given an anonymous user, When Google sign-in is canceled, Then it is swallowed and the previous user is kept',
    () async {
      await startSignedInAsAnon();
      when(
        () => authRepo.signInWithGoogle(),
      ).thenThrow(const Failure.auth('canceled'));

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(container.read(authControllerProvider).value, anon);
    },
  );

  test(
    'Given an anonymous user, When Google sign-in fails otherwise, Then it rethrows and keeps the previous user',
    () async {
      await startSignedInAsAnon();
      when(
        () => authRepo.signInWithGoogle(),
      ).thenThrow(const Failure.network());

      await expectLater(
        container.read(authControllerProvider.notifier).signInWithGoogle(),
        throwsA(isA<Failure>()),
      );

      expect(container.read(authControllerProvider).value, anon);
    },
  );

  group('deleteAccount', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      when(() => userRepo.deleteUserData(any())).thenAnswer((_) async {});
      when(() => authRepo.deleteAuthAccount()).thenAnswer((_) async {});
      when(() => authRepo.reauthenticateForDeletion()).thenAnswer((_) async {});
    });

    test(
      'Given no signed-in user, When deleteAccount is called, Then it returns a message and deletes nothing',
      () async {
        when(
          () => authRepo.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));
        container.listen(authControllerProvider, (_, _) {});
        await container.read(authControllerProvider.future);

        final result = await container
            .read(authControllerProvider.notifier)
            .deleteAccount();

        expect(result, 'No signed-in user.');
        verifyNever(() => userRepo.deleteUserData(any()));
        verifyNever(() => authRepo.deleteAuthAccount());
      },
    );

    test(
      'Given a signed-in user, When deleteAccount succeeds, Then it deletes user data then the auth account, resets local state and returns null',
      () async {
        SharedPreferences.setMockInitialValues({
          AppConstants.onboardingCompleteKey: true,
          'theme_mode': 'dark',
        });
        await startSignedInAsAnon();

        final result = await container
            .read(authControllerProvider.notifier)
            .deleteAccount();

        expect(result, isNull);
        verifyInOrder([
          () => userRepo.deleteUserData('anon1'),
          () => authRepo.deleteAuthAccount(),
        ]);
        verifyNever(() => authRepo.reauthenticateForDeletion());
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(AppConstants.onboardingCompleteKey), isFalse);
        expect(prefs.containsKey('theme_mode'), isFalse);
      },
    );

    test(
      'Given a non-anonymous user, When deletion needs recent login, Then it reauthenticates and retries',
      () async {
        when(
          () => authRepo.authStateChanges(),
        ).thenAnswer((_) => Stream.value(google));
        container.listen(authControllerProvider, (_, _) {});
        await container.read(authControllerProvider.future);
        var calls = 0;
        when(() => authRepo.deleteAuthAccount()).thenAnswer((_) async {
          if (calls++ == 0) throw const Failure.auth('requires-recent-login');
        });

        final result = await container
            .read(authControllerProvider.notifier)
            .deleteAccount();

        expect(result, isNull);
        verifyInOrder([
          () => authRepo.deleteAuthAccount(),
          () => authRepo.reauthenticateForDeletion(),
          () => authRepo.deleteAuthAccount(),
        ]);
      },
    );

    test(
      'Given an anonymous user, When deletion needs recent login, Then it skips reauthentication and returns null',
      () async {
        await startSignedInAsAnon();
        when(
          () => authRepo.deleteAuthAccount(),
        ).thenThrow(const Failure.auth('requires-recent-login'));

        final result = await container
            .read(authControllerProvider.notifier)
            .deleteAccount();

        expect(result, isNull);
        verifyNever(() => authRepo.reauthenticateForDeletion());
        verify(() => authRepo.deleteAuthAccount()).called(1);
      },
    );

    test(
      'Given another auth failure, When deleteAccount is called, Then it returns the authentication message',
      () async {
        await startSignedInAsAnon();
        when(
          () => authRepo.deleteAuthAccount(),
        ).thenThrow(const Failure.auth('boom'));

        final result = await container
            .read(authControllerProvider.notifier)
            .deleteAccount();

        expect(result, 'Authentication error. Please try again.');
        verifyNever(() => authRepo.reauthenticateForDeletion());
      },
    );

    test(
      'Given a non-auth failure, When deleteAccount is called, Then it returns the generic message',
      () async {
        await startSignedInAsAnon();
        when(
          () => userRepo.deleteUserData(any()),
        ).thenThrow(const Failure.network());

        final result = await container
            .read(authControllerProvider.notifier)
            .deleteAccount();

        expect(result, 'Something went wrong. Please try again.');
        verifyNever(() => authRepo.deleteAuthAccount());
      },
    );

    test(
      'Given an unexpected exception, When deleteAccount is called, Then it returns the generic message',
      () async {
        await startSignedInAsAnon();
        when(() => userRepo.deleteUserData(any())).thenThrow(StateError('x'));

        final result = await container
            .read(authControllerProvider.notifier)
            .deleteAccount();

        expect(result, 'Something went wrong. Please try again.');
      },
    );
  });

  group('updateDisplayName', () {
    test(
      'Given a current user, When updateDisplayName is called, Then it updates the auth and profile names',
      () async {
        when(() => authRepo.updateDisplayName(any())).thenAnswer((_) async {});
        when(() => authRepo.currentUser).thenReturn(google);
        await startSignedInAsAnon();

        await container
            .read(authControllerProvider.notifier)
            .updateDisplayName('Ada');

        verify(() => authRepo.updateDisplayName('Ada')).called(1);
        verify(() => userRepo.updateProfile('g1', name: 'Ada')).called(1);
      },
    );

    test(
      'Given no current user, When updateDisplayName is called, Then only the auth name is updated',
      () async {
        when(() => authRepo.updateDisplayName(any())).thenAnswer((_) async {});
        when(() => authRepo.currentUser).thenReturn(null);
        await startSignedInAsAnon();

        await container
            .read(authControllerProvider.notifier)
            .updateDisplayName('Ada');

        verify(() => authRepo.updateDisplayName('Ada')).called(1);
        verifyNever(
          () => userRepo.updateProfile(any(), name: any(named: 'name')),
        );
      },
    );
  });

  group('signOut', () {
    test(
      'Given a signed-in user, When signOut is called, Then it resets local onboarding and theme and signs out of the auth repository',
      () async {
        SharedPreferences.setMockInitialValues({
          AppConstants.onboardingCompleteKey: true,
          'theme_mode': 'dark',
        });
        when(() => authRepo.signOut()).thenAnswer((_) async {});
        await startSignedInAsAnon();

        await container.read(authControllerProvider.notifier).signOut();

        verify(() => authRepo.signOut()).called(1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(AppConstants.onboardingCompleteKey), isFalse);
        expect(prefs.containsKey('theme_mode'), isFalse);
      },
    );
  });
}
