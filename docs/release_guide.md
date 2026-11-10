# Release Guide

> End-to-end playbook: local QA → beta distribution → App Store / Play Store submission.

## Table of Contents

1. [Overview](#1-overview)
2. [Version Management](#2-version-management)
3. [Release Kickoff Process](#3-release-kickoff-process)
4. [One-Time Setup (First Release Only)](#4-one-time-setup-first-release-only)
5. [Pre-Release QA](#5-pre-release-qa)
6. [Beta Testing](#6-beta-testing)
7. [Store Listing Requirements](#7-store-listing-requirements)
8. [Submitting for Review](#8-submitting-for-review)
9. [Subsequent Releases](#9-subsequent-releases)
10. [Quick Reference Checklists](#10-quick-reference-checklists)

---

## 1. Overview

### Build Modes

| Mode        | Compilation                                              | Use for                                        |
| ----------- | -------------------------------------------------------- | ---------------------------------------------- |
| **Debug**   | JIT, assertions on, hot reload                           | Day-to-day development on simulators/emulators |
| **Profile** | AOT, most debug overhead stripped, profiling hooks kept  | Flutter DevTools performance tracing           |
| **Release** | Fully AOT, all assertions stripped, maximum optimisation | Final QA on device, store submission           |

Never benchmark or performance-test in debug mode. Always do final QA in **release** mode on a **physical device**.

### Flavors

| Flavor       | Entry point                | Firebase project     | Bundle ID                     |
| ------------ | -------------------------- | -------------------- | ----------------------------- |
| `staging`    | `lib/main_staging.dart`    | `<your-app>-staging` | `com.example.yourapp.staging` |
| `production` | `lib/main_production.dart` | `<your-app>-prod`    | `com.example.yourapp`         |

All store submissions use the **production** flavor. The `Makefile` injects `--dart-define=APP_ENV=<flavor>` automatically.

---

## 2. Version Management

### Format

```yaml
# pubspec.yaml
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
# e.g.:
version: 1.2.0+5
```

| Part                 | Android       | iOS                          | Visible to users?            |
| -------------------- | ------------- | ---------------------------- | ---------------------------- |
| `1.2.0` (build name) | `versionName` | `CFBundleShortVersionString` | Yes, shown in store listings |
| `5` (build number)   | `versionCode` | `CFBundleVersion`            | No, internal only            |

Flutter reads both from `pubspec.yaml` and injects them into both platforms automatically.

### When to Bump

| Change type                                    | What to bump  | Example               |
| ---------------------------------------------- | ------------- | --------------------- |
| Bug fix / hotfix                               | PATCH + BUILD | `1.0.0+1` → `1.0.1+2` |
| New feature(s)                                 | MINOR + BUILD | `1.0.1+2` → `1.1.0+3` |
| Breaking redesign                              | MAJOR + BUILD | `1.1.0+3` → `2.0.0+4` |
| Re-upload same version (e.g. TestFlight retry) | BUILD only    | `1.1.0+3` → `1.1.0+4` |

### Platform Rules

**iOS:** Build number must be unique per version string. You can reuse build number 5 across `1.0.0+5` and `1.1.0+5`.

**Android:** `versionCode` must be strictly increasing across **all** tracks (internal, alpha, beta, production). If you upload build 10 to the internal track, your next upload to any track must be 11+.

Safe rule: always increment the build number with every upload.

---

## 3. Release Kickoff Process

Run these steps in order at the start of every release cycle.

### Step 1: Pre-Flight Gate

```bash
dart format .
make release-preflight
```

`make release-preflight` runs `fvm flutter analyze && fvm flutter test`. Do not proceed if formatting would change files or if either command fails.

### Step 2: Bump Version

```bash
make bump-version VERSION=1.2.0 BUILD=5
git add pubspec.yaml
git commit -m "chore(release): bump version to 1.2.0+5"
```

### Step 3: Generate Changelog

```bash
make changelog
# Edit CHANGELOG.md, remove noise commits, and clarify user-facing entries
git add CHANGELOG.md
git commit -m "docs(release): update changelog for 1.2.0"
```

### Step 4: Tag the Release

```bash
make tag-release VERSION=1.2.0
# Push the tag after QA passes:
git push origin v1.2.0
```

### Step 5: Build Release Artifacts

```bash
# iOS, produces build/ios/ipa/*.ipa
make build-prod-ipa

# Android, produces build/app/outputs/bundle/productionRelease/app-production-release.aab
# Also writes obfuscation symbols to build/app/outputs/symbols/
make build-prod-aab
```

The AAB build runs with `--obfuscate --split-debug-info`. Upload the symbol directory alongside your AAB in Play Console for readable crash traces.

### Step 6: Distribute to Beta

See [Beta Testing](#6-beta-testing) for full details.

---

## 4. One-Time Setup (First Release Only)

### iOS

#### 4.1 Apple Developer Program

- Enroll at [developer.apple.com](https://developer.apple.com). Fee: **$99/year**
- Organisation enrollment requires a D-U-N-S number (free, takes 1-5 business days)

#### 4.2 Bundle ID

In the [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list):

1. Identifiers → `+` → App IDs
2. Register your bundle ID (e.g. `com.example.yourapp`)
3. Enable the capabilities your app actually uses. If you scaffolded Apple Sign-In, confirm that capability is enabled for the app ID.

#### 4.3 Distribution Certificate

1. Certificates → `+` → Apple Distribution
2. Generate a CSR from Keychain Access (Certificate Assistant → Request a Certificate)
3. Upload the CSR, download the `.cer`, double-click to install in Keychain
4. One certificate covers all your apps. You only need to do this once per developer account.

#### 4.4 Provisioning Profile

**Xcode automatic signing (recommended):** Open `ios/Runner.xcworkspace` → Runner target → Signing & Capabilities → enable "Automatically manage signing" → select your team. Xcode handles profile creation and renewal.

#### 4.5 App Store Connect App Record

1. [App Store Connect](https://appstoreconnect.apple.com) → My Apps → `+` → New App
2. Platform: iOS, enter your app name, Primary language, Bundle ID, SKU
3. Leave it in "Prepare for Submission". You can use TestFlight without ever publishing.

#### 4.6 App Icon

The 1024×1024 App Store icon must be embedded in the app bundle's asset catalog, not uploaded separately to App Store Connect.

Location: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Requirements:

- 1024 × 1024 px, PNG format
- No transparency (fully opaque)
- No rounded corners (iOS applies its own mask)
- sRGB color space

Missing or incorrect icon causes `ITMS-90704` at upload. The build is rejected before it reaches App Store Connect.

#### 4.7 Privacy Manifest

iOS 17.5+ requires a `PrivacyInfo.xcprivacy` file declaring all API usage reasons. The file must be at `ios/Runner/PrivacyInfo.xcprivacy`.

This template already scaffolds that file. Review it before your first submission and add any additional API reasons your app needs.

Minimum content for this template (SharedPreferences + file access):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>C617.1</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
```

Add more entries if your app uses additional APIs (see [Apple's required reasons API list](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)).

---

### Android

#### 4.8 Google Play Console Account

- Create at [play.google.com/console](https://play.google.com/console). Fee: **$25 one-time**
- Complete your developer profile (public name, contact email, website)

#### 4.9 Upload Keystore and Play App Signing

See **`docs/android_signing.md`** for the full step-by-step guide.

Summary:

1. Generate an upload keystore once, then back it up immediately
2. Configure `android/app/build.gradle.kts` to sign release builds
3. On first Play Console upload, enroll in Play App Signing
4. Register both the upload key and Play signing key SHA fingerprints in Firebase

#### 4.10 App Record in Play Console

1. All apps → Create app
2. Name, default language, app or game, free or paid
3. **Free to Paid cannot be changed after publishing.**

---

## 5. Pre-Release QA

### Run on a Physical Device

Simulators/emulators do not reflect real release performance (JIT vs AOT). Always test on real hardware.

```bash
# Source env vars and run in release mode
set -a && . ./.env.production && set +a && \
fvm flutter run --flavor production -t lib/main_production.dart \
  --release \
  --dart-define=APP_ENV=production \
  --dart-define=POSTHOG_API_KEY=$POSTHOG_API_KEY \
  --dart-define=SENTRY_DSN=$SENTRY_DSN \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID
```

Or use the Makefile shortcut:

```bash
make run-prod-release RELEASE_DEVICE=<device-id>
```

### What to Verify

| Area                 | What to check                                                                                           |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| **Cold start**       | App launches without crash; no white flash before splash                                                |
| **Auth flow**        | Google Sign-In and Apple Sign-In complete end-to-end on a physical device                               |
| **Firebase SHA**     | Google Sign-In succeeds on Android (SHA fingerprints registered in Firebase, see android_signing.md)    |
| **Sentry**           | Trigger a test error; verify it appears in your Sentry project dashboard                                |
| **PostHog**          | Navigate main screens; verify events appear in PostHog (check ad-blockers/Pihole if events are missing) |
| **Dark/light theme** | Both themes render correctly                                                                            |
| **Core user flow**   | Complete the main user journey end-to-end in release mode                                               |

### Profile Mode for Performance Tracing

If you spot jank, use profile mode and Flutter DevTools before switching to release:

```bash
fvm flutter run --flavor production -t lib/main_production.dart --profile \
  --dart-define=APP_ENV=production --dart-define=...
```

---

## 6. Beta Testing

### iOS: TestFlight

You do not need a live App Store listing to use TestFlight. Your app can stay in "Prepare for Submission" indefinitely while distributing via TestFlight.

**Upload a build:**

1. Run `make build-prod-ipa`
2. Open Apple Transporter (free, Mac App Store) → Add IPA → Deliver
3. Wait for processing (~5-10 min). You will get an email when it is ready.

**Internal testers (instant, no review):**

- Up to 100 testers with App Store Connect roles
- In App Store Connect → TestFlight → Internal Testing → Add Testers

**External testers (recommended for early feedback):**

- Up to 10,000 testers. They only need an Apple ID.
- Share via email invite or a **public TestFlight link**
- In App Store Connect → TestFlight → External Testing → Add External Testers

**Review rules for external testing:**

| Scenario                                                   | Review required?                   |
| ---------------------------------------------------------- | ---------------------------------- |
| First build of a new version (e.g. `1.2.0+1`)              | Yes, typically a few hours         |
| Subsequent builds of the **same version** (e.g. `1.2.0+2`) | No, auto-approved after processing |
| Next version number (e.g. `1.3.0+1`)                       | Yes, cycle resets                  |

Iterate freely with `+2`, `+3`, etc. under the same version string without triggering another review.

**Build lifetime:** 90 days. Testers must install a new build after expiry.

---

### Android: Two Options

#### Firebase App Distribution (Friends/Family)

Best for early-stage and non-technical testers.

- Unlimited testers, unlimited builds, free
- Testers install via email invite. No Play Store account is required.
- Works before Play Console setup

```bash
firebase appdistribution:distribute \
  build/app/outputs/bundle/productionRelease/app-production-release.aab \
  --app YOUR_FIREBASE_APP_ID \
  --groups "friends-family" \
  --release-notes "$(head -20 CHANGELOG.md)"
```

#### Google Play Internal Testing Track (Release Candidates)

Best for testing the full Play Store install experience.

- Up to 100 testers (must have a Google account)
- Builds processed in minutes
- Does not require a public listing to be live

Promote to production when ready: Play Console → Internal testing → Promote release → Production (staged rollout available).

---

## 7. Store Listing Requirements

### iOS App Store

| Asset                    | Spec                                                                   | Notes                                     |
| ------------------------ | ---------------------------------------------------------------------- | ----------------------------------------- |
| App icon                 | 1024×1024 PNG, no alpha, **in asset catalog, not uploaded separately** | See §4.6                                  |
| iPhone 6.9" screenshots  | At least 1, up to 10                                                   | Required (iPhone 16 Pro Max)              |
| iPhone 6.5" screenshots  | At least 1, up to 10                                                   | Required (iPhone 14 Plus / 15 Plus)       |
| iPad screenshots         | At least 1, up to 10                                                   | Required only if iPad is supported        |
| App name                 | Max 30 characters                                                      |                                           |
| Subtitle                 | Max 30 characters                                                      |                                           |
| Description              | Max 4000 characters                                                    | First 3 lines shown before "More"         |
| Keywords                 | Max 100 characters, comma-separated                                    |                                           |
| Support URL              | Must be a live URL                                                     | Required                                  |
| Privacy policy URL       | Must be a live URL                                                     | Required                                  |
| Age rating               | Complete questionnaire                                                 | Use the 2025 form with 13+/16+/18+ tiers  |
| Privacy nutrition labels | Declare all data types                                                 | Required, declare auth data and analytics |
| Export compliance        | Answer encryption question                                             | HTTPS = standard encryption, answer yes   |

### Android Play Store

| Asset               | Spec                        | Notes                                            |
| ------------------- | --------------------------- | ------------------------------------------------ |
| App icon            | 512×512 PNG, max 1024 KB    |                                                  |
| Feature graphic     | 1024×500 PNG or JPEG        | Shown at top of store listing                    |
| Phone screenshots   | At least 2, up to 8         | Required                                         |
| Short description   | Max 80 characters           |                                                  |
| Full description    | Max 4000 characters         |                                                  |
| Content rating      | Complete IARC questionnaire | Required, app will be rejected without it        |
| Data safety section | Declare all data collected  | Required, include auth and analytics             |
| Privacy policy URL  | Must be a live URL          | Required                                         |
| Target API level    | Android 15 (API 35)         | Mandatory for all new submissions as of Aug 2025 |

---

## 8. Submitting for Review

### iOS: App Store

#### Step 1: Upload the IPA

**Option A: Apple Transporter (recommended)**

1. Download Transporter (free, Mac App Store)
2. Sign in with the Apple ID tied to your developer account
3. Drop your `.ipa` file → Deliver
4. Wait for the processing email (~10-30 min)

**Option B: `xcrun altool` (CI/CD)**

```bash
# App-specific password (generate at appleid.apple.com)
xcrun altool --upload-app --type ios \
  -f path/to/App.ipa \
  --username your@appleid.com \
  --password "xxxx-xxxx-xxxx-xxxx"

# Or App Store Connect API key (preferred for CI)
xcrun altool --upload-app --type ios \
  -f path/to/App.ipa \
  --apiKey YOUR_KEY_ID \
  --apiIssuer YOUR_ISSUER_ID
```

#### Step 2: Create a New Version in App Store Connect

App Store Connect → My Apps → your app → `+` next to iOS platform → enter version number → Create.

#### Step 3: Fill in Required Metadata

All fields in §7 must be complete. The UI shows red warnings for anything missing.

#### Step 4: Associate the Build

Version page → Build section → `+` → select the processed build → Done.

#### Step 5: Submit for Review

Add for Review → Submit to App Review. Status changes to "Waiting for Review."

**Review time:** First submissions typically 1-3 days. Updates are often approved in hours. Live times at [runway.team/appreviewtimes](https://www.runway.team/appreviewtimes).

**Common rejection reasons:**

- Missing or inaccessible privacy policy URL
- App crashes on reviewer's device (always test release builds on a physical device)
- Privacy nutrition labels incomplete or inaccurate
- Age rating questionnaire not completed
- App icon missing from asset catalog (`ITMS-90704`)
- Missing demo account credentials if the app requires sign-in to reach core features

---

### Android: Google Play

1. Play Console → your app → Production → Create new release
2. Upload `app-production-release.aab` from `build/app/outputs/bundle/productionRelease/`
3. Upload the symbol directory from `build/app/outputs/symbols/` (required for readable crash traces)
4. Write release notes
5. Complete store listing, content rating, data safety, privacy policy
6. Save → Review release → Start rollout

**Rollout options:**

- 100%: all users immediately after approval
- Staged (10% → 50% → 100%): recommended for major releases

**Review time:** First submission typically 3-7 days. Updates usually 1-3 days.

---

## 9. Subsequent Releases

| Task                         | First release | Subsequent releases              |
| ---------------------------- | ------------- | -------------------------------- |
| Apple Developer enrollment   | Required      | Already done                     |
| Distribution certificate     | Create once   | Renew annually (Xcode warns you) |
| App Store Connect app record | Create once   | Already exists                   |
| Play Console account         | Create once   | Already done                     |
| Upload keystore              | Generate once | Already exists, never lose it    |
| Store listing assets         | Full setup    | Only update if something changed |
| Version bump                 | Required      | Required                         |
| Build number increment       | Required      | Required                         |
| Release artifact build       | Required      | Required                         |
| Beta testing                 | Recommended   | Recommended for major changes    |

Short version for updates: **bump version → preflight → build → upload → submit**.

---

## 10. Quick Reference Checklists

### Release Kickoff

```
[ ] dart format . with no pending changes
[ ] make release-preflight, analyze and tests pass
[ ] make bump-version VERSION=x.y.z BUILD=n
[ ] git commit version bump
[ ] make changelog, then edit output and commit CHANGELOG.md
[ ] make tag-release VERSION=x.y.z  (push tag after QA)
[ ] make build-prod-ipa
[ ] make build-prod-aab
[ ] Test release build on physical device (§5)
```

### iOS App Store Submission

```
[ ] Release build tested on physical iPhone in release mode
[ ] Google Sign-In + Apple Sign-In verified end-to-end
[ ] Sentry error reporting verified
[ ] App icon in ios/Runner/Assets.xcassets/AppIcon.appiconset/ (1024x1024, no alpha)
[ ] PrivacyInfo.xcprivacy present and complete
[ ] Screenshots: iPhone 6.9" and 6.5" required
[ ] App name, subtitle, description, keywords filled
[ ] Privacy policy URL set (live URL)
[ ] Support URL set (live URL)
[ ] Privacy nutrition labels completed
[ ] Age rating questionnaire completed (2025 form with 13+/16+/18+ tiers)
[ ] Export compliance answered (HTTPS = standard encryption)
[ ] IPA uploaded via Apple Transporter
[ ] Build finished processing (Apple's email)
[ ] Build associated with version in App Store Connect
[ ] No red warnings in App Store Connect UI
[ ] Submitted for Review
```

### Android Play Store Submission

```
[ ] Release build tested on physical Android device
[ ] Google Sign-In verified (Firebase SHA fingerprints correct, see android_signing.md)
[ ] App icon (512x512 PNG)
[ ] Feature graphic (1024x500)
[ ] At least 2 phone screenshots
[ ] Short + full description filled
[ ] IARC content rating questionnaire completed
[ ] Data safety section completed
[ ] Privacy policy URL set
[ ] Signed AAB built (make build-prod-aab)
[ ] Symbol directory uploaded alongside AAB
[ ] AAB uploaded to Play Console
[ ] Release notes written
[ ] Rolled out (staged or 100%)
```
