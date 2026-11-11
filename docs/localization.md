# Localization

The app ships English (`en`, template and fallback) and Vietnamese (`vi`) using Flutter `gen-l10n`.

## Layout

- `l10n.yaml`: config (`arb-dir: lib/l10n`, template `app_en.arb`, output `lib/l10n/generated/`).
- `lib/l10n/app_en.arb` (template) and `lib/l10n/app_vi.arb`: both always have identical keys and placeholders.
- `lib/l10n/generated/`: generated, gitignored, excluded from analysis. `make codegen` and `make setup` run `fvm flutter gen-l10n` before `build_runner`.
- `lib/core/l10n/`: `resolveAppLocale`, `LocaleNotifier` / `localeProvider` (keepAlive, SharedPreferences key `locale_code`), `appLocalizationsProvider`, and the `context.l10n` extension.

## Using strings

In widgets: `context.l10n.settingsTitle`. Outside the widget tree (notifications, services), read `ref.read(appLocalizationsProvider)`. Never hardcode user-facing text.

## Adding a key

1. Add the key to `app_en.arb` with an `@key` entry that has a `description`. Placeholders must declare `type`. Use ICU plurals for counts.
2. Add the same key (and same placeholder names) to every other ARB.
3. Run `make codegen`, then `make check-l10n`.

Naming: `<area><Thing>` in lowerCamelCase.

| Prefix | Use |
| --- | --- |
| `common*` | Shared by several features (`commonCancel`, `commonConfirm`) |
| `notifications*`, `ads*`, `apple*`, `google*`, `anon*` | Used only inside that optional feature's marker blocks |
| other areas (`settings*`, `onboarding*`, `home*`, ...) | One screen or feature |

A feature prefix is the feature name followed by an uppercase letter.
<!-- BEGIN_BLUEPRINT -->
`tool/init.dart --no-<feature>` removes every key (and its `@key`) with that feature's prefix from all ARB files, because JSON cannot hold `BEGIN_<NAME>` / `END_<NAME>` markers.
<!-- END_BLUEPRINT -->
Keep the string read inside the same marker block it was in, so stripped builds still analyze.

`appTitle` (`Blueprint App`) and `appDescription` (`A Flutter + Firebase starter app`) are untranslated in every ARB.
<!-- BEGIN_BLUEPRINT -->
`init --title` / `--description` rename them in all `.arb` files. After `init --description`, translate `appDescription` in the non-English ARBs.
<!-- END_BLUEPRINT -->

## Adding a language

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb`, set `@@locale`, translate every value (including `languageNativeName`, the language's own name, shown in the picker).
2. Add the code to `CFBundleLocalizations` in `ios/Runner/Info.plist`. Every shipped locale must be listed.
3. Run `make codegen` and `make check-l10n`.

`make check-l10n` (`scripts/check_l10n.dart`, part of release checks and CI) fails on missing or extra keys and on placeholder mismatches.

## Language choice

Settings > Appearance > Language offers System plus each supported locale. "System" matches the device language by language code (`vi_VN` resolves to `vi`) and falls back to `en`. The choice is stored in SharedPreferences (`locale_code`) and is not reset on sign-out or account deletion.

Notifications use translated strings. The background timezone isolate (`lib/core/services/timezone_sync_service.dart`) has no provider scope, so it resolves the language from the `locale_code` preference.

## Server use

The choice is also written to Firestore `users/{uid}.preferences.languageCode` (nullable string, `null` for System). The app never reads it back; it exists so Cloud Functions or other server code can pick the user's language for push messages and emails.
