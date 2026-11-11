# Test Suite Design

Date: 2026-11-11
Status: approved in conversation, pending written-spec review

## 1. Goal

The boilerplate ships at least one working, copyable example of every kind of test a Flutter + Firebase app needs, and CI runs them. Generated apps keep the tests that match the features they kept.

Today there are 19 app tests (two controllers and `AppEnv`) and 43 init-tool tests. There are no repository, router, widget, integration, Firestore/Storage rules, or Cloud Functions tests. The Firebase repositories are at 0% line coverage. `docs/testing_guide.md` describes files that do not exist.

### Success criteria

1. `make analyze`, `make check-test-layout`, and `make coverage` pass at the repo root. The coverage gate meets the thresholds in section 3.3.
2. `make test-firebase` passes locally and in the `firebase` CI job.
3. `make test-integration DEVICE=<id>` passes on at least one local iOS simulator or Android emulator.
4. `tool/verify_init.sh` passes for the three `blueprint.yml` flag combinations and for `--no-functions`. It now also runs `make check-test-layout coverage`.
5. `docs/testing_guide.md` and `AGENTS.md` describe what is actually in the repo.

The `integration.yml` workflow can only be verified after a push. This is stated, not claimed.

## 2. Decisions

| # | Decision | Chosen |
|---|---|---|
| D1 | Where full-app flows run | CI runs a widget-level app flow test (`test/app_test.dart`: real router, fake repositories). On-device `integration_test/` runs against the Firebase Emulator locally, plus a manual (`workflow_dispatch`) Android emulator workflow. |
| D2 | Data-layer test approach | `fake_cloud_firestore` + `firebase_auth_mocks` dev dependencies. Versions must be compatible with the current `cloud_firestore` / `firebase_auth`; check this at implementation time. |
| D3 | Google / Apple static SDK calls | Small behavior-preserving refactor. `FirebaseAuthRepository` takes `GoogleSignIn` and an Apple credential function through its constructor. `PostHogAnalyticsRepository` takes a `Posthog` instance. Providers pass the real instances. |
| D4 | Coverage gate | Per-layer thresholds (section 3.3), enforced by a script outside `tool/` so generated apps keep it. The thresholds in `AGENTS.md` are updated to match. |
| D5 | Test file organization | One test file per source file, at the mirrored path (section 3.1), enforced by a script. |
| D6 | Scope split | One spec, three phases (P1 → P2 → P3). Each phase ends green on its own. |

## 3. Conventions

### 3.1 Test file layout

1. **One source file → exactly one test file, mirrored path:** `lib/a/b/foo.dart` ↔ `test/a/b/foo_test.dart`. Do not split one source file's tests across files. Large sources get one `group()` per method. Init's `testMirror` already relies on this: disabling a path feature deletes its mirrored tests.
2. **No orphan tests:** every `test/**/*_test.dart` must map to an existing `lib/` file. `test/helpers/` holds support code, not tests, and is exempt.
3. **Non-Dart equivalents:**
   - `firestore.rules` → `firebase_tests/firestore.rules.test.ts`
   - `storage.rules` → `firebase_tests/storage.rules.test.ts`
   - `functions/src/index.ts` → `functions/test/index.test.ts`
   - `integration_test/<flow>_test.dart` holds flow tests, exempt from rule 1. `integration_test/helpers/` is exempt like `test/helpers/`.
4. **Blueprint-only tool tests:** `tool/src/foo.dart` ↔ `test/tool/foo_test.dart` (the `src/` segment is dropped). This is a documented exception. `test/tool/repo_markers_test.dart` merges into `test/tool/manifest_test.dart`, because `knownMarkers` lives in `manifest.dart`.
5. **Enforcement:** `scripts/check_test_layout.sh` (`make check-test-layout`) fails on any `test/**/*_test.dart` with no matching source, applying the exceptions above. CI runs it in the `test` job.

### 3.2 Test style

- Descriptions use Given-When-Then. Existing tests are renamed to match.
- Mocks use `mocktail` only. Fakes for Firebase come from D2. Controller tests never mock Firebase SDK classes.
- No real network calls in `test/`. Emulator traffic stays local; `integration_test/` and the Node tests target `localhost` / `10.0.2.2` only.

### 3.3 Coverage gate

`scripts/coverage_gate.sh <lcov file>` (`make coverage` runs `flutter test --coverage` and then this script). It prints the percentage per layer and fails below the threshold. Generated files (`*.g.dart`, `*.freezed.dart`) are always excluded.

| Layer | Paths | Threshold |
|---|---|---|
| domain | any `lib/**/domain/**` | 100% |
| data | any `lib/**/data/**` | ≥ 90% |
| application | any `lib/**/application/**`, plus `lib/core/{router,config,providers}/**` | ≥ 80% |
| not gated | `presentation/`, `theme/`, `core/services/` (native plugin wrappers), `core/utils/`, `lib/main.dart`, `lib/app.dart` | none |

Files that no test loads are missing from lcov, which would hide them from the percentages. The script therefore lists every gated `lib/` file and **fails if a gated file is absent from lcov**, naming the file. Every gated file must be loaded by at least one test, which section 3.1 already expects.

### 3.4 Interaction with init feature toggles

- Tests for marker features (POSTHOG, SENTRY, APPLE, GOOGLE, ANON, NOTIFICATIONS*) are wrapped in the same marker blocks inside the test files, as in `lib/`.
- Tests for path features sit under the mirrored path, so init deletes them: `lib/features/notifications` → `test/features/notifications`, and `functions/` → `functions/test/`.
- A test file must still compile and contain at least one test after any combination of markers is stripped. `verify_init` checks this.

## 4. P1: Dart tests (`flutter test`)

### 4.1 Refactors (behavior-preserving)

- `FirebaseAuthRepository(FirebaseAuth, AnalyticsRepository, {GoogleSignIn googleSignIn, AppleCredentialFetcher fetchAppleCredential})`.
  - The new parameters and their fields sit inside the `GOOGLE` / `APPLE` marker blocks.
  - `AppleCredentialFetcher` is a typedef matching `SignInWithApple.getAppleIDCredential`.
  - The provider passes `GoogleSignIn.instance` and `SignInWithApple.getAppleIDCredential`.
- `PostHogAnalyticsRepository(Posthog posthog)` sits inside `POSTHOG`. The provider passes `Posthog()`.

### 4.2 Test files

| Test file | Covers |
|---|---|
| `test/core/router/app_router_test.dart` | The redirect matrix: loading → `/splash`; signed out → `/onboarding/intro`; signed in and onboarding incomplete → `/onboarding/intro`; complete while on onboarding or splash → `/` |
| `test/core/config/app_env_test.dart` | Existing; renamed to Given-When-Then |
| `test/core/data/posthog_analytics_repository_test.dart` | SDK calls per method (`POSTHOG`) |
| `test/core/providers/haptics_provider_test.dart` | Read and persist |
| `test/core/theme/theme_provider_test.dart` | Read and persist theme mode |
| `test/features/auth/data/firebase_auth_repository_test.dart` | `authStateChanges` (synchronous current user first); anonymous sign-in; Google/Apple sign-in and anonymous linking, cancel, unavailable, credential-already-in-use; `updateDisplayName`; delete and reauth; sign-out; every `Failure` mapping |
| `test/features/auth/application/auth_controller_test.dart` | Existing, plus `deleteAccount`, `updateDisplayName`, `signOut`; renamed |
| `test/features/auth/presentation/auth_failure_message_test.dart` | `Failure` → user message |
| `test/features/user_profile/data/firebase_user_repository_test.dart` | User stream (missing or malformed document → null); `recordLogin`; preference updates; errors → `Failure.server` |
| `test/features/user_profile/application/user_profile_providers_test.dart` | Provider wiring and derived values |
| `test/features/settings/application/settings_controller_test.dart` | Theme, haptics, notification time, delete account |
| `test/features/onboarding/application/onboarding_controller_test.dart` | Existing; renamed |
| `test/features/onboarding/presentation/login_prompt_view_test.dart` | Widget example: buttons per enabled feature; "Continue as Guest" calls the controller; loading state; failure snackbar |
| `test/features/notifications/application/notification_scheduler_test.dart` | Scheduling logic with `NotificationService` mocked |
| `test/app_test.dart` | App flow with the real router and fake repositories. Always: a signed-in user with onboarding complete lands on Home. Inside `ANON`: splash → intro → theme → guest → Home. |

### 4.3 Infrastructure

- Dev dependencies: `fake_cloud_firestore`, `firebase_auth_mocks`.
- `test/helpers/fakes.dart`: in-memory fakes that implement the concrete `Firebase*Repository` types, for widget and app tests.
- `test/helpers/pump_app.dart`: `pumpApp(tester, child, {overrides})` wraps the child in `ProviderScope` and a `MaterialApp` with the app theme.
- `scripts/check_test_layout.sh` and `scripts/coverage_gate.sh`. Makefile targets `check-test-layout` and `coverage`.
- `ci.yml` job `test`: `make check-test-layout coverage` replaces `make test`.
- `tool/verify_init.sh` runs `make setup analyze check-test-layout coverage`.
- `AGENTS.md` section 3.4: new thresholds, the layout rule, and the rules-test rule from P2. `docs/testing_guide.md` is rewritten to match the repo, and its stale `main_*.dart` reference is fixed.

## 5. P2: Firebase Emulator tests (rules and functions)

- `firebase.json` gets an `emulators` block: auth 9099, firestore 8080, storage 9199, functions 5001, `singleProjectMode: true`, UI disabled. All tests use project `demo-test`; the `demo-` prefix runs offline with no real project. Init's `_dropFunctions` also removes `emulators.functions`.
- `firebase_tests/` is a standalone Node package, kept under `--no-functions`. It uses `@firebase/rules-unit-testing` and `vitest`; check versions at implementation time.
  - `firestore.rules.test.ts`:
    - The owner can read and write `users/{uid}`.
    - Another user is denied.
    - An unauthenticated client is denied.
    - An unmatched collection is denied.
  - `storage.rules.test.ts`:
    - Only the owner can access `users/{uid}/**`.
    - `public/**` can be read when signed in, but not when signed out.
    - Nobody can write to `public/**`.
- `functions/test/index.test.ts` uses `firebase-functions-test` and `vitest`, with the Admin SDK against the Firestore emulator.
  - `helloWorld`:
    - An unauthenticated call gets `unauthenticated`.
    - A call with a name gets the named greeting.
    - A call without a name gets the default greeting.
  - `onUserCreate`:
    - A document without `createdAt` gets the server timestamp.
    - An existing `createdAt` is kept.
    - An empty document causes no write.
  - `functions/package.json` gets a `test` script. Tests are excluded from the `tsc` build output.
- `make test-firebase`:
  - Fails early with a clear message if the `firebase` CLI or Java 21+ is missing.
  - Runs `npm ci` in `firebase_tests/` (and `functions/` if present), so it needs no Flutter.
  - Then runs `firebase emulators:exec --project demo-test --only firestore,storage "<npm test in firebase_tests, and in functions if present>"`.
  - `make setup` also runs `npm ci` in `firebase_tests/`.
- `ci.yml` job `firebase`:
  - Installs Node 22, Java 21 (temurin), and a pinned `firebase-tools`.
  - Caches the emulator jars.
  - Runs `make test-firebase` in parallel with `test`.

## 6. P3: Integration tests (`integration_test/`)

### 6.1 Problems and approach

- **Build needs per-flavor Firebase config files.** `make test-integration` writes stub staging `google-services.json` and `GoogleService-Info.plist` files (project `demo-test`, the app's package/bundle id) **only when they are missing**. It never overwrites real files.
- **The default Firebase app may point to a real project.** The harness does not call `main()`. Instead it:
  - initializes a secondary Firebase app named `integration` with `demo-test` options;
  - points it at the emulators (`useAuthEmulator`, `useFirestoreEmulator`);
  - overrides the `FirebaseAuth` / `FirebaseFirestore` providers to use that app;
  - replaces analytics with a no-op;
  - skips App Check, Sentry and Workmanager.

### 6.2 Files

- `integration_test/helpers/emulator_harness.dart`:
  - `setUpEmulators()`.
  - `resetEmulators()`, which calls the emulator REST endpoints to clear accounts and documents.
  - `pumpTestApp(tester)`.
- `integration_test/app_flow_test.dart`:
  - **Returning user (always present):** the test signs in anonymously through the SDK and marks onboarding complete. The app opens on Home. Settings → sign out returns to onboarding.
  - **New guest (inside `ANON`):** intro → theme → "Continue as Guest" → Home, then the test checks that `users/{uid}` exists in the Firestore emulator.
- Google and Apple Sign-In use native UI and are not automated; the guide says so.

### 6.3 Running

- `make test-integration DEVICE=<id> [EMULATOR_HOST=…]`:
  - Writes any missing stubs.
  - Runs `firebase emulators:exec --project demo-test --only auth,firestore "fvm flutter test integration_test --flavor staging -d <id> --dart-define=EMULATOR_HOST=<host>"`.
  - The host defaults to `10.0.2.2` for Android emulators and `localhost` otherwise.
- `.github/workflows/integration.yml`:
  - Triggered only by `workflow_dispatch`, on `ubuntu-latest` with KVM.
  - Installs Java 21, Node 22, firebase-tools and Flutter 3.41.4.
  - Uses `reactivecircus/android-emulator-runner` (API 34) to run `make setup test-integration DEVICE=emulator-5554`.
  - Ships in generated apps.
- Dev dependency: `integration_test` (Flutter SDK).

## 7. Out of scope

- Golden (screenshot) tests.
- Testing `NotificationService` or `TimezoneSyncService` against the native plugins.
- Running `integration_test/` on every push.
- Automating Google or Apple Sign-In UI.

## 8. Risks

- `fake_cloud_firestore` / `firebase_auth_mocks` may lag the current FlutterFire major versions. Mitigation: check before adding. If incompatible, mock the SDK with `mocktail` in the repository tests only, and record a ruling.
- The 100% domain threshold may hit unreachable generated or defensive lines. Mitigation: fix the gap with a test. If a line is truly unreachable, record a ruling; do not lower the threshold silently.
- On iOS, the Xcode build script copies `GoogleService-Info.plist` and reads `CLIENT_ID` / `REVERSED_CLIENT_ID`. The stub plist must contain those keys.
- Emulator startup in CI adds roughly 1–2 minutes to the `firebase` job; the jar cache reduces this.
