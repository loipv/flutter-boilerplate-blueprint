# Localization (Multi-Language) Design

Date: 2026-11-11
Status: approved in conversation, pending written-spec review

## 1. Goal

The blueprint ships localization as a core, always-on capability. An app generated from it has every user-facing string in ARB files, ships English and Vietnamese, follows the device language by default, and lets the user pick a language in Settings. Adding a language means adding one ARB file and one `Info.plist` entry, with no Dart changes.

### Success criteria

1. Every user-facing string in `lib/` comes from `AppLocalizations`. No hardcoded UI string remains in presentation code, `authFailureMessage` or notification content.
2. `app_en.arb` (template) and `app_vi.arb` ship with identical keys and full translations.
3. With no choice saved, the app shows the first device locale it supports, else English.
4. Settings → Appearance has a Language tile listing "System" plus every supported locale, each shown in its own language. A change applies immediately, persists across restarts, and is written to `users/{uid}.preferences.languageCode`.
5. Daily reminder notifications use the active app language and are rescheduled when it changes.
6. `scripts/check_l10n.dart` fails when any ARB file's keys or placeholders differ from the template. It runs in `release-preflight`, the `build-prod-*` targets and CI.
7. `dart tool/init.dart --no-<feature>` removes that feature's ARB keys. `--title` renames the app title in the ARB files.
8. `make analyze`, `make check-test-layout` and `make coverage` pass. `tool/verify_init.sh` passes for every flag set in the `blueprint.yml` matrix.

## 2. Decisions

| # | Decision | Chosen |
|---|---|---|
| D1 | Library | Flutter `gen-l10n` (ARB + `flutter_localizations` + `intl`). Rejected: `slang` (third-party, global `t` state outside Riverpod), `easy_localization` (string keys, runtime-only errors). |
| D2 | Optional or core | Core, always on. No `--no-l10n` init flag: once strings are extracted they cannot be stripped back out with markers. A single-language app deletes `app_vi.arb`. |
| D3 | Shipped locales | `en` (template, fallback) and `vi`. |
| D4 | Generated code | Output to `lib/l10n/generated/`, gitignored like `*.g.dart`. `make codegen` and `make setup` run `fvm flutter gen-l10n`. |
| D5 | Source of truth | SharedPreferences via `LocaleNotifier`, mirroring `ThemeNotifier`. `null` means follow the system. |
| D6 | Firestore | Settings also writes `preferences.languageCode` (nullable string), mirroring `updateThemeMode`. It is never read back to drive the UI. It exists so server code (Cloud Functions, push) knows the user's language. |
| D7 | Sign-out / delete account | The language is **not** reset (unlike theme). It belongs to the person holding the device. |
| D8 | Where the user chooses | Settings only, as a `DropdownButton` tile in Appearance next to `_ThemeTile`. Onboarding is unchanged. |
| D9 | Language names | Each ARB defines `languageNativeName` ("English", "Tiếng Việt"). The picker reads it via `lookupAppLocalizations(locale)`, so the list comes from `AppLocalizations.supportedLocales`. |
| D10 | Strings outside the widget tree | `appLocalizationsProvider` returns `AppLocalizations` for the resolved locale without a `BuildContext`. |
| D11 | Android per-app language (`localeConfig`) | Not added. Two places to pick a language would conflict. |
| D12 | iOS | `CFBundleLocalizations` in `ios/Runner/Info.plist` lists `en` and `vi`. Without it iOS does not report `vi` to the app. |
| D13 | Feature-specific keys | Keys used only by an optional feature start with that feature's prefix. Init removes them (and their `@` metadata) from every ARB when the feature is turned off. |

## 3. Architecture

```
l10n.yaml
lib/
├── l10n/
│   ├── app_en.arb              # template
│   ├── app_vi.arb
│   └── generated/              # gitignored, from gen-l10n
│       └── app_localizations*.dart
└── core/
    └── l10n/
        ├── l10n_extension.dart
        ├── resolve_app_locale.dart
        ├── locale_provider.dart
        └── app_localizations_provider.dart
scripts/check_l10n.dart
docs/localization.md
```

### 3.1 Configuration

**`l10n.yaml`**:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-dir: lib/l10n/generated
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

**`pubspec.yaml`**: add `flutter_localizations: { sdk: flutter }` under dependencies and `generate: true` under `flutter:`. `intl` is already present.

**`.gitignore`**: add `lib/l10n/generated/`.

**`Makefile`**: `codegen` and `setup` run `$(FLUTTER) gen-l10n` before `build_runner`. Add a `check-l10n` target (`dart scripts/check_l10n.dart`) and append it to `RELEASE_CHECKS`, outside any feature marker.

### 3.2 Core l10n units

**`l10n_extension.dart`**

```dart
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

**`resolve_app_locale.dart`**: a pure function, the only place locale resolution happens.

```dart
/// Locale the app renders in.
///
/// Returns [chosen] when it is supported; otherwise the first of [system]
/// whose languageCode is supported; otherwise English.
Locale resolveAppLocale(
  Locale? chosen,
  List<Locale> system, {
  List<Locale> supported = AppLocalizations.supportedLocales,
});
```

Matching is by `languageCode`. An unsupported `chosen` (e.g. a removed language left in prefs) is ignored.

**`locale_provider.dart`**: `@Riverpod(keepAlive: true) class LocaleNotifier`, shaped like `ThemeNotifier`.

- `build()` reads `prefs.getString('locale_code')`. Returns `null` when absent. When present but unsupported, logs a warning and returns `null`.
- `setLocale(Locale? locale)` sets state, then writes the code, or removes the key when `locale` is null.
- No `resetToSystem` (D7).

**`app_localizations_provider.dart`**

```dart
@riverpod
AppLocalizations appLocalizations(Ref ref) {
  final chosen = ref.watch(localeProvider).value;
  final system = WidgetsBinding.instance.platformDispatcher.locales;
  return lookupAppLocalizations(resolveAppLocale(chosen, system));
}
```

### 3.3 Changes to existing code

**`lib/app.dart`** (`MaterialApp.router`):

- `locale: ref.watch(localeProvider).value` (null while loading or when following the system).
- `localizationsDelegates: AppLocalizations.localizationsDelegates`
- `supportedLocales: AppLocalizations.supportedLocales`
- `localeListResolutionCallback: (system, supported) => resolveAppLocale(null, system ?? const [], supported: supported.toList())`
- `onGenerateTitle: (context) => context.l10n.appTitle` replaces `title:`.

**`UserPreferences`**: add `String? languageCode` (no default; null means system). Old documents without the field deserialize to null.

**`SettingsController.updateLanguage(String? languageCode)`**: same shape as `updateThemeMode`: read existing preferences, `copyWith(languageCode:)`, `savePreferences`, log.

**`SettingsScreen`**: `_LanguageTile` in Appearance after `_ThemeTile`. `leading: Icon(LucideIcons.languages)`, title `l10n.settingsLanguage`, trailing `DropdownButton<Locale?>` with `null → l10n.settingsLanguageSystem` and one item per `AppLocalizations.supportedLocales` labelled `lookupAppLocalizations(locale).languageNativeName`. `onChanged` calls `localeProvider.notifier.setLocale(locale)` and `settingsController.updateLanguage(locale?.languageCode)`.

**String extraction**: every hardcoded user-facing string in `lib/` moves to ARB. Files with strings today: `settings_screen.dart`, `login_prompt_view.dart`, `theme_selection_view.dart`, `profile_screen.dart`, `intro_view.dart`, `home_screen.dart`, `explore_screen.dart`, `auth_button.dart`, `auth_failure_message.dart`, `main_scaffold.dart`, `ad_privacy_options_tile.dart`, `app_snack_bar.dart`, `notification_service.dart`. Log messages, analytics event names, Firestore keys and payload strings stay in code.

- `authFailureMessage(Failure, {required SignInMethod method, required AppLocalizations l10n})`.
- `_SectionHeader`, `_AccountSummaryTile` and other private widgets read `context.l10n`.
- Time formatting keeps using `MaterialLocalizations` / `TimeOfDay.format`, which now follows the app locale.

**Notifications** (inside `NOTIFICATIONS` markers):

- `NotificationService.scheduleDailyNotification` takes `title`, `body`, `channelName` and `channelDescription` as required parameters; it no longer has English defaults.
- `NotificationScheduler` reads `appLocalizationsProvider` when scheduling and also `ref.listen(appLocalizationsProvider, …)`: when the language changes and a reminder time is set, it reschedules with the new strings.
- `TimezoneLifecycleObserver` gets a `getL10n` callback (like `getPrefs`) for its reschedule path; `app.dart` passes `() => ref.read(appLocalizationsProvider)`.

**iOS**: `ios/Runner/Info.plist` gains

```xml
<key>CFBundleLocalizations</key>
<array>
  <string>en</string>
  <string>vi</string>
</array>
```

## 4. ARB conventions

- Key format: `<area><Thing>` in lowerCamelCase, e.g. `settingsLanguage`, `onboardingIntroHeadline`, `commonCancel`. `common*` for strings shared across features.
- Every key in `app_en.arb` has an `@key` entry with a `description` for translators. Placeholders declare their type.
- Plurals and selects use ICU syntax.
- `appTitle` is "Blueprint App" in every ARB (brand names are not translated).
- `languageNativeName` exists in every ARB.
- **Feature prefixes (D13).** A key used only inside one optional feature's markers starts with:

| Feature | Prefix |
|---|---|
| notifications | `notifications` |
| ads | `ads` |
| apple | `apple` |
| google | `google` |
| anon | `anon` |

Keys shared by more than one feature (e.g. "Try Apple instead" in an account-collision message that exists when either provider is on) use a non-feature prefix such as `auth` and remain after init.

## 5. Guardrails

**`scripts/check_l10n.dart`**: reads `l10n.yaml` for `arb-dir` and the template, then for every other `app_*.arb`:

- reports keys missing from it and keys not in the template (ignoring `@`-keys and `@@locale`);
- reports placeholder names that differ from the template's for the same key.

Exits 1 with one line per problem, 0 with `l10n OK (<n> locales, <m> keys)`. Pure functions (`compareArb(template, other)`) are separated from I/O so `test/scripts/check_l10n_test.dart` covers them.

**`AGENTS.md`**: add to forbidden patterns: "❌ Hardcoded user-facing strings: use `context.l10n.<key>` (or `appLocalizationsProvider` outside the widget tree); add keys to `lib/l10n/app_en.arb` and every other ARB". Add `l10n/` to the directory tree and `LocaleNotifier` to the keepAlive list.

## 6. Init tool

- **`tool/src/manifest.dart`**: add `.arb` to `textExtensions`, so the title rename reaches `appTitle`. Add `arbKeyPrefixes` to `FeatureRule` and set it per the table in section 4.
- **`tool/src/plan.dart`**: for each removed feature, rewrite every `lib/l10n/*.arb`: drop each key starting with one of its prefixes and the matching `@key`. Preserve key order and 2-space JSON indentation. A malformed ARB is an `InitFailure` (exit 1).
- **`test/tool/`**: tests for the `.arb` rename and for prefix stripping (key and `@key` removed, other keys untouched, order kept).
- **`tool/verify_init.sh`**: after init, for each `--no-<feature>` flag passed, fail if any ARB still has a key with that feature's prefix. `make setup` then regenerates l10n, and `analyze` catches any stripped key still used outside markers.

## 7. Testing

- **`test/helpers/pump_app.dart`** and `test/app_test.dart`: add `localizationsDelegates`, `supportedLocales` and `locale: const Locale('en')`, so existing `find.text` assertions keep passing.
- **`integration_test/app_flow_test.dart`**: pin English by overriding `localeProvider` (or seeding prefs with `en`), so a simulator set to Vietnamese does not break it.
- New tests (one per source file, Given-When-Then):
  - `test/core/l10n/resolve_app_locale_test.dart`: chosen supported; chosen unsupported; system match by language code (`vi_VN` → `vi`); no system match → `en`; empty system list → `en`.
  - `test/core/l10n/locale_provider_test.dart`: empty prefs → null; stored `vi` → `Locale('vi')`; stored unsupported → null; `setLocale` writes and removes.
  - `test/core/l10n/app_localizations_provider_test.dart`: chosen `vi` → Vietnamese strings.
  - `test/core/l10n/l10n_extension_test.dart`.
  - New `test/features/settings/presentation/settings_screen_test.dart`: selecting Tiếng Việt switches visible strings and calls both notifiers.
  - `settings_controller_test.dart` (existing): `updateLanguage` writes `languageCode`, and null.
  - `notification_scheduler_test.dart` (existing): language change with a reminder set reschedules with translated strings; without a reminder, nothing is scheduled.
  - `user_preferences_test.dart` (existing): `languageCode` round-trips; missing field → null.
  - `auth_failure_message_test.dart` (existing): passes `l10n` and asserts translated messages.
  - `test/scripts/check_l10n_test.dart`.
  - `notification_service.dart` and `timezone_lifecycle_observer.dart` have no tests today and are outside the coverage gate; their new parameters are exercised through `notification_scheduler_test.dart`.
- **Coverage gate**: in `scripts/coverage_gate.dart`, add `lib/core/l10n/` to the application group (≥ 80%), with a case in `test/scripts/coverage_gate_test.dart`. `lib/l10n/generated/` is outside every gated group.

## 8. Documentation

- **New `docs/localization.md`**: adding a language (ARB file, `languageNativeName`, `CFBundleLocalizations`, `make codegen`, `make check-l10n`); adding a key (naming, `@description`, placeholders, plurals); feature prefixes; reading strings outside widgets; how the server can use `preferences.languageCode`.
- **`docs/tech.md`**: packages and directory structure.
- **`docs/ui_ux.md`**: Language tile in the Settings spec.
- **`CLAUDE.md`**: `docs/localization.md` under "Also Read When Relevant"; the strings ban in Critical Bans.
- **`CHANGELOG.md`**: an Unreleased entry. The blueprint version bump and tag follow `README.md` as a separate step.

## 9. Out of scope

- RTL layout work (no RTL locale ships).
- Localized native permission prompts (`InfoPlist.strings`) and store listings.
- Reading `preferences.languageCode` back from Firestore or syncing it across devices.
- Translation-service integration (Crowdin, Lokalise).
- A language step in onboarding.
