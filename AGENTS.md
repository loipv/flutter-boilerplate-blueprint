# AGENTS.md

> **System Context**: This file is the "Living Documentation" for this project. It defines the rules, tech stack, and philosophy that must be applied to every request. AI agents (Claude, Codex, Gemini) must read this before writing any code.

---

## 1. Constitution & Core Philosophy

### 1.1 Project Identity

**App:** `flutter-firebase-blueprint` — a Flutter + Firebase starter template with feature-first architecture, Riverpod 3.x, auth, onboarding, and release tooling.
**Stack:** Flutter + Firebase · Feature-First Clean Architecture · Riverpod 3.x code-gen

### 1.2 Architectural Vetos

- **STRICTLY FORBID "Layer-First" architecture** (`lib/controllers/`, `lib/models/`, `lib/views/` (all banned))
- **STRICTLY FORBID** `GetX`, `Provider`, or `Bloc`
- **STRICTLY FORBID Firebase SDK imports** outside of `data/` layers and entrypoints (`main_staging.dart`, `main_production.dart`, `firebase_options_*.dart`). Domain, application, and presentation layers must remain backend-agnostic.
- **STRICTLY FORBID `posthog_flutter` and `sentry_flutter` imports** outside of `core/data/` (SDK implementations), `core/router/` (observer injection), and entrypoints.
- **STRICTLY FORBID leaking raw backend exceptions** (`FirebaseException`, etc.) past the data layer. All exceptions must be mapped to the `Failure` union type.

---

## 2. Core Behavioral Rules

### 2.1 Code Context Discovery (CRITICAL)

**Search the codebase before writing any code or asking clarifying questions.**

1. Use semantic search or grep for existing patterns before creating new ones
2. No assumptions about business logic or implementation details; search first
3. If no results, state this explicitly and request clarification

### 2.1.1 Blueprint Release Context

This repository has two separate versioning concerns:

- The **blueprint version** for this template repo, defined by `BLUEPRINT_VERSION` in `scaffold.sh`
- The **generated app version** in each scaffolded app's `pubspec.yaml`

For blueprint release work:

1. Read `README.md` and `CHANGELOG.md` first
2. Treat `main` as the default install path for the latest stable blueprint
3. Treat Git tags as reproducible snapshots for older exact blueprint versions
4. Update blueprint release docs and metadata together: `scaffold.sh`, `README.md`, `CHANGELOG.md`, and any generated version-stamp files
5. Do not use generated-app Makefile release commands (`make bump-version`, `make tag-release`) as the source of truth for blueprint releases

### 2.2 Architecture Enforcement

#### Feature-First Clean Architecture

Every feature lives under `lib/features/<name>/` with up to four layers:

- `domain/`: Freezed entities + **abstract repository interfaces**
- `data/`: Concrete implementations (`Firebase*Repository`)
- `application/`: AsyncNotifier controllers (`@riverpod` code-gen)
- `presentation/`: Pages, widgets, screens

Shared code lives in `lib/core/` (router, theme, domain models, services, error types).

Platform setup and release wiring live outside `lib/` too. When a task touches auth, publishing, or platform configuration, also read the generated app's `docs/setup.md`, `docs/auth_setup.md`, and the `ios/` / `android/` flavor files before changing code.

#### Strictly Forbidden Patterns

- ❌ `StatefulWidget`: use `ConsumerWidget` / `ConsumerStatefulWidget`
- ❌ Relative imports: use `package:__APP_PACKAGE__/…` everywhere
- ❌ `SizedBox` for spacing: use `Gap(AppSpacing.pX)`
- ❌ Manual JSON parsing: use `@freezed` with `json_serializable`
- ❌ `print()` / `debugPrint()`: use `AppLogger`
- ❌ `Color.withOpacity()`: use `Color.withValues(alpha:)`
- ❌ Material Icons or `phosphor_flutter`: use `lucide_icons_flutter`
- ❌ `google_fonts` package: fonts are bundled as assets; use `TextStyle(fontFamily: 'Inter')` or `'Inter_24pt'` or `'JetBrainsMono'`
- ❌ Direct `HapticFeedback.*()` calls (except the haptics settings toggle): use `AppHaptics.*(ref)`

### 2.3 State Management: Riverpod 3.x Code-Gen

Every provider uses `@riverpod` or `@Riverpod(keepAlive: true)`:

```dart
// Functional provider
@riverpod
Future<SharedPreferences> sharedPreferences(Ref ref) async => ...;

// Class-based notifier
@riverpod
class ExampleController extends _$ExampleController {
  @override
  FutureOr<List<Item>> build() async => _fetch();

  Future<void> addItem(String item) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => _fetch());
  }
}
```

**keepAlive providers:** `AuthController`, `FirebaseAuthRepository` (as `AuthRepository`), `FirebaseUserRepository` (as `UserRepository`), `PostHogAnalyticsRepository` (as `AnalyticsRepository`), `ThemeNotifier`, `OnboardingController`.

After editing annotated classes, run:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

### 2.4 Backend Abstraction Pattern

- **Abstract interfaces** live in `domain/`; controllers and UI depend only on these
- **Firebase implementations** live in `data/`; never imported from domain/application/presentation
- **Error mapping**: every repository method catches backend exceptions and maps them to `Failure` (Network, Cache, Auth, Server, Permission, Unknown)
- **No raw exceptions**: `FirebaseException` must never leak past the data layer

### 2.5 Logging

```dart
class MyRepository {
  static const _log = AppLogger('MyRepository');

  Future<void> doWork() async {
    _log.info('Starting work');
    try {
      // …
    } catch (e, st) {
      _log.error('Work failed', error: e, stackTrace: st);
    }
  }
}
```

- `static const _log = AppLogger('<ClassName>')` at the top of every class
- `.info()` for routine events, `.warning()` for recoverable problems, `.error()` for failures
- In release mode, `AppLogger.error` (SEVERE) is forwarded to Sentry automatically

### 2.6 Navigation

GoRouter with Riverpod-driven redirect guards in `lib/core/router/app_router.dart`:

- Uses `_RouterRefreshNotifier` with `ref.listen`, which triggers redirects without rebuilding the router instance (preserves bottom nav state)
- Auth gate → if not signed in, redirect to `/onboarding/intro`
- Onboarding gate → if not complete, redirect to `/onboarding/intro`
- Splash shown during cold-start while auth + onboarding state are loading
- `parentNavigatorKey: rootNavigatorKey` covers bottom nav for detail screens

### 2.7 Data Flow & Error Handling

```
UI → Controller (AsyncNotifier) → Repository Interface → Concrete Implementation → Firebase
```

- Controllers use `AsyncValue.guard()` for state transitions
- Always handle all `AsyncValue` states in UI: `when(data:, loading:, error:)`
- Map `Failure` types to user-facing strings in the presentation layer

---

## 3. Technology Stack

### 3.1 Directory Structure

```text
lib/
├── main_staging.dart           # Staging entry point
├── main_production.dart        # Production entry point
├── app.dart                    # Root Widget
├── firebase_options_staging.dart     # Generated by flutterfire configure
├── firebase_options_production.dart  # Generated by flutterfire configure
├── core/
│   ├── constants/              # Firestore collection names, app-wide constants
│   ├── data/                   # Shared data implementations
│   ├── domain/                 # Shared abstract interfaces (AnalyticsRepository)
│   ├── errors/                 # Failure union (Freezed)
│   ├── presentation/           # MainScaffold, SplashScreen, AppSnackBar
│   ├── providers/              # SharedPreferences, hapticsEnabled
│   ├── router/                 # GoRouter config
│   ├── services/               # SessionLifecycleObserver, NotificationService, timezone sync
│   ├── theme/                  # AppColors, AppSpacing, AppTheme, AppTypography
│   └── utils/                  # AppLogger, AppHaptics
└── features/
    ├── auth/                   # Authentication (anon + Google + Apple)
    ├── onboarding/             # Multi-step FTUX
    ├── home/                   # Home screen (customize per app)
    ├── settings/               # Account, linking, theme, notifications, delete
    ├── notifications/          # Optional notification scheduling wrapper
    └── user_profile/           # Firestore user document CRUD
```

Generated apps also include platform setup files such as:

```text
ios/config/Staging/GoogleService-Info.plist
ios/config/Production/GoogleService-Info.plist
android/app/src/staging/google-services.json
android/app/src/production/google-services.json
```

### 3.2 Package Dependency Rules

The Riverpod stack must be upgraded as a unit:

- `flutter_riverpod: ^3.0.0`
- `riverpod_annotation: ^4.0.0`
- `riverpod_generator: ^4.0.0+1`

Never change one without the others.

### 3.3 Advanced Environment Configuration

Generated apps may optionally use environment-driven platform and analytics overrides:

- `POSTHOG_HOST`: custom PostHog region or self-hosted domain
- `FIREBASE_AUTH_DOMAIN`: custom Firebase Auth redirect domain
- `APP_CHECK_DEBUG_TOKEN_IOS` / `APP_CHECK_DEBUG_TOKEN_ANDROID`: local App Check debug runs

Do not hardcode these values in source. Keep them in env files and read them in entrypoints only.

### 3.4 Testing Standards

- **Coverage**: 100% for domain + data layers, 80% for application layer
- **Mocking**: `mocktail` only; mock the **abstract interface**, never the Firebase class
- **Style**: Given-When-Then for all test descriptions
- **Rule**: Never make real network calls in unit tests

```dart
class MockAuthRepository extends Mock implements AuthRepository {}

test(
  'Given anonymous user, When signInWithGoogle succeeds, Then user is updated',
  () async { … },
);
```

---

## 4. Security Mandate

**Users only access `users/{userId}`.** Public content is Read-Only.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Add public collection rules below
  }
}
```

Never expose admin or other users' data to the client.

---

## 5. General Behavioral Preferences

1. **Reference existing patterns**: use `lib/features/auth/` as the full 4-layer reference
2. **No speculative abstractions**: build what the task requires, not what might be needed later
3. **No layer-crossing**: presentation never imports from `data/`, domain never imports from `application/`
4. **Run after every change**: `dart format .` then `fvm flutter analyze`
5. **Update `plans/master_plan.md`** when completing tasks (if present)
