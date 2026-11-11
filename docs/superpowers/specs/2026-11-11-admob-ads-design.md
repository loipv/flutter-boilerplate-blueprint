# Google AdMob Ads Design

Date: 2026-11-11
Status: approved in conversation, pending written-spec review

## 1. Goal

The blueprint ships Google AdMob as an optional feature. A new app gets banner, interstitial, rewarded and app open ads, GDPR/ATT consent, and four independent ways to turn ads off, without writing any ads plumbing.

### Success criteria

1. Ads can be turned off at four levels, and each one works without the others:
   1. **Init:** `dart tool/init.dart --no-ads` removes the feature, the package and its platform config.
   2. **Build:** `ADS_ENABLED=false` in `.env.<flavor>` stops the SDK from initializing and the consent form from showing.
   3. **Remote Config:** `ConfigKeys.adsEnabled` (master) and one key per format turn ads off from the Firebase Console in the running session.
   4. **User:** overriding `adFreeProvider` to `true` (e.g. after a "remove ads" purchase) hides every ad.
2. No ad loads until UMP reports `canRequestAds`. EEA/UK users see the GDPR form; iOS users see the IDFA explainer and ATT prompt when it is set up in AdMob. Settings shows "Privacy options" when UMP requires it.
3. Cold start never waits on ads, and an ads failure never stops the app or throws past the data layer.
4. Staging and non-release builds always use Google's test ad unit IDs.
5. A production build with `ADS_ENABLED=true` fails the release checks when an App ID is still Google's sample ID or an ad unit ID is a test ID. An empty production ad unit ID only warns, and that format stays off on that platform.
6. A fresh clone runs with ads on (sample App IDs, test unit IDs) after `make setup`.
7. `make analyze`, `make check-test-layout` and `make coverage` pass. `tool/verify_init.sh` passes with defaults, `--no-ads`, and `--no-ads --no-remote-config`.

## 2. Decisions

| # | Decision | Chosen |
|---|---|---|
| D1 | Place in the blueprint | Feature module `lib/features/ads/` with domain, data, application and presentation layers. Optional init feature `ads`, marker `ADS`. With the feature off, the whole folder is deleted (the `notifications` pattern), not stubbed. |
| D2 | SDK confinement | `google_mobile_ads` is imported only in `lib/features/ads/data/`. The banner reaches presentation as a `Widget` inside a domain `AdBannerHandle`, so presentation never imports the SDK. The ads domain therefore imports `package:flutter/widgets.dart` for the `Widget` type. |
| D3 | Formats | Anchored adaptive banner, interstitial, rewarded, app open. |
| D4 | On/off levels | Build flag && Remote Config master && Remote Config per format && !`adFree` && consent. Combined in `adsEnabledProvider(AdFormat)`. |
| D5 | Per-user ad-free source | `adFreeProvider`, a hook that returns `false`. Apps override it. No Firestore field, no in-app purchase. |
| D6 | Consent | UMP before the first ad request. ATT is shown by UMP's IDFA explainer. A Settings tile opens the privacy options form when UMP requires it. |
| D7 | When ads start | When `MainScaffold` first builds, i.e. after splash, auth and onboarding. Not in `main.dart`. |
| D8 | Demo placement | One banner at the bottom of `HomeScreen`, and app open on resume. Interstitial and rewarded ship as API plus docs, not wired into any flow. |
| D9 | Ad unit IDs | Eight `.env` variables (format × platform). Staging and non-release builds always use Google's test IDs. |
| D10 | App IDs | Committed in native config per flavor (they are not secret). Both flavors default to Google's sample App IDs. |
| D11 | Full-screen pacing | One minimum interval (Remote Config, default 90 s) shared by interstitial and app open. Rewarded is not capped. |
| D12 | Release guard | `scripts/check_ads_config.dart`, run by `release-preflight`, `build-prod-ipa` and `build-prod-aab`. |

## 3. Architecture

```
lib/features/ads/
├── domain/
│   ├── ad_format.dart
│   ├── ad_unit_ids.dart
│   ├── rewarded_outcome.dart
│   ├── ad_banner_handle.dart
│   └── ads_repository.dart
├── data/
│   ├── google_mobile_ads_gateway.dart
│   └── google_mobile_ads_repository.dart
├── application/
│   ├── ad_free_provider.dart
│   ├── ads_consent_controller.dart
│   ├── ads_enabled_provider.dart
│   ├── ad_frequency_cap.dart
│   ├── ads_controller.dart
│   └── app_open_ad_observer.dart
└── presentation/
    ├── ad_banner.dart
    └── ad_privacy_options_tile.dart
```

### 3.1 Domain

**`ad_format.dart`**: `enum AdFormat { banner, interstitial, rewarded, appOpen }`.

**`ad_unit_ids.dart`**: `enum AdPlatform { android, ios }`, the IDs for every format and platform, and Google's published test IDs as constants.

```dart
class AdUnitIds {
  /// Ad unit ID for [format] on [platform], or null when the format has no ID.
  ///
  /// Returns Google's test ID unless [env] is production and [isRelease].
  /// In a production release build, returns the `.env` value, or null when it
  /// is empty.
  static String? resolve({
    required AdFormat format,
    required AdPlatform platform, // android | ios
    required AppEnv env,
    required bool isRelease,
  });
}
```

The `.env` values come from `String.fromEnvironment('ADMOB_<FORMAT>_<PLATFORM>')`.

**`rewarded_outcome.dart`**: `sealed class RewardedOutcome` with three subclasses:

- `RewardEarned(int amount, String type)`;
- `RewardDismissed`: closed before the reward was earned;
- `RewardUnavailable`: disabled, not loaded, or failed to show.

**`ad_banner_handle.dart`**:

```dart
abstract class AdBannerHandle {
  Widget get widget;
  Size get size;
  void dispose();
}
```

**`ads_repository.dart`**: no method throws. Failures are logged and returned as `false`, `null` or `RewardUnavailable`.

```dart
abstract class AdsRepository {
  /// Gathers UMP consent (showing the form if required), then initializes the
  /// SDK when ads may be requested. Returns the resulting [canRequestAds].
  Future<bool> initialize({required bool debugGeographyEea});

  bool get canRequestAds;
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();

  /// Loads an anchored adaptive banner for [width]. Null on failure.
  Future<AdBannerHandle?> loadBanner({required String adUnitId, required double width});

  /// Loads a full-screen ad of [format] into its one-slot cache.
  Future<void> preload(AdFormat format, {required String adUnitId});

  /// Shows the cached ad. False when nothing is cached or showing fails.
  /// Reloads the slot after the ad is dismissed.
  Future<bool> showInterstitial();
  Future<RewardedOutcome> showRewarded();
  Future<bool> showAppOpen();
}
```

`initialize` follows Google's order: `requestConsentInfoUpdate`, then `loadAndShowConsentFormIfRequired`. When `canRequestAds` is already true from an earlier session, `MobileAds.initialize()` starts in parallel and does not wait for the form.

### 3.2 Data

**`google_mobile_ads_gateway.dart`**: a thin class around the SDK's static and singleton calls (`MobileAds.instance`, `ConsentInformation.instance`, `ConsentForm`, `BannerAd`, `InterstitialAd.load`, `RewardedAd.load`, `AppOpenAd.load`). It has no logic, so tests mock it.

**`google_mobile_ads_repository.dart`**: implements `AdsRepository` on top of the gateway.

- Keeps one cached ad per full-screen format and reloads it after dismissal, using the last unit ID.
- Drops a cached app open ad older than 4 hours, following Google's guidance.
- Logs a load failure with code `3` (no fill) as `warning`, and any other error as `error`.
- `@Riverpod(keepAlive: true) AdsRepository adsRepository(Ref ref)` is the provider.

These are the only two files that import `google_mobile_ads`.

### 3.3 Application

**`ad_free_provider.dart`**: `@Riverpod(keepAlive: true) bool adFree(Ref ref) => false;`. The doc comment shows how to override it from a purchase state provider.

**`ads_consent_controller.dart`**: a keepAlive `AsyncNotifier<bool>`. Its state is "may request ads".

- When `ADS_ENABLED` is false, it returns `false` and never touches the repository.
- Otherwise it calls `repository.initialize(debugGeographyEea: …)` and returns the result.
- `debugGeographyEea` is true only when `ADS_DEBUG_GEOGRAPHY=eea` and the build is not a production release.
- `refreshAfterPrivacyOptions()` re-reads `canRequestAds` after the privacy options form closes.

**`ads_enabled_provider.dart`**: `@riverpod bool adsEnabled(Ref ref, AdFormat format)` is true only when all of these hold:

- `bool.fromEnvironment('ADS_ENABLED')` is true;
- `ref.watchConfig(ConfigKeys.adsEnabled)` is true;
- `ref.watchConfig(<per-format key>)` is true;
- `ref.watch(adFreeProvider)` is false;
- `ref.watch(adsConsentControllerProvider).value == true`;
- `AdUnitIds.resolve(...)` for the current platform is not null.

**`ad_frequency_cap.dart`**: pure Dart with an injected clock.

- `canShowFullScreen()` is true once `adsFullScreenMinIntervalSeconds` has passed since the last full-screen ad closed.
- `recordFullScreenClosed()` records that time.

**`ads_controller.dart`**: a keepAlive notifier and the one entry point for app code.

- `Future<bool> maybeShowInterstitial()`: checks enabled and the cap, shows the ad, then records the close.
- `Future<RewardedOutcome> showRewarded()`: checks enabled only, no cap.
- `Future<bool> maybeShowAppOpen()`: checks enabled and the cap. Skips while another full-screen ad is showing, and on the first resume after a full-screen ad closes.
- Preloads interstitial and app open once consent allows ads, for each format that is enabled.

**`app_open_ad_observer.dart`**: a `WidgetsBindingObserver` that calls `maybeShowAppOpen()` on `AppLifecycleState.resumed`. Cold start produces no `resumed` after the shell is up, so app open never shows on cold start.

### 3.4 Presentation

**`ad_banner.dart`**: `AdBanner` is a `ConsumerStatefulWidget`.

- It watches `adsEnabledProvider(AdFormat.banner)`, uses a `LayoutBuilder` for the width, and loads through the repository.
- It renders zero size while loading, while disabled, and after a failure.
- On success it renders `handle.widget` at `handle.size`.
- It disposes the handle on unmount, and when ads turn off.

**`ad_privacy_options_tile.dart`**: a `ListTile` ("Privacy options", Lucide icon). It is shown only when `privacyOptionsRequired`. A tap calls `showPrivacyOptions()` and then `refreshAfterPrivacyOptions()`.

### 3.5 Integration points (inside `ADS` markers)

- `MainScaffold.initState`: after the first frame, read `adsConsentControllerProvider` to start consent. Register `AppOpenAdObserver` and remove it in `dispose`.
- `HomeScreen`: `AdBanner` at the bottom of the body.
- `SettingsScreen`: a "Privacy" section with `AdPrivacyOptionsTile`.
- `ConfigKeys`: six keys, also added to `ConfigKeys.all`:

| Key | Type | Default |
|---|---|---|
| `ads_enabled` | bool | `true` |
| `ads_banner_enabled` | bool | `true` |
| `ads_interstitial_enabled` | bool | `true` |
| `ads_rewarded_enabled` | bool | `true` |
| `ads_app_open_enabled` | bool | `true` |
| `ads_full_screen_min_interval_seconds` | int | `90` |

With `--no-remote-config`, `ConfigKeys` stays and returns these defaults, so the Remote Config level is always on.

## 4. Data flow

```
MainScaffold first build
  → AdsConsentController.build
      ADS_ENABLED false → state false (SDK untouched)
      else → AdsRepository.initialize → UMP (+ ATT via IDFA explainer) → MobileAds.initialize
  → state true → AdsController preloads enabled full-screen formats
  → adsEnabledProvider(banner) true → AdBanner loads → renders

Remote Config update / adFree change / consent change
  → adsEnabledProvider recomputes → AdBanner hides or shows; controller checks on next call

App resumed → AppOpenAdObserver → AdsController.maybeShowAppOpen → cap + flags → repository.showAppOpen
```

## 5. Error handling

- The data layer catches every SDK error and logs it with `AppLogger`. Callers only see `false`, `null` or `RewardUnavailable`.
- Ads do not use the `Failure` union, because no screen reports an ads error to the user.
- A consent error leaves `canRequestAds` as the SDK reports it (usually false). The app runs without ads.

## 6. Environment variables

Added to both `.env.*.example` files inside `# BEGIN_ADS` / `# END_ADS`:

```bash
# Google AdMob. See docs/ads_setup.md.
# false = never initialize the SDK or show the consent form in this flavor.
ADS_ENABLED=true
# Ad unit IDs. Used only by production release builds; every other build uses
# Google's test IDs. Blank = that format is off on that platform.
ADMOB_BANNER_ANDROID=
ADMOB_BANNER_IOS=
ADMOB_INTERSTITIAL_ANDROID=
ADMOB_INTERSTITIAL_IOS=
ADMOB_REWARDED_ANDROID=
ADMOB_REWARDED_IOS=
ADMOB_APP_OPEN_ANDROID=
ADMOB_APP_OPEN_IOS=
```

The staging example also has:

```bash
# Optional. "eea" makes the consent form behave as in the EEA (non-release
# production builds and all staging builds only).
ADS_DEBUG_GEOGRAPHY=
```

## 7. Platform config

**Android**
- `AndroidManifest.xml` gets `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="${admobAppId}"/>` in `ADS` markers.
- `build.gradle.kts` sets `manifestPlaceholders["admobAppId"]` in each flavor, in `ADS` markers. Both default to `ca-app-pub-3940256099942544~3347511713`.
- The SDK merges the `AD_ID` permission itself.

**iOS**
- `Info.plist` gets, in `ADS` markers:
  - `GADApplicationIdentifier = $(ADMOB_APP_ID)`;
  - `NSUserTrackingUsageDescription`;
  - Google's `SKAdNetworkItems` list.
- `project.pbxproj` sets the build setting `ADMOB_APP_ID` on the Runner target's six configurations. Both flavors default to `ca-app-pub-3940256099942544~1458002511`.
- The pbxproj has no markers, because Xcode rewrites the file and drops comments.
- The deployment target (16.0) already meets the SDK's minimum.
- The app's `PrivacyInfo.xcprivacy` is unchanged, because the SDK ships its own privacy manifest. Verify this during implementation; if the SDK's manifest turns out not to be enough, add the entries the app's manifest needs and document them.

## 8. Init integration

- `Feature.ads`, flag `--no-ads`, label "Google AdMob ads", usage line `--no-ads  Remove Google AdMob ads`.
- `featureRules[Feature.ads] = FeatureRule(markers: ['ADS'], paths: [...])`. The paths are:
  - `lib/features/ads`
  - `test/features/ads`
  - `scripts/check_ads_config.dart`
  - `test/scripts/check_ads_config_test.dart`
  - `docs/ads_setup.md`
- If a single `ADS` marker cannot cover an imports block and a body block in the same file, add `ADS_IMPORTS`, following `NOTIFICATIONS_IMPORTS`.
- A dedicated step, like `dropFunctions` for `firebase.json`, removes every `ADMOB_APP_ID = …;` line from `ios/Runner.xcodeproj/project.pbxproj` when ads are off. It runs only when the feature is disabled and is covered by `test/tool/plan_test.dart`.

## 9. Release guard

`scripts/check_ads_config.dart` reads `.env.production`, `android/app/build.gradle.kts` and `ios/Runner.xcodeproj/project.pbxproj`. It exits 0 at once when `ADS_ENABLED` is not `true`. Otherwise:

| Case | Result |
|---|---|
| Production App ID (Android or iOS) is Google's sample ID | fail, exit 1 |
| A production ad unit ID is a Google test ID | fail, exit 1 |
| A production ad unit ID is blank | warning; the format is off on that platform |
| All four IDs of one platform are blank | warning, suggesting `ADS_ENABLED=false` |

The parsing and the checks are pure functions, tested in `test/scripts/check_ads_config_test.dart` like the existing scripts. The Makefile calls the script in `release-preflight`, `build-prod-ipa` and `build-prod-aab`, inside `ADS` markers.

## 10. Dependencies

`google_mobile_ads` (latest stable, which bundles UMP), in `pubspec.yaml` inside `# BEGIN_ADS` / `# END_ADS`.

## 11. Testing

TDD with Mocktail. Each test file mirrors a source file.

**Pure Dart**
- `ad_unit_ids_test`: test IDs for staging and for non-release production builds; `.env` IDs for production release builds; blank gives null.
- `ad_frequency_cap_test`: the interval is respected, read from Remote Config, and timed with an injected clock.

**Providers** (`ProviderContainer`, `MockAdsRepository`, overridden `remoteConfigRepositoryProvider`)
- `ads_enabled_provider_test`: the combinations of build flag, RC master, RC per format, `adFree`, consent and unit ID. Bumping the Remote Config revision recomputes the result.
- `ads_consent_controller_test`: the flag off never calls `initialize`; an `initialize` failure leaves the state at `false`.
- `ads_controller_test`: interstitial respects enabled and the cap; rewarded is not capped; app open is skipped while a full-screen ad shows and on the resume right after one.
- `app_open_ad_observer_test`: only `resumed` triggers.

**Data**
- `google_mobile_ads_repository_test` with a mocked `GoogleMobileAdsGateway`:
  - load errors map to `null` / `false` / `RewardUnavailable`;
  - the slot reloads after an ad is dismissed;
  - an app open ad older than 4 hours is discarded;
  - no method throws.
- The gateway has no logic and starts with `// coverage:ignore-file`, so it does not pull the data layer below the 90% gate. `scripts/coverage_gate.dart` reports gated files that have code but are missing from lcov. If it reports the gateway, make the gate skip files that contain `coverage:ignore-file`, and add a case to `test/scripts/coverage_gate_test.dart`.

**Widgets**
- `ad_banner_test`: zero size when disabled or after a failure; renders a fake `handle.widget` on success; disposes on unmount.
- `ad_privacy_options_tile_test`: hidden when not required; a tap calls `showPrivacyOptions`.
- Existing Home, Settings and MainScaffold tests: override the ads providers where needed. `ADS_ENABLED` is undefined in tests, so ads are off by default.

**Init and scripts**
- `test/tool/manifest_test.dart` and `plan_test.dart` cover `Feature.ads` and the pbxproj step.
- `test/scripts/check_ads_config_test.dart` covers every row of the table in section 9.
- `tool/verify_init.sh` must pass with defaults, `--no-ads`, and `--no-ads --no-remote-config`.

**Not automated:** loading real ads on a device. `docs/ads_setup.md` has a manual staging checklist instead.

## 12. Documentation

- New `docs/ads_setup.md`, covering:
  - creating the AdMob apps;
  - App IDs (where they live per flavor) and ad unit IDs;
  - Privacy & messaging: the GDPR message and the IDFA explainer;
  - `app-ads.txt`;
  - Play Console "Contains ads" and Data safety;
  - App Store privacy labels;
  - testing the EEA flow with `ADS_DEBUG_GEOGRAPHY`;
  - overriding `adFreeProvider`;
  - examples of interstitial and rewarded calls;
  - the manual test checklist.
- AGENTS.md (in `ADS` markers):
  - `google_mobile_ads` may be imported only in `features/ads/data/`;
  - add `AdsRepository`, `AdsConsentController`, `AdsController` and `AdFree` to the keepAlive list;
  - add `features/ads/` to the directory tree.
- `docs/tech.md`: package and directory entries.
- `docs/setup.md`: the env variables.
- `docs/release_guide.md`: the ads checklist and the release guard.
- `README.md`: init table row for `--no-ads`.
- `tool/app_readme.md`: a pointer to `docs/ads_setup.md`.
- `CHANGELOG.md`: an entry under Unreleased.
- CLAUDE.md's "Also Read When Relevant" list: `docs/ads_setup.md`.

## 13. Out of scope

- In-app purchases and a real "remove ads" store integration (only the `adFreeProvider` hook).
- Native ads, rewarded interstitial, and mediation adapters.
- Analytics events for ad impressions and revenue (apps can add them in `AdsController` later).
- Showing app open on cold start.
- Placing interstitial or rewarded ads in any blueprint flow.
- Automated tests against the real SDK.
