import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/features/auth/application/auth_controller.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/user_profile/application/user_profile_providers.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockUserRepository userRepo;
  late ProviderContainer container;

  const user = UserEntity(id: 'u1', displayName: 'Ada');

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

  group('currentUser', () {
    test(
      'Given the auth stream has not emitted, When reading currentUser, Then it is loading',
      () {
        when(
          () => authRepo.authStateChanges(),
        ).thenAnswer((_) => const Stream<UserEntity?>.empty());

        expect(container.read(currentUserProvider).isLoading, isTrue);
      },
    );

    test(
      'Given a signed-in user, When reading currentUser, Then it mirrors authControllerProvider',
      () async {
        when(
          () => authRepo.authStateChanges(),
        ).thenAnswer((_) => Stream.value(user));
        container.listen(currentUserProvider, (_, _) {});
        await container.read(authControllerProvider.future);

        expect(container.read(currentUserProvider).value, user);
        expect(
          container.read(currentUserProvider),
          container.read(authControllerProvider),
        );
      },
    );
  });

  group('userProfileStream', () {
    test(
      'Given no signed-in user, When listening to userProfileStream, Then it emits nothing and never queries the repository',
      () async {
        when(
          () => authRepo.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));
        container.listen(authControllerProvider, (_, _) {});
        await container.read(authControllerProvider.future);

        final values = <AsyncValue<UserEntity?>>[];
        container.listen(
          userProfileStreamProvider,
          (_, next) => values.add(next),
          fireImmediately: true,
        );
        await Future<void>.delayed(Duration.zero);

        expect(values, isNotEmpty);
        expect(values.every((v) => v.value == null), isTrue);
        verifyNever(() => userRepo.getUserStream(any()));
      },
    );

    test(
      'Given a signed-in user, When listening to userProfileStream, Then it emits the repository values',
      () async {
        when(
          () => authRepo.authStateChanges(),
        ).thenAnswer((_) => Stream.value(user));
        when(() => userRepo.getUserStream('u1')).thenAnswer(
          (_) =>
              Stream.fromIterable([user, user.copyWith(displayName: 'Grace')]),
        );
        container.listen(authControllerProvider, (_, _) {});
        await container.read(authControllerProvider.future);

        final values = <UserEntity?>[];
        container.listen(userProfileStreamProvider, (_, next) {
          final v = next.value;
          if (next.hasValue) values.add(v);
        }, fireImmediately: true);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(values, [user, user.copyWith(displayName: 'Grace')]);
        verify(() => userRepo.getUserStream('u1')).called(1);
      },
    );
  });
}
