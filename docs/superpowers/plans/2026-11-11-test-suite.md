# Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working, copyable example of every test type (unit, data, router, widget, app flow, Firebase rules, Cloud Functions, on-device integration), enforced in CI by a file-layout check and a per-layer coverage gate.

**Architecture:**
- **P1** adds Dart tests under `test/`, mirrored one-to-one with `lib/`, plus two Dart scripts in `scripts/`: the layout check and the coverage gate. It also makes a small refactor so `FirebaseAuthRepository` and `PostHogAnalyticsRepository` take their SDKs through the constructor.
- **P2** adds Node tests that run against the Firebase Emulator (`demo-test` project): `firebase_tests/` for the rules, `functions/test/` for Cloud Functions.
- **P3** adds `integration_test/`, which runs on a device against the emulator through a secondary Firebase app.

**Tech Stack:**
- Flutter 3.41.4 via fvm, `flutter_test`, `mocktail`, `fake_cloud_firestore` ^4.4.0, `firebase_auth_mocks` ^0.15.2, `mock_exceptions` ^0.8.2, `integration_test` (SDK).
- Node 22, `vitest` ^5.1.0, `@firebase/rules-unit-testing` ^6.0.0, `firebase` ^13.2.0.
- firebase-tools 15.13.0 and Java 21.

**Spec:** `docs/superpowers/specs/2026-11-11-test-suite-design.md`

## Rulings vs the spec (decided while planning; recorded here, not re-litigated)

- **S1:** `lib/features/auth/data/firebase_auth_repository.dart` has **no** `GOOGLE` / `APPLE` markers, and `google_sign_in` / `sign_in_with_apple` are unconditional dependencies. Spec 4.1's "inside the marker blocks" therefore does not apply. The new constructor parameters are plain. A third parameter `bool? isAndroid` is added so tests can cover the Android Apple web path; without it the data layer cannot reach 90%.
- **S2:** The layout check and coverage gate are **Dart scripts** (`scripts/check_test_layout.dart`, `scripts/coverage_gate.dart`), not `.sh`, so their logic is unit-tested. New layout exception: `scripts/<n>.dart` ↔ `test/scripts/<n>_test.dart`. The scripts ship in generated apps.
- **S3:** Interface-only files (abstract classes, no bodies) never appear in lcov. The gate fails on a gated file absent from lcov **only if the file has executable code**: it contains `=>`, or a `)` followed by an optional `async`/`async*`/`sync*` and then `{`.
- **S4:** `firebase-functions-test` declares `jest` as a peer dependency. Functions tests therefore call the v2 functions' own `.run(...)` method under `vitest`, with the Admin SDK against the Firestore emulator. `firebase-functions-test` is not added.
- **S5:** `coverage/` is added to `.gitignore`. `make coverage` writes `coverage/lcov.info`.

## Global Constraints

- Run Flutter/Dart only through the Makefile or `fvm flutter` / `fvm dart`. Never use bare `flutter`. In the Makefile, Dart is `$(FLUTTER:flutter=dart)`.
- **Layout rule:** `lib/a/b/foo.dart` ↔ `test/a/b/foo_test.dart`, exactly one test file per source file. Exempt: `test/helpers/**`, `test/flutter_test_config.dart`, `integration_test/**`. Mirrors: `tool/src/<n>.dart` ↔ `test/tool/<n>_test.dart` (blueprint only) and `scripts/<n>.dart` ↔ `test/scripts/<n>_test.dart`.
- **Test descriptions:** `'Given <state>, When <action>, Then <outcome>'`. `group()` names are plain nouns (the method or route name).
- **Mocks:** `mocktail` only. Firebase fakes come from `fake_cloud_firestore` / `firebase_auth_mocks`, with error injection via `mock_exceptions` `whenCalling(...).on(...).thenThrow(...)`. Controller tests never mock Firebase SDK classes.
- **Imports:** `lib/` code is imported as `package:blueprint_app/...`. Test helpers and `tool/` / `scripts/` sources use relative imports, as existing tests already do.
- **Coverage thresholds:** domain 100%, data ≥ 90%, application ≥ 80%.
  - domain = `lib/**/domain/**`
  - data = `lib/**/data/**`
  - application = `lib/**/application/**` plus `lib/core/router/**`, `lib/core/config/**`, `lib/core/providers/**`
  - `*.g.dart` and `*.freezed.dart` are excluded.
- **Markers:** marker lines are whole lines (`// BEGIN_X` / `// END_X`). A test file for a marker feature must compile and still contain ≥ 1 `test`/`testWidgets` after **any** combination of markers is stripped. Zero tests makes `flutter test` exit 79.
- **Emulator:** project id `demo-test`; ports auth 9099, firestore 8080, storage 9199, functions 5001.
- **Commits:** one per task (more is fine), message prefix `test:` / `feat:` / `refactor:` / `ci:` / `docs:`. Never push. Never stage `docs/superpowers/.gitignore`.
- Lints from `AGENTS.md` apply to any `lib/` change: `Gap` not `SizedBox`, `AppLogger` not `print`, `ConsumerWidget`.

## Review Focus

1. **Every flag combination:** a test file whose marker blocks are all stripped must still compile and have ≥ 1 test. Task 11 runs `verify_init` for `--no-posthog --no-sentry --no-notifications --no-anon` and `--no-apple --no-google`, in addition to the CI combinations.
2. **Gate on unloaded files:** a gated file that no test loads must fail the gate when it has code, and pass when it is interface-only. Task 2 tests both cases.
3. **Layout check on near-miss names:** `test/foo/bar_test.dart` with only `lib/foo/baz.dart`, or `test/helpers/x_test.dart`, `test/tool/...`, `test/scripts/...`, `test/flutter_test_config.dart`. Task 1 tests each.
4. **`make test-firebase` after `--no-functions`:** only the rules tests run, and the command must not fail on the missing `functions/`. Task 13 verifies this on an init'd copy.
5. **Integration stubs never overwrite real config:** `make test-integration` writes the staging `google-services.json` / `GoogleService-Info.plist` only when they are missing. Task 14 verifies this with a pre-existing file whose content must be unchanged.

---

## Phase P1: Dart tests, layout check, coverage gate

### Task 1: Layout check script

**Files:**
- Create: `scripts/check_test_layout.dart`
- Test: `test/scripts/check_test_layout_test.dart`
- Modify: `Makefile` (add `check-test-layout` to `.PHONY`, the target, and a help line)
- Move: `test/tool/repo_markers_test.dart` → its two tests into `test/tool/manifest_test.dart` (new file); delete `repo_markers_test.dart`

**Interfaces:**
- Produces:
  - `String? expectedSourceFor(String testPath)`: maps a forward-slash repo-relative test path to its source path. Returns `null` for exempt paths: `test/helpers/**`, anything not ending in `_test.dart`, and anything under `integration_test/`.
  - `List<String> findOrphanTests(Iterable<String> testPaths, bool Function(String path) exists)`: returns each test path whose expected source does not exist, sorted.
  - `main()`: lists `test/**/*_test.dart`, prints the orphans, and exits 1 if there are any, otherwise prints `Test layout OK (<n> files)` and exits 0.

- [ ] **Step 1: Write the failing tests** in `test/scripts/check_test_layout_test.dart` (`import '../../scripts/check_test_layout.dart';`):
  - `expectedSourceFor('test/features/auth/data/firebase_auth_repository_test.dart')` == `'lib/features/auth/data/firebase_auth_repository.dart'`
  - `expectedSourceFor('test/app_test.dart')` == `'lib/app.dart'`
  - `expectedSourceFor('test/tool/markers_test.dart')` == `'tool/src/markers.dart'`
  - `expectedSourceFor('test/scripts/coverage_gate_test.dart')` == `'scripts/coverage_gate.dart'`
  - `expectedSourceFor('test/helpers/mocks.dart')`, `expectedSourceFor('test/helpers/x_test.dart')` and `expectedSourceFor('test/flutter_test_config.dart')` are all `null`
  - `findOrphanTests(['test/foo/bar_test.dart', 'test/foo/baz_test.dart'], (p) => p == 'lib/foo/baz.dart')` == `['test/foo/bar_test.dart']`
- [ ] **Step 2: Run them and confirm they fail:** `fvm flutter test test/scripts/check_test_layout_test.dart`. Expected: a compile error, because the file is missing.
- [ ] **Step 3: Implement `scripts/check_test_layout.dart`.** Use only `dart:io`. `main` walks `test/` recursively, converts paths to forward slashes, and uses `File(p).existsSync()` for `exists`.
- [ ] **Step 4: Move the repo-marker tests.**
  - Create `test/tool/manifest_test.dart` holding both tests from `repo_markers_test.dart`, renamed to Given-When-Then.
  - Delete `test/tool/repo_markers_test.dart`.
- [ ] **Step 5: Add the Makefile target.** `check-test-layout: ; $(FLUTTER:flutter=dart) scripts/check_test_layout.dart`. Help line: `make check-test-layout  (every test file mirrors a source file)`.
- [ ] **Step 6: Verify.**
  - `fvm flutter test test/scripts test/tool`: PASS.
  - `make check-test-layout` prints `Test layout OK`, because every existing test already mirrors a source file.
- [ ] **Step 7: Commit.** `git commit -m "test: add test layout check script"`

### Task 2: Coverage gate script

**Files:**
- Create: `scripts/coverage_gate.dart`
- Test: `test/scripts/coverage_gate_test.dart`
- Modify: `Makefile` (`coverage` target, `.PHONY`, help line); `.gitignore` (add `coverage/`)

**Interfaces:**
- Produces:
  - `enum Layer { domain, data, application }` with `double get threshold` (domain 100, data 90, application 80).
  - `Layer? layerOf(String libPath)`. Returns `null` for non-gated paths, `*.g.dart` and `*.freezed.dart`.
  - `Map<String, ({int found, int hit})> parseLcov(String lcov)`. Keyed by the `SF:` path normalized to repo-relative `lib/...`.
  - `bool hasExecutableCode(String dartSource)`. Strips `//` line comments, then applies the S3 rule.
  - `GateResult evaluate(Map<String, ({int found, int hit})> lcov, Map<String, String> gatedSources)`.
    - `gatedSources` maps a lib path to its source text.
    - `GateResult` has `Map<Layer, ({int found, int hit})> totals`, `List<String> unloaded` (gated files with code that are absent from lcov), and `bool get passed`. A layer with `found == 0` passes.
  - `main(List<String> args)`:
    - Reads `args.first` (default `coverage/lcov.info`) and every gated `lib/**.dart`.
    - Prints one line per layer, `domain  100.0% (6/6)  >= 100% OK`, then each unloaded file.
    - Exits 1 on failure.

- [ ] **Step 1: Write the failing tests.**
  - `layerOf('lib/features/auth/domain/user_entity.dart')` == `Layer.domain`
  - `layerOf('lib/core/data/posthog_analytics_repository.dart')` == `Layer.data`
  - `layerOf('lib/core/router/app_router.dart')` == `Layer.application`
  - `layerOf('lib/features/x/application/y.g.dart')` == `null`
  - `layerOf('lib/features/home/presentation/home_screen.dart')` == `null`
  - `layerOf('lib/core/services/notification_service.dart')` == `null`
  - `parseLcov('SF:lib/a/data/b.dart\nLF:10\nLH:9\nend_of_record\n')` == `{'lib/a/data/b.dart': (found: 10, hit: 9)}`. Also accept an absolute `SF:` path ending in `/lib/a/data/b.dart`.
  - `hasExecutableCode('abstract class A { Future<void> f(); }')` is `false`.
  - `hasExecutableCode('class A { void f() { } }')`, `hasExecutableCode('int f() => 1;')` and `hasExecutableCode('Future<void> f() async {}')` are each `true`.
  - `evaluate` with data `(found: 10, hit: 8)` gives `passed == false`. With `(found: 10, hit: 9)`, `passed == true`.
  - `evaluate` with gated source `lib/x/data/y.dart` = `'int f() => 1;'` absent from lcov gives `unloaded == ['lib/x/data/y.dart']` and `passed == false`. The same file with an interface-only source gives `passed == true`.
- [ ] **Step 2: Run them and confirm they fail:** `fvm flutter test test/scripts/coverage_gate_test.dart`. Expected: a compile error.
- [ ] **Step 3: Implement `scripts/coverage_gate.dart`** with `dart:io` only.
- [ ] **Step 4: Add the Makefile target.** `coverage: ; $(FLUTTER) test --coverage && $(FLUTTER:flutter=dart) scripts/coverage_gate.dart coverage/lcov.info`. Help line: `make coverage  (tests + per-layer coverage gate)`. Add `coverage/` to `.gitignore`.
- [ ] **Step 5: Verify.**
  - `fvm flutter test test/scripts`: PASS.
  - `make coverage` runs and **fails** (data is below 90% today). That is expected here; confirm the output names the layers and the unloaded files.
- [ ] **Step 6: Commit.** `git commit -m "test: add per-layer coverage gate script"`

### Task 3: FirebaseAuthRepository refactor and data tests

**Files:**
- Modify: `lib/features/auth/data/firebase_auth_repository.dart` (constructor, the 4 static SDK call sites, `Platform.isAndroid`, provider)
- Modify: `pubspec.yaml` (dev: `fake_cloud_firestore: ^4.4.0`, `firebase_auth_mocks: ^0.15.2`, `mock_exceptions: ^0.8.2`), then `make codegen`
- Test: `test/features/auth/data/firebase_auth_repository_test.dart`

**Interfaces:**
- Produces:
  - `typedef AppleCredentialFetcher = Future<AuthorizationCredentialAppleID> Function({required List<AppleIDAuthorizationScopes> scopes, String? nonce});` in `firebase_auth_repository.dart`.
  - `FirebaseAuthRepository(FirebaseAuth firebaseAuth, AnalyticsRepository analytics, {required GoogleSignIn googleSignIn, required AppleCredentialFetcher fetchAppleCredential, bool? isAndroid})`.
    - `isAndroid` defaults to `Platform.isAndroid`.
    - Every `GoogleSignIn.instance` becomes the injected instance. Every `SignInWithApple.getAppleIDCredential` becomes `fetchAppleCredential`. `Platform.isAndroid` becomes the field.
  - The provider passes `googleSignIn: GoogleSignIn.instance, fetchAppleCredential: SignInWithApple.getAppleIDCredential`.
  - The public API and behavior are unchanged; `test/helpers/mocks.dart` stays valid.

- [ ] **Step 1: Add the dev dependencies, then run `make codegen`.** `fvm flutter pub get` must keep `firebase_auth` 6.x and `cloud_firestore` 6.x.
- [ ] **Step 2: Write the failing tests.** Use `MockFirebaseAuth` from `firebase_auth_mocks` and mocktail mocks for `GoogleSignIn`, `GoogleSignInAccount` and `AnalyticsRepository`. Groups and tests:
  - `authStateChanges`: Given a signed-in `MockFirebaseAuth`, When listening, Then the first event is that user's entity (synchronous current user first). Given signed out, Then the first event is `null`.
  - `signInAnonymously`: Given success, Then it returns an entity with `isAnonymous == true` and, when `name` is passed, `displayName` set. Given `FirebaseAuthException(code: 'operation-not-allowed')` (via `authExceptions`), Then it throws `Failure.auth`.
  - `signInWithGoogle`:
    - Given signed out and `authenticate()` returning an account with `idToken`, Then it returns a non-anonymous entity.
    - Given an anonymous current user, Then it links rather than signs in, and the uid is unchanged.
    - Given `GoogleSignInException(code: GoogleSignInExceptionCode.canceled)`, Then it throws `Failure.auth('canceled')`.
    - Given any other `GoogleSignInException`, Then it throws a `Failure.unknown`.
    - Given a Firebase `credential-already-in-use`, Then it throws `Failure.auth('credential-already-in-use')`.
    - Given an empty Firebase displayName and Google `displayName: 'Ada'`, Then the returned entity's `displayName == 'Ada'`.
  - `signInWithApple`, with `isAndroid: false`:
    - Given a credential with `identityToken`, Then it returns an entity. Given `givenName: 'Ada'`, `familyName: 'L'`, Then `displayName == 'Ada L'`.
    - Given a null `identityToken`, Then it throws `Failure.auth('apple-unavailable')`.
    - Given `SignInWithAppleAuthorizationException(code: AuthorizationErrorCode.canceled)`, Then it throws `Failure.auth('canceled')`. With `code: unknown`, Then `Failure.auth('apple-unavailable')`. With `code: failed`, Then a `Failure.unknown`.
  - `signInWithApple`, with `isAndroid: true` (the web provider path):
    - The success path signs in.
    - When linking hits `credential-already-in-use`, Then it falls back to sign-in.
    - Given `email-already-in-use`, Then it throws `Failure.auth('email-already-in-use')`.
    - `MockFirebaseAuth` may not support `signInWithProvider` / `linkWithProvider`. In that case use mocktail mocks of `FirebaseAuth` / `User` / `UserCredential` **for this group only** (allowed in repository tests).
  - `updateDisplayName`: Then the current user's displayName is updated. Given no current user, Then it does not throw.
  - `deleteAuthAccount`: Given `requires-recent-login`, Then it throws `Failure.auth('requires-recent-login')`, matching the code's mapping.
  - `reauthenticateForDeletion`:
    - The Google provider path calls `googleSignIn.authenticate()`.
    - The Apple provider path calls `fetchAppleCredential`.
    - Given an unsupported provider, Then it throws `Failure.auth('unsupported-provider')`.
    - Given no user, Then it throws `Failure.auth('No signed-in user')`.
  - `signOut`: Then it calls `googleSignIn.signOut()` and `analytics.reset()`. Given `googleSignIn.signOut()` throws `Exception('x')`, Then it throws a `Failure.unknown`.
  - Read each method's actual `on ... catch` mapping in the source and assert exactly that. The bullet values above come from the current source.
- [ ] **Step 3: Run them and confirm they fail:** `fvm flutter test test/features/auth/data/`. Expected: compile errors on the new constructor parameters.
- [ ] **Step 4: Implement the refactor** described in Interfaces, then `make codegen`.
- [ ] **Step 5: Verify.**
  - `fvm flutter test test/features/auth/`: PASS.
  - `make analyze`: no issues.
  - `fvm flutter test --coverage test/features/auth/data/` shows ≥ 90% for `firebase_auth_repository.dart`. Check this with the Task 2 script: `fvm dart scripts/coverage_gate.dart coverage/lcov.info` and read the data line. Other files may be unloaded at this point; ignore them.
- [ ] **Step 6: Commit.** `git commit -m "refactor: inject Google and Apple sign-in into FirebaseAuthRepository; add data tests"`

### Task 4: FirebaseUserRepository data tests

**Files:**
- Test: `test/features/user_profile/data/firebase_user_repository_test.dart`

**Interfaces:**
- Consumes: `FirebaseUserRepository(FirebaseFirestore)` and the `UserRepository` methods: `getUserStream`, `savePreferences`, `recordLogin`, `updateProfile`, `markOnboardingComplete`, `deleteUserData`, `updateLastAccessed`. The collection name is `AppConstants.usersCollection`.

- [ ] **Step 1: Write the tests** with `FakeFirebaseFirestore`; errors via `whenCalling(Invocation.method(#set, null)).on(docRef).thenThrow(FirebaseException(plugin: 'cloud_firestore'))` and the same for `#update` / `#delete`.
  - `getUserStream`: Given no document, Then it emits `null`. Given a valid document, Then it emits an entity with `id == uid`. Given a malformed document (a wrong type for a field), Then it emits `null` and does not throw.
  - `savePreferences`: Then the document holds the preference fields. Given a set error, Then it throws `Failure.server()`.
  - `recordLogin`: Then it writes the `signInProvider` and login timestamp fields the source writes. With `signInProvider: null`, Then the field is absent.
  - `updateProfile`, `markOnboardingComplete`, `deleteUserData`, `updateLastAccessed`: one success test each, asserting the document state. Each method whose source maps errors to `Failure.server()` also gets an error test. For methods whose source only logs (no rethrow), the error test asserts that they complete normally.
- [ ] **Step 2: Run the tests.** `fvm flutter test test/features/user_profile/data/`: PASS. The source is unchanged, so any failure is a test bug or a real bug; report a real bug and do not paper over it.
- [ ] **Step 3: Commit.** `git commit -m "test: add FirebaseUserRepository data tests"`

### Task 5: PostHog repository injection and domain tests

**Files:**
- Modify: `lib/core/data/posthog_analytics_repository.dart`. Add a constructor `PostHogAnalyticsRepository(this._posthog)` with field `final Posthog _posthog;`. The constructor parameter, field and import sit inside `// BEGIN_POSTHOG` blocks, so that with PostHog stripped the class has an implicit no-arg constructor. The provider passes `Posthog()` inside a marker block in the argument list:
  ```dart
  return PostHogAnalyticsRepository(
    // BEGIN_POSTHOG
    Posthog(),
    // END_POSTHOG
  );
  ```
  The constructor needs the same treatment: `PostHogAnalyticsRepository(` / `// BEGIN_POSTHOG` / `this._posthog,` / `// END_POSTHOG` / `);`. Replace every `Posthog()` call in the method bodies with `_posthog`.
- Test: `test/core/data/posthog_analytics_repository_test.dart`, `test/features/auth/domain/user_entity_test.dart`, `test/features/auth/domain/user_preferences_test.dart`

- [ ] **Step 1: Write the failing tests.**
  - PostHog (mock `Posthog` via mocktail; inside `POSTHOG` blocks):
    - `captureEvent('e', properties: {'k': 'v'})` calls `capture(eventName: 'e', properties: {'k': 'v'})`.
    - `captureScreen('Home')` calls `screen(screenName: 'Home')`.
    - `reset()` calls `reset()`.
    - Match the exact SDK call shapes in the current source.
  - One test **outside** markers: Given the repository, When `captureEvent`, `captureScreen` and `reset` are called, Then they complete. Construct the repository with the marker-wrapped argument pattern above. The arguments it passes to `captureEvent` must match `AnalyticsRepository.captureEvent`'s signature exactly.
  - `UserEntity`: a JSON round-trip (`UserEntity.fromJson(e.toJson()) == e`) for a fully populated entity. Defaults: `isAnonymous == false` if that is the source default (read it). Plus every custom getter or method in the file.
  - `UserPreferences`: a JSON round-trip and default values.
- [ ] **Step 2: Run them and confirm they fail:** `fvm flutter test test/core/data test/features/auth/domain`. Expected: compile errors on the constructor.
- [ ] **Step 3: Implement the PostHog change**, then `make codegen`.
- [ ] **Step 4: Verify.**
  - The tests PASS and `make analyze` is clean.
  - Strip check: copy the repository to a temp dir with `rsync` as `tool/verify_init.sh` does, run `fvm dart tool/init.dart --yes --name x_app --no-posthog`, then `fvm flutter analyze lib/core/data test/core/data`: no issues. Delete the temp dir.
- [ ] **Step 5: Commit.** `git commit -m "refactor: inject Posthog into PostHogAnalyticsRepository; add domain tests"`

### Task 6: Controller and provider tests (application layer)

**Files:**
- Modify: `test/features/auth/application/auth_controller_test.dart`, `test/features/onboarding/application/onboarding_controller_test.dart`, `test/core/config/app_env_test.dart` (rename to Given-When-Then and add the tests listed)
- Create: `test/features/settings/application/settings_controller_test.dart`, `test/features/user_profile/application/user_profile_providers_test.dart`

**Interfaces:**
- Consumes: `authControllerProvider` (methods `signInAnonymously({String? name})`, `signInWithGoogle()`, `signInWithApple()`, `deleteAccount() → Future<String?>`, `updateDisplayName(String)`, `signOut()`); `settingsControllerProvider` (`updateThemeMode(ThemeMode)`, `updateHaptics(bool)`, `updateNotificationTime(String?)` inside `NOTIFICATIONS`, `deleteAccount()`); `currentUserProvider`, `userProfileStreamProvider`; the mocks in `test/helpers/mocks.dart`.

- [ ] **Step 1: Rename every existing test description** in the three files to `Given …, When …, Then …`, keeping the assertions.
- [ ] **Step 2: Write the new tests.**
  - `auth_controller`:
    - `deleteAccount`: Given success, Then it calls `userRepo.deleteUserData(uid)` and `authRepo.deleteAuthAccount()` in the source's order, and returns the source's success value. Given `requires-recent-login`, Then it calls `reauthenticateForDeletion` and retries, if the source does that; assert exactly what the source does.
    - `updateDisplayName('Ada')`: Then it calls both `authRepo.updateDisplayName` and `userRepo.updateProfile(uid, name: 'Ada')`.
    - `signOut`: Then it calls `authRepo.signOut()`.
  - `settings_controller`:
    - Given a signed-in user, When `updateThemeMode(ThemeMode.dark)`, Then `savePreferences(uid, prefs with the dark theme)` is called.
    - Given no user, Then `savePreferences` is never called.
    - The same pair for `updateHaptics(false)` and, inside a `NOTIFICATIONS` block, for `updateNotificationTime('08:30')`.
    - `deleteAccount()` delegates to the auth controller.
  - `user_profile_providers`: `currentUser` mirrors `authControllerProvider`. `userProfileStream` emits `null` when signed out, and the repository stream's values when signed in.
- [ ] **Step 3: Run the tests.** `fvm flutter test test/features test/core/config`: PASS.
- [ ] **Step 4: Commit.** `git commit -m "test: cover settings, user profile providers and remaining auth controller paths"`

### Task 7: Router, theme, haptics tests and test bootstrap

**Files:**
- Create: `test/flutter_test_config.dart`, `test/core/router/app_router_test.dart`, `test/core/theme/theme_provider_test.dart`, `test/core/providers/haptics_provider_test.dart`

**Interfaces:**
- Produces: `test/flutter_test_config.dart` with `Future<void> testExecutable(FutureOr<void> Function() testMain)`.
  - Inside `// BEGIN_POSTHOG` blocks, it registers a mock handler that returns `null` on `MethodChannel('posthog_flutter')` via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`. This is the channel name in `posthog_flutter` 5.x `posthog_flutter_io.dart`, and it lets `PosthogObserver` run in widget tests.
  - It then calls `SharedPreferences.setMockInitialValues({})` and `await testMain()`.

- [ ] **Step 1: Write the failing tests.**
  - `app_router` (pump `MaterialApp.router(routerConfig: container.read(routerProvider))` inside `UncontrolledProviderScope`; override `authControllerProvider` and `onboardingControllerProvider` with test notifiers, or override the repositories with the `test/helpers/mocks.dart` mocks):
    - Given auth loading, Then the location is `/splash`.
    - Given signed out, Then `/onboarding/intro`.
    - Given signed in and onboarding incomplete, Then `/onboarding/intro`.
    - Given signed in and onboarding complete at `/splash`, Then `/`.
    - Given complete and navigating to `/onboarding/intro`, Then it redirects to `/`.
    - Given complete and navigating to `/explore`, Then it stays.
  - `theme_provider`: Given no stored value, Then `ThemeMode.system`. When `setTheme(ThemeMode.dark)`, Then the state is dark and `prefs.getString('theme_mode')` holds the stored form the source uses. `resetToSystem()` clears it.
  - `haptics_provider`: mirrors the user's `preferences.hapticsEnabled`; falls back to the source default when signed out.
- [ ] **Step 2: Run them and confirm they fail, then implement only `test/flutter_test_config.dart`.** No `lib/` change is expected. If a redirect test fails, report it as a bug rather than changing the router.
- [ ] **Step 3: Verify.** `fvm flutter test test/core`: PASS. `make check-test-layout`: OK.
- [ ] **Step 4: Commit.** `git commit -m "test: add router redirect, theme and haptics tests"`

### Task 8: Widget test helpers, login prompt and failure message tests

**Files:**
- Create: `test/helpers/fakes.dart`, `test/helpers/pump_app.dart`, `test/features/onboarding/presentation/login_prompt_view_test.dart`, `test/features/auth/presentation/auth_failure_message_test.dart`

**Interfaces:**
- Produces:
  - `class FakeAuthRepository implements FirebaseAuthRepository` (in-memory):
    - Constructor `FakeAuthRepository({UserEntity? initialUser})`.
    - `currentUser` returns `null` / non-`null` to match the source getter's type (read it).
    - `authStateChanges()` replays the current value, then subsequent changes.
    - `signInAnonymously` creates `UserEntity(id: 'anon-1', isAnonymous: true, signInProvider: 'anonymous')`.
    - `signOut` emits `null`.
    - Other methods throw `UnimplementedError` unless a later task needs them.
  - `class FakeUserRepository implements FirebaseUserRepository`: stores documents in a `Map<String, UserEntity>` and records calls in `List<String> calls`.
  - `Future<void> pumpApp(WidgetTester tester, Widget child, {List<Override> overrides = const []})`: wraps the child in `ProviderScope(overrides:)` and `MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child))`, then pumps and settles.

- [ ] **Step 1: Write the failing tests.**
  - `auth_failure_message`:
    - `Failure.auth('canceled')` → `null`.
    - `apple-unavailable` → the exact Apple string in the source.
    - `missing-or-invalid-nonce` → the exact string.
    - `email-already-in-use` with `SignInMethod.google` → the "Try Apple instead." string; with `.apple` → the "Try Google instead." string.
    - Any other auth code → `null`.
    - `Failure.server()` → `null`.
  - `login_prompt_view`:
    - Given an anonymous user, Then the Apple button appears (in `APPLE`), the Google button appears (in `GOOGLE`), and "Continue as Guest" appears (in `ANON`).
    - When "Continue as Guest" is tapped and the dialog's "Continue" is tapped, Then onboarding completes (in `ANON`).
    - When sign-in fails with `Failure.auth('apple-unavailable')`, Then a snackbar shows that message (in `APPLE`).
    - **One test outside all markers:** Given an anonymous user, Then "Get Started" is shown, and tapping it calls `completeOnboarding`.
- [ ] **Step 2: Run them and confirm they fail; implement the helpers; run until they pass:** `fvm flutter test test/features/onboarding/presentation test/features/auth/presentation`.
- [ ] **Step 3: Commit.** `git commit -m "test: add widget test helpers, login prompt and failure message tests"`

### Task 9: NotificationScheduler test

**Files:**
- Test: `test/features/notifications/application/notification_scheduler_test.dart` (the whole file belongs to the notifications path feature; init deletes it with `--no-notifications`, so no markers are needed)

**Interfaces:**
- Consumes:
  - `NotificationScheduler({required Widget child})`, a `ConsumerStatefulWidget`.
  - `notificationServiceProvider` (from `lib/core/services/notification_service.dart`). Mock `NotificationService` via mocktail.
  - The `sharedPreferencesProvider` keys `NotificationService.kNotificationHour` / `kNotificationMinute`.

- [ ] **Step 1: Write the tests.** Read `notification_scheduler.dart` and assert its listeners:
  - When the user's notification-time preference changes to `'08:30'`, Then the service schedules 08:30 and stores hour 8 / minute 30 in prefs.
  - When it changes to `null`, Then it cancels.
  - When a payload arrives on the service's stream, Then `_handlePayload` routes as the source does.
  - The child is rendered.
- [ ] **Step 2: Run the tests.** `fvm flutter test test/features/notifications`: PASS.
- [ ] **Step 3: Commit.** `git commit -m "test: add NotificationScheduler tests"`

### Task 10: App flow test

**Files:**
- Test: `test/app_test.dart`

**Interfaces:**
- Consumes: `App`, `FakeAuthRepository`, `FakeUserRepository`, `authRepositoryProvider`, `userRepositoryProvider`, `analyticsRepositoryProvider` (overridden with a mocktail `AnalyticsRepository`), `notificationServiceProvider` (overridden inside `NOTIFICATIONS`), and `OnboardingRepository`'s prefs key. Read `onboarding_repository.dart` for the key name.

- [ ] **Step 1: Write the tests.**
  - **Outside markers:** Given `FakeAuthRepository(initialUser: a signed-in user)` and prefs marking onboarding complete, When `App` is pumped and settled, Then `HomeScreen` is shown.
  - **Inside `ANON`:** Given no user, When `App` is pumped, Then the app signs in anonymously (through `App._checkAuth`) and shows the intro. Advance through intro → theme selection → login prompt using the visible button labels in those views. Tap "Continue as Guest", then "Continue". Then `HomeScreen` is shown and `FakeUserRepository.calls` contains the onboarding-complete call.
- [ ] **Step 2: Run the tests.** `fvm flutter test test/app_test.dart`: PASS. If `FlutterNativeSplash.remove()` throws in tests, stub its channel in `test/flutter_test_config.dart`; do not change `lib/app.dart`.
- [ ] **Step 3: Commit.** `git commit -m "test: add app flow test"`

### Task 11: Wire the P1 gate into CI, init verification and docs

**Files:**
- Modify:
  - `.github/workflows/ci.yml`: the `test` job's final step becomes `make check-test-layout coverage` (keep Analyze).
  - `tool/verify_init.sh`: `make setup analyze test` → `make setup analyze check-test-layout coverage`.
  - `AGENTS.md` section 3.4.
  - `docs/testing_guide.md`.
  - `README.md` (the verify_init sentence).
  - `CHANGELOG.md` (v1.0.0 Added).

- [ ] **Step 1: Run the gate.** `make coverage` must PASS all three layers with zero unloaded files. If a layer is short, add the missing tests to the owning task's test file (one source → one test file). Do not lower a threshold. A truly unreachable line becomes a ruling reported back.
- [ ] **Step 2: Edit `ci.yml` and `verify_init.sh`.**
- [ ] **Step 3: Rewrite the docs.**
  - `AGENTS.md` 3.4:
    - The thresholds and layer paths from Global Constraints.
    - The layout rule and its exemptions.
    - "Every change to `firestore.rules` or `storage.rules` updates `firebase_tests/`."
    - Given-When-Then.
  - `docs/testing_guide.md`: replace the Structure, Running Tests, Repository Tests, Widget Tests and Coverage sections with the real layout and commands:
    - `make test`, `make check-test-layout`, `make coverage`.
    - The fakes/mock_exceptions pattern.
    - `pumpApp`.
    - The router test pattern.
    - Fix the `main_*.dart` reference to `main.dart`.
    - Leave the P2/P3 sections for Tasks 13 and 15.
- [ ] **Step 4: Verify.**
  - `make analyze`, `make check-test-layout` and `make coverage` all PASS.
  - `tool/verify_init.sh` passes for each of:
    - `--yes --name blueprint_ci`
    - `--yes --name blueprint_ci --no-notifications --no-posthog --no-sentry --no-functions --no-apple --no-google`
    - `--yes --name acme_notes --org io.acme --title "Acme Notes" --description "Notes for Acme" --shared-app-id`
    - `--yes --name strip_a --no-posthog --no-sentry --no-notifications --no-anon`
    - `--yes --name strip_b --no-apple --no-google`
- [ ] **Step 5: Commit.** `git commit -m "ci: enforce test layout and coverage gate; document test conventions"`

## Phase P2: Firebase Emulator tests

### Task 12: Emulator config and Firestore/Storage rules tests

**Files:**
- Modify:
  - `firebase.json`: add `"emulators": {"auth": {"port": 9099}, "firestore": {"port": 8080}, "storage": {"port": 9199}, "functions": {"port": 5001}, "ui": {"enabled": false}, "singleProjectMode": true}`.
  - `tool/src/plan.dart`: `_dropFunctions` also removes `emulators.functions` when present.
- Test: extend the existing `firebase.json` test in `test/tool/`. If none exists, add a test for `_dropFunctions` through the narrowest public seam; if it is private, make it a top-level `dropFunctions(String) → String` in `plan.dart` and test it in `test/tool/plan_test.dart`.
- Create: `firebase_tests/package.json` (name `blueprint_app-firebase-tests`, private, `"type": "module"`, scripts `"test": "vitest run"`, devDependencies `vitest ^5.1.0`, `@firebase/rules-unit-testing ^6.0.0`, `firebase ^13.2.0`), `firebase_tests/package-lock.json` (generated by `npm install`), `firebase_tests/firestore.rules.test.ts`, `firebase_tests/storage.rules.test.ts`, `firebase_tests/vitest.config.ts` (`test: { fileParallelism: false }`).
- Modify:
  - `Makefile`:
    - `setup` also runs `npm ci` in `firebase_tests/`.
    - New target `test-firebase` and its help line.
  - `.gitignore`: add `firebase_tests/node_modules/` if not covered.

**Interfaces:**
- Produces: `make test-firebase`.
  - It checks `command -v firebase` and `java -version` (major ≥ 21), else prints `test-firebase needs the Firebase CLI and Java 21+ (see docs/testing_guide.md)` and exits 1.
  - It runs `npm ci` in `firebase_tests` (and in `functions` if that directory exists).
  - Then `firebase emulators:exec --project demo-test --only firestore,storage "npm --prefix firebase_tests test$(if functions dir) && npm --prefix functions test"`. Build the inner command in shell so that a missing `functions/` simply drops the second part.

- [ ] **Step 1: Write the rules tests** with `initializeTestEnvironment({projectId: 'demo-test', firestore: {rules: readFileSync('../firestore.rules')}, storage: {rules: …}})`, `assertSucceeds` / `assertFails`, and `clearFirestore()` / `clearStorage()` in `beforeEach`.
  - Firestore:
    - Given alice, When she reads or writes `users/alice`, Then it succeeds.
    - Given bob, When he reads or writes `users/alice`, Then it fails.
    - Given unauthenticated, When reading `users/alice`, Then it fails.
    - Given alice, When she writes `items/x`, Then it fails.
  - Storage:
    - Given alice, When she uploads to or reads `users/alice/a.png`, Then it succeeds.
    - Given bob, When he accesses `users/alice/a.png`, Then it fails.
    - Given alice, When she reads `public/a.png`, Then it succeeds; unauthenticated, it fails.
    - Given alice, When she writes `public/a.png`, Then it fails.
- [ ] **Step 2: Run them.** `make test-firebase`: all PASS. Check that the failure mode is real: temporarily change `firestore.rules` to `allow read, write: if true;`, confirm the "bob" test fails, then revert.
- [ ] **Step 3: Init check.** In an rsync'd temp copy, run `fvm dart tool/init.dart --yes --name x_app --no-functions`. Confirm that `firebase.json` has no `functions` key and no `emulators.functions`. Delete the copy.
- [ ] **Step 4: Commit.** `git commit -m "test: add Firestore and Storage rules tests on the emulator"`

### Task 13: Cloud Functions tests, CI job and docs

**Files:**
- Modify:
  - `functions/package.json`: script `"test": "vitest run"`; devDependency `vitest ^5.1.0`; regenerate `package-lock.json`.
  - `functions/tsconfig.json`: unchanged, since `include: ["src"]` already keeps `test/` out of the build. Confirm that `npm run build` emits no `lib/test`.
- Create: `functions/test/index.test.ts`, `functions/vitest.config.ts`
- Modify:
  - `.github/workflows/ci.yml`: add job `firebase`, runs-on `ubuntu-latest`, with these steps:
    - `actions/checkout@v4`
    - `actions/setup-node@v4` (node 22)
    - `actions/setup-java@v4` (`distribution: temurin`, `java-version: 21`)
    - `npm i -g firebase-tools@15.13.0`
    - `actions/cache@v4` on `~/.cache/firebase/emulators`, key `firebase-emulators-15.13.0`
    - `make test-firebase`
  - `docs/testing_guide.md`: add a "Firebase rules & functions tests" section (requirements, `make test-firebase`, how to add a rule test and a function test, and why functions tests use `.run()`).
  - `CHANGELOG.md`

**Interfaces:**
- Consumes: `helloWorld` (v2 `onCall`) and `onUserCreate` (v2 `onDocumentCreated`) from `functions/src/index.ts`, each called via `.run(...)`.

- [ ] **Step 1: Write the tests.** Import from `../src/index`. `emulators:exec` sets `FIRESTORE_EMULATOR_HOST` and `GCLOUD_PROJECT=demo-test`, so `admin.initializeApp()` targets the emulator.
  - `helloWorld.run({auth: undefined, data: {}} as any)` rejects with an `HttpsError` whose code is `'unauthenticated'`.
  - `helloWorld.run({auth: {uid: 'u1'}, data: {name: 'Ada'}} as any)` resolves `{message: 'Hello, Ada!'}`. With `data: {}` it resolves `{message: 'Hello, World!'}`.
  - For `onUserCreate`, write `users/u1` = `{name: 'x'}` through the Admin SDK, get the snapshot, call `onUserCreate.run({params: {userId: 'u1'}, data: snap} as any)`, then re-read: `createdAt` is set. If the document already has `createdAt: 'keep'`, it stays `'keep'`. With `data: undefined`, the call resolves and nothing is written.
  - Clear documents between tests with the Admin SDK (`recursiveDelete(collection('users'))`).
- [ ] **Step 2: Run them.** `make test-firebase`: rules and functions all PASS. `npm --prefix functions run build` still succeeds with no test output in `lib/`.
- [ ] **Step 3: Init check.** In an rsync'd temp copy init'd with `--no-functions`, run `make test-firebase`. Only the rules tests run, and the command exits 0. Delete the copy.
- [ ] **Step 4: Commit.** `git commit -m "test: add Cloud Functions tests and firebase CI job"`

## Phase P3: Integration tests

### Task 14: Emulator harness, app flow integration test, `make test-integration`

**Files:**
- Modify: `pubspec.yaml` (dev: `integration_test: {sdk: flutter}`)
- Create: `integration_test/helpers/emulator_harness.dart`, `integration_test/app_flow_test.dart`, `scripts/integration_stubs.sh`
- Modify: `Makefile` (`test-integration` target and its help line)

**Interfaces:**
- Produces:
  - `scripts/integration_stubs.sh`:
    - Writes `android/app/src/staging/google-services.json` (project `demo-test`, the staging package name read from `android/app/build.gradle.kts` `applicationId` plus the `.staging` suffix if that line exists).
    - Writes `ios/config/Staging/GoogleService-Info.plist` (keys `API_KEY`, `GCM_SENDER_ID`, `PROJECT_ID=demo-test`, `BUNDLE_ID`, `GOOGLE_APP_ID`, `CLIENT_ID`, `REVERSED_CLIENT_ID`, `STORAGE_BUCKET`).
    - Each file is written **only if missing**, and the script prints which ones it wrote.
    - It is a shell script because it runs before Flutter. It is not a Dart file, so the layout check does not apply.
  - `integration_test/helpers/emulator_harness.dart`:
    - `const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');`
    - `Future<FirebaseApp> setUpEmulators()`: initializes the app named `'integration'` with `FirebaseOptions(apiKey: 'demo', appId: '1:1:android:1', messagingSenderId: '1', projectId: 'demo-test')`, then calls `useAuthEmulator(emulatorHost, 9099)` and `useFirestoreEmulator(emulatorHost, 8080)`.
    - `Future<void> resetEmulators()`: sends HTTP `DELETE` to `http://$emulatorHost:9099/emulator/v1/projects/demo-test/accounts` and `http://$emulatorHost:8080/emulator/v1/projects/demo-test/databases/(default)/documents` via `dart:io` `HttpClient`.
    - `Future<void> pumpTestApp(WidgetTester tester, FirebaseApp app)` pumps `ProviderScope(child: App())` with these overrides:
      - `authRepositoryProvider` → `FirebaseAuthRepository(FirebaseAuth.instanceFor(app: app), noopAnalytics, googleSignIn: GoogleSignIn.instance, fetchAppleCredential: SignInWithApple.getAppleIDCredential)`
      - `userRepositoryProvider` → `FirebaseUserRepository(FirebaseFirestore.instanceFor(app: app))`
      - `analyticsRepositoryProvider` → a private no-op `AnalyticsRepository`
      - inside `NOTIFICATIONS`, `notificationServiceProvider` → a private no-op subclass or `implements`
  - `make test-integration DEVICE=<id> [EMULATOR_HOST=<host>]`:
    - Requires `DEVICE`, the Firebase CLI and Java 21+.
    - Runs `scripts/integration_stubs.sh`.
    - Then runs `firebase emulators:exec --project demo-test --only auth,firestore "$(FLUTTER) test integration_test --flavor staging -d $(DEVICE) --dart-define=EMULATOR_HOST=$(HOST)"`.
    - `HOST` defaults to `10.0.2.2` when `DEVICE` starts with `emulator-`, otherwise `localhost`.

- [ ] **Step 1: Write `integration_test/app_flow_test.dart`** (`IntegrationTestWidgetsFlutterBinding.ensureInitialized()`; `setUpAll(setUpEmulators)`; `setUp(resetEmulators)` plus `SharedPreferences` cleared).
  - **Outside markers:**
    - Given the test signs in anonymously via `FirebaseAuth.instanceFor(app:)` and onboarding is marked complete in prefs, When the app is pumped, Then Home is shown.
    - When Settings → sign out runs (use the visible labels in `settings_screen.dart`), Then the onboarding intro is shown.
  - **Inside `ANON`:**
    - Given a fresh start, When intro → theme → "Continue as Guest" → "Continue", Then Home is shown.
    - The Firestore document `users/<currentUid>` exists, checked via `FirebaseFirestore.instanceFor(app:)`.
- [ ] **Step 2: Implement the harness, the stub script and the Makefile target.**
- [ ] **Step 3: Get a device.** No iOS simulator device or Android AVD exists on this machine yet. Create an iOS simulator with `xcrun simctl create "Blueprint iPhone" "iPhone 16" com.apple.CoreSimulator.SimRuntime.iOS-26-3` (use any iPhone device type listed by `xcrun simctl list devicetypes`), then boot it. Record the device creation as a side effect in the report.
- [ ] **Step 4: Run it.** `make test-integration DEVICE=<simulator id>`: all PASS. If the iOS build fails on signing or plist keys, fix the stub script; do not edit Xcode project settings.
- [ ] **Step 5: Check that stubs never overwrite.**
  - Write `{"marker":"real"}` to `android/app/src/staging/google-services.json` and run `scripts/integration_stubs.sh`. The file is byte-identical afterwards.
  - Delete it, and delete any stub files this task created that are untracked. Both paths are gitignored, so `git status` stays clean.
- [ ] **Step 6: Commit.** `git commit -m "test: add emulator-backed integration test and make test-integration"`

### Task 15: Manual integration workflow and docs

**Files:**
- Create: `.github/workflows/integration.yml`
  - `on: workflow_dispatch`; one job on `ubuntu-latest`.
  - Steps:
    - checkout
    - enable KVM (the documented udev rule step for `reactivecircus/android-emulator-runner`)
    - setup-java 21 temurin
    - setup-node 22
    - `npm i -g firebase-tools@15.13.0`
    - `subosito/flutter-action@v2` (3.41.4, stable, cache)
    - `reactivecircus/android-emulator-runner@v2` with `api-level: 34`, `arch: x86_64`, `script: make setup test-integration DEVICE=emulator-5554`
- Modify:
  - `docs/testing_guide.md`: add an "Integration tests" section covering:
    - Requirements.
    - iOS simulator vs Android emulator hosts.
    - The stub files.
    - Why a secondary Firebase app is used.
    - Google/Apple Sign-In not automated.
    - The manual workflow.
  - `README.md`: one line in the testing / CI description listing `ci.yml` (test + firebase jobs) and `integration.yml` (manual).
  - `CHANGELOG.md`
- Test: none new. The workflow can only run after a push; say so in the report.

- [ ] **Step 1: Write the workflow and docs.**
- [ ] **Step 2: Verify.**
  - The workflow YAML parses: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/integration.yml'))"`.
  - `make analyze`, `make check-test-layout` and `make coverage` PASS.
  - `tool/verify_init.sh --yes --name final_app` passes.
- [ ] **Step 3: Commit.** `git commit -m "ci: add manual Android integration workflow; document integration tests"`
