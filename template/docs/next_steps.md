# Next Steps

Post-scaffold checklist and use-case guide. Detailed setup lives in `docs/setup.md`, and auth-specific platform steps live in `docs/auth_setup.md`.

Scaffolded from `flutter-boilerplate-blueprint` version `v__BLUEPRINT_VERSION__`. See `BLUEPRINT_VERSION.md` in the project root if you need to report which blueprint snapshot this app started from.

---

## Priority checklist

### Tier 1: Required (app won't run without these)

- [ ] **Create two Firebase projects** (staging and production) at [console.firebase.google.com](https://console.firebase.google.com)
- [ ] **Install the FlutterFire CLI** if you haven't already: `dart pub global activate flutterfire_cli`
- [ ] **Run `flutterfire configure`** for each project to generate `lib/firebase_options_staging.dart` and `lib/firebase_options_production.dart`
- [ ] **Place platform Firebase files** in `ios/config/Staging/`, `ios/config/Production/`, `android/app/src/staging/`, and `android/app/src/production/`
- [ ] **Fill in `.env.staging` and `.env.production`** with the values needed for the features you selected during scaffolding
- [ ] **Enable Firestore** (Native mode) in each Firebase project
- [ ] **Enable Anonymous auth** in each project: Authentication > Sign-in method
- [ ] **Deploy security rules**: `make deploy-staging && make deploy-prod`
- [ ] **iOS pods**: `cd ios && pod install && cd ..`
- [ ] **First run**: `make run-staging`

### Tier 2: Before real users

- [ ] **If you included Google Sign-In**: enable it in Firebase, add a SHA-1 fingerprint for Android, and set `GOOGLE_SERVER_CLIENT_ID` in both env files
- [ ] **If you included Apple Sign-In**: enable it in Firebase, configure it in the Apple Developer portal, and add the capability in Xcode
- [ ] **If you use a custom Firebase Auth redirect domain**: set `FIREBASE_AUTH_DOMAIN` in each env file and verify both environments
- [ ] **Set up App Check**: register your apps and fill in `APP_CHECK_DEBUG_TOKEN_IOS` / `APP_CHECK_DEBUG_TOKEN_ANDROID` in env files
- [ ] **Read `docs/auth_setup.md`** and verify both environments separately before testing sign-in
- [ ] **If you included PostHog or Sentry**: fill in the matching env values, set `POSTHOG_HOST` if you use a custom domain or EU region, and confirm they report correctly in staging
- [ ] **Android release signing**: generate an upload keystore and configure env vars (see `docs/android_signing.md`)
- [ ] **Describe your app**: fill in the one-line description placeholder in `AGENTS.md` (and your AI bootloader file if present)

### Tier 3: Before launch

- [ ] **App icon**: replace `assets/icons/app_logo.png` (1024x1024 PNG), then run `make icons && make splash`
- [ ] **Onboarding copy**: update headlines and body text in `features/onboarding/presentation/`
- [ ] **Home screen**: replace the placeholder in `features/home/presentation/home_screen.dart`
- [ ] **Explore / Library screens**: replace or remove tabs you don't need, then update the router and scaffold to match
- [ ] **Profile screen**: add any app-specific fields
- [ ] **User model**: add domain-specific fields to `UserEntity` and `UserPreferences`
- [ ] **Firestore collection names**: define them in `core/constants/app_constants.dart`
- [ ] **Run preflight**: `make release-preflight` (analyze + test gate must pass with zero errors)
- [ ] **Privacy manifest** (iOS): review `ios/Runner/PrivacyInfo.xcprivacy` and add any app-specific API reasons
- [ ] **Store listing assets**: screenshots, app description, keywords, privacy policy URL
- [ ] **Tag your first release**: `make bump-version VERSION=1.0.0 BUILD=1 && make tag-release VERSION=1.0.0`
- [ ] **Submit**: follow the end-to-end checklist in `docs/release_guide.md`

---

## Use-case paths

### Just running it locally

Do Tier 1 only. You can point both flavors at a single Firebase project to start. Skip App Check, signing, and icons for now.

### Solo side project

Do Tiers 1 and 2. Signing can wait until your first TestFlight build. Pick a color preset during scaffolding; you can swap it later by editing `app_colors.dart`.

### Production app with a team

Finish all three tiers before you invite beta users. A few things worth extra attention:

- Firestore security rules: review `firestore.rules` and tighten them for your data model before going live
- App Check: prevents unauthorized clients from hitting your Firebase backend
- Android signing: keep the keystore in a password manager and share via secrets manager, not Slack

### Adding a new feature

Follow the four-layer pattern:

```
features/<name>/
  domain/       <- entities + repository interface (pure Dart)
  data/         <- Firebase implementation
  application/  <- @riverpod controller
  presentation/ <- ConsumerWidget screens and widgets
```

Read `AGENTS.md` and `docs/tech.md` before writing any code.

### Deploying to the App Store or Play Store

Run `make release-preflight` first. Then:

- iOS: `make build-prod-ipa`, upload via Xcode Organizer or `xcrun altool`
- Android: `make build-prod-aab`, upload to Play Console

---

## FAQ

**The app crashes on launch.**
The most likely cause is a missing Firebase config file. Check that `lib/firebase_options_staging.dart` exists and was generated with `flutterfire configure --project=<your-staging-id>`.

**`make run-staging` has empty `--dart-define` values at runtime.**
Run `fvm flutter clean` first. `String.fromEnvironment` is a compile-time constant, so stale build cache can hold old (empty) values.

**Google Sign-In fails on Android.**
Add your debug SHA-1 to the Firebase Android app: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`. Paste the SHA-1 into Firebase Console, then re-download `google-services.json`.

**Apple Sign-In returns `invalid-credential` for returning users.**
Do not remove `authorizationCode` from the `OAuthProvider.credential()` call. It is required for Firebase to complete the server-side token exchange during link operations.

**Analytics or Sentry events are not showing up.**
Check for a local network ad-blocker (Pi-hole, NextDNS, etc.) blocking analytics domains. Add PostHog and Sentry domains to your allowlist, or test on a different network.

**I want to remove a bottom nav tab.**
Delete the screen file, remove its `StatefulShellBranch` from `app_router.dart`, remove its `NavigationDestination` from `main_scaffold.dart`, then delete the feature directory.

**I want to remove PostHog or Sentry after scaffolding.**
Remove the package from `pubspec.yaml`. For PostHog, replace `PostHogAnalyticsRepository` with a no-op stub that implements `AnalyticsRepository`, or delete the interface and all call sites. For Sentry, remove the `Sentry.captureException` block from `AppLogger` and the `SentryNavigatorObserver` from `app_router.dart`.

**Code generation fails.**
Delete `.dart_tool/` and re-run `make codegen`. If it still fails, look for syntax errors in your `@freezed` or `@riverpod` annotated files. A malformed annotation will break the whole run without a clear error message.

**How do I add push notifications?**
If you included notifications at scaffold time, the app already has local notification plumbing, a reminder preference in Settings, and timezone re-sync support. What is still left is app-specific payload routing and any remote push setup. For remote push, add `firebase_messaging`, configure APNs, and extend the generated notification service.
