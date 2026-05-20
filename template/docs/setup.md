# Setup Guide

Use this after scaffolding a new app. It covers the pieces required to get the app running locally, then points you to the deeper setup guides for auth and releases.

## 1. Prerequisites

| Tool              | Install                                                       |
| ----------------- | ------------------------------------------------------------- |
| Flutter (via FVM) | `dart pub global activate fvm`                                |
| Firebase CLI      | `npm install -g firebase-tools`                               |
| FlutterFire CLI   | `dart pub global activate flutterfire_cli`                    |
| Xcode (iOS)       | App Store                                                     |
| Android Studio    | [developer.android.com](https://developer.android.com/studio) |
| CocoaPods         | `sudo gem install cocoapods`                                  |

## 2. Scaffold a New App

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/loipv/flutter-boilerplate-blueprint/main/scaffold.sh)"
```

The questionnaire asks for:

- app name, package name, organization, description
- bottom nav layout
- brand color preset
- optional features such as notifications, analytics, Sentry, and Cloud Functions
- whether FVM should use the blueprint-tested Flutter SDK or the latest stable channel

The script creates a new Flutter project in the output directory you choose, then overlays the template on top.

If you choose FVM, the default is the blueprint-tested Flutter SDK pinned by the template. That keeps scaffolds reproducible and aligned with the version the blueprint was last validated against. If you prefer to track the newest stable SDK, choose the stable-channel option during scaffolding.

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

Run `flutterfire configure` for each project, then place the generated platform files in the flavor-specific locations below.

### Flutter config

Generate:

- `lib/firebase_options_staging.dart`
- `lib/firebase_options_production.dart`

### iOS config

Place the files here exactly:

```text
ios/config/Staging/GoogleService-Info.plist
ios/config/Production/GoogleService-Info.plist
```

These paths are already wired into the Xcode project. During build, the right plist is copied into the app bundle automatically.

### Android config

Place the files here:

```text
android/app/src/staging/google-services.json
android/app/src/production/google-services.json
```

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
APP_CHECK_DEBUG_TOKEN_IOS=
APP_CHECK_DEBUG_TOKEN_ANDROID=
UPLOAD_KEYSTORE_PATH=
UPLOAD_KEY_ALIAS=
UPLOAD_STORE_PASSWORD=
UPLOAD_KEY_PASSWORD=
```

`POSTHOG_HOST` is optional. Leave it blank for the SDK default, or set it if you use PostHog EU cloud or a custom/self-hosted domain.

`FIREBASE_AUTH_DOMAIN` is optional. Set it only if you use a custom Firebase Auth redirect domain. Most apps can leave it blank.

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
make test
```
