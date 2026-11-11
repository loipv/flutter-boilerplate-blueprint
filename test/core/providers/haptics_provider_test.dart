import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/core/providers/haptics_provider.dart';
import 'package:blueprint_app/features/auth/application/auth_controller.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/user_profile/application/user_profile_providers.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockUserRepository userRepo;
  late ProviderContainer container;

  const user = UserEntity(id: 'u1');

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
  });

  Future<void> signIn(UserEntity? u) async {
    when(() => authRepo.authStateChanges()).thenAnswer((_) => Stream.value(u));
    container.listen(hapticsEnabledProvider, (_, _) {});
    await container.read(authControllerProvider.future);
  }

  /// Lets the profile stream deliver its events.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('hapticsEnabled', () {
    test(
      'Given the user is signed out, When reading hapticsEnabled, Then it falls back to true',
      () async {
        await signIn(null);
        await settle();

        expect(container.read(hapticsEnabledProvider), isTrue);
        verifyNever(() => userRepo.getUserStream(any()));
      },
    );

    test(
      'Given a signed-in user whose profile is still loading, When reading hapticsEnabled, Then it falls back to true',
      () async {
        when(
          () => userRepo.getUserStream('u1'),
        ).thenAnswer((_) => const Stream<UserEntity?>.empty());
        await signIn(user);

        expect(container.read(userProfileStreamProvider).isLoading, isTrue);
        expect(container.read(hapticsEnabledProvider), isTrue);
      },
    );

    test(
      'Given a profile with hapticsEnabled false, When reading hapticsEnabled, Then it is false',
      () async {
        when(() => userRepo.getUserStream('u1')).thenAnswer(
          (_) => Stream.value(
            user.copyWith(
              preferences: const UserPreferences(hapticsEnabled: false),
            ),
          ),
        );
        await signIn(user);
        await settle();

        expect(container.read(hapticsEnabledProvider), isFalse);
      },
    );

    test(
      'Given a profile with hapticsEnabled true, When reading hapticsEnabled, Then it is true',
      () async {
        when(() => userRepo.getUserStream('u1')).thenAnswer(
          (_) => Stream.value(
            user.copyWith(
              preferences: const UserPreferences(hapticsEnabled: true),
            ),
          ),
        );
        await signIn(user);
        await settle();

        expect(container.read(hapticsEnabledProvider), isTrue);
      },
    );

    test(
      'Given the profile stream errors, When reading hapticsEnabled, Then it falls back to true',
      () async {
        when(
          () => userRepo.getUserStream('u1'),
        ).thenAnswer((_) => Stream<UserEntity?>.error(Exception('boom')));
        await signIn(user);
        await settle();

        expect(container.read(userProfileStreamProvider).hasError, isTrue);
        expect(container.read(hapticsEnabledProvider), isTrue);
      },
    );
  });
}
