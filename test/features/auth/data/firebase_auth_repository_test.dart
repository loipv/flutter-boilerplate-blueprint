import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:blueprint_app/core/domain/analytics_repository.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

// Firebase SDK test doubles, used only where firebase_auth_mocks cannot
// simulate the behavior (see the comments at each use).

/// `MockUser.linkWithCredential` / `linkWithProvider` assert that the user is
/// not anonymous, so a successful anonymous link needs a mocktail user.
class _MockFirebaseAuthSdk extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

/// `UserInfo` constructors are `@protected`; this fake supplies a provider id.
class _FakeUserInfo extends Fake implements UserInfo {
  _FakeUserInfo(this.providerId);

  @override
  final String providerId;
}

/// `UserMetadata` constructors are `@protected`.
class _FakeUserMetadata extends Fake implements UserMetadata {
  @override
  DateTime? get creationTime => null;

  @override
  DateTime? get lastSignInTime => null;
}

/// Records each call made through [FirebaseAuthRepository]'s Apple fetcher.
class _AppleFetcherSpy {
  _AppleFetcherSpy(this._respond);

  final Future<AuthorizationCredentialAppleID> Function() _respond;
  final calls = <({List<AppleIDAuthorizationScopes> scopes, String? nonce})>[];

  Future<AuthorizationCredentialAppleID> call({
    required List<AppleIDAuthorizationScopes> scopes,
    String? nonce,
  }) {
    calls.add((scopes: scopes, nonce: nonce));
    return _respond();
  }
}

AuthorizationCredentialAppleID _appleCredential({
  String? identityToken = 'apple-id-token',
  String? givenName,
  String? familyName,
}) {
  return AuthorizationCredentialAppleID(
    userIdentifier: 'apple-user',
    givenName: givenName,
    familyName: familyName,
    authorizationCode: 'apple-auth-code',
    email: null,
    identityToken: identityToken,
    state: null,
  );
}

FirebaseAuthException _authError(String code, [String? message]) =>
    FirebaseAuthException(code: code, message: message ?? '$code message');

void main() {
  late _MockGoogleSignIn googleSignIn;
  late _MockGoogleSignInAccount googleAccount;
  late _MockAnalyticsRepository analytics;
  late _AppleFetcherSpy apple;

  setUpAll(() {
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback'));
    registerFallbackValue(OAuthProvider('apple.com'));
  });

  setUp(() {
    googleSignIn = _MockGoogleSignIn();
    googleAccount = _MockGoogleSignInAccount();
    analytics = _MockAnalyticsRepository();
    apple = _AppleFetcherSpy(() async => _appleCredential());

    when(
      () => googleAccount.authentication,
    ).thenReturn(const GoogleSignInAuthentication(idToken: 'google-id-token'));
    when(() => googleAccount.displayName).thenReturn(null);
    when(
      () => googleSignIn.authenticate(),
    ).thenAnswer((_) async => googleAccount);
    when(() => googleSignIn.signOut()).thenAnswer((_) async {});
    when(() => analytics.reset()).thenAnswer((_) async {});
  });

  FirebaseAuthRepository buildRepo(
    FirebaseAuth auth, {
    bool isAndroid = false,
  }) {
    return FirebaseAuthRepository(
      auth,
      analytics,
      googleSignIn: googleSignIn,
      fetchAppleCredential: apple.call,
      isAndroid: isAndroid,
    );
  }

  /// A [MockFirebaseAuth] whose current user is a fresh anonymous user.
  ///
  /// No `mockUser` is configured, so a later non-anonymous sign-in produces a
  /// different, non-anonymous user (an "existing account").
  Future<MockFirebaseAuth> anonymousAuth() async {
    final auth = MockFirebaseAuth();
    await auth.signInAnonymously();
    return auth;
  }

  /// A mocktail anonymous user that becomes non-anonymous once linked.
  ///
  /// Used because `MockUser` cannot complete an anonymous link (it asserts).
  ({_MockFirebaseAuthSdk auth, _MockUser user}) linkableAnonymousUser({
    required String linkedProviderId,
  }) {
    final auth = _MockFirebaseAuthSdk();
    final user = _MockUser();
    final credential = _MockUserCredential();
    var linked = false;

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('anon-uid');
    when(() => user.email).thenReturn(null);
    when(() => user.displayName).thenReturn('Anon Ada');
    when(() => user.metadata).thenReturn(_FakeUserMetadata());
    when(() => user.isAnonymous).thenAnswer((_) => !linked);
    when(() => user.providerData).thenAnswer(
      (_) => linked ? [_FakeUserInfo(linkedProviderId)] : <UserInfo>[],
    );
    when(() => credential.user).thenReturn(user);
    when(() => user.linkWithCredential(any())).thenAnswer((_) async {
      linked = true;
      return credential;
    });
    when(() => user.linkWithProvider(any())).thenAnswer((_) async {
      linked = true;
      return credential;
    });
    return (auth: auth, user: user);
  }

  group('authStateChanges', () {
    test(
      'Given a signed-in user, When listening, Then the current user is emitted first and then the stream events',
      () async {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', displayName: 'Ada'),
        );

        final events = await buildRepo(
          auth,
        ).authStateChanges().take(2).toList();

        expect(events.map((e) => e?.id), ['u1', 'u1']);
        expect(events.first?.displayName, 'Ada');
      },
    );

    test(
      'Given signed out, When listening, Then the first event is null',
      () async {
        final auth = MockFirebaseAuth();

        final first = await buildRepo(auth).authStateChanges().first;

        expect(first, isNull);
      },
    );
  });

  group('currentUser', () {
    test(
      'Given a signed-in user, When reading currentUser, Then it returns that user as an entity',
      () {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'ada@example.com'),
        );

        final user = buildRepo(auth).currentUser;

        expect(user?.id, 'u1');
        expect(user?.email, 'ada@example.com');
      },
    );

    test(
      'Given signed out, When reading currentUser, Then it returns null',
      () {
        expect(buildRepo(MockFirebaseAuth()).currentUser, isNull);
      },
    );
  });

  group('signInAnonymously', () {
    test(
      'Given success and a name, When signing in, Then it returns an anonymous entity with that displayName',
      () async {
        final auth = MockFirebaseAuth();

        final user = await buildRepo(auth).signInAnonymously(name: 'Ada');

        expect(user.isAnonymous, isTrue);
        expect(user.signInProvider, 'anonymous');
        expect(user.displayName, 'Ada');
      },
    );

    test(
      'Given success and no name, When signing in, Then it returns an anonymous entity without a displayName',
      () async {
        final user = await buildRepo(MockFirebaseAuth()).signInAnonymously();

        expect(user.isAnonymous, isTrue);
        expect(user.displayName, isNull);
      },
    );

    test(
      'Given operation-not-allowed, When signing in, Then it throws Failure.auth with the exception message',
      () async {
        final auth = MockFirebaseAuth();
        whenCalling(Invocation.method(#signInAnonymously, null))
            .on(auth)
            .thenThrow(
              _authError('operation-not-allowed', 'Anonymous auth disabled'),
            );

        await expectLater(
          buildRepo(auth).signInAnonymously(),
          throwsA(const Failure.auth('Anonymous auth disabled')),
        );
      },
    );

    test(
      'Given an unexpected error, When signing in, Then it throws Failure.unknown',
      () async {
        final auth = MockFirebaseAuth();
        whenCalling(
          Invocation.method(#signInAnonymously, null),
        ).on(auth).thenThrow(Exception('boom'));

        await expectLater(
          buildRepo(auth).signInAnonymously(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });

  group('signInWithGoogle', () {
    test(
      'Given signed out and an account with an idToken, When signing in, Then it returns a non-anonymous entity',
      () async {
        final auth = MockFirebaseAuth(
          mockUser: MockUser(
            uid: 'g1',
            displayName: 'Ada',
            providerData: [_FakeUserInfo('google.com')],
          ),
        );

        final user = await buildRepo(auth).signInWithGoogle();

        expect(user.id, 'g1');
        expect(user.isAnonymous, isFalse);
        expect(user.signInProvider, 'google');
        verify(() => googleSignIn.authenticate()).called(1);
      },
    );

    test(
      'Given an anonymous current user, When signing in, Then it links instead of signing in and keeps the uid',
      () async {
        // mocktail SDK doubles: MockUser cannot complete an anonymous link.
        final fixture = linkableAnonymousUser(linkedProviderId: 'google.com');

        final user = await buildRepo(fixture.auth).signInWithGoogle();

        expect(user.id, 'anon-uid');
        expect(user.isAnonymous, isFalse);
        expect(user.signInProvider, 'google');
        verify(() => fixture.user.linkWithCredential(any())).called(1);
        verifyNever(() => fixture.auth.signInWithCredential(any()));
      },
    );

    test(
      'Given an anonymous user whose link hits credential-already-in-use, When signing in, Then it signs in to the existing account',
      () async {
        final auth = await anonymousAuth();
        final anonymous = auth.currentUser!;
        whenCalling(
          Invocation.method(#linkWithCredential, null),
        ).on(anonymous).thenThrow(_authError('credential-already-in-use'));

        final user = await buildRepo(auth).signInWithGoogle();

        expect(user.isAnonymous, isFalse);
        expect(user.id, isNot(anonymous.uid));
      },
    );

    test(
      'Given an anonymous user whose link hits email-already-in-use, When signing in, Then it throws Failure.auth(email-already-in-use)',
      () async {
        final auth = await anonymousAuth();
        whenCalling(
          Invocation.method(#linkWithCredential, null),
        ).on(auth.currentUser!).thenThrow(_authError('email-already-in-use'));

        await expectLater(
          buildRepo(auth).signInWithGoogle(),
          throwsA(const Failure.auth('email-already-in-use')),
        );
      },
    );

    test(
      'Given an anonymous user whose link hits another error, When signing in, Then it throws Failure.auth with that code',
      () async {
        final auth = await anonymousAuth();
        whenCalling(
          Invocation.method(#linkWithCredential, null),
        ).on(auth.currentUser!).thenThrow(_authError('network-request-failed'));

        await expectLater(
          buildRepo(auth).signInWithGoogle(),
          throwsA(const Failure.auth('network-request-failed')),
        );
      },
    );

    test(
      'Given the user cancels, When signing in, Then it throws Failure.auth(canceled)',
      () async {
        when(() => googleSignIn.authenticate()).thenThrow(
          const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        );

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithGoogle(),
          throwsA(const Failure.auth('canceled')),
        );
      },
    );

    test(
      'Given any other GoogleSignInException, When signing in, Then it throws Failure.unknown',
      () async {
        when(() => googleSignIn.authenticate()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
          ),
        );

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithGoogle(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );

    test(
      'Given Firebase throws credential-already-in-use, When signing in, Then it throws Failure.auth(credential-already-in-use)',
      () async {
        final auth = MockFirebaseAuth();
        whenCalling(
          Invocation.method(#signInWithCredential, null),
        ).on(auth).thenThrow(_authError('credential-already-in-use'));

        await expectLater(
          buildRepo(auth).signInWithGoogle(),
          throwsA(const Failure.auth('credential-already-in-use')),
        );
      },
    );

    test(
      'Given no Firebase displayName and a Google displayName, When signing in, Then the entity uses the Google displayName',
      () async {
        when(() => googleAccount.displayName).thenReturn('Ada');
        final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'g2'));

        final user = await buildRepo(auth).signInWithGoogle();

        expect(user.displayName, 'Ada');
      },
    );

    test(
      'Given an unexpected error, When signing in, Then it throws Failure.unknown',
      () async {
        when(() => googleSignIn.authenticate()).thenThrow(Exception('boom'));

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithGoogle(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });

  group('signInWithApple', () {
    test(
      'Given isAndroid is omitted on a non-Android test host, When signing in, Then it uses the native Apple fetcher',
      () async {
        final repo = FirebaseAuthRepository(
          MockFirebaseAuth(mockUser: MockUser(uid: 'a1')),
          analytics,
          googleSignIn: googleSignIn,
          fetchAppleCredential: apple.call,
        );

        final user = await repo.signInWithApple();

        expect(user.id, 'a1');
        expect(apple.calls, hasLength(1));
      },
    );

    test(
      'Given a credential with an identityToken, When signing in, Then it returns the entity and requests email and fullName with a nonce',
      () async {
        final auth = MockFirebaseAuth(
          mockUser: MockUser(
            uid: 'a1',
            providerData: [_FakeUserInfo('apple.com')],
          ),
        );

        final user = await buildRepo(auth).signInWithApple();

        expect(user.id, 'a1');
        expect(user.signInProvider, 'apple');
        expect(user.displayName, isNull);
        expect(apple.calls, hasLength(1));
        expect(apple.calls.single.scopes, [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ]);
        expect(apple.calls.single.nonce, hasLength(64));
      },
    );

    test(
      'Given givenName Ada and familyName L, When signing in, Then the displayName is "Ada L"',
      () async {
        apple = _AppleFetcherSpy(
          () async => _appleCredential(givenName: 'Ada', familyName: 'L'),
        );
        final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'a1'));

        final user = await buildRepo(auth).signInWithApple();

        expect(user.displayName, 'Ada L');
      },
    );

    test(
      'Given a null identityToken, When signing in, Then it throws Failure.auth(apple-unavailable)',
      () async {
        apple = _AppleFetcherSpy(
          () async => _appleCredential(identityToken: null),
        );

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithApple(),
          throwsA(const Failure.auth('apple-unavailable')),
        );
      },
    );

    test(
      'Given the user cancels, When signing in, Then it throws Failure.auth(canceled)',
      () async {
        apple = _AppleFetcherSpy(
          () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'canceled',
          ),
        );

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithApple(),
          throwsA(const Failure.auth('canceled')),
        );
      },
    );

    test(
      'Given an unknown authorization error, When signing in, Then it throws Failure.auth(apple-unavailable)',
      () async {
        apple = _AppleFetcherSpy(
          () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.unknown,
            message: 'error 1000',
          ),
        );

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithApple(),
          throwsA(const Failure.auth('apple-unavailable')),
        );
      },
    );

    test(
      'Given a failed authorization error, When signing in, Then it throws Failure.unknown',
      () async {
        apple = _AppleFetcherSpy(
          () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'failed',
          ),
        );

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithApple(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );

    test(
      'Given Firebase rejects the credential, When signing in, Then it throws Failure.auth with that code',
      () async {
        final auth = MockFirebaseAuth();
        whenCalling(
          Invocation.method(#signInWithCredential, null),
        ).on(auth).thenThrow(_authError('invalid-credential'));

        await expectLater(
          buildRepo(auth).signInWithApple(),
          throwsA(const Failure.auth('invalid-credential')),
        );
      },
    );

    test(
      'Given an anonymous user whose link hits email-already-in-use, When signing in, Then it throws Failure.auth(email-already-in-use)',
      () async {
        final auth = await anonymousAuth();
        whenCalling(
          Invocation.method(#linkWithCredential, null),
        ).on(auth.currentUser!).thenThrow(_authError('email-already-in-use'));

        await expectLater(
          buildRepo(auth).signInWithApple(),
          throwsA(const Failure.auth('email-already-in-use')),
        );
      },
    );

    test(
      'Given an anonymous user whose link hits another error, When signing in, Then it throws Failure.auth with that code',
      () async {
        final auth = await anonymousAuth();
        whenCalling(
          Invocation.method(#linkWithCredential, null),
        ).on(auth.currentUser!).thenThrow(_authError('network-request-failed'));

        await expectLater(
          buildRepo(auth).signInWithApple(),
          throwsA(const Failure.auth('network-request-failed')),
        );
      },
    );

    test(
      'Given an unexpected error, When signing in, Then it throws Failure.unknown',
      () async {
        apple = _AppleFetcherSpy(() async => throw Exception('boom'));

        await expectLater(
          buildRepo(MockFirebaseAuth()).signInWithApple(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });

  group('signInWithApple on Android (web provider)', () {
    test(
      'Given signed out, When signing in, Then it signs in with the Apple provider without the native fetcher',
      () async {
        final auth = MockFirebaseAuth(
          mockUser: MockUser(
            uid: 'a1',
            providerData: [_FakeUserInfo('apple.com')],
          ),
        );

        final user = await buildRepo(auth, isAndroid: true).signInWithApple();

        expect(user.id, 'a1');
        expect(user.signInProvider, 'apple');
        expect(apple.calls, isEmpty);
      },
    );

    test(
      'Given an anonymous current user, When signing in, Then it links the Apple provider and keeps the uid',
      () async {
        // mocktail SDK doubles: MockUser cannot complete an anonymous link.
        final fixture = linkableAnonymousUser(linkedProviderId: 'apple.com');

        final user = await buildRepo(
          fixture.auth,
          isAndroid: true,
        ).signInWithApple();

        expect(user.id, 'anon-uid');
        expect(user.signInProvider, 'apple');
        verify(() => fixture.user.linkWithProvider(any())).called(1);
        verifyNever(() => fixture.auth.signInWithProvider(any()));
      },
    );

    test(
      'Given linking hits credential-already-in-use, When signing in, Then it falls back to signing in',
      () async {
        final auth = await anonymousAuth();
        final anonymous = auth.currentUser!;
        whenCalling(
          Invocation.method(#linkWithProvider, null),
        ).on(anonymous).thenThrow(_authError('credential-already-in-use'));

        final user = await buildRepo(auth, isAndroid: true).signInWithApple();

        expect(user.isAnonymous, isFalse);
        expect(user.id, isNot(anonymous.uid));
      },
    );

    test(
      'Given linking hits email-already-in-use, When signing in, Then it throws Failure.auth(email-already-in-use)',
      () async {
        final auth = await anonymousAuth();
        whenCalling(
          Invocation.method(#linkWithProvider, null),
        ).on(auth.currentUser!).thenThrow(_authError('email-already-in-use'));

        await expectLater(
          buildRepo(auth, isAndroid: true).signInWithApple(),
          throwsA(const Failure.auth('email-already-in-use')),
        );
      },
    );

    test(
      'Given linking hits another error, When signing in, Then it throws Failure.auth with the exception message',
      () async {
        final auth = await anonymousAuth();
        whenCalling(Invocation.method(#linkWithProvider, null))
            .on(auth.currentUser!)
            .thenThrow(_authError('internal-error', 'Link broke'));

        await expectLater(
          buildRepo(auth, isAndroid: true).signInWithApple(),
          throwsA(const Failure.auth('Link broke')),
        );
      },
    );

    for (final code in [
      'web-context-cancelled',
      'cancelled-popup-request',
      'user-cancelled',
    ]) {
      test(
        'Given the provider flow fails with $code, When signing in, Then it throws Failure.auth(canceled)',
        () async {
          final auth = MockFirebaseAuth();
          whenCalling(
            Invocation.method(#signInWithProvider, null),
          ).on(auth).thenThrow(_authError(code));

          await expectLater(
            buildRepo(auth, isAndroid: true).signInWithApple(),
            throwsA(const Failure.auth('canceled')),
          );
        },
      );
    }

    test(
      'Given the provider flow fails with another code, When signing in, Then it throws Failure.auth with the exception message',
      () async {
        final auth = MockFirebaseAuth();
        whenCalling(Invocation.method(#signInWithProvider, null))
            .on(auth)
            .thenThrow(_authError('operation-not-allowed', 'Apple disabled'));

        await expectLater(
          buildRepo(auth, isAndroid: true).signInWithApple(),
          throwsA(const Failure.auth('Apple disabled')),
        );
      },
    );

    test(
      'Given an unexpected error, When signing in, Then it throws Failure.unknown',
      () async {
        final auth = MockFirebaseAuth();
        whenCalling(
          Invocation.method(#signInWithProvider, null),
        ).on(auth).thenThrow(Exception('boom'));

        await expectLater(
          buildRepo(auth, isAndroid: true).signInWithApple(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });

  group('updateDisplayName', () {
    test(
      'Given a signed-in user, When updating, Then the current user displayName changes',
      () async {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', displayName: 'Ada'),
        );

        await buildRepo(auth).updateDisplayName('Grace');

        expect(auth.currentUser!.displayName, 'Grace');
      },
    );

    test(
      'Given no current user, When updating, Then it completes without throwing',
      () async {
        await expectLater(
          buildRepo(MockFirebaseAuth()).updateDisplayName('Grace'),
          completes,
        );
      },
    );

    test(
      'Given reload fails, When updating, Then it throws Failure.auth with the exception message',
      () async {
        // MockUser's equality (and so mock_exceptions' lookup key) includes
        // displayName, so start with the name being set to keep the key stable.
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', displayName: 'Grace'),
        );
        whenCalling(Invocation.method(#reload, null))
            .on(auth.currentUser!)
            .thenThrow(_authError('network-request-failed', 'Offline'));

        await expectLater(
          buildRepo(auth).updateDisplayName('Grace'),
          throwsA(const Failure.auth('Offline')),
        );
      },
    );
  });

  group('deleteAuthAccount', () {
    test('Given a signed-in user, When deleting, Then it completes', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1'),
      );

      await expectLater(buildRepo(auth).deleteAuthAccount(), completes);
    });

    test(
      'Given requires-recent-login, When deleting, Then it throws Failure.auth(requires-recent-login)',
      () async {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1'),
        );
        whenCalling(
          Invocation.method(#delete, null),
        ).on(auth.currentUser!).thenThrow(_authError('requires-recent-login'));

        await expectLater(
          buildRepo(auth).deleteAuthAccount(),
          throwsA(const Failure.auth('requires-recent-login')),
        );
      },
    );

    test(
      'Given no current user, When deleting, Then it throws Failure.auth(No signed-in user)',
      () async {
        await expectLater(
          buildRepo(MockFirebaseAuth()).deleteAuthAccount(),
          throwsA(const Failure.auth('No signed-in user')),
        );
      },
    );
  });

  group('reauthenticateForDeletion', () {
    MockFirebaseAuth signedInWith(String providerId) => MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', providerData: [_FakeUserInfo(providerId)]),
    );

    test(
      'Given a Google user, When reauthenticating, Then it authenticates with Google',
      () async {
        await buildRepo(signedInWith('google.com')).reauthenticateForDeletion();

        verify(() => googleSignIn.authenticate()).called(1);
        expect(apple.calls, isEmpty);
      },
    );

    test(
      'Given an Apple user, When reauthenticating, Then it fetches an Apple credential',
      () async {
        await buildRepo(signedInWith('apple.com')).reauthenticateForDeletion();

        expect(apple.calls, hasLength(1));
        expect(apple.calls.single.nonce, hasLength(64));
        verifyNever(() => googleSignIn.authenticate());
      },
    );

    test(
      'Given an unsupported provider, When reauthenticating, Then it throws Failure.auth(unsupported-provider)',
      () async {
        await expectLater(
          buildRepo(signedInWith('password')).reauthenticateForDeletion(),
          throwsA(const Failure.auth('unsupported-provider')),
        );
      },
    );

    test(
      'Given no current user, When reauthenticating, Then it throws Failure.auth(No signed-in user)',
      () async {
        await expectLater(
          buildRepo(MockFirebaseAuth()).reauthenticateForDeletion(),
          throwsA(const Failure.auth('No signed-in user')),
        );
      },
    );

    test(
      'Given Firebase rejects the credential, When reauthenticating, Then it throws Failure.auth with that code',
      () async {
        final auth = signedInWith('google.com');
        whenCalling(
          Invocation.method(#reauthenticateWithCredential, null),
        ).on(auth.currentUser!).thenThrow(_authError('user-mismatch'));

        await expectLater(
          buildRepo(auth).reauthenticateForDeletion(),
          throwsA(const Failure.auth('user-mismatch')),
        );
      },
    );

    test(
      'Given an unexpected error, When reauthenticating, Then it throws Failure.unknown',
      () async {
        when(() => googleSignIn.authenticate()).thenThrow(Exception('boom'));

        await expectLater(
          buildRepo(signedInWith('google.com')).reauthenticateForDeletion(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });

  group('signOut', () {
    test(
      'Given a signed-in user, When signing out, Then it signs out of Firebase and Google and resets analytics',
      () async {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1'),
        );

        await buildRepo(auth).signOut();

        expect(auth.currentUser, isNull);
        verify(() => googleSignIn.signOut()).called(1);
        verify(() => analytics.reset()).called(1);
      },
    );

    test(
      'Given Google sign-out throws, When signing out, Then it throws Failure.unknown',
      () async {
        when(() => googleSignIn.signOut()).thenThrow(Exception('x'));

        await expectLater(
          buildRepo(MockFirebaseAuth()).signOut(),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );

    test(
      'Given Firebase sign-out fails, When signing out, Then it throws Failure.auth with the exception message',
      () async {
        final auth = MockFirebaseAuth();
        whenCalling(
          Invocation.method(#signOut, null),
        ).on(auth).thenThrow(_authError('internal-error', 'Sign-out broke'));

        await expectLater(
          buildRepo(auth).signOut(),
          throwsA(const Failure.auth('Sign-out broke')),
        );
        verifyNever(() => analytics.reset());
      },
    );
  });
}
