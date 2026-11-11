import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

const _uid = 'user-1';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseUserRepository repository;
  late DocumentReference<Map<String, dynamic>> userDoc;

  FirebaseException firestoreError() =>
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

  /// Registers [method] to throw on the exact doc the repository will call.
  void injectError(Symbol method) {
    whenCalling(
      Invocation.method(method, null),
    ).on(userDoc).thenThrow(firestoreError());
  }

  Future<Map<String, dynamic>?> readDoc() async => (await userDoc.get()).data();

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirebaseUserRepository(firestore);
    userDoc = firestore.collection(AppConstants.usersCollection).doc(_uid);
  });

  group('getUserStream', () {
    test('Given no document, When listening, Then it emits null', () async {
      expect(await repository.getUserStream(_uid).first, isNull);
    });

    test(
      'Given a valid document, When listening, Then it emits an entity with id == uid',
      () async {
        await userDoc.set({
          'email': 'a@b.com',
          'displayName': 'Ada',
          'totalSessionCount': 3,
        });

        final user = await repository.getUserStream(_uid).first;

        expect(user, isNotNull);
        expect(user!.id, _uid);
        expect(user.email, 'a@b.com');
        expect(user.displayName, 'Ada');
        expect(user.totalSessionCount, 3);
      },
    );

    // Regression: Firestore returns Timestamps for date fields (recordLogin
    // writes serverTimestamp), which UserEntity.fromJson cannot cast.
    test(
      'Given a document with Timestamp dates, When listening, Then it emits the entity with matching DateTimes and the stored preferences',
      () async {
        final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
        final lastLogin = DateTime.utc(2026, 11, 11, 9, 30);
        await userDoc.set({
          'createdAt': Timestamp.fromDate(created),
          'lastLoginAt': Timestamp.fromDate(lastLogin),
          'signInProvider': 'anonymous',
          'totalSessionCount': 2,
          'preferences': {'themeMode': 'dark', 'hapticsEnabled': false},
        });

        final user = await repository.getUserStream(_uid).first;

        expect(user, isNotNull);
        expect(user!.createdAt, created);
        expect(user.lastLoginAt, lastLogin);
        expect(user.lastAccessedAt, isNull);
        expect(user.totalSessionCount, 2);
        expect(
          user.preferences,
          const UserPreferences(
            themeMode: ThemeMode.dark,
            hapticsEnabled: false,
          ),
        );
      },
    );

    test(
      'Given recordLogin wrote the document, When listening, Then it emits a non-null entity with lastLoginAt set',
      () async {
        await repository.recordLogin(_uid, signInProvider: 'anonymous');

        final user = await repository.getUserStream(_uid).first;

        expect(user, isNotNull);
        expect(user!.lastLoginAt, isNotNull);
        expect(user.signInProvider, 'anonymous');
      },
    );

    test(
      'Given a malformed document, When listening, Then it emits null and does not throw',
      () async {
        await userDoc.set({'totalSessionCount': 'not-a-number'});

        final user = await repository.getUserStream(_uid).first;

        expect(user, isNull);
      },
    );
  });

  group('savePreferences', () {
    test(
      'Given preferences, When saved, Then the document holds the preference fields',
      () async {
        await repository.savePreferences(
          _uid,
          const UserPreferences(
            themeMode: ThemeMode.dark,
            hapticsEnabled: false,
          ),
        );

        final prefs = (await readDoc())!['preferences'] as Map;
        expect(prefs['themeMode'], 'dark');
        expect(prefs['hapticsEnabled'], false);
      },
    );

    test(
      'Given existing fields, When preferences are saved, Then they are merged',
      () async {
        await userDoc.set({'displayName': 'Ada'});

        await repository.savePreferences(_uid, const UserPreferences());

        final data = (await readDoc())!;
        expect(data['displayName'], 'Ada');
        expect(data['preferences'], isNotNull);
      },
    );

    test(
      'Given an unrelated field and existing preferences, When saved, Then no top-level key contains a dot and preferences hold the new values',
      () async {
        await userDoc.set({
          'displayName': 'Ada',
          'preferences': {'themeMode': 'light', 'hapticsEnabled': true},
        });

        await repository.savePreferences(
          _uid,
          const UserPreferences(
            themeMode: ThemeMode.dark,
            hapticsEnabled: false,
          ),
        );

        final data = (await readDoc())!;
        expect(data.keys.where((k) => k.contains('.')), isEmpty);
        expect(data['displayName'], 'Ada');
        final prefs = data['preferences'] as Map;
        expect(prefs['themeMode'], 'dark');
        expect(prefs['hapticsEnabled'], false);
      },
    );

    test(
      'Given a set error, When saved, Then it throws Failure.server()',
      () async {
        injectError(#set);

        await expectLater(
          repository.savePreferences(_uid, const UserPreferences()),
          throwsA(const Failure.server()),
        );
      },
    );
  });

  group('recordLogin', () {
    test(
      'Given a provider, When login is recorded, Then provider, timestamp and count are written',
      () async {
        await repository.recordLogin(_uid, signInProvider: 'google');

        final data = (await readDoc())!;
        expect(data['signInProvider'], 'google');
        expect(data['lastLoginAt'], isA<Timestamp>());
        expect(data['totalSessionCount'], 1);
      },
    );

    test(
      'Given a prior session, When login is recorded again, Then the count increments',
      () async {
        await repository.recordLogin(_uid, signInProvider: 'google');
        await repository.recordLogin(_uid, signInProvider: 'google');

        expect((await readDoc())!['totalSessionCount'], 2);
      },
    );

    test(
      'Given a null provider, When login is recorded, Then signInProvider is absent',
      () async {
        await repository.recordLogin(_uid);

        final data = (await readDoc())!;
        expect(data.containsKey('signInProvider'), isFalse);
        expect(data['lastLoginAt'], isA<Timestamp>());
      },
    );

    test(
      'Given a set error, When login is recorded, Then it completes normally',
      () async {
        injectError(#set);

        await repository.recordLogin(_uid, signInProvider: 'google');

        expect((await userDoc.get()).exists, isFalse);
      },
    );
  });

  group('updateProfile', () {
    test(
      'Given a name, When the profile is updated, Then displayName is stored',
      () async {
        await repository.updateProfile(_uid, name: 'Grace');

        expect((await readDoc())!['displayName'], 'Grace');
      },
    );

    test(
      'Given no name, When the profile is updated, Then nothing is written',
      () async {
        await repository.updateProfile(_uid);

        expect((await userDoc.get()).exists, isFalse);
      },
    );

    test(
      'Given a set error, When the profile is updated, Then it throws Failure.server()',
      () async {
        injectError(#set);

        await expectLater(
          repository.updateProfile(_uid, name: 'Grace'),
          throwsA(const Failure.server()),
        );
      },
    );
  });

  group('markOnboardingComplete', () {
    test(
      'Given a user, When onboarding is marked complete, Then the flag is true',
      () async {
        await repository.markOnboardingComplete(_uid);

        expect((await readDoc())!['onboardingCompleted'], true);
      },
    );

    test(
      'Given a set error, When onboarding is marked complete, Then it completes normally',
      () async {
        injectError(#set);

        await repository.markOnboardingComplete(_uid);

        expect((await userDoc.get()).exists, isFalse);
      },
    );
  });

  group('deleteUserData', () {
    test(
      'Given an existing document, When deleted, Then it no longer exists',
      () async {
        await userDoc.set({'displayName': 'Ada'});

        await repository.deleteUserData(_uid);

        expect((await userDoc.get()).exists, isFalse);
      },
    );

    test(
      'Given a delete error, When deleted, Then it throws Failure.server()',
      () async {
        await userDoc.set({'displayName': 'Ada'});
        injectError(#delete);

        await expectLater(
          repository.deleteUserData(_uid),
          throwsA(const Failure.server()),
        );
        expect((await userDoc.get()).exists, isTrue);
      },
    );
  });

  group('updateLastAccessed', () {
    test(
      'Given a user, When last accessed is updated, Then lastAccessedAt is a timestamp',
      () async {
        await repository.updateLastAccessed(_uid);

        expect((await readDoc())!['lastAccessedAt'], isA<Timestamp>());
      },
    );

    test(
      'Given a set error, When last accessed is updated, Then it completes normally',
      () async {
        injectError(#set);

        await repository.updateLastAccessed(_uid);

        expect((await userDoc.get()).exists, isFalse);
      },
    );
  });
}
