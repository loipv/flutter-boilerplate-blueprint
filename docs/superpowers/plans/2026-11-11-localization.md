# Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every user-facing string in the blueprint come from ARB files, ship English and Vietnamese, follow the device language by default, and let the user pick a language in Settings.

**Architecture:**
- Flutter `gen-l10n` generates `AppLocalizations` from `lib/l10n/app_*.arb` into `lib/l10n/generated/` (gitignored).
- `lib/core/l10n/` holds the units:
  - one pure resolver, `resolveAppLocale`;
  - `LocaleNotifier`, which stores the choice in SharedPreferences, mirroring `ThemeNotifier`;
  - `appLocalizationsProvider`, which serves strings outside the widget tree;
  - the `context.l10n` extension.
- Settings writes the choice to Firestore as well, write-only.
- Init strips optional-feature keys from the ARB files by prefix.

**Tech Stack:** Flutter 3.41 (fvm), `flutter_localizations`, `intl` 0.20, Riverpod 3 code-gen, Mocktail.

**Spec:** `docs/superpowers/specs/2026-11-11-localization-design.md`

## Global Constraints

- Commands: use `make` targets, otherwise `fvm flutter` / `fvm dart`. Never bare `flutter`.
- Imports are absolute (`package:blueprint_app/...`). Generated l10n import: `package:blueprint_app/l10n/generated/app_localizations.dart`.
- `AppLogger` for logging, Lucide icons, `Gap(AppSpacing.pX)`, `ConsumerWidget` / `ConsumerStatefulWidget`.
- Test names: `Given ..., When ..., Then ...`; one test file per source file at the mirrored path.
- Run `make codegen` after editing any ARB file or `@riverpod` / `@freezed` file. `make codegen` must run `gen-l10n` **before** `build_runner`.
- Shipped locales: `en` (template, fallback) and `vi`. Both ARB files always have identical keys and placeholders.
- `appTitle` = `Blueprint App` and `appDescription` = `A Flutter + Firebase starter app` in **every** ARB, untranslated (init renames them).
- Key format: `<area><Thing>` lowerCamelCase. Every key in `app_en.arb` has an `@key` with `description`; placeholders declare `type`.
- Feature prefixes: a key used only inside one optional feature's markers starts with `notifications`, `ads`, `apple`, `google` or `anon`, followed by an uppercase letter.
- SharedPreferences key for the language: `locale_code`. Firestore field: `preferences.languageCode` (nullable string).
- The language is **not** reset on sign-out or account deletion.
- Marker blocks stay as they are: a string moved to ARB is still read inside the same `BEGIN_<NAME>` block it was in.
- Both variants must pass `make analyze`: markers kept, and every feature stripped.

## Review Focus

1. **Device language changes while the app runs and no choice is saved.** The UI follows (Flutter does this), and so must reminder text. `_AppState` invalidates `appLocalizationsProvider` in `didChangeLocales`. Test in Task 9.
2. **Device locale with a region or an unsupported language** (`vi_VN`, `fr_FR`, `[fr, vi]`). Match by `languageCode`, take the first supported one, else `en`. Tests in Task 1.
3. **Stored `locale_code` no longer supported** (a language was removed). Follow the system, log a warning, do not crash. Test in Task 3.
4. **Firestore write fails while changing language.** The UI still switches (local is the source of truth) and nothing throws. Test in Task 5.
5. **Vietnamese text is longer than English.** Settings and onboarding must not overflow at 320 px width in `vi`. Tests in Tasks 5 and 6.

---

### Task 1: gen-l10n scaffolding and locale resolver

**Files:**
- Modify: `pubspec.yaml`, `.gitignore`, `analysis_options.yaml`, `Makefile` (`codegen`, `setup`), `ios/Runner/Info.plist`, `scripts/coverage_gate.dart`
- Create: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_vi.arb`, `lib/core/l10n/resolve_app_locale.dart`, `lib/core/l10n/l10n_extension.dart`
- Test: `test/core/l10n/resolve_app_locale_test.dart`, `test/core/l10n/l10n_extension_test.dart`, `test/scripts/coverage_gate_test.dart`

**Interfaces:**
- Produces:
  - `Locale resolveAppLocale(Locale? chosen, List<Locale> system, {List<Locale> supported = AppLocalizations.supportedLocales})`
  - `extension AppLocalizationsX on BuildContext { AppLocalizations get l10n; }`
  - ARB keys `appTitle`, `appDescription`, `languageNativeName`.

- [ ] **Step 1: Configure gen-l10n**
  - `pubspec.yaml`: add `flutter_localizations: { sdk: flutter }` under dependencies (next to `flutter`), and `generate: true` under `flutter:`.
  - `l10n.yaml`: exactly the block in spec §3.1.
  - `.gitignore`: add `lib/l10n/generated/`.
  - `analysis_options.yaml`: add `"lib/l10n/generated/**"` to `analyzer.exclude`. Generated code is excluded like `*.g.dart`.
  - `Makefile`: in `codegen` and `setup`, run `$(FLUTTER) gen-l10n` on the line before `build_runner`.
  - `ios/Runner/Info.plist`: add `CFBundleLocalizations` with `en` and `vi` (spec §3.3).
  - ARB files:

    | key | en | vi |
    |---|---|---|
    | `appTitle` | Blueprint App | Blueprint App |
    | `appDescription` | A Flutter + Firebase starter app | A Flutter + Firebase starter app |
    | `languageNativeName` | English | Tiếng Việt |

    `app_en.arb` starts with `"@@locale": "en"`, `app_vi.arb` with `"@@locale": "vi"`.

  Run: `make codegen`
  Expected: `lib/l10n/generated/app_localizations.dart`, `app_localizations_en.dart` and `app_localizations_vi.dart` exist.

- [ ] **Step 2: Write the failing tests**

`test/core/l10n/resolve_app_locale_test.dart`, `group('resolveAppLocale')`:
- `Given chosen vi, When resolved with system [en], Then Locale('vi')`
- `Given chosen fr (unsupported), When resolved with system [vi_VN], Then Locale('vi')`
- `Given no choice and system [vi_VN], When resolved, Then Locale('vi')`. Assert `languageCode == 'vi'` and the result is one of `supported`.
- `Given no choice and system [fr_FR, vi_VN], When resolved, Then Locale('vi')`
- `Given no choice and system [fr_FR], When resolved, Then Locale('en')`
- `Given no choice and an empty system list, When resolved, Then Locale('en')`
- `Given supported [Locale('en')] and system [vi], When resolved, Then Locale('en')`

`test/core/l10n/l10n_extension_test.dart`:
- `Given a MaterialApp with locale vi, When context.l10n is read, Then languageNativeName is 'Tiếng Việt'`

`test/scripts/coverage_gate_test.dart`, add:
- `Given a core l10n file, When classified, Then it is application`: `layerOf('lib/core/l10n/locale_provider.dart') == Layer.application`
- `Given a generated l10n file, When classified, Then it is null`: `layerOf('lib/l10n/generated/app_localizations.dart')` is null

- [ ] **Step 3: Run the tests to verify they fail**

Run: `fvm flutter test test/core/l10n test/scripts/coverage_gate_test.dart`
Expected: FAIL (missing files, `layerOf` returns null for `lib/core/l10n/`).

- [ ] **Step 4: Implement**
  - `resolve_app_locale.dart`: return a member of `supported`, never the input object, so `vi_VN` resolves to `Locale('vi')`. The fallback is the element of `supported` whose `languageCode == 'en'`, else `supported.first`.
  - `l10n_extension.dart`: `AppLocalizations.of(this)`.
  - `coverage_gate.dart`: add `libPath.startsWith('lib/core/l10n/')` to the application group.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `fvm flutter test test/core/l10n test/scripts/coverage_gate_test.dart && make analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml .gitignore analysis_options.yaml Makefile ios/Runner/Info.plist lib/l10n/*.arb lib/core/l10n scripts/coverage_gate.dart test/core/l10n test/scripts/coverage_gate_test.dart
git commit -m "feat(l10n): add gen-l10n setup and locale resolver"
```

---

### Task 2: ARB parity check

**Files:**
- Create: `scripts/check_l10n.dart`
- Modify: `Makefile` (`check-l10n` target, `RELEASE_CHECKS`, help text), `.github/workflows/ci.yml`
- Test: `test/scripts/check_l10n_test.dart`

**Interfaces:**
- Produces:
  - `List<String> compareArb(Map<String, dynamic> template, Map<String, dynamic> other, {required String locale})`: one human-readable problem per line, empty when they match.
  - `Set<String> placeholdersOf(Map<String, dynamic> arb, String key)`: placeholder names from `@key.placeholders`, falling back to `{name}` tokens parsed from the message when the `@key` is absent (non-template files usually have no metadata).
  - `make check-l10n`

- [ ] **Step 1: Write the failing tests** (`group('compareArb')`, `group('placeholdersOf')`)
  - `Given identical keys, When compared, Then no problems`
  - `Given a key missing from vi, When compared, Then one problem naming the key and 'vi'`
  - `Given an extra key in vi, When compared, Then one problem naming the key`
  - `Given @-keys and @@locale that differ, When compared, Then they are ignored`
  - `Given {time} in en and {thoi_gian} in vi for the same key, When compared, Then one placeholder problem`
  - `Given a plural message, When placeholdersOf runs, Then only the plural argument name is returned`. Use `{count, plural, =1{1 item} other{{count} items}}` and expect `{'count'}`.

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/scripts/check_l10n_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement `scripts/check_l10n.dart`**
  - `main` reads `arb-dir` and `template-arb-file` from `l10n.yaml`. Parse these two `key: value` lines by hand; `scripts/` does not depend on a YAML package.
  - It compares every other `app_*.arb` file. On problems it prints them and exits 1; otherwise it prints `l10n OK (<n> locales, <m> keys)`.
  - Placeholder parsing: take the top-level `{name}` and `{name, plural|select, ...}` tokens. Skip text nested inside ICU branches.
  - `Makefile`: add `check-l10n` (`$(FLUTTER:flutter=dart) scripts/check_l10n.dart`) and `RELEASE_CHECKS += check-l10n` **outside** the ADS block. Add it to `.PHONY` and to the help text.
  - `ci.yml`: change `make check-test-layout coverage` to `make check-l10n check-test-layout coverage`.

- [ ] **Step 4: Verify**

Run: `fvm flutter test test/scripts/check_l10n_test.dart && make check-l10n`
Expected: tests pass; prints `l10n OK (2 locales, 3 keys)`.

- [ ] **Step 5: Commit**

```bash
git add scripts/check_l10n.dart test/scripts/check_l10n_test.dart Makefile .github/workflows/ci.yml
git commit -m "feat(l10n): add ARB parity check to release checks and CI"
```

---

### Task 3: LocaleNotifier and appLocalizationsProvider

**Files:**
- Create: `lib/core/l10n/locale_provider.dart`, `lib/core/l10n/app_localizations_provider.dart`
- Test: `test/core/l10n/locale_provider_test.dart`, `test/core/l10n/app_localizations_provider_test.dart`

**Interfaces:**
- Consumes: `resolveAppLocale` (Task 1), `sharedPreferencesProvider`.
- Produces:
  - `@Riverpod(keepAlive: true) class LocaleNotifier` → `localeProvider` (`AsyncValue<Locale?>`). `Future<Locale?> build()`, `Future<void> setLocale(Locale? locale)`.
  - `@riverpod AppLocalizations appLocalizations(Ref ref)` → `appLocalizationsProvider`.

- [ ] **Step 1: Write the failing tests** (pattern: `test/core/theme/theme_provider_test.dart`)

`locale_provider_test.dart`, `group('localeProvider')`:
- `Given no stored value, When built, Then null`
- `Given stored 'vi', When built, Then Locale('vi')`
- `Given stored 'fr' (unsupported), When built, Then null`
- `Given setLocale(Locale('vi')), When called, Then state is vi and prefs 'locale_code' is 'vi'`
- `Given stored 'vi', When setLocale(null), Then state is null and 'locale_code' is removed`

`app_localizations_provider_test.dart`, `group('appLocalizationsProvider')`:
- `Given stored 'vi', When read, Then languageNativeName is 'Tiếng Việt'` (await `localeProvider.future` first)
- `Given no stored value and the test platform locale en_US, When read, Then languageNativeName is 'English'`
- `Given stored 'en', When setLocale(vi) is called, Then a re-read returns Vietnamese`

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/core/l10n`
Expected: FAIL (missing providers).

- [ ] **Step 3: Implement** both files, then run `make codegen`.
  - `LocaleNotifier`: `static const _storageKey = 'locale_code'` and `static const _log = AppLogger('LocaleNotifier')`. When the stored code is unsupported, log a warning and return null.
  - `appLocalizations`: implement as spec §3.2, i.e. `lookupAppLocalizations(resolveAppLocale(chosen, WidgetsBinding.instance.platformDispatcher.locales))`.

- [ ] **Step 4: Verify**

Run: `fvm flutter test test/core/l10n && make analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n test/core/l10n
git commit -m "feat(l10n): add LocaleNotifier and appLocalizationsProvider"
```

---

### Task 4: Wire localization into the app and test harnesses

**Files:**
- Modify: `lib/app.dart`, `test/helpers/pump_app.dart`, `test/app_test.dart`, `test/core/router/app_router_test.dart`, `test/features/ads/presentation/ad_banner_test.dart`, `test/features/onboarding/presentation/onboarding_scaffold_test.dart`, `integration_test/app_flow_test.dart`
- Test: `test/app_test.dart`

**Interfaces:**
- Consumes: `localeProvider`, `resolveAppLocale`, `context.l10n`.
- Produces: every widget under `App` and under `pumpApp` can call `context.l10n`.

- [ ] **Step 1: Write the failing tests** in `test/app_test.dart` (reuse its existing setup; seed prefs with `SharedPreferences.setMockInitialValues`):
  - `Given stored locale_code 'vi', When App is pumped, Then Localizations.localeOf on HomeScreen is vi`
  - `Given no stored locale and device locales [fr_FR], When App is pumped, Then the locale is en`. Set `tester.platformDispatcher.localesTestValue` and reset it in `addTearDown`.

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/app_test.dart`
Expected: FAIL (locale is `en_US` or delegates missing).

- [ ] **Step 3: Implement**
  - `app.dart`: implement as spec §3.3 (`locale`, `localizationsDelegates`, `supportedLocales`, `localeListResolutionCallback`, `onGenerateTitle` replacing `title`).
  - Test harnesses: every `MaterialApp(` in `test/` and `integration_test/` gets `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: AppLocalizations.supportedLocales` and `locale: const Locale('en')`. That covers `pump_app.dart` and the three test files listed under Files.
  - `integration_test/app_flow_test.dart` `setUp`: after `prefs.clear()`, `await prefs.setString('locale_code', 'en');`.

- [ ] **Step 4: Verify**

Run: `make test && make analyze`
Expected: all pass, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart test integration_test
git commit -m "feat(l10n): wire AppLocalizations into MaterialApp and test harnesses"
```

---

### Task 5: Language preference and Settings tile

**Files:**
- Modify: `lib/features/auth/domain/user_preferences.dart`, `lib/features/settings/application/settings_controller.dart`, `lib/features/settings/presentation/settings_screen.dart`, both ARB files
- Test: `test/features/auth/domain/user_preferences_test.dart`, `test/features/settings/application/settings_controller_test.dart`, create `test/features/settings/presentation/settings_screen_test.dart`

**Interfaces:**
- Consumes: `localeProvider.notifier.setLocale`, `lookupAppLocalizations`, `AppLocalizations.supportedLocales`.
- Produces:
  - `UserPreferences.languageCode` (`String?`);
  - `SettingsController.updateLanguage(String? languageCode)`;
  - `pumpApp(tester, child, {overrides, Locale? locale})`: a non-null `locale` pins it; null follows `localeProvider`, falling back to `en`. Tasks 6–8 use `locale: const Locale('vi')`;
  - ARB keys below.

| key | en | vi |
|---|---|---|
| `settingsLanguage` | Language | Ngôn ngữ |
| `settingsLanguageSystem` | System | Theo hệ thống |

- [ ] **Step 1: Write the failing tests**

`user_preferences_test.dart`:
- `Given languageCode 'vi', When round-tripped through JSON, Then it is preserved`
- `Given JSON without languageCode, When parsed, Then languageCode is null`

`settings_controller_test.dart`, `group('updateLanguage')`, following `updateThemeMode`:
- `Given a signed-in user, When updateLanguage('vi'), Then savePreferences gets UserPreferences(languageCode: 'vi')`
- `Given stored languageCode 'vi' and hapticsEnabled false, When updateLanguage(null), Then languageCode is null and hapticsEnabled stays false`
- `Given savePreferences throws, When updateLanguage('vi'), Then the controller state has an error and nothing throws to the caller`

`settings_screen_test.dart` (new), `group('SettingsScreen')`. Pump with `pumpApp` and override `authRepositoryProvider` and `userRepositoryProvider` with mocks from `test/helpers/mocks.dart` that emit a signed-in user:
- `Given English, When pumped, Then the Language tile shows 'System'`
- `Given the Language dropdown, When 'Tiếng Việt' is selected, Then 'Ngôn ngữ' is shown and prefs 'locale_code' is 'vi' and savePreferences got languageCode 'vi'`
- `Given savePreferences throws, When 'Tiếng Việt' is selected, Then 'Ngôn ngữ' is still shown and no exception is reported` (`tester.takeException()` is null)
- `Given locale vi and a 320x640 surface, When pumped, Then no overflow is reported`. Set `tester.view.physicalSize`, `devicePixelRatio = 1`, and reset both in `addTearDown`.

For the vi cases, build the `MaterialApp` with `locale: ref.watch(localeProvider).value ?? const Locale('en')` inside a `Consumer`, or set `locale_code` in the mock prefs before pumping. Then `pumpApp`'s fixed `en` does not block the switch. Add an optional `Locale? locale` parameter to `pumpApp`, and when it is null read `localeProvider`, falling back to `en`.

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/features/auth/domain test/features/settings`
Expected: FAIL.

- [ ] **Step 3: Implement**
  - `UserPreferences`: add `String? languageCode` and replace the TODO example comment (`@Default('en') String language`) with nothing; the field now exists.
  - `SettingsController.updateLanguage`: same shape as `updateThemeMode`, logging `Language updated to ${languageCode ?? 'system'}`.
  - `settings_screen.dart`: add `_LanguageTile` after `_ThemeTile` as spec §3.3 describes. Labels are `context.l10n.settingsLanguage` / `settingsLanguageSystem`, and each locale shows `lookupAppLocalizations(l).languageNativeName`.
  - Run `make codegen`.

- [ ] **Step 4: Verify**

Run: `fvm flutter test test/features && make check-l10n && make analyze`
Expected: PASS, `l10n OK`, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/domain lib/features/settings lib/l10n test/features test/helpers
git commit -m "feat(l10n): add language preference and Settings language tile"
```

---

### Task 6: Extract strings from the shell and onboarding

**Files:**
- Modify: `lib/core/presentation/main_scaffold.dart`, `lib/features/home/presentation/home_screen.dart`, `lib/features/explore/presentation/explore_screen.dart`, `lib/features/profile/presentation/profile_screen.dart`, `lib/features/onboarding/presentation/intro_view.dart`, `lib/features/onboarding/presentation/theme_selection_view.dart`, both ARB files
- Test: create `test/features/onboarding/presentation/intro_view_test.dart`, `test/features/onboarding/presentation/theme_selection_view_test.dart`

**ARB keys** (the app bar titles of Home/Explore/Profile reuse the `nav*` keys; the Explore headline reuses `navExplore`; Profile's Settings tooltip uses `settingsTitle`):

| key | en | vi |
|---|---|---|
| `navHome` | Home | Trang chủ |
| `navExplore` | Explore | Khám phá |
| `navProfile` | Profile | Hồ sơ |
| `settingsTitle` | Settings | Cài đặt |
| `homeWelcome` | Welcome | Chào mừng |
| `homePlaceholder` | Your home screen content goes here. | Nội dung màn hình chính của bạn sẽ hiển thị ở đây. |
| `explorePlaceholder` | Your explore / discovery content goes here. | Nội dung khám phá của bạn sẽ hiển thị ở đây. |
| `profileLoadError` | Could not load profile. Please try again. | Không thể tải hồ sơ. Vui lòng thử lại. |
| `profileNotSignedIn` | Not signed in | Chưa đăng nhập |
| `authSignOut` | Sign out | Đăng xuất |
| `onboardingIntroHeadline` | Welcome to\n{appName} | Chào mừng đến với\n{appName} |
| `onboardingGetStarted` | Get Started | Bắt đầu |
| `onboardingThemeHeadline` | Choose Your Vibe | Chọn phong cách của bạn |
| `onboardingThemeBody` | Pick a look that feels right. You can change this later. | Chọn giao diện bạn thấy hợp. Bạn có thể đổi lại sau. |
| `onboardingThemeDawn` / `…DawnSubtitle` | Dawn / Light mode | Bình minh / Chế độ sáng |
| `onboardingThemeAuto` / `…AutoSubtitle` | Auto / Follows system | Tự động / Theo hệ thống |
| `onboardingThemeDusk` / `…DuskSubtitle` | Dusk / Dark mode | Hoàng hôn / Chế độ tối |
| `commonConfirm` | Confirm | Xác nhận |

`onboardingIntroHeadline` has placeholder `appName` (String). The intro view passes `context.l10n.appTitle`, and its tagline becomes `context.l10n.appDescription`.

- [ ] **Step 1: Write the failing tests**
  - `intro_view_test.dart`: `Given locale vi, When IntroView is pumped, Then 'Chào mừng đến với\nBlueprint App' and 'Bắt đầu' are shown`
  - `theme_selection_view_test.dart`:
    - `Given locale vi, When pumped, Then 'Chọn phong cách của bạn' is shown`
    - `Given locale vi and a 320x640 surface, When pumped, Then no overflow is reported`

    Override `localeProvider`/prefs as needed; `ThemeSelectionView` reads `themeProvider`.

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/features/onboarding`
Expected: new tests FAIL (English text shown).

- [ ] **Step 3: Replace each literal** with its `context.l10n.<key>`. Remove `const` where a `Text` now reads `l10n`. Text that has the `Blueprint App` brand inline must go through `appTitle`.

- [ ] **Step 4: Verify**

Run: `make test && make check-l10n && make analyze`
Expected: PASS. `integration_test` copy (`Get Started`, `Confirm`, `Profile`) is unchanged in English.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(l10n): localize shell, home, explore, profile and onboarding"
```

---

### Task 7: Extract auth strings, including the application layer

**Files:**
- Modify: `lib/features/auth/presentation/widgets/auth_button.dart`, `lib/features/auth/presentation/auth_failure_message.dart`, `lib/features/onboarding/presentation/login_prompt_view.dart`, `lib/features/auth/application/auth_controller.dart`, both ARB files
- Test: `test/features/auth/presentation/auth_failure_message_test.dart`, `test/features/auth/application/auth_controller_test.dart`, `test/features/onboarding/presentation/login_prompt_view_test.dart`

**Interfaces:**
- Consumes: `appLocalizationsProvider` (Task 3).
- Produces: `String? authFailureMessage(Failure failure, {required SignInMethod method, required AppLocalizations l10n})`.

`deleteAccount()` keeps `Future<String?>` and reads `ref.read(appLocalizationsProvider)` for its messages. This fills a gap in the spec: those strings live in the application layer.

| key | en | vi |
|---|---|---|
| `authSignInFailed` | Sign-in failed. Please try again. | Đăng nhập thất bại. Vui lòng thử lại. |
| `authContinueWithApple` | Continue with Apple | Tiếp tục với Apple |
| `authContinueWithGoogle` | Continue with Google | Tiếp tục với Google |
| `authAppleUnavailable` | Sign in with Apple isn't available on this device. Try Google instead, or continue as a guest. | Đăng nhập bằng Apple không khả dụng trên thiết bị này. Hãy thử Google, hoặc tiếp tục với tư cách khách. |
| `authAppleNonceError` | Apple sign-in ran into a problem. Try again, or use Google instead. | Đăng nhập bằng Apple gặp sự cố. Hãy thử lại hoặc dùng Google. |
| `authEmailInUseTryApple` | An account with this email already exists. Try Apple instead. | Đã có tài khoản dùng email này. Hãy thử đăng nhập bằng Apple. |
| `authEmailInUseTryGoogle` | An account with this email already exists. Try Google instead. | Đã có tài khoản dùng email này. Hãy thử đăng nhập bằng Google. |
| `authDeleteNoUser` | No signed-in user. | Không có người dùng nào đang đăng nhập. |
| `authErrorRetry` | Authentication error. Please try again. | Lỗi xác thực. Vui lòng thử lại. |
| `commonErrorRetry` | Something went wrong. Please try again. | Đã xảy ra lỗi. Vui lòng thử lại. |
| `commonCancel` | Cancel | Hủy |
| `onboardingLoginHeadline` | Create your account | Tạo tài khoản của bạn |
| `onboardingLoginBody` | Sign in to sync your data across devices. You can always skip this and sign in later. | Đăng nhập để đồng bộ dữ liệu giữa các thiết bị. Bạn luôn có thể bỏ qua và đăng nhập sau. |
| `anonContinueAsGuest` | Continue as Guest | Tiếp tục với tư cách khách |
| `anonConfirmTitle` | Continue as Guest? | Tiếp tục với tư cách khách? |
| `anonConfirmBody` | Your data won't sync across devices. You can sign in later from Settings. | Dữ liệu của bạn sẽ không được đồng bộ giữa các thiết bị. Bạn có thể đăng nhập sau trong Cài đặt. |
| `anonConfirmContinue` | Continue | Tiếp tục |

The `anon*` keys are read only inside `ANON` blocks. The anon dialog's Cancel button uses `commonCancel`. `login_prompt_view` reuses `onboardingGetStarted` from Task 6.

- [ ] **Step 1: Update and add tests**
  - `auth_failure_message_test.dart`: pass `l10n: lookupAppLocalizations(const Locale('en'))` to the existing cases, then add `Given l10n vi and code 'apple-unavailable', When mapped, Then the Vietnamese authAppleUnavailable text`.
  - `auth_controller_test.dart`: existing `deleteAccount` expectations stay in English; the test platform locale is `en_US`. Add `Given stored locale_code 'vi' and no user, When deleteAccount, Then 'Không có người dùng nào đang đăng nhập.'`.
  - `login_prompt_view_test.dart`: keep it passing (English through `pumpApp`).

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/features/auth test/features/onboarding`
Expected: FAIL (signature mismatch / English text).

- [ ] **Step 3: Implement.** Replace the literals, add the `l10n` parameter, and pass `context.l10n` from `login_prompt_view.dart` and `settings_screen.dart` (`_linkAccount`). Do not move any `// BEGIN_` / `// END_` line.

- [ ] **Step 4: Verify**

Run: `make test && make check-l10n && make analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(l10n): localize auth buttons, failure messages and login prompt"
```

---

### Task 8: Extract Settings and ads strings

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`, `lib/features/ads/presentation/ad_privacy_options_tile.dart`, both ARB files
- Test: `test/features/settings/presentation/settings_screen_test.dart`, `test/features/ads/presentation/ad_privacy_options_tile_test.dart`

| key | en | vi |
|---|---|---|
| `settingsAppearance` | Appearance | Giao diện |
| `settingsTheme` | Theme | Chủ đề |
| `settingsThemeSystem` / `…Light` / `…Dark` | System / Light / Dark | Theo hệ thống / Sáng / Tối |
| `settingsAccessibility` | Accessibility | Trợ năng |
| `settingsHaptics` | Haptic feedback | Phản hồi rung |
| `settingsAccount` | Account | Tài khoản |
| `settingsSaveProgressTitle` | Save your progress | Lưu tiến trình của bạn |
| `settingsSaveProgressBody` | Link Apple or Google to keep your data across devices. | Liên kết Apple hoặc Google để giữ dữ liệu trên mọi thiết bị. |
| `settingsAccountLinked` | Account linked successfully. | Liên kết tài khoản thành công. |
| `settingsSignOutTitle` | Sign out? | Đăng xuất? |
| `settingsSignOutBody` | You can sign back in at any time. | Bạn có thể đăng nhập lại bất cứ lúc nào. |
| `settingsDeleteAccount` | Delete account | Xóa tài khoản |
| `settingsDeleteAccountTitle` | Delete account? | Xóa tài khoản? |
| `settingsDeleteAccountBody` | This will permanently delete your account and associated data. This cannot be undone. | Thao tác này sẽ xóa vĩnh viễn tài khoản và dữ liệu liên quan. Không thể hoàn tác. |
| `commonDelete` | Delete | Xóa |
| `settingsGuest` | Guest | Khách |
| `settingsGuestSession` | Guest session | Phiên khách |
| `settingsSignedIn` / `…WithApple` / `…WithGoogle` | Signed in / Signed in with Apple / Signed in with Google | Đã đăng nhập / Đã đăng nhập bằng Apple / Đã đăng nhập bằng Google |
| `notificationsSectionTitle` | Reminders | Nhắc nhở |
| `notificationsDailyReminder` | Daily reminder | Nhắc nhở hằng ngày |
| `notificationsOff` | Off | Tắt |
| `notificationsScheduledFor` | Scheduled for {time} | Đã hẹn lúc {time} |
| `notificationsReminderTime` | Reminder time | Giờ nhắc |
| `notificationsPermissionDenied` | Notifications are disabled for this app. Enable them in system settings and try again. | Thông báo đang bị tắt cho ứng dụng này. Hãy bật trong phần cài đặt hệ thống rồi thử lại. |
| `adsPrivacySection` | Privacy | Quyền riêng tư |
| `adsPrivacyOptions` | Privacy options | Tùy chọn quyền riêng tư |
| `adsManageConsent` | Manage ad consent | Quản lý đồng ý quảng cáo |

`notificationsScheduledFor` has placeholder `time` (String). The avatar fallback initial is `settingsGuest.substring(0, 1)`. Sign-out tile and dialog button use `authSignOut`; Cancel uses `commonCancel`.

- [ ] **Step 1: Add tests**
  - `settings_screen_test.dart`: `Given locale vi, When pumped, Then 'Giao diện', 'Trợ năng' and 'Xóa tài khoản' are shown`.
  - Put a `// BEGIN_NOTIFICATIONS` … `// END_NOTIFICATIONS` block around `Given locale vi and a reminder at 08:00, When pumped, Then 'Nhắc nhở hằng ngày' is shown`.
  - `ad_privacy_options_tile_test.dart`: existing English assertions keep passing.

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/features/settings`
Expected: new tests FAIL.

- [ ] **Step 3: Replace the literals**
  - `_SectionHeader('Privacy')` → `_SectionHeader(context.l10n.adsPrivacySection)`, still inside the ADS block.
  - `_AccountSummaryTile` and `_ThemeTile` read `context.l10n`.

- [ ] **Step 4: Verify**

Run: `make test && make check-l10n && make analyze`
Then grep for leftovers:

```bash
grep -rnE "Text\('[A-Z]|label: '[A-Z]|tooltip: '[A-Z]|title: '[A-Z]|subtitle: '[A-Z]" lib --include='*.dart' | grep -v l10n/generated
```

Expected: tests pass, `l10n OK`, no issues; the grep prints nothing.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(l10n): localize Settings and ads privacy tile"
```

---

### Task 9: Localized notifications

**Files:**
- Modify: `lib/core/services/notification_service.dart`, `lib/core/services/timezone_lifecycle_observer.dart`, `lib/features/notifications/application/notification_scheduler.dart`, `lib/app.dart`, both ARB files
- Test: `test/features/notifications/application/notification_scheduler_test.dart`, `test/app_test.dart`

**Interfaces:**
- Consumes: `appLocalizationsProvider`.
- Produces:
  - `NotificationService.scheduleDailyNotification({required TimeOfDay time, required String title, required String body, required String channelName, required String channelDescription, String payload = 'daily_reminder'})`
  - `NotificationService.rescheduleIfTimezoneChanged(SharedPreferences prefs, AppLocalizations l10n)`
  - `TimezoneLifecycleObserver({required NotificationService notificationService, required Future<SharedPreferences> Function() getPrefs, required AppLocalizations Function() getL10n})`

| key | en | vi |
|---|---|---|
| `notificationsDailyTitle` | Reminder | Nhắc nhở |
| `notificationsDailyBody` | Your daily reminder is ready. | Lời nhắc hằng ngày của bạn đã sẵn sàng. |
| `notificationsChannelName` | Daily reminders | Lời nhắc hằng ngày |
| `notificationsChannelDescription` | Recurring reminders for your app | Lời nhắc định kỳ từ ứng dụng |

`AndroidNotificationDetails` is no longer `const`. The channel id `daily_reminder_channel` is unchanged.

- [ ] **Step 1: Write the failing tests**

`notification_scheduler_test.dart`: update the stubs and verifies to match the new named parameters with `any(named: ...)`. Add:
- `Given a reminder at 08:00, When the profile emits it, Then scheduleDailyNotification gets title 'Reminder' and body 'Your daily reminder is ready.'`
- `Given a reminder at 08:00 is set, When localeProvider.setLocale(vi) is called, Then scheduleDailyNotification is called again with title 'Nhắc nhở'`
- `Given no reminder, When localeProvider.setLocale(vi) is called, Then nothing is scheduled`

`app_test.dart`, **outside** any marker block (the observer is general, not notification-specific):
- `Given the app is running with no saved language, When the device locales change to [vi], Then appLocalizationsProvider returns Vietnamese`. Set `tester.platformDispatcher.localesTestValue`, then call `tester.binding.handleLocaleChanged()` and pump. Read via `ProviderScope.containerOf(tester.element(find.byType(HomeScreen)))`.

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/features/notifications test/app_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
  - `NotificationScheduler`: build the four strings from `ref.read(appLocalizationsProvider)` when scheduling. Add `ref.listen(appLocalizationsProvider, …)` that reschedules from the current profile's `notificationTime` when it is set.
  - `rescheduleIfTimezoneChanged`: pass the four strings from `l10n`.
  - `TimezoneLifecycleObserver._syncTimezone`: pass `_getL10n()`.
  - `app.dart`:
    - pass `getL10n: () => ref.read(appLocalizationsProvider)`;
    - `_AppState` mixes in `WidgetsBindingObserver`: register it in `initState`, remove it in `dispose`, and in `didChangeLocales` call `ref.invalidate(appLocalizationsProvider)`.

- [ ] **Step 4: Verify**

Run: `make test && make check-l10n && make analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(l10n): localize daily reminder notifications"
```

---

### Task 10: Init tool support for ARB files

**Files:**
- Modify: `tool/src/manifest.dart`, `tool/src/plan.dart`, `tool/verify_init.sh`
- Test: `test/tool/manifest_test.dart`, `test/tool/plan_test.dart`

**Interfaces:**
- Produces:
  - `FeatureRule.arbKeyPrefixes` (`List<String>`, default `const []`).
  - `String dropArbKeys(String text, List<String> prefixes)` in `plan.dart`, next to `dropFunctions`. It throws `InitFailure` on invalid JSON or a non-object root.

Prefixes: notifications → `['notifications']`, ads → `['ads']`, apple → `['apple']`, google → `['google']`, anon → `['anon']`. A key matches a prefix when it equals the prefix or starts with the prefix followed by an uppercase ASCII letter (`ads` matches `adsPrivacyOptions`, not `address`).

- [ ] **Step 1: Write the failing tests**

`manifest_test.dart`:
- `Given an .arb path, When isTextFile, Then true`
- `Given featureRules, When read, Then ads has arbKeyPrefixes ['ads'] and posthog has none`

`plan_test.dart`, `group('dropArbKeys')`:
- `Given adsPrivacyOptions and @adsPrivacyOptions, When dropped with ['ads'], Then both are gone and other keys remain in their original order`
- `Given a key 'address', When dropped with ['ads'], Then it is kept`
- `Given non-ASCII values, When dropped, Then they are written unescaped with 2-space indentation and a trailing newline`
- `Given invalid JSON, When dropped, Then it throws InitFailure`

Plan-level test (follow the existing temp-dir plan tests): `Given --no-ads, When the plan is built, Then lib/l10n/app_vi.arb in writes has no ads* keys and appTitle is renamed to the new title`.

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/tool`
Expected: FAIL.

- [ ] **Step 3: Implement**
  - `textExtensions` gains `.arb`.
  - In `InitPlan` text loop: when `path` is under `lib/l10n/` and ends with `.arb`, apply `dropArbKeys(text, prefixes of disabled features)` after `renameText`.
  - `dropArbKeys` uses `jsonDecode` and `JsonEncoder.withIndent('  ')`, plus `'\n'`.
  - `verify_init.sh`: for each of `notifications ads apple google anon` whose `--no-<name>` flag was passed, fail when `grep -qE "\"@?<name>[A-Z]" lib/l10n/*.arb` matches. Echo `ARB: <name> keys removed`.

- [ ] **Step 4: Verify**

```bash
make test
tool/verify_init.sh --yes --name blueprint_ci
tool/verify_init.sh --yes --name blueprint_ci --no-notifications --no-posthog --no-sentry --no-functions --no-apple --no-google --no-remote-config --no-ads
```

Expected: tests pass; both runs end with `OK`. The stripped variant runs `make setup` (regenerating l10n) and `analyze` cleanly.

- [ ] **Step 5: Commit**

```bash
git add tool test/tool
git commit -m "feat(init): rename and strip feature keys in ARB files"
```

---

### Task 11: Documentation and final verification

**Files:**
- Create: `docs/localization.md`
- Modify: `AGENTS.md`, `CLAUDE.md`, `docs/tech.md`, `docs/ui_ux.md`, `CHANGELOG.md`

- [ ] **Step 1: Write the docs**
  - `docs/localization.md`: cover the topics in spec §8, plus the key tables' conventions (`common*`, feature prefixes, untranslated `appTitle`/`appDescription`). Add a note that after `init --description`, apps should translate `appDescription` in non-English ARBs.
  - `AGENTS.md`:
    - forbidden-pattern line (spec §5);
    - `l10n/` in the directory tree (`lib/l10n/` ARB + generated, `core/l10n/`);
    - `LocaleNotifier` in the keepAlive list;
    - in §2.1.1, a sentence that JSON/ARB files cannot hold markers, so optional-feature keys use the feature prefix.
  - `CLAUDE.md`:
    - `docs/localization.md` under "Also Read When Relevant";
    - `- **Strings:** ARB + context.l10n. No hardcoded UI text` in Critical Bans;
    - `make check-l10n` in Key Commands.
  - `docs/tech.md`: `flutter_localizations` in the packages list, plus the l10n paths.
  - `docs/ui_ux.md`: Language tile in the Settings spec.
  - `CHANGELOG.md`: an `Unreleased` entry, "Localization: gen-l10n with English and Vietnamese, Settings language picker, `make check-l10n`, init strips feature keys from ARB files."

- [ ] **Step 2: Final verification**

```bash
make release-preflight
make check-l10n
```

Expected: format leaves no diff in tracked files, analyze has no issues, layout passes, the coverage gate passes (`lib/core/l10n/**` ≥ 80%), and `l10n OK (2 locales, <n> keys)`.

- [ ] **Step 3: Commit**

```bash
git add docs AGENTS.md CLAUDE.md CHANGELOG.md
git commit -m "docs(l10n): document localization and add changelog entry"
```
