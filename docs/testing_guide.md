# Testing Guide

## Philosophy

- Test behavior, not implementation details
- Unit test domain logic and controllers; widget test critical UI flows
- Use real objects where cheap; mock only at system boundaries (Firebase, network)
- All mocks use `mocktail`, never `mockito`

## Structure

Every source file under `lib/` has exactly one test file at the mirrored path: `lib/a/b/foo.dart` ↔ `test/a/b/foo_test.dart`. Scripts follow the same rule: `scripts/<name>.dart` ↔ `test/scripts/<name>_test.dart`.

```
test/
├── app_test.dart             # App flow: lib/app.dart with in-memory fakes
├── flutter_test_config.dart  # Global bootstrap, runs before every test file
├── core/
│   ├── config/               # AppEnv
│   ├── data/                 # Analytics repository
│   ├── providers/            # Haptics provider
│   ├── router/               # Redirect rules
│   └── theme/                # Theme provider
├── features/
│   └── <feature>/
│       ├── application/      # Controller and provider tests
│       ├── data/             # Repository tests (fake Firebase)
│       ├── domain/           # Entity tests
│       └── presentation/     # Widget tests
├── scripts/                  # Tests for scripts/ (layout check, coverage gate)
└── helpers/
    ├── fakes.dart            # In-memory FakeAuthRepository, FakeUserRepository
    ├── mocks.dart            # Mocktail mocks
    └── pump_app.dart         # pumpApp() for widget tests
```

Exempt from the one-to-one rule: `test/helpers/**`, `test/flutter_test_config.dart` and `integration_test/**`. `make check-test-layout` fails on any `*_test.dart` file whose source file does not exist, so a test file moves or goes away with its source.

<!-- BEGIN_BLUEPRINT -->
In the blueprint, `tool/src/<name>.dart` ↔ `test/tool/<name>_test.dart`. init deletes `test/tool/` with `tool/`.
<!-- END_BLUEPRINT -->

Optional features keep their tests inside the same marker blocks as their `lib/` code: a test, import or helper that only exists for Apple sign-in sits between the `BEGIN_APPLE` / `END_APPLE` lines, exactly like the code it tests. Every test file must still compile and keep at least one test after any combination of features is stripped; a file with zero tests makes `flutter test` exit with code 79.

Test descriptions use Given-When-Then: `'Given <state>, When <action>, Then <outcome>'`. `group()` names are the method or route under test.

## Running Tests

```sh
make test               # all tests under test/
make check-test-layout  # every test file mirrors a source file
make coverage           # tests with coverage, then the per-layer coverage gate
```

CI (`.github/workflows/ci.yml`) runs `make analyze`, then `make check-test-layout coverage`.

Run a single file:

```sh
fvm flutter test test/features/auth/application/auth_controller_test.dart
```

`test/flutter_test_config.dart` runs before every test file. It sets empty `SharedPreferences` mock values.
<!-- BEGIN_POSTHOG -->
It also answers the `posthog_flutter` method channel, so widget tests that pump the router never hit `MissingPluginException`.
<!-- END_POSTHOG -->

## Mocking with Mocktail

```dart
// test/helpers/mocks.dart
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

class MockAuthRepository extends Mock implements FirebaseAuthRepository {}

class MockUserRepository extends Mock implements FirebaseUserRepository {}
```

The mocks implement the concrete `Firebase*Repository` classes because the repository providers are typed to them; tests inject them with `authRepositoryProvider.overrideWithValue(...)` and `userRepositoryProvider.overrideWithValue(...)`.

Two working examples ship with the repo:

- `test/features/auth/application/auth_controller_test.dart`
- `test/features/onboarding/application/onboarding_controller_test.dart`

Copy their structure for new controller tests.

Register fallback values for custom types:

```dart
setUpAll(() {
  registerFallbackValue(const Failure.unknown());
});
```

## Controller Tests

Use `ProviderContainer` to test Riverpod controllers in isolation:

```dart
test('signInAnonymously records the login and emits the user', () async {
  final authRepo = MockAuthRepository();
  final userRepo = MockUserRepository();
  when(() => authRepo.authStateChanges())
      .thenAnswer((_) => const Stream<UserEntity?>.empty());
  when(() => authRepo.signInAnonymously(name: any(named: 'name')))
      .thenAnswer((_) async => anon);
  when(() => userRepo.recordLogin(any(), signInProvider: any(named: 'signInProvider')))
      .thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      userRepositoryProvider.overrideWithValue(userRepo),
    ],
  );
  addTearDown(container.dispose);
  container.listen(authControllerProvider, (_, _) {});

  await container.read(authControllerProvider.notifier).signInAnonymously();

  expect(container.read(authControllerProvider).value, anon);
});
```

See `test/features/auth/application/auth_controller_test.dart` for the full setup, including `anon` and the shared stubs.

## Repository Tests

Repository tests run the real `Firebase*Repository` against in-memory Firebase fakes. They never touch the network.

- `fake_cloud_firestore`: `FakeFirebaseFirestore()` stands in for `FirebaseFirestore`
- `firebase_auth_mocks`: `MockFirebaseAuth()` and `MockUser(...)` stand in for `FirebaseAuth` and `User`
- `mock_exceptions`: injects an error on a single call

```dart
late FakeFirebaseFirestore firestore;
late FirebaseUserRepository repository;
late DocumentReference<Map<String, dynamic>> userDoc;

setUp(() {
  firestore = FakeFirebaseFirestore();
  repository = FirebaseUserRepository(firestore);
  userDoc = firestore.collection(AppConstants.usersCollection).doc('user-1');
});

test(
  'Given Firestore is unavailable, When saving preferences, Then it throws Failure.server',
  () async {
    whenCalling(Invocation.method(#set, null))
        .on(userDoc)
        .thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

    await expectLater(
      repository.savePreferences('user-1', const UserPreferences()),
      throwsA(const Failure.server()),
    );
  },
);
```

Register the error on the same reference the repository calls (here the `users/user-1` document), with the method name as a symbol (`#set`, `#update`, `#get`, `#delete`).

The fakes do not reproduce every rule of the real SDK. For example, `fake_cloud_firestore` expands dotted keys such as `'preferences.themeMode'` in `set()`, while real Firestore stores them as literal field names. A green repository test therefore does not prove the write is right against real Firestore; check the SDK docs for anything the fake might paper over.

Where `firebase_auth_mocks` cannot model a flow (for example linking an anonymous `MockUser`), mock `FirebaseAuth` and `User` with `mocktail` inside the repository test only. Controller tests never mock Firebase SDK classes. See `test/features/auth/data/firebase_auth_repository_test.dart` and `test/features/user_profile/data/firebase_user_repository_test.dart`.

## Router Tests

Router tests pump `MaterialApp.router` on the real `routerProvider`, with mocked repositories feeding the auth state. Hold the router with `container.listen`, not `container.read`: under Riverpod 3 a provider nobody listens to is paused and never sees auth or onboarding updates. The app watches `routerProvider`, so the listener matches production.

```dart
final container = ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(authRepo),
    userRepositoryProvider.overrideWithValue(userRepo),
  ],
);
addTearDown(container.dispose);

final router = container.listen(routerProvider, (_, _) {}).read();
await tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ),
);
await tester.pumpAndSettle();

expect(router.routerDelegate.currentConfiguration.uri.path, '/onboarding/intro');
```

Seed the onboarding flag with `SharedPreferences.setMockInitialValues(...)` before creating the container. See `test/core/router/app_router_test.dart`.

## Widget Tests

`pumpApp(tester, child, {overrides})` in `test/helpers/pump_app.dart` pumps `child` inside a `ProviderScope` with `overrides`, a themed `MaterialApp` and a `Scaffold`, then settles. Use the in-memory fakes from `test/helpers/fakes.dart` for the repositories, and mocks only where a test needs to stub a failure:

```dart
testWidgets(
  'Given a signed-in user, When the view is shown, Then it offers Get Started',
  (tester) async {
    await pumpApp(
      tester,
      const LoginPromptView(),
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initialUser: signedInUser),
        ),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );

    expect(find.text('Get Started'), findsOneWidget);
  },
);
```

`FakeAuthRepository` replays the current user to each new listener; `FakeUserRepository` keeps documents in `users` and records each call in `calls`. A method no test needs yet throws `UnimplementedError`; implement it in the fake when a test first needs it.

`test/app_test.dart` pumps the whole app (`lib/app.dart`) on the same fakes and walks a user flow end to end.

## AsyncValue Testing

Controllers return `AsyncValue`. Test all three states:

```dart
// Loading
expect(container.read(myControllerProvider), const AsyncLoading<void>());

// Data
expect(
  container.read(myControllerProvider).value,
  isNotNull,
);

// Error
expect(
  container.read(myControllerProvider),
  isA<AsyncError<void>>(),
);
```

## Failure Mapping

Every data layer method should map exceptions to `Failure`. Test the mapping directly:

```dart
test('maps FirebaseException to AuthFailure', () async {
  when(() => mockFirebaseAuth.signInAnonymously())
      .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

  expect(() => repo.signInAnonymously(), throwsA(isA<Failure>()));
});
```

## Coverage

`make coverage` runs `flutter test --coverage`, writes `coverage/lcov.info`, then runs `scripts/coverage_gate.dart`. The gate fails when a layer is below its threshold:

| Layer       | Paths                                                                                       | Minimum |
| ----------- | ------------------------------------------------------------------------------------------- | ------- |
| domain      | `lib/**/domain/**`                                                                          | 100%    |
| data        | `lib/**/data/**`                                                                            | 90%     |
| application | `lib/**/application/**`, `lib/core/router/**`, `lib/core/config/**`, `lib/core/providers/**` | 80%     |

Generated files (`*.g.dart`, `*.freezed.dart`) are excluded. A gated file with executable code that no test loads fails the gate as `UNLOADED`, even when the layer total is above the threshold; interface-only files (abstract classes without bodies) are allowed.

Everything else is not gated, including presentation widgets, `lib/core/services/**`, `lib/core/theme/**`, `lib/core/utils/**`, `lib/app.dart`, the `lib/main.dart` entry point and the `lib/firebase_options_*.dart` files. Cover their critical paths with widget and app flow tests instead.

Do not lower a threshold to get a change through. Add the missing test to the source file's mirrored test file.

## Linting Before PR

```sh
dart format .
make analyze
make test
```

All three must pass with zero errors before merging.
