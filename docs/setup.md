# Setup Guide

Use this after scaffolding a new app. It covers the pieces required to get the app running locally, then points you to the deeper setup guides for auth and releases.

<!-- BEGIN_BLUEPRINT -->
## Scaffold a New App

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/loipv/flutter-boilerplate-blueprint/main/scaffold.sh)"
```

The script clones the blueprint into the target directory and runs `dart tool/init.dart`, which renames it in place. It asks for:

- package name, organization, display name, description
- which optional features to keep: notifications, PostHog, Sentry, Cloud Functions, Apple, Google, anonymous sign-in

Every question has a flag (see `README.md`). Bottom nav tabs, brand colors, the AI tool file, and FVM are edited by hand afterwards; see `docs/next_steps.md`.

<!-- END_BLUEPRINT -->
## 1. Prerequisites

| Tool              | Install                                                       |
| ----------------- | ------------------------------------------------------------- |
| Flutter (via FVM) | `dart pub global activate fvm`                                |
| Firebase CLI      | `npm install -g firebase-tools`                               |
| FlutterFire CLI   | `dart pub global activate flutterfire_cli`                    |
| Xcode (iOS)       | App Store                                                     |
| Android Studio    | [developer.android.com](https://developer.android.com/studio) |
| CocoaPods         | `sudo gem install cocoapods`                                  |

## 2. Install Dependencies

```sh
make setup
```

This runs `pub get`, code generation, and `npm install` in `functions/` when that directory exists. If you use FVM, the repo pins the Flutter SDK in `.fvmrc`; the `make` targets pick up `fvm` automatically.

## 3. Create Firebase Projects

Create one Firebase project for each environment:

| Environment | Suggested name   |
| ----------- | ---------------- |
| Staging     | `my-app-staging` |
| Production  | `my-app-prod`    |

For each Firebase project, register:

- one iOS app with the matching bundle ID
- one Android app with the matching package name

## 4. Add Firebase Config Files

This project uses two flavors (staging, production), so you must run `flutterfire configure` **twice** — once per Firebase project — and pass `--out` to write each Dart options file to a flavor-specific path. After each run, **move** the generated `GoogleService-Info.plist` and `google-services.json` from their default locations into the flavor folders below.

> Prerequisite: `dart pub global activate flutterfire_cli` and `firebase login` must already be completed.

### Run for staging

```sh
flutterfire configure \
  --project=<your-staging-firebase-project-id> \
  --out=lib/firebase_options_staging.dart \
  --ios-bundle-id=<staging bundle id, or the production id with --shared-app-id> \
  --android-package-name=<staging package name, or the production id with --shared-app-id> \
  --platforms=ios,android \
  --yes
```

Then move the platform files into the staging folders:

```sh
mv ios/Runner/GoogleService-Info.plist ios/config/Staging/GoogleService-Info.plist
mv android/app/google-services.json    android/app/src/staging/google-services.json
```

### Run for production

```sh
flutterfire configure \
  --project=<your-production-firebase-project-id> \
  --out=lib/firebase_options_production.dart \
  --ios-bundle-id=<prod bundle id> \
  --android-package-name=<prod package name> \
  --platforms=ios,android \
  --yes
```

Then move the platform files into the production folders:

```sh
mv ios/Runner/GoogleService-Info.plist ios/config/Production/GoogleService-Info.plist
mv android/app/google-services.json    android/app/src/production/google-services.json
```

### Final layout

```text
lib/firebase_options_staging.dart
lib/firebase_options_production.dart
ios/config/Staging/GoogleService-Info.plist
ios/config/Production/GoogleService-Info.plist
android/app/src/staging/google-services.json
android/app/src/production/google-services.json
```

These paths are already wired into the Xcode project and Gradle build — the right plist / JSON is selected automatically based on the active flavor.

### Notes

- Do **not** leave the default `lib/firebase_options.dart` in the repo — delete it if it appears. `lib/main.dart` references the flavor-suffixed files only.
- You can configure staging first and production later. `lib/main.dart` imports both options files, so `make setup` writes a stub for any one that is missing (both files are git-ignored, so a fresh clone has neither). A flavor whose options file is still a stub stops at startup with the `flutterfire configure` command to run.
- If `flutterfire configure` fails parsing `ios/Runner.xcodeproj/project.pbxproj`, check that any build setting whose value contains a space (for example `APP_DISPLAY_NAME`) is wrapped in double quotes, e.g. `APP_DISPLAY_NAME = "My App Name";`.

## 5. Fill In Environment Files

Scaffolding creates:

```text
.env.staging
.env.production
```

Required values:

```text
POSTHOG_API_KEY=          # if PostHog was included
SENTRY_DSN=               # if Sentry was included
GOOGLE_SERVER_CLIENT_ID=  # if Google Sign-In was included
```

`GOOGLE_SERVER_CLIENT_ID` is the Google web OAuth client ID used by Android Google Sign-In. You can find it inside the matching `google-services.json` under `oauth_client[]` where `client_type = 3`.

Optional values:

```text
POSTHOG_HOST=
FIREBASE_AUTH_DOMAIN=
API_BASE_URL=
# BEGIN_REMOTE_CONFIG
REMOTE_CONFIG_ENV=
# END_REMOTE_CONFIG
APP_CHECK_DEBUG_TOKEN_IOS=
APP_CHECK_DEBUG_TOKEN_ANDROID=
UPLOAD_KEYSTORE_PATH=
UPLOAD_KEY_ALIAS=
UPLOAD_STORE_PASSWORD=
UPLOAD_KEY_PASSWORD=
```

`POSTHOG_HOST` is optional. Leave it blank for the SDK default, or set it if you use PostHog EU cloud or a custom/self-hosted domain.

`FIREBASE_AUTH_DOMAIN` is optional. Set it only if you use a custom Firebase Auth redirect domain. Most apps can leave it blank.

`API_BASE_URL` is the base URL of your HTTP API. It is the default for `ConfigKeys.apiBaseUrl` until Remote Config returns a value (first install, offline).

<!-- BEGIN_REMOTE_CONFIG -->
`REMOTE_CONFIG_ENV` is optional. It is the value of the Remote Config custom signal `environment`. Leave it blank to use the flavor name (`staging` / `production`).
<!-- END_REMOTE_CONFIG -->

`APP_CHECK_DEBUG_TOKEN_*` is useful for local device runs. The production flavor uses the same debug-token path only in debug mode, so you can test production builds locally without weakening release builds.

## 6. Enable Firebase Products

In each Firebase project:

- enable Firestore in Native mode
- enable Anonymous auth
- enable any OAuth providers you selected during scaffolding

For auth-specific setup, read [docs/auth_setup.md](./auth_setup.md).

Deploy the bundled Firestore rules:

```sh
make deploy-staging
make deploy-prod
```

<!-- BEGIN_REMOTE_CONFIG -->
### Remote Config

Remote Config is optional (init flag `--no-remote-config`). Enable it in each Firebase project (Console, Remote Config).

**Per-environment values.** The app sets a custom signal `environment` on the client before each fetch. Its value is `REMOTE_CONFIG_ENV`, or the flavor name when blank. In the Console, add a condition on the custom signal `environment` that exactly matches `staging`, and one for `production`, then set per-condition values on a parameter. If a team points both flavors at one Firebase project, this signal keeps their values separate; Auth, Firestore and App Check are then shared too. The signal also works with `--shared-app-id`, where a condition on App ID could not tell staging from production.

**Adding a key.** Add one line to `lib/core/domain/config_keys.dart` and list it in `ConfigKeys.all`:

```dart
static const newHomeEnabled = ConfigKey<bool>('new_home_enabled', false);
```

Then create a parameter with the same name in the Console. Supported types: `String`, `bool`, `int`, `double`. `get()` never throws: it returns the key's default when the key has no remote or default value, when a bool value is not exactly `true` / `false` (case-sensitive), or when an int / double value cannot be parsed.

**Loading strategy.** At startup the app activates the values cached from a previous launch (defaults from code / `.env` until something was fetched), then runs one background `fetchAndActivate()` per launch. If it activates new values, they apply in the same session. There are no real-time updates and no periodic refetch. `minimumFetchInterval` throttles fetches across launches: 5 minutes for staging, 1 hour for production (`AppEnv.remoteConfigMinFetchInterval`).

**Reading values.**

- `ref.watchConfig(ConfigKeys.x)` (on `Ref` and `WidgetRef`) returns the value and rebuilds the caller when new values are activated.
- `ref.read(remoteConfigRepositoryProvider).get(ConfigKeys.x)` does not rebuild; it sees new values on its next read.
- `apiBaseUrl` can change once, a few seconds after startup. Read it per request, or `watchConfig` it so the HTTP client is rebuilt. A client that caches the URL at creation keeps the old one until the next launch.

The Firebase Emulator does not support Remote Config; the app falls back to the defaults there.
<!-- END_REMOTE_CONFIG -->

## 7. Platform Setup

### iOS

Install pods:

```sh
cd ios && pod install && cd ..
```

Then open `ios/Runner.xcworkspace` and:

1. set your Apple team on the Runner target
2. verify the staging and production bundle IDs
3. confirm any capabilities you need, such as Sign in with Apple

The template already scaffolds:

- flavor-specific Xcode schemes
- `Runner.entitlements` for Apple Sign-In
- `PrivacyInfo.xcprivacy`
- build logic that copies the right `GoogleService-Info.plist`

### Android

The template already scaffolds:

- staging and production product flavors
- Google services plugin setup
- release signing hooks that read from env vars

For release signing and Play Console setup, read [docs/android_signing.md](./android_signing.md).

## 8. Notifications

If you included notifications during scaffolding, the generated app already contains:

- local notification dependencies
- Android notification permissions
- iOS background task entries for timezone re-sync
- a notification service and a basic reminder preference in Settings

What it does not include yet is app-specific copy, payload routing, or remote push. The generated code leaves those parts for your app.

## 9. First Run

```sh
make run-staging
```

If you want to test the production flavor locally:

```sh
make run-prod
```

## 10. Code Generation and Verification

After changing any `@freezed` or `@riverpod` file:

```sh
make codegen
```

Before you start building features:

```sh
make analyze
make check-test-layout
make coverage
```
