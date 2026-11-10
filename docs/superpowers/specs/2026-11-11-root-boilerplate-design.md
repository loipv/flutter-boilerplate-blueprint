# Root boilerplate refactor: design

Date: 2026-11-11
Status: awaiting review
Target release: blueprint `v1.0.0` (breaking)

## 1. Goal

Turn this repo from "a `template/` folder plus a generator script" into a complete,
runnable Flutter app at the repo root, so that:

- `analyze` and `test` run directly in the repo, with no scaffold step first.
- New features are developed and verified in place, like in any Flutter project.
- Scaffolding a new app becomes "clone, then rename in place" instead of
  "generate from a tokenized template".

### Decisions already made

| Decision | Choice |
| --- | --- |
| Scaffold options kept | Identity (name, org, title, description) and feature toggles (Notifications, PostHog, Sentry, Functions, Apple, Google, Anonymous) |
| Scaffold options dropped | Tab count, color presets, AI tool choice, FVM choice |
| Platform folders | Commit complete `ios/` and `android/` |
| Canonical navigation | 3 tabs: Home, Explore, Profile |
| Scaffold tool | Dart script `tool/init.dart`, run in place |

### Success criteria

1. On a fresh clone: `make setup && make analyze && make test` pass at the root.
2. `grep -rE '__[A-Z][A-Z0-9_]+__'` over tracked files matches only `__FILE__` in `ios/Podfile`.
3. Running `tool/init.dart` with each CI combination (section 7) produces a project
   that passes analyze and test and contains none of: `blueprint_app`,
   `Blueprint App`, `BEGIN_`/`END_` marker lines, blueprint-only files.
4. `scaffold.sh` contains no `sed` or `python3` and no template logic.
5. `make run-staging` launches the app from the root once real Firebase config
   files are present. This one is verified by hand; CI cannot cover it.

### Out of scope

- A full test suite. Only seed tests ship with this refactor (section 7).
- Upgrading the pinned Flutter version (stays `3.41.4`) or any dependency.
- Keeping `v0.x` curl one-liners working (section 8).
- The iOS bundle identifier containing an underscore when the package name has
  one (`com.example.blueprint_app`). This is today's behavior and is preserved.

## 2. Repo layout

Everything under `template/` moves to the root with `git mv`, so history follows
the files. `template/` no longer exists afterwards.

```text
/
├── lib/ assets/ functions/ ios/ android/ test/     the app
├── docs/                                           app docs (from template/docs)
│   ├── repo-assets/                                blueprint-only
│   └── superpowers/                                blueprint-only
├── tool/
│   ├── init.dart                                   scaffold entrypoint
│   ├── src/                                        init logic, pure functions
│   └── app_readme.md                               README for generated apps
├── .github/workflows/ci.yml                        kept in generated apps
├── .github/workflows/blueprint.yml                 blueprint-only
├── scaffold.sh                                     thin bootstrap, blueprint-only
├── BLUEPRINT_VERSION.md                            version source of truth
├── AGENTS.md CLAUDE.md README.md CHANGELOG.md LICENSE
└── pubspec.yaml Makefile firebase.json *.rules .fvmrc .env.*.example
```

### 2.1 Tokens become fixed values

| Token | Value at root |
| --- | --- |
| `__APP_PACKAGE__` | `blueprint_app` |
| `__APP_ORG__` | `com.example` (application id `com.example.blueprint_app`) |
| `__APP_TITLE__` | `Blueprint App` |
| `__APP_DESC__` | `A Flutter + Firebase starter app` |
| `__PRIMARY_LIGHT__`, `__PRIMARY_DARK__`, `__ACCENT__`, `__BG_LIGHT__`, `__BG_DARK__` | Sage Green preset: `0xFF3C5A4D`, `0xFF7CA692`, `0xFF5BA87F`, `0xFFF9F9F6`, `0xFF121614` |
| `__SPLASH_BG__` | `0xFF141D21` in Dart, `#141D21` in `pubspec.yaml` |
| `__BLUEPRINT_VERSION__` | removed; `BLUEPRINT_VERSION.md` is a real file |
| `__AI_TOOL_NAME__` | `CLAUDE.md` |
| `__FLUTTER_CMD__` | see 2.2 |

None of `blueprint_app`, `Blueprint App` or `com.example.blueprint_app` occurs in
the repo today, so they are safe to find and replace later.

`pubspec.yaml` note: the current scaffold writes the splash color as `0xFF…` into
the `flutter_native_splash` and `flutter_launcher_icons` config. Those tools take
`#RRGGBB`. Confirm by running `make splash` and `make icons` during implementation.

### 2.2 Flutter command

The Makefile detects FVM instead of being rewritten by the scaffold:

```make
FLUTTER ?= $(shell command -v fvm >/dev/null 2>&1 && echo "fvm flutter" || echo "flutter")
```

All targets use `$(FLUTTER)`. `make setup` is new: `pub get`, then codegen, then
`npm install` in `functions/` when that folder exists.

Docs and agent files replace `__FLUTTER_CMD__` with "use the `make` target; where
none exists, `fvm flutter`". `.fvmrc` stays committed with `3.41.4`.

### 2.3 Navigation

- `lib/core/router/app_router_3tabs.dart` becomes `app_router.dart` (the `part`
  directive becomes `app_router.g.dart`).
- `lib/core/presentation/main_scaffold_3tabs.dart` becomes `main_scaffold.dart`.
- Delete the 2-tab and 4-tab variants (4 files) and `lib/features/library/`,
  which only the 4-tab router imports.
- `docs/next_steps.md` gains a short "add or remove a tab" section.

### 2.4 Platform folders

Run `flutter create --platforms ios,android --org com.example --project-name blueprint_app .`
at the root with Flutter `3.41.4`, without `--overwrite`, so the 13 customized
files already tracked are kept. Then:

- Delete the generated `lib/main.dart` and `test/widget_test.dart`. (Today's
  scaffold leaves both in generated apps as counter-app leftovers.)
- Commit every generated file that the merged `.gitignore` does not exclude.
  A fresh create yields 64 platform files; 6 are replaced by tracked files.
- Keep `.metadata`.

Prerequisite: this machine has Flutter 3.47.9 and no `fvm`. Install `fvm` and
Flutter `3.41.4` before this step.

## 3. Code changes needed for the root to compile

### 3.1 Sentry

`NO_SENTRY` is the only inverse marker, and with both blocks present the
entrypoints call `runApp` twice. Replace both blocks in `main_staging.dart` and
`main_production.dart` with one path:

```dart
  void startApp() => runApp(const ProviderScope(child: App()));

  // BEGIN_SENTRY
  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) { /* unchanged */ }, appRunner: startApp);
    return;
  }
  // END_SENTRY
  startApp();
```

The `assert(_sentryDsn.isNotEmpty, …)` is removed; a missing DSN now means
"run without Sentry". The `NO_SENTRY` marker no longer exists anywhere.

PostHog keeps its `assert` on `POSTHOG_API_KEY` unchanged.

### 3.2 Firebase options stubs

Commit `lib/firebase_options_staging.dart` and `lib/firebase_options_production.dart`
as stubs exposing `DefaultFirebaseOptions.currentPlatform` with placeholder
values, added with `git add -f`. They stay listed in `.gitignore`, so a generated
app (fresh `git init`) does not track the real files `flutterfire configure` writes.

Risk: running `flutterfire configure` inside the blueprint repo modifies the
tracked stubs. `AGENTS.md` (blueprint section) tells maintainers to run
`git update-index --skip-worktree` on both files first.

### 3.3 Feature markers

`// BEGIN_X` / `// END_X` blocks stay as they are in Dart, `AndroidManifest.xml`
and `Info.plist`. Two additions:

- `pubspec.yaml` wraps optional dependencies in `# BEGIN_X` / `# END_X`
  (`NOTIFICATIONS`, `POSTHOG`, `SENTRY`, including `sentry_dart_plugin` under
  `dev_dependencies`), replacing the scaffold's per-line `sed` deletions.
- Markdown uses `<!-- BEGIN_BLUEPRINT -->` / `<!-- END_BLUEPRINT -->` for
  blueprint-only passages.

## 4. `tool/init.dart`

Imports only `dart:` libraries, so `dart tool/init.dart` runs before `pub get`.
It edits the working tree in place and never touches `.git` contents.

### 4.1 Inputs

Each prompt has a flag; `--yes` accepts defaults for anything not passed.

| Prompt | Flag | Default | Validation |
| --- | --- | --- | --- |
| Package name | `--name` | current directory name | `^[a-z][a-z0-9_]*$`, not a Dart reserved word |
| Organization | `--org` | `com.example` | dot-separated segments, each `[a-z][a-z0-9_]*`, at least two |
| Display name | `--title` | package name in Title Case | non-empty, none of `' " \ $ < > &` |
| Description | `--description` | `A new Flutter app` | same character rule as title |
| Notifications | `--no-notifications` | on | |
| PostHog | `--no-posthog` | on | |
| Sentry | `--no-sentry` | on | |
| Cloud Functions | `--no-functions` | on | |
| Apple Sign-In | `--no-apple` | on | |
| Google Sign-In | `--no-google` | on | |
| Anonymous sign-in | `--no-anon` | on | |

Invalid input in interactive mode re-prompts; with flags it exits non-zero with
the reason. All validation happens before any file is changed.

### 4.2 Steps, in order

1. **Rename.** Over all text files (extension allowlist, binaries skipped),
   replace in this order: `com.example.blueprint_app` → `<org>.<name>`,
   `blueprint_app` → `<name>`, `Blueprint App` → `<title>`,
   `A Flutter + Firebase starter app` → `<description>`. Move
   `android/app/src/main/kotlin/com/example/blueprint_app/` to the path matching
   the new org and name.
2. **Features.** For each disabled feature, delete its marker blocks everywhere
   and its files:

   | Feature | Markers removed | Files removed |
   | --- | --- | --- |
   | Notifications | `NOTIFICATIONS`, `NOTIFICATIONS_IMPORTS`, `NOTIFICATIONS_SECTION`, `NOTIFICATIONS_HELPERS`, `NOTIFICATIONS_PREF` | `lib/core/services/{notification_service,timezone_lifecycle_observer,timezone_sync_service}.dart`, `lib/features/notifications/`, `test/features/notifications/` |
   | PostHog | `POSTHOG` | none (repository stays as a no-op) |
   | Sentry | `SENTRY` | none |
   | Apple | `APPLE` | none (package stays) |
   | Google | `GOOGLE` | none (package stays) |
   | Anonymous | `ANON` | none |
   | Functions | none | `functions/`, and the `functions` key in `firebase.json` |

   For enabled features, delete only the marker lines, so generated apps carry no
   scaffold comments. Markers match as whole tokens: `BEGIN_NOTIFICATIONS` must
   not match `BEGIN_NOTIFICATIONS_IMPORTS`.
3. **Blueprint-only content.** Remove `<!-- BEGIN_BLUEPRINT -->` blocks, then
   delete `CHANGELOG.md`, `LICENSE`, `scaffold.sh`, `docs/repo-assets/`,
   `docs/superpowers/`, `.github/workflows/blueprint.yml`, `test/tool/`, and
   replace `README.md` with `tool/app_readme.md`.
4. **Environment stubs.** Copy `.env.staging.example` to `.env.staging` and
   `.env.production.example` to `.env.production`.
5. **Git.** Run `git init` only when no `.git` directory exists.
6. **Self-removal.** Delete `tool/`, then print next steps (`make setup`,
   Firebase setup, `docs/next_steps.md`).

### 4.3 Structure

- `tool/init.dart`: argument parsing, prompts, orchestration, exit codes.
- `tool/src/options.dart`: the options value type and validation.
- `tool/src/markers.dart`: `stripBlocks(text, marker)` and `stripMarkerLines(text)`; pure string functions.
- `tool/src/rename.dart`: replacement list and Kotlin path computation; pure.
- `tool/src/manifest.dart`: feature table and blueprint-only path list as constants.

### 4.4 Failure handling

- A path named in `manifest.dart` that does not exist is an error, not a skip.
  This keeps the manifest from going stale.
- After all steps, init scans for leftover `blueprint_app`, `Blueprint App` and
  marker lines and exits non-zero listing them.
- Init does not delete `.git`, so a maintainer who runs it in the blueprint repo
  by mistake recovers with `git checkout . && git clean -fd`.

## 5. `scaffold.sh`

Roughly 30 lines of bash, no template knowledge:

1. Require `git` and `dart` (or `fvm`).
2. Take the target directory as `$1` and `shift`, or prompt for it when absent;
   fail if it exists.
3. `git clone --depth 1 --branch "${BLUEPRINT_REF:-main}"` from the remote into
   it. When `scaffold.sh` sits in a checkout (`tool/init.dart` is beside it),
   clone from that local path instead, which uses its committed state.
4. Remove the cloned `.git`.
5. `cd` in and run `dart tool/init.dart "$@"` with the remaining arguments
   (via `fvm dart` when available).
6. Run `make setup`.

The existing `main` one-liner keeps working. A pinned version is
`BLUEPRINT_REF=v1.0.0 bash -c "$(curl -fsSL …/v1.0.0/scaffold.sh)"`.

Users may also skip the script: GitHub "Use this template" or `git clone`, then
`dart tool/init.dart`.

## 6. Documentation

- `AGENTS.md`: merge root and template versions (27 differing lines). The
  blueprint release section goes inside `BEGIN_BLUEPRINT` markers and is
  rewritten for the new process.
- `CLAUDE.md`: merge with `template/AGENT.md` the same way; fix paths
  (`template/docs/…` → `docs/…`).
- Delete `CODEX.md` and `template/AGENT.md`. Codex reads `AGENTS.md` directly.
- `template/README.md` becomes `tool/app_readme.md`.
- Root `README.md`: rewrite quick start, the scaffold question table, the
  generated project shape, and the release section.
- `.gitignore`: union of both files; drop the `template/functions/…` entries.
- `docs/testing_guide.md`: point at the seed tests that now exist.

Release process after this change: update `BLUEPRINT_VERSION.md`, the "Latest
stable" line in `README.md`, and `CHANGELOG.md`; commit; tag; push.

## 7. Tests and CI

### Seed tests

- `test/features/auth/application/auth_controller_test.dart`
- `test/features/onboarding/application/onboarding_controller_test.dart`
- `test/tool/markers_test.dart`, `rename_test.dart`, `options_test.dart`

Feature tests follow `docs/testing_guide.md` (Mocktail, provider overrides).
Tests for an optional feature live under `test/features/<feature>/` so init
removes them with the feature.

### `.github/workflows/ci.yml` (kept in generated apps)

Flutter `3.41.4`; `make setup`, `make analyze`, `make test`.

### `.github/workflows/blueprint.yml` (blueprint-only)

For each combination: copy the repo, run init non-interactively, then
`make setup analyze test`, then assert no leftovers.

| Combination | Flags |
| --- | --- |
| defaults | `--yes --name blueprint_ci` |
| everything off | `--yes --name blueprint_ci` plus all seven `--no-*` flags |
| custom identity | `--yes --name acme_notes --org io.acme --title "Acme Notes" --description "Notes for Acme"` |

## 8. Release and compatibility

- Ships as `v1.0.0`.
- Breaking: `scaffold.sh` at tags `v0.6.0` to `v0.9.0` clones `main` (not its
  own tag) and reads `template/`, so those one-liners stop working once this
  merges. `CHANGELOG.md` and `README.md` say so and point to the new command.
- The README no longer advertises a `v0.x` pinned command.

## 9. Implementation order

1. Move files to root; replace tokens; collapse tab variants; Sentry change;
   Firebase stubs. Exit: root passes `make analyze`.
2. Generate and commit platform folders.
3. `tool/init.dart` with unit tests.
4. New `scaffold.sh`.
5. Seed feature tests.
6. CI workflows.
7. Documentation merge and README rewrite.
8. Version bump to `v1.0.0` and changelog.
