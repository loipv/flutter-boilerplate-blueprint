# Changelog

All notable changes to the `flutter-boilerplate-blueprint` template should be documented in this file.

The generated app's `pubspec.yaml` version is separate from the blueprint version. Use this changelog to track scaffold and template changes between blueprint tags.

## v0.9.0 - 2026-05-20

### Changed

- Adopted Riverpod 3.x provider naming convention: `themeNotifierProvider` renamed to `themeProvider` across the template (riverpod_generator 3.x drops the `Notifier` suffix automatically). Generated `.g.dart` files will produce the new name after running `make codegen`.
- `main_staging.dart` and `main_production.dart` now use `DefaultFirebaseOptions.currentPlatform` instead of flavor-specific `StagingFirebaseOptions`/`ProductionFirebaseOptions` — aligns with the standard FlutterFire CLI output.

### Added

- `template/assets/icons/app_logo.png` ships a default app logo asset.

## v0.8.1 - 2026-05-20

### Changed

- Docs polish: added FlutterFire CLI prerequisite to setup docs and shipped a `template/README.md` for scaffolded projects.

## v0.7.0 - 2026-05-19

### Fixed

- Scaffolded apps no longer fail to compile when feature flags are disabled. Previously `USE_POSTHOG`, `USE_SENTRY`, `USE_APPLE`, `USE_GOOGLE`, and `USE_ANON` either silently removed the package from `pubspec.yaml` while leaving every code reference intact (compile error), or did nothing at all (`USE_ANON`). Now scaffold.sh strips matching `BEGIN_<FLAG>/END_<FLAG>` blocks in template files for each disabled feature.
- Scaffolded apps no longer keep the `notificationTime` field in `user_preferences.dart` when notifications are disabled. The `BEGIN_NOTIFICATIONS_PREF` markers existed in the template but were never stripped by `scaffold.sh`.

### Changed

- `USE_APPLE`, `USE_GOOGLE`, `USE_ANON` are now UI-toggle flags: when disabled, the relevant sign-in UI is hidden but the `sign_in_with_apple` / `google_sign_in` packages stay installed and the auth interface methods remain. This is intentional — full code stripping for these three flags requires cross-cutting interface/impl/controller markers and was deferred to keep the v0.7.0 change safe and verifiable.
- `USE_POSTHOG=false` now keeps `PostHogAnalyticsRepository` as a no-op implementation of `AnalyticsRepository`. The class + provider remain so callers (e.g. `FirebaseAuthRepository`) work unchanged; only the SDK calls become no-ops.
- `USE_SENTRY=false` strips `SentryFlutter.init` wrapping; a `BEGIN_NO_SENTRY` block in each `main_*.dart` provides the fallback bare `runApp(...)` call.
- `scaffold.sh` `strip_marked_block` helper now guards `[ -f "$file" ] || return 0` so strips on files that may not exist (e.g. removed by a prior strip) no longer error.

### Breaking / manual follow-up

- None — but generated apps may show analyzer warnings about unused imports/parameters when many flags are disabled at once. These are non-blocking and easily resolved with a `dart fix --apply`.

## v0.6.0 - 2026-05-19

### Added

- `template/AGENTS.md` is now shipped to every generated app. The AI bootloader (`CLAUDE.md` / `CODEX.md` / `GEMINI.md`) referenced `AGENTS.md` as required reading, but the file was missing from `template/`, leaving generated apps without "full rules" documentation.

### Fixed

- `scaffold.sh` now correctly replaces `__APP_PACKAGE__` (and other tokens) in files living under `lib/.../data/` directories and in `.firebaserc`. The previous binary-file skip used `file "$path" | grep 'data'`, which matched the literal string `data` in the printed pathname (e.g. `lib/core/data/...`) or in `file`'s output for JSON files (`JSON data`), causing those files to be skipped entirely. Fixed by using `file -b` (brief, no filename) and tightening the skip pattern to `(font|executable|compiled)`.
- `template/Makefile` no longer hardcodes `DEVICE=iPhone` and `RELEASE_DEVICE=device-id` defaults. The `-d` flag is now only passed when the user explicitly sets `DEVICE=` or `RELEASE_DEVICE=`, letting Flutter pick the device by default.
- `template/Makefile` no longer enumerates each env var by name. A new `dart_defines` Make function reads every `KEY=VALUE` line from the env file and emits `--dart-define=KEY=VALUE` flags automatically. Adding a new variable to `.env.staging` / `.env.production` no longer requires editing the Makefile.
- `template/Makefile` now falls back to a top-level `.env` file when `.env.staging` or `.env.production` is missing, simplifying quick local experiments.

### Changed

- Blueprint repo URL updated from `sandeshan/flutter-firebase-blueprint` to `loipv/flutter-boilerplate-blueprint` across `scaffold.sh`, `README.md`, `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `template/docs/setup.md`, and `template/docs/next_steps.md`.
- Removed redundant `template/BLUEPRINT_VERSION.md`. The file is always overwritten by `scaffold.sh` at scaffold time, so the template copy was dead weight.

### Breaking / manual follow-up

- None

## v0.5.0 - 2026-04-11

### Fixed

- `template/pubspec.yaml` now uses a compatible `freezed` 3.x / `freezed_annotation` 3.x pair, fixing `flutter pub get` failures caused by the `riverpod_generator` 4.x and `freezed` 2.x `source_gen` conflict.
- `template/lib/core/data/posthog_analytics_repository.dart`, `template/lib/features/auth/data/firebase_auth_repository.dart`, and `template/lib/features/user_profile/data/firebase_user_repository.dart` now expose concrete repository types from their `@Riverpod` providers, fixing `InvalidTypeException` failures during code generation on refreshed Riverpod generator versions.
- `template/lib/core/services/notification_service.dart` now uses the current `flutter_local_notifications` named-argument APIs required by the upgraded notifications package set.
- `template/lib/main_staging.dart` and `template/lib/main_production.dart` now match the current `posthog_flutter` and `firebase_app_check` APIs, including the renamed production App Check provider classes.

### Changed

- `template/pubspec.yaml` now refreshes the blueprint's shared package constraints to current stable versions across Riverpod, GoRouter, Firebase, analytics/monitoring, notifications, and codegen tooling.
- Generated apps now target Dart `^3.11.0` to satisfy the upgraded package set.

### Breaking / manual follow-up

- Generated apps now require a Dart/Flutter toolchain compatible with Dart `3.11.x`.

## v0.3.0 - 2026-04-11

### Fixed

- `template/pubspec.yaml` now uses a compatible `freezed` 3.x / `freezed_annotation` 3.x pair and raises the generated app Dart SDK floor to `^3.11.0`, fixing `flutter pub get` failures caused by the `riverpod_generator` 4.x and `freezed` 2.x `source_gen` conflict.

### Changed

- `template/pubspec.yaml` now refreshes the blueprint's shared package constraints to current stable versions across Riverpod, GoRouter, Firebase, analytics/monitoring, notifications, and codegen tooling, and raises the generated app Dart SDK floor to `^3.11.0` to satisfy those newer packages.
- `scaffold.sh` now makes every feature yes/no prompt explicitly default to `yes`, matching the prompt text and intended scaffold flow.
- `scaffold.sh` now centralizes the blueprint Flutter SDK pin in a single constant and, when FVM is enabled, defaults to that tested version while offering an explicit opt-in for the latest stable channel.
- `scaffold.sh` now shows the selected FVM SDK in the scaffold summary before project creation.
- `README.md` now documents the FVM SDK choice and explains why the scaffold defaults to a blueprint-tested Flutter version.
- `template/docs/setup.md` now documents the FVM SDK choice and uses the supported `bash -c "$(curl ...)"` scaffold command.

### Breaking / manual follow-up

- None

## v0.2.1 - 2026-04-11

### Fixed

- `scaffold.sh` now initializes and checks prerequisite flags before the interactive feature prompts, preventing `HAS_FVM: unbound variable` failures during setup.
- `scaffold.sh` now defaults the output directory prompt to the current working directory plus the generated package name instead of hardcoding `~/Dev/<package>`.
- `scaffold.sh` now fails fast with a clear message when invoked under `sh`, avoiding confusing runtime errors from Bash-only syntax.

### Changed

- `README.md` now documents `bash -c "$(curl ...)"` as the supported remote invocation and explicitly states that the scaffold requires Bash.
- `README.md` now documents the output directory default as `<current-dir>/<package>`.

### Breaking / manual follow-up

- None

## v0.2.0 - 2026-04-11

### Fixed

- `scaffold.sh` now writes interactive prompt text directly to the terminal so the "App identity" questions display correctly when the script is run via `sh -c "$(curl ...)"`.

### Changed

- `README.md` now uses relative Markdown links for blueprint release files instead of local machine file paths.

### Breaking / manual follow-up

- None

## v0.1.0 - 2026-04-06

Initial tagged blueprint release.

### Added

- Feature-first Flutter + Firebase starter template with Riverpod 3.x, auth, onboarding, theming, optional notifications, and release tooling
- Interactive `scaffold.sh` flow for generating new apps from the blueprint
- Stable blueprint versioning via `BLUEPRINT_VERSION` in `scaffold.sh`
- `BLUEPRINT_VERSION.md` stamped into generated apps
- Blueprint-level `CHANGELOG.md` for tracking scaffold changes between tags

### Changed

- README now documents the blueprint release workflow for bumping version, updating the changelog, committing, tagging, and pushing
- README now treats `main` as the default install path and uses tags for reproducible older blueprint snapshots

### Breaking / manual follow-up

- None
