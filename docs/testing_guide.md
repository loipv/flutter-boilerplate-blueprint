# Testing Guide

## Philosophy

- Test behavior, not implementation details
- Unit test domain logic and controllers; widget test critical UI flows
- Use real objects where cheap; mock only at system boundaries (Firebase, network)
- All mocks use `mocktail`, never `mockito`

## Structure

```
test/
├── features/
│   ├── auth/
│   │   ├── application/    # Controller tests
│   │   └── data/           # Repository tests (with mock Firebase)
│   ├── onboarding/
│   └── ...
├── core/
│   └── errors/             # Failure mapping tests
└── helpers/
    ├── fakes.dart           # Fake implementations
    └── mocks.dart           # Mocktail mocks
```

## Running Tests

```sh
make test
# runs the Flutter test runner via fvm when installed
```

Run a single file:

```sh
fvm flutter test test/features/auth/application/auth_controller_test.dart
```

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

Test the data layer with a mocked Firebase SDK or a local emulator.

For lightweight unit tests, mock `FirebaseFirestore`:

```dart
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
```

For integration tests, use the Firebase Local Emulator Suite:

```sh
firebase emulators:start --only auth,firestore
fvm flutter test integration_test/ --dart-define=USE_EMULATOR=true
```

## Widget Tests

```dart
testWidgets('HomeScreen shows welcome text', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((_) => Stream.value(fakeUser)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );

  expect(find.text('Welcome'), findsOneWidget);
});
```

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

Focus coverage on:

1. All `Failure` mapping paths in `data/` repositories
2. Auth state machine (signed out → anon → linked)
3. Onboarding completion guard logic in router
4. Controller methods that call multiple repositories

Skip coverage for:

- Pure widget layout code
- Generated files (`*.g.dart`, `*.freezed.dart`)
- `main_*.dart` entry points

## Linting Before PR

```sh
dart format .
make analyze
make test
```

All three must pass with zero errors before merging.
