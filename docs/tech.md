# Technical Reference

## Stack

| Layer          | Choice                                         |
| -------------- | ---------------------------------------------- |
| UI             | Flutter (stable, via FVM)                      |
| State          | Riverpod 3.x (`@riverpod` code-gen)            |
| Navigation     | GoRouter + `StatefulShellRoute`                |
| Backend        | Firebase (Auth, Firestore, Storage, Functions) |
| Error tracking | Sentry                                         |
| Analytics      | PostHog                                        |
| Notifications  | Local notifications + timezone sync (optional) |
| DI             | Riverpod providers (no service locator)        |

## Directory Structure

```
lib/
├── main.dart                # Entry point for both flavors
├── app.dart                 # ProviderScope + MaterialApp.router
│
├── core/
│   ├── config/              # AppEnv: per-flavor runtime config
│   ├── constants/           # App-wide constants
│   ├── data/                # Core data impl (analytics)
│   ├── domain/              # Core interfaces (AnalyticsRepository)
│   ├── errors/              # Failure union type
│   ├── presentation/        # MainScaffold, SplashScreen, shared widgets
│   ├── providers/           # SharedPreferences, haptics providers
│   ├── router/              # GoRouter (app_router.dart)
│   ├── services/            # SessionLifecycleObserver, notifications, timezone sync
│   ├── theme/               # AppColors, AppTypography, AppSpacing, AppTheme
│   └── utils/               # AppLogger, AppHaptics
│
└── features/
    ├── auth/                # Authentication (anon + Google + Apple)
    │   ├── domain/          # AuthRepository interface, UserEntity, UserPreferences
    │   ├── data/            # FirebaseAuthRepository
    │   ├── application/     # AuthController
    │   └── presentation/    # AuthButton widget
    ├── onboarding/          # Onboarding flow
    │   ├── domain/          # (via shared prefs; no separate domain file)
    │   ├── data/            # OnboardingRepository (SharedPreferences)
    │   ├── application/     # OnboardingController, OnboardingState
    │   └── presentation/    # IntroView, ThemeSelectionView, LoginPromptView, OnboardingScaffold
    ├── user_profile/        # User data (Firestore)
    │   ├── domain/          # UserRepository interface
    │   ├── data/            # FirebaseUserRepository
    │   └── application/     # currentUserProvider, userRepositoryProvider
    ├── settings/            # App settings and account actions
    │   ├── application/     # SettingsController
    │   └── presentation/    # SettingsScreen
    ├── notifications/       # Notification scheduling wrapper (optional)
    ├── home/                # Home tab (replace with your content)
    ├── explore/             # Explore tab (optional; 3+ tab layouts)
    └── profile/             # Profile tab
```

## Architecture Rules

### Feature-First, Clean Architecture

Each feature is self-contained with four sub-layers:

```
domain/      → Entities, repository interfaces, value objects (pure Dart)
data/        → Firebase/HTTP implementations of domain interfaces
application/ → Riverpod controllers, providers, business logic
presentation/→ Widgets only; reads providers, dispatches actions
```

**No cross-layer imports going upward.** Data never imports from presentation. Domain never imports from data.

**Firebase SDK imports are confined to `data/` layers only.** The only exception is `main_*.dart` (initialization) and `core/router/` (Sentry/PostHog observers).

### Riverpod Code-Gen

All providers use `@riverpod` annotation:

```dart
@riverpod
class MyController extends _$MyController {
  @override
  FutureOr<MyState> build() async { ... }
}

@riverpod
Future<List<Item>> items(Ref ref) async { ... }
```

Run `make codegen` after any change to annotated files.

### Error Handling

All exceptions from Firebase (or any external system) are caught at the data layer boundary and mapped to the `Failure` union type:

```dart
// core/errors/failure.dart
@freezed
abstract class Failure with _$Failure {
  const factory Failure.network([String? message]) = NetworkFailure;
  const factory Failure.cache([String? message]) = CacheFailure;
  const factory Failure.auth([String? message]) = AuthFailure;
  const factory Failure.server([String? message]) = ServerFailure;
  const factory Failure.permission([String? message]) = PermissionFailure;
  const factory Failure.unknown([String? message]) = UnknownFailure;
}
```

Controllers return `AsyncValue`; the UI uses `.when(data:, loading:, error:)`.

### GoRouter Auth Guard

The router lives in a `@Riverpod(keepAlive: true)` provider. Auth and onboarding state changes trigger a `redirect` re-evaluation via `_RouterRefreshNotifier` + `ref.listen`, which avoids recreating the router (which resets navigation position).

```
/splash   → loading state
/onboarding/* → not logged in OR onboarding incomplete
/         → logged in + onboarding complete
```

## Key Packages

| Package                                                    | Purpose                                              |
| ---------------------------------------------------------- | ---------------------------------------------------- |
| `flutter_riverpod` + `riverpod_annotation`                 | State management                                     |
| `go_router`                                                | Declarative navigation                               |
| `firebase_core` / `firebase_auth` / `cloud_firestore`      | Firebase                                             |
| `google_sign_in`                                           | Google OAuth                                         |
| `sign_in_with_apple`                                       | Apple Sign-In                                        |
| `freezed` + `json_serializable`                            | Immutable models + JSON                              |
| `shared_preferences`                                       | Local persistence (onboarding, theme)                |
| `flutter_local_notifications` + `timezone` + `workmanager` | Optional local notifications and timezone sync       |
| `lucide_icons_flutter`                                     | Icons (do not substitute)                            |
| `gap`                                                      | Spacing (use `Gap(AppSpacing.pN)`: never `SizedBox`) |
| `posthog_flutter`                                          | Analytics                                            |
| `sentry_flutter`                                           | Error tracking                                       |

## Flavors

Two flavors: `staging` and `production`, selected at build time with `--flavor`. Each flavor has its own display name and Firebase project, and by default its own bundle/application id (`.staging` suffix; init `--shared-app-id` makes staging use the production id, see `docs/release_guide.md`).

One entry point, `lib/main.dart`, serves both flavors:

- `AppEnv.fromFlavor(appFlavor)` (`lib/core/config/app_env.dart`) maps the flavor to an environment and throws if the app was started without `--flavor`.
- `AppEnv` holds the per-environment differences (Sentry trace rate, debug SDK logging, App Check debug providers).
- `main.dart` initializes Firebase with `lib/firebase_options_staging.dart` or `lib/firebase_options_production.dart` to match.

Secrets come from `.env.staging` / `.env.production` as `--dart-define` values. The `make run-*` and `make build-*` commands pass the flavor and the matching env file.

## Code Generation

```sh
make codegen
# equivalent to:
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`) are created by running `make codegen`. Run code generation after changing annotated files and before committing those changes in your app project.

## Logging

```dart
const _log = AppLogger('FeatureName');
_log.info('Something happened');
_log.warning('Unexpected state');
_log.error('Failed', error: e, stackTrace: st);  // auto-forwards SEVERE to Sentry
```

Never use `print()` or `debugPrint()`.
