# Google AdMob Setup

Ads are an optional init feature. This guide covers going from Google's test ads to real ones. Everything lives in `lib/features/ads/`. Google's own docs: [AdMob Help](https://support.google.com/admob).

Until you finish this guide, the app serves Google's test ads only. `make check-ads-config` blocks a production release that still uses test or sample IDs.

---

## AdMob account and apps

1. Sign in at [admob.google.com](https://admob.google.com) and accept the terms.
2. Add the app twice: once for Android, once for iOS. Use the real package name and bundle id.
3. Staging does not need its own AdMob app. Staging builds always show Google's test ads.
4. Under each app, create the ad units you need: banner, interstitial, rewarded, app open. Skip the formats you will not show.

---

## App IDs

An App ID looks like `ca-app-pub-1234567890123456~1234567890`. It is not secret and lives in native config, not in `.env`.

**Android.** Set `manifestPlaceholders["admobAppId"]` for each flavor in `android/app/build.gradle.kts`. It feeds the `com.google.android.gms.ads.APPLICATION_ID` meta-data in `AndroidManifest.xml`.

**iOS.** Set the build setting `ADMOB_APP_ID` per configuration: Xcode, Runner target, Build Settings, User-Defined. Set it on all six configurations (Debug, Profile, Release for each flavor). `Info.plist` reads it through `GADApplicationIdentifier = $(ADMOB_APP_ID)`.

Both default to Google's sample App IDs. Replace at least the production ones. The release guard fails while production still has a sample ID.

`Info.plist` also holds `SKAdNetworkItems`, a 50-entry snapshot of Google's list. Refresh it from the "SKAdNetwork" step of Google's [iOS quick start](https://developers.google.com/admob/ios/quick-start) before each release.

---

## Ad unit IDs

Ad unit IDs go in `.env.production`:

```bash
ADS_ENABLED=true
ADMOB_BANNER_ANDROID=ca-app-pub-.../...
ADMOB_BANNER_IOS=ca-app-pub-.../...
ADMOB_INTERSTITIAL_ANDROID=
ADMOB_INTERSTITIAL_IOS=
ADMOB_REWARDED_ANDROID=
ADMOB_REWARDED_IOS=
ADMOB_APP_OPEN_ANDROID=
ADMOB_APP_OPEN_IOS=
```

- Only production release builds read these. Staging and every non-release build always use Google's test unit IDs.
- A blank ID turns that format off on that platform.
- Never click your own real ads. Use test ads in development.

---

## Consent: GDPR message and IDFA explainer

The app asks for consent through Google's User Messaging Platform (UMP) before it initializes the SDK.

1. In AdMob: Privacy & messaging. Create a GDPR message (EEA, UK, Switzerland) and publish it for both apps.
2. For iOS, also create an IDFA explainer message. It runs before Apple's App Tracking Transparency prompt.
3. Add a "Privacy options entry point" to the GDPR message. Without it the Settings "Privacy options" tile never shows.
4. `NSUserTrackingUsageDescription` in `Info.plist` is the text of Apple's tracking prompt. Rewrite it for your app.

Users in the EEA can reopen the form from Settings, Privacy options. When `adFreeProvider` is true, the consent form is never shown.

---

## app-ads.txt

`app-ads.txt` proves you own the app and lets advertisers buy it.

1. Publish the developer website URL in the App Store and Play Store listings.
2. In AdMob, open the app's `app-ads.txt` page and copy the line it gives you.
3. Host it at `https://<your-domain>/app-ads.txt` (the root of the developer domain).
4. Wait for AdMob to verify it. This can take days.

---

## Store declarations

**Google Play.** Play Console, App content:
- Ads: answer "Yes, my app contains ads".
- Data safety: declare the data the ads SDK collects (device or other IDs, app interactions, diagnostics). Follow Google's [data disclosure guide](https://support.google.com/admob/answer/10243672).
- Advertising ID: declare that the app uses it for advertising. The SDK merges the `AD_ID` permission itself.

**App Store.** App Store Connect, App Privacy:
- Declare the data used for third-party advertising (identifiers, usage data) as collected and, if you use IDFA, as tracking.
- The SDK ships its own `PrivacyInfo.xcprivacy`, so the app's privacy manifest is unchanged.

These answers are your responsibility and depend on how you configure AdMob.

---

## Turning ads off

**At scaffold time.** `dart run tool/init.dart --no-ads` removes the code, config, dependency and this guide.

**Per build.** Set `ADS_ENABLED=false` in the env file. The SDK is never initialized and the consent form never shows in that flavor.

**Remotely.** With Remote Config, these keys switch ads without a release. All default to on:

| Key                                  | Effect                                                |
| ------------------------------------ | ----------------------------------------------------- |
| `ads_enabled`                        | Master switch for every format                        |
| `ads_banner_enabled`                 | Banners                                               |
| `ads_interstitial_enabled`           | Interstitials                                         |
| `ads_rewarded_enabled`               | Rewarded ads                                          |
| `ads_app_open_enabled`               | App open ads                                          |
| `ads_full_screen_min_interval_seconds` | Minimum seconds between full-screen ads (default 90) |

An app open ad is also blocked for 5 seconds after any full-screen ad closes.

**Per user.** `adFreeProvider` (`lib/features/ads/application/ad_free_provider.dart`) is the hook for "remove ads" purchases. It defaults to false. Override it where you create the `ProviderScope`:

```dart
ProviderScope(
  overrides: [
    adFreeProvider.overrideWith(
      (ref) => ref.watch(purchaseProvider).value?.isPremium ?? false,
    ),
  ],
  child: const App(),
)
```

When it is true, no ad shows and the consent form is skipped.

---

## Showing interstitial and rewarded ads

The blueprint places a banner on Home and registers app open ads in `MainScaffold`. It does not place interstitials or rewarded ads. Call them where your app needs them. Both go through `AdsController`, never throw, and respect the frequency cap.

Interstitial, at a natural break such as finishing a task:

```dart
final shown = await ref.read(adsControllerProvider).maybeShowInterstitial();
// shown is false when no ad was shown (off, capped, not loaded). Carry on either way.
```

Rewarded, when the user opts in for a reward:

```dart
final outcome = await ref.read(adsControllerProvider).showRewarded();
switch (outcome) {
  case RewardEarned(:final amount, :final type):
    // Grant the reward.
  case RewardDismissed():
    // The user closed the ad early. No reward.
  case RewardUnavailable():
    // No ad could be shown. Tell the user to try later.
}
```

App open ads: `AppOpenAdObserver` calls `maybeShowAppOpen()` when the app returns to the foreground. They never show on cold start.

---

## Testing the EEA flow

1. Run a staging build, or a non-release production build.
2. Pass `ADS_DEBUG_GEOGRAPHY=eea` in the env file. The consent form behaves as in the EEA.
3. Reset consent between runs: uninstall the app, or reinstall it.
4. `ADS_DEBUG_GEOGRAPHY` has no effect on production release builds.

---

## Manual test checklist

```
[ ] Staging build shows Google test banner on Home
[ ] First launch shows the consent form (with ADS_DEBUG_GEOGRAPHY=eea)
[ ] Settings shows "Privacy options" after consent; tapping it reopens the form
[ ] iOS: the IDFA explainer, then Apple's tracking prompt, appear in order
[ ] Interstitial: shown once, not again inside the minimum interval
[ ] Rewarded: RewardEarned on completion, RewardDismissed on early close
[ ] App open: shows on return from background, not on cold start, not within 5 s of another full-screen ad
[ ] ADS_ENABLED=false: no ads, no consent form
[ ] adFreeProvider true: no ads, no consent form
[ ] Remote Config ads_enabled=false hides every format
[ ] Production release build: real ads load (use your own device as a test device)
[ ] No ad covers navigation or content
```

---

## Release guard

`make check-ads-config` runs automatically before `release-preflight`, `build-prod-ipa` and `build-prod-aab`. It reads the first existing of `.env.production`, `.env`, plus the App IDs in `build.gradle.kts` and `project.pbxproj`. It exits 0 at once when `ADS_ENABLED` is not `true`. Otherwise:

| Case                                          | Result                                       |
| --------------------------------------------- | -------------------------------------------- |
| A production App ID is Google's sample ID     | fail                                         |
| A production ad unit ID is a Google test ID   | fail                                         |
| The production App ID is missing              | fail                                         |
| An ad unit ID is blank                        | warning, that format is off on that platform |
| All four IDs of one platform are blank        | warning, consider `ADS_ENABLED=false`        |
