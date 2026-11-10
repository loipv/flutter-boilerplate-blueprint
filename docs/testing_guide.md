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
# equivalent to: fvm flutter test
```

Run a single file:

```sh
fvm flutter test test/features/auth/application/auth_controller_test.dart
```

## Mocking with Mocktail

```dart
// mocks.dart
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/auth/domain/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
```

Register fallback values for custom types:

```dart
setUpAll(() {
  registerFallbackValue(const Failure.unexpected(''));
});
```

## Controller Tests

Use `ProviderContainer` to test Riverpod controllers in isolation:

```dart
test('signInAnonymously succeeds', () async {
  final mockRepo = MockAuthRepository();
  when(() => mockRepo.signInAnonymously()).thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(mockRepo),
    ],
  );
  addTearDown(container.dispose);

  final controller = container.read(authControllerProvider.notifier);
  await controller.signInAnonymously();

  verify(() => mockRepo.signInAnonymously()).called(1);
});
```

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

  final result = await repo.signInAnonymously();
  // If using Either or catching in controller:
  expect(result, isA<AuthFailure>());
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
