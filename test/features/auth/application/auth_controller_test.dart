import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/core/errors/failure.dart';
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

  test('signInAnonymously records the login and emits the user', () async {
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
  });

  test('signInWithGoogle migrates preferences when the uid changes', () async {
    await startSignedInAsAnon();
    when(() => authRepo.signInWithGoogle()).thenAnswer((_) async => google);

    await container.read(authControllerProvider.notifier).signInWithGoogle();

    verify(() => userRepo.savePreferences('g1', anon.preferences)).called(1);
    verify(() => userRepo.updateProfile('g1', name: 'Ada')).called(1);
    expect(container.read(authControllerProvider).value, google);
  });

  test(
    'signInWithGoogle swallows a canceled sign-in and keeps the previous user',
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
    'signInWithGoogle rethrows other failures and keeps the previous user',
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
}
