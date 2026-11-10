# Auth Setup

This template already wires the Flutter-side auth flow. What you still need to do is connect the Firebase, Apple, and Google platform pieces correctly for each environment.

## 1. What Is Already Scaffolded

The generated project already includes:

- anonymous auth flow
- Google and Apple sign-in code paths
- iOS entitlements for Sign in with Apple
- iOS build logic that injects Google client IDs from the selected `GoogleService-Info.plist`
- Android flavor wiring for `google-services.json`

What you still need to configure is the provider setup in Firebase and the platform credentials that sit outside the Dart code.

## 2. Firebase Auth Providers

In both the staging and production Firebase projects, enable only the providers you selected during scaffolding.

Common combinations:

- Anonymous only
- Anonymous + Google
- Anonymous + Apple
- Anonymous + Google + Apple

If you enable a provider in one Firebase project but not the other, expect environment-specific failures during sign-in.

## 3. Google Sign-In

### Android

1. Add your Android app to each Firebase project.
2. Add SHA-1 and SHA-256 fingerprints for the relevant signing keys.
3. Re-download `google-services.json` after adding fingerprints.
4. Place the files in:

```text
android/app/src/staging/google-services.json
android/app/src/production/google-services.json
```

5. Copy the web OAuth client ID from `google-services.json` into:

```text
.env.staging
.env.production
```

Use the value from `oauth_client[]` where `client_type = 3`. In this template that variable is named `GOOGLE_SERVER_CLIENT_ID`.

### iOS

1. Add your iOS app to each Firebase project.
2. Download both `GoogleService-Info.plist` files.
3. Place them in:

```text
ios/config/Staging/GoogleService-Info.plist
ios/config/Production/GoogleService-Info.plist
```

4. Open `ios/Runner.xcworkspace` and set your Apple team.

You do not need to hand-edit `Info.plist` with your Google client IDs. The Xcode build script reads them from the correct Firebase plist at build time.

## 4. Sign in with Apple

### Apple Developer Portal

1. Register every iOS app ID you plan to run, usually both the staging and production bundle IDs.
2. Enable the Sign in with Apple capability for each app ID that needs it.
3. Make sure your team and signing settings are valid in Xcode for each build configuration.

### Firebase

In Firebase Authentication:

1. enable Apple as a sign-in provider
2. connect the provider with your Apple Developer credentials if Firebase prompts for them

### Xcode

The template already includes `ios/Runner/Runner.entitlements` with the Apple Sign-In entitlement. After scaffolding, confirm that Signing & Capabilities still shows the capability correctly for your team and bundle IDs.

## 5. App Check

The template uses:

- `AndroidProvider.debug` / `AppleProvider.debug` style flows for local debug runs
- Play Integrity on Android release builds
- Device Check on iOS release builds

Register App Check debug tokens in Firebase Console and place them in:

```text
.env.staging
.env.production
```

Use:

```text
APP_CHECK_DEBUG_TOKEN_IOS=
APP_CHECK_DEBUG_TOKEN_ANDROID=
```

Production flavor debug runs can also use these tokens. Release builds still use real attestation providers.

## 6. Custom Auth Domain

Most apps do not need this.

If you use a branded or self-managed Firebase Auth redirect domain, set this in each env file:

```text
FIREBASE_AUTH_DOMAIN=
```

Examples:

```text
FIREBASE_AUTH_DOMAIN=staging-auth.yourdomain.com
FIREBASE_AUTH_DOMAIN=auth.yourdomain.com
```

The template entrypoints will override the generated `firebase_options_*.dart` auth domain at runtime without requiring you to edit generated files.

This matters most for:

- branded Firebase Auth redirect flows
- Apple sign-in on Android, where Firebase completes the OAuth redirect through the configured auth domain
- teams that want separate staging and production redirect domains

Leave it blank if you use the default Firebase-provided auth domain.

## 7. Common Failure Cases

### Google Sign-In fails on Android

Usually one of these is wrong:

- SHA fingerprint missing in Firebase
- stale `google-services.json`
- wrong `GOOGLE_SERVER_CLIENT_ID`

### Apple Sign-In fails immediately on iPhone

Check:

- the device is signed into an Apple ID
- Sign in with Apple is enabled for the app ID
- the Xcode signing team is correct

### One environment works and the other does not

Treat staging and production as two separate auth setups. Each needs its own:

- Firebase app registration
- config files
- SHA fingerprints
- provider enablement
- auth domain setup, if you use a custom one

## 8. Related Guides

- [docs/setup.md](./setup.md)
- [docs/android_signing.md](./android_signing.md)
- [docs/release_guide.md](./release_guide.md)
