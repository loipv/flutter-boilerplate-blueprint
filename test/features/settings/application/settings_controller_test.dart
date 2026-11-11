import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/features/auth/application/auth_controller.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/settings/application/settings_controller.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockUserRepository userRepo;
  late ProviderContainer container;

  const user = UserEntity(id: 'u1');

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
    when(() => userRepo.savePreferences(any(), any())).thenAnswer((_) async {});
    when(
      () => userRepo.getUserStream(any()),
    ).thenAnswer((_) => Stream.value(null));
  });

  Future<void> signIn(UserEntity? u) async {
    when(() => authRepo.authStateChanges()).thenAnswer((_) => Stream.value(u));
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
  }

  group('updateThemeMode', () {
    test(
      'Given a signed-in user, When updateThemeMode(dark) is called, Then preferences with the dark theme are saved',
      () async {
        await signIn(user);

        await container
            .read(settingsControllerProvider.notifier)
            .updateThemeMode(ThemeMode.dark);

        verify(
          () => userRepo.savePreferences(
            'u1',
            const UserPreferences(themeMode: ThemeMode.dark),
          ),
        ).called(1);
        expect(container.read(settingsControllerProvider).hasError, isFalse);
      },
    );

    test(
      'Given stored preferences, When updateThemeMode is called, Then other preferences are preserved',
      () async {
        await signIn(user);
        when(() => userRepo.getUserStream('u1')).thenAnswer(
          (_) => Stream.value(
            const UserEntity(
              id: 'u1',
              preferences: UserPreferences(hapticsEnabled: false),
            ),
          ),
        );

        await container
            .read(settingsControllerProvider.notifier)
            .updateThemeMode(ThemeMode.light);

        verify(
          () => userRepo.savePreferences(
            'u1',
            const UserPreferences(
              themeMode: ThemeMode.light,
              hapticsEnabled: false,
            ),
          ),
        ).called(1);
      },
    );

    test(
      'Given no user, When updateThemeMode is called, Then nothing is saved',
      () async {
        await signIn(null);

        await container
            .read(settingsControllerProvider.notifier)
            .updateThemeMode(ThemeMode.dark);

        verifyNever(() => userRepo.savePreferences(any(), any()));
      },
    );

    test(
      'Given saving fails, When updateThemeMode is called, Then the state holds the error',
      () async {
        await signIn(user);
        when(
          () => userRepo.savePreferences(any(), any()),
        ).thenThrow(StateError('x'));

        await container
            .read(settingsControllerProvider.notifier)
            .updateThemeMode(ThemeMode.dark);

        expect(container.read(settingsControllerProvider).hasError, isTrue);
      },
    );
  });

  group('updateLanguage', () {
    test(
      "Given a signed-in user, When updateLanguage('vi') is called, Then savePreferences gets UserPreferences(languageCode: 'vi')",
      () async {
        await signIn(user);

        await container
            .read(settingsControllerProvider.notifier)
            .updateLanguage('vi');

        verify(
          () => userRepo.savePreferences(
            'u1',
            const UserPreferences(languageCode: 'vi'),
          ),
        ).called(1);
        expect(container.read(settingsControllerProvider).hasError, isFalse);
      },
    );

    test(
      "Given stored languageCode 'vi' and hapticsEnabled false, When updateLanguage(null) is called, Then languageCode is null and hapticsEnabled stays false",
      () async {
        await signIn(user);
        when(() => userRepo.getUserStream('u1')).thenAnswer(
          (_) => Stream.value(
            const UserEntity(
              id: 'u1',
              preferences: UserPreferences(
                languageCode: 'vi',
                hapticsEnabled: false,
              ),
            ),
          ),
        );

        await container
            .read(settingsControllerProvider.notifier)
            .updateLanguage(null);

        verify(
          () => userRepo.savePreferences(
            'u1',
            const UserPreferences(hapticsEnabled: false),
          ),
        ).called(1);
      },
    );

    test(
      "Given savePreferences throws, When updateLanguage('vi') is called, Then the controller state has an error and nothing throws to the caller",
      () async {
        await signIn(user);
        when(
          () => userRepo.savePreferences(any(), any()),
        ).thenThrow(StateError('x'));

        await container
            .read(settingsControllerProvider.notifier)
            .updateLanguage('vi');

        expect(container.read(settingsControllerProvider).hasError, isTrue);
      },
    );
  });

  group('updateHaptics', () {
    test(
      'Given a signed-in user, When updateHaptics(false) is called, Then preferences with haptics off are saved',
      () async {
        await signIn(user);

        await container
            .read(settingsControllerProvider.notifier)
            .updateHaptics(false);

        verify(
          () => userRepo.savePreferences(
            'u1',
            const UserPreferences(hapticsEnabled: false),
          ),
        ).called(1);
      },
    );

    test(
      'Given no user, When updateHaptics is called, Then nothing is saved',
      () async {
        await signIn(null);

        await container
            .read(settingsControllerProvider.notifier)
            .updateHaptics(false);

        verifyNever(() => userRepo.savePreferences(any(), any()));
      },
    );

    // Regression: SettingsScreen only ref.reads the notifier, so nothing
    // listens to it while a real Firestore write is in flight.
    test(
      'Given a signed-in user and a slow savePreferences, When updateHaptics(false) is called with nothing listening to the controller, Then it completes without throwing and the preferences are saved',
      () async {
        await signIn(user);
        final write = Completer<void>();
        when(
          () => userRepo.savePreferences(any(), any()),
        ).thenAnswer((_) => write.future);

        final pending = container
            .read(settingsControllerProvider.notifier)
            .updateHaptics(false);
        // Give Riverpod time to dispose an unlistened provider mid-write.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        write.complete();

        await expectLater(pending, completes);
        verify(
          () => userRepo.savePreferences(
            'u1',
            const UserPreferences(hapticsEnabled: false),
          ),
        ).called(1);
      },
    );
  });

  // BEGIN_NOTIFICATIONS
  group('updateNotificationTime', () {
    test(
      'Given a signed-in user, When updateNotificationTime(08:30) is called, Then preferences with that time are saved',
      () async {
        await signIn(user);

        await container
            .read(settingsControllerProvider.notifier)
            .updateNotificationTime('08:30');

        verify(
          () => userRepo.savePreferences(
            'u1',
            const UserPreferences(notificationTime: '08:30'),
          ),
        ).called(1);
      },
    );

    test(
      'Given no user, When updateNotificationTime is called, Then nothing is saved',
      () async {
        await signIn(null);

        await container
            .read(settingsControllerProvider.notifier)
            .updateNotificationTime('08:30');

        verifyNever(() => userRepo.savePreferences(any(), any()));
      },
    );
  });
  // END_NOTIFICATIONS
}
