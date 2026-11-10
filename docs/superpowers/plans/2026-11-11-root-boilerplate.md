# Root Boilerplate Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the app out of `template/` so the repo root is a runnable Flutter project, and replace the 579-line generator with a Dart `tool/init.dart` that renames the clone in place.

**Architecture:** The root holds one real app with fixed identity values (`blueprint_app`, `com.example`, `Blueprint App`). Optional features stay delimited by `BEGIN_X`/`END_X` comment markers. `tool/init.dart` (pure `dart:` imports) renames the fixed values, strips markers and files for disabled features, deletes blueprint-only content, and removes itself. `scaffold.sh` shrinks to clone-and-run-init.

**Tech Stack:** Flutter 3.41.4 via FVM, Dart, Riverpod 3.x code-gen, Mocktail, bash, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-11-root-boilerplate-design.md`

## Global Constraints

- Work on branch `refactor/root-boilerplate`. Never commit to `main`. Do not push or tag; Task 12 hands that to the maintainer.
- Flutter is pinned to `3.41.4` (`.fvmrc`). Run Flutter and Dart through `fvm` or the `make` targets. Do not change any dependency version in `pubspec.yaml`.
- Fixed values at root, verbatim: package `blueprint_app`; application id `com.example.blueprint_app`; title `Blueprint App`; description `A Flutter + Firebase starter app`.
- Colors at root: primary `0xFF3C5A4D`, primary dark `0xFF7CA692`, accent `0xFF5BA87F`, light background `0xFFF9F9F6`, dark background `0xFF121614`, splash `0xFF141D21` in Dart and `#141D21` in `pubspec.yaml`.
- Marker names: `NOTIFICATIONS`, `NOTIFICATIONS_IMPORTS`, `NOTIFICATIONS_SECTION`, `NOTIFICATIONS_HELPERS`, `NOTIFICATIONS_PREF`, `POSTHOG`, `SENTRY`, `APPLE`, `GOOGLE`, `ANON`, `BLUEPRINT`. `NO_SENTRY` must not exist after Task 2.
- Marker line forms: `// BEGIN_X`, `# BEGIN_X`, `<!-- BEGIN_X -->` (and `END_X`), alone on a line, any indentation.
- Files under `tool/` import only `dart:` libraries and each other by relative path. Use `stdout`/`stderr`, not `print` (`avoid_print` is on).
- Code under `lib/` follows `AGENTS.md`: absolute `package:` imports, `@riverpod` code-gen, `AppLogger`, no `SizedBox` spacing, Lucide icons.
- Commit messages follow the repo's conventional style (`refactor:`, `feat:`, `test:`, `docs:`, `chore:`).
- Token check used throughout (spec criterion 2; `CHANGELOG.md` and `docs/superpowers/` are excluded because they describe the old tokens):

  ```bash
  git grep -nE '__[A-Z][A-Z0-9_]+__' -- . ':!CHANGELOG.md' ':!docs/superpowers'
  ```

  Expected output: only the two `__FILE__` lines in `ios/Podfile`. Until Task 9 rewrites `scaffold.sh`, add `':!scaffold.sh'` to the command, because the old script still names the tokens.
- In the test tables below, `\|` stands for a single `|` character (Markdown table escaping), not a backslash.

## Review Focus

Inputs the spec implies but does not spell out, most likely first. Each has a test in the task named.

1. The new name or org contains a fixed value (`--name blueprint_app_two`, or the user keeps `blueprint_app`): renaming must not double-replace and the leftover scan must not report a false failure. Tests in Task 7; end-to-end run in Task 8.
2. An org with more than two segments (`io.acme.mobile`): `MainActivity.kt` lands in `kotlin/io/acme/mobile/<name>/` and the empty `com/example/` folders are gone. Tests in Task 7 and Task 8.
3. Title or description with regex-special or non-ASCII characters (`Ghi Chú (v2.0) | Beta`): inserted literally. Test in Task 7.
4. A marker block with no matching `END_X`, or an `END_X` with no `BEGIN_X`: init fails naming the marker and never deletes to end of file. Test in Task 5.
5. Invalid input (`--name Bad-Name`, an unknown flag): init exits non-zero having changed no file. Tests in Task 6; working-tree check in Task 8.

---

### Task 0: Toolchain

**Files:** none.

- [ ] **Step 1: Install FVM and the pinned SDK**

Install FVM following https://fvm.app/documentation/getting-started/installation, then from the repo root run `fvm install 3.41.4`.

- [ ] **Step 2: Verify**

Run: `fvm flutter --version`
Expected: first line starts with `Flutter 3.41.4`.

---

### Task 1: Move `template/` to the root and replace tokens

**Files:**
- Move: everything under `template/` to the same path at the root, except the four below
- Move: `template/README.md` → `tool/app_readme.md`
- Move: `template/docs/*` → `docs/`
- Delete: `template/AGENTS.md`, `template/AGENT.md` (Task 11 merges their content from `git show main:template/AGENTS.md` and `git show main:template/AGENT.md`)
- Modify: `.gitignore` (union with `template/.gitignore`, then delete the template copy)
- Modify: `Makefile`, `pubspec.yaml`, `docs/next_steps.md`, `tool/app_readme.md`
- Create: `BLUEPRINT_VERSION.md`

**Interfaces:**
- Produces: `make setup`; Makefile variable `FLUTTER`; root `BLUEPRINT_VERSION.md` with the single line `Blueprint version: v0.9.0`.

- [ ] **Step 1: Move the files with `git mv`**

Move `docs` file by file (a directory move would nest it under the existing `docs/`). After this step `git ls-files template` prints nothing and `template/` does not exist.

- [ ] **Step 2: Merge `.gitignore`**

Union of both files. Remove the two `template/functions/…` lines. Add `.fvm/`. `functions/.gitignore` already covers `node_modules/` and `lib/`.

- [ ] **Step 3: Replace tokens**

One-off commands (BSD `sed`; these are not shipped). The Makefile goes first so its Flutter command becomes the variable from Step 4:

```bash
sed -i '' 's|__FLUTTER_CMD__|$(FLUTTER)|g' Makefile
git ls-files -z -- . ':!CHANGELOG.md' ':!README.md' ':!scaffold.sh' ':!docs/superpowers' ':!assets' \
| xargs -0 sed -i '' \
  -e 's|__APP_ORG__\.__APP_PACKAGE__|com.example.blueprint_app|g' \
  -e 's|__APP_PACKAGE__|blueprint_app|g' \
  -e 's|__APP_ORG__|com.example|g' \
  -e 's|__APP_TITLE__|Blueprint App|g' \
  -e 's|__APP_DESC__|A Flutter + Firebase starter app|g' \
  -e 's|__PRIMARY_LIGHT__|0xFF3C5A4D|g' -e 's|__PRIMARY_DARK__|0xFF7CA692|g' \
  -e 's|__ACCENT__|0xFF5BA87F|g' \
  -e 's|__BG_LIGHT__|0xFFF9F9F6|g' -e 's|__BG_DARK__|0xFF121614|g' \
  -e 's|"__SPLASH_BG__"|"#141D21"|g' -e 's|__SPLASH_BG__|0xFF141D21|g' \
  -e 's|__AI_TOOL_NAME__|CLAUDE.md|g' \
  -e 's|__FLUTTER_CMD__|fvm flutter|g'
```

Then by hand:
- `docs/next_steps.md` line 5 becomes: ``Scaffolded from `flutter-boilerplate-blueprint`. See `BLUEPRINT_VERSION.md` in the project root for the blueprint version this app started from.``
- `tool/app_readme.md` line 5 becomes: ``Scaffolded from [`flutter-boilerplate-blueprint`](https://github.com/loipv/flutter-boilerplate-blueprint). See [`BLUEPRINT_VERSION.md`](BLUEPRINT_VERSION.md) for the version.``

- [ ] **Step 4: Makefile**

Add at the top:

```make
FLUTTER ?= $(shell command -v fvm >/dev/null 2>&1 && echo "fvm flutter" || echo "flutter")
```

Add a `setup` target (in `.PHONY` and in `help` under "Dev") that runs `$(FLUTTER) pub get`, then the `codegen` recipe, then `npm install` inside `functions/` only when that directory exists.

- [ ] **Step 5: Create `BLUEPRINT_VERSION.md`**

Content: `Blueprint version: v0.9.0` and a newline.

- [ ] **Step 6: Verify**

Run the token check from Global Constraints (with the `scaffold.sh` exclusion).
Expected: only the two `__FILE__` lines in `ios/Podfile`.

Run: `fvm flutter pub get`
Expected: `Got dependencies!` and exit 0. This creates `pubspec.lock`; commit it, since the root is now an app.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor: move template to repo root and replace tokens with fixed values"
```

---

### Task 2: Make the root compile

**Files:**
- Rename: `lib/core/router/app_router_3tabs.dart` → `lib/core/router/app_router.dart`
- Rename: `lib/core/presentation/main_scaffold_3tabs.dart` → `lib/core/presentation/main_scaffold.dart`
- Delete: `lib/core/router/app_router_{2,4}tabs.dart`, `lib/core/presentation/main_scaffold_{2,4}tabs.dart`, `lib/features/library/`
- Modify: `lib/main_staging.dart`, `lib/main_production.dart`, `pubspec.yaml`
- Create: `lib/firebase_options_staging.dart`, `lib/firebase_options_production.dart`

**Interfaces:**
- Produces: a root where `make setup && make analyze` passes; `pubspec.yaml` with `# BEGIN_X`/`# END_X` around optional dependencies.

- [ ] **Step 1: Collapse the tab variants**

After the renames, the router's `part` directive is `part 'app_router.g.dart';`. Fix any import that still names a `_3tabs` file.

- [ ] **Step 2: Single `runApp` path in both entrypoints**

Remove the `assert(_sentryDsn.isNotEmpty, …)` block and both the trailing `BEGIN_SENTRY` and `BEGIN_NO_SENTRY` blocks. Replace them with (environment string and sample rate unchanged per file):

```dart
  void startApp() => runApp(const ProviderScope(child: App()));

  // BEGIN_SENTRY
  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      // existing option assignments, unchanged
    }, appRunner: startApp);
    return;
  }
  // END_SENTRY
  startApp();
```

- [ ] **Step 3: Firebase options stubs**

Each file declares `class DefaultFirebaseOptions` with `static FirebaseOptions get currentPlatform` returning a `const FirebaseOptions` whose `apiKey`, `appId`, `messagingSenderId` and `projectId` are all `'stub'`. A header comment gives the `flutterfire configure --project=<id> --out=<this file>` command that replaces it. Both paths are in `.gitignore`, so add them with `git add -f`.

- [ ] **Step 4: Markers in `pubspec.yaml`**

Wrap `flutter_local_notifications`, `timezone`, `flutter_timezone`, `workmanager` in `# BEGIN_NOTIFICATIONS`/`# END_NOTIFICATIONS`; `posthog_flutter` in `POSTHOG`; `sentry_flutter` in `SENTRY`; and `sentry_dart_plugin` (under `dev_dependencies`) in its own `SENTRY` block.

- [ ] **Step 5: Verify**

Run: `make setup && make analyze`
Expected: `No issues found!`

Run: `git grep -n 'NO_SENTRY\|_2tabs\|_4tabs\|_3tabs'  -- . ':!docs/superpowers' ':!CHANGELOG.md' ':!scaffold.sh' ':!README.md'`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add -A && git add -f lib/firebase_options_staging.dart lib/firebase_options_production.dart
git commit -m "refactor: make the root app compile in place"
```

---

### Task 3: Commit complete platform folders

**Files:**
- Create: every file `flutter create` generates under `ios/` and `android/` that `.gitignore` does not exclude; `.metadata`
- Delete (generated, unwanted): `lib/main.dart`, `test/widget_test.dart`, any `*.iml` or `.idea/`

- [ ] **Step 1: Generate**

```bash
fvm flutter create --no-pub --platforms ios,android --org com.example --project-name blueprint_app .
```

Do not pass `--overwrite`.

- [ ] **Step 2: Confirm no tracked file was modified**

Run: `git status --porcelain | grep -v '^??'`
Expected: no output (only untracked additions; the 13 customized platform files and everything else tracked are unchanged).

- [ ] **Step 3: Remove the leftovers and check identity**

Delete `lib/main.dart` and `test/widget_test.dart`.

Run: `grep -rn 'blueprintApp' ios android`
Expected: no output. If anything matches, change it to `blueprint_app` so one fixed value covers both platforms.

Run: `ls android/app/src/main/kotlin/com/example/blueprint_app/MainActivity.kt`
Expected: the path prints.

- [ ] **Step 4: Check the splash and icon config (spec 2.1)**

Stage everything first (`git add -A`) so the new platform files are protected. Then:

Run: `make splash && make icons`
Expected: both exit 0 with no "Invalid color" error. If either rejects the color, stop and report; do not change the value's format without confirming what the tool accepts.

Discard what the two commands generated: `git checkout -- . && git clean -fd ios android assets`.

- [ ] **Step 5: Verify**

Run: `make analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "chore: commit complete ios and android projects"
```

---

### Task 4: Seed feature tests

Ordered before the init tool because a generated app loses `test/tool/`, and `flutter test` fails when no test exists.

**Files:**
- Create: `test/helpers/mocks.dart`
- Create: `test/features/auth/application/auth_controller_test.dart`
- Create: `test/features/onboarding/application/onboarding_controller_test.dart`

**Interfaces:**
- Produces: `MockAuthRepository` and `MockUserRepository` in `test/helpers/mocks.dart`.

`authRepositoryProvider` and `userRepositoryProvider` are typed to the concrete classes, so the mocks are `class MockAuthRepository extends Mock implements FirebaseAuthRepository {}` and `class MockUserRepository extends Mock implements FirebaseUserRepository {}`. Do not change the provider return types.

These tests describe existing behavior, so they should pass on the first run. If one fails, stop and report it; do not change `lib/` to make it pass.

- [ ] **Step 1: Write `auth_controller_test.dart`**

Each test builds a `ProviderContainer` overriding `authRepositoryProvider` and `userRepositoryProvider` with the mocks. Fixtures: `anon = UserEntity(id: 'anon1', isAnonymous: true, signInProvider: 'anonymous', preferences: UserPreferences(hapticsEnabled: false))`, `google = UserEntity(id: 'g1', displayName: 'Ada', signInProvider: 'google')`.

| Test name | Arrange | Assert |
| --- | --- | --- |
| `signInAnonymously records the login and emits the user` | `authStateChanges` → empty stream; `signInAnonymously` → `anon` | state value is `anon`; `recordLogin('anon1', signInProvider: 'anonymous')` called once |
| `signInWithGoogle migrates preferences when the uid changes` | `authStateChanges` → `Stream.value(anon)`, awaited; `signInWithGoogle` → `google` | `savePreferences('g1', anon.preferences)` called once; `updateProfile('g1', name: 'Ada')` called once; state value is `google` |
| `signInWithGoogle swallows a canceled sign-in and keeps the previous user` | as above; `signInWithGoogle` throws `const Failure.auth('canceled')` | the call completes without throwing; state value is `anon` |
| `signInWithGoogle rethrows other failures and keeps the previous user` | as above; throws `const Failure.network()` | throws a `Failure`; state value is `anon` |

- [ ] **Step 2: Write `onboarding_controller_test.dart`**

Uses `TestWidgetsFlutterBinding.ensureInitialized()` and `SharedPreferences.setMockInitialValues(...)` with the real `sharedPreferencesProvider`; overrides the two repository providers with mocks.

| Test name | Arrange | Assert |
| --- | --- | --- |
| `starts incomplete when nothing is stored` | initial values `{}` | built state has `isComplete == false`, `currentStep == 0` |
| `starts complete when the flag is stored` | `{AppConstants.onboardingCompleteKey: true}` | `isComplete == true` |
| `nextStep increments currentStep` | `{}` | after one call `currentStep == 1` |
| `markLocallyComplete persists the flag` | `{}` | state `isComplete == true`; `SharedPreferences` holds `true` under `AppConstants.onboardingCompleteKey` |
| `completeOnboarding writes preferences and the flag for the current user` | `currentUser` → `UserEntity(id: 'u1')` | `savePreferences('u1', any())` and `markOnboardingComplete('u1')` each called once |
| `completeOnboarding skips Firestore when there is no user` | `currentUser` → `null` | `verifyNever` on `savePreferences` and `markOnboardingComplete`; `isComplete == true` |
| `resetOnboarding clears the flag` | `{AppConstants.onboardingCompleteKey: true}` | state `isComplete == false`; the key is absent |

- [ ] **Step 3: Run**

Run: `make test`
Expected: `All tests passed!` with 11 tests.

- [ ] **Step 4: Commit**

```bash
git add test && git commit -m "test: add seed tests for auth and onboarding controllers"
```

---

### Task 5: `tool/src/markers.dart`

**Files:**
- Create: `tool/src/markers.dart`
- Test: `test/tool/markers_test.dart`

**Interfaces:**
- Produces:
  - `class MarkerException implements Exception` with `final String message`
  - `String stripBlocks(String text, String marker)`: removes each `BEGIN_<marker>` … `END_<marker>` block including both marker lines; throws `MarkerException` on a `BEGIN` without `END` or an `END` without `BEGIN`
  - `String stripMarkerLines(String text)`: removes every marker line of any name, keeps the content between them
  - `bool hasMarkerLines(String text)`

A marker line matches `^\s*(?://|#|<!--)\s*(BEGIN|END)_([A-Z][A-Z0-9_]*)\s*(?:-->)?\s*$`; the name is compared for equality, never as a prefix. Line endings and the final newline are preserved.

- [ ] **Step 1: Write the failing tests**

| Test name | Input | Expected |
| --- | --- | --- |
| `stripBlocks removes a dart block and its marker lines` | `a\n  // BEGIN_SENTRY\n  x();\n  // END_SENTRY\nb\n`, `SENTRY` | `a\nb\n` |
| `stripBlocks removes every occurrence` | two `POSTHOG` blocks separated by `keep\n` | `keep\n` |
| `stripBlocks handles yaml and xml comment forms` | `# BEGIN_SENTRY\n  s: 1\n# END_SENTRY\n` and `<!-- BEGIN_NOTIFICATIONS -->\n<p/>\n<!-- END_NOTIFICATIONS -->\n` | empty string for both |
| `stripBlocks matches the whole marker name` | text with a `NOTIFICATIONS_IMPORTS` block, marker `NOTIFICATIONS` | text unchanged |
| `stripBlocks leaves other markers alone` | `GOOGLE` block inside text, marker `APPLE` | text unchanged |
| `stripBlocks throws when END is missing` | `// BEGIN_SENTRY\nx\n`, `SENTRY` | `MarkerException` whose message contains `SENTRY` |
| `stripBlocks throws when END has no BEGIN` | `x\n// END_SENTRY\n`, `SENTRY` | `MarkerException` whose message contains `SENTRY` |
| `stripMarkerLines keeps the content` | `// BEGIN_GOOGLE\nimport 'g';\n// END_GOOGLE\n` | `import 'g';\n` |
| `stripMarkerLines ignores prose that mentions a marker` | `see BEGIN_SENTRY in the docs\n` | unchanged |
| `hasMarkerLines` | `  # END_POSTHOG\n` → `true`; `plain\n` → `false` | |

- [ ] **Step 2: Run to see them fail**

Run: `fvm flutter test test/tool/markers_test.dart`
Expected: FAIL, `markers.dart` not found.

- [ ] **Step 3: Implement the three functions in `tool/src/markers.dart`**

Process line by line with the regex above.

- [ ] **Step 4: Run to see them pass**

Run: `fvm flutter test test/tool/markers_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add tool/src/markers.dart test/tool/markers_test.dart && git commit -m "feat: add marker stripping for the init tool"
```

---

### Task 6: `tool/src/options.dart`

**Files:**
- Create: `tool/src/options.dart`
- Test: `test/tool/options_test.dart`

**Interfaces:**
- Produces:
  - `enum Feature { notifications, posthog, sentry, functions, apple, google, anon }`
  - `class InitOptions` with `const InitOptions({required String name, required String org, required String title, required String description, Set<Feature> disabled = const {}})` and matching final fields
  - `class ParsedArgs` with nullable `name`, `org`, `title`, `description`, plus `Set<Feature> disabled` and `bool yes`
  - `ParsedArgs parseArgs(List<String> args)`: accepts `--name v` and `--name=v` (same for `--org`, `--title`, `--description`), `--yes`, and `--no-<feature name>`; throws `FormatException` on an unknown flag or a missing value
  - `String? validateName(String value)`, `String? validateOrg(String value)`, `String? validateText(String value)`: `null` when valid, otherwise the message to show
  - `String titleFromName(String name)`

Rules (spec 4.1): name matches `^[a-z][a-z0-9_]*$` and is not a Dart reserved word; org has at least two dot-separated segments, each `[a-z][a-z0-9_]*`; text is non-empty after trimming and contains none of `' " \ $ < > &`.

- [ ] **Step 1: Write the failing tests**

| Test name | Assertions |
| --- | --- |
| `validateName accepts snake_case` | `acme_notes`, `a1` → `null` |
| `validateName rejects bad names` | `Bad-Name`, `1app`, `acme notes`, empty, `class`, `void`, `null` → non-null |
| `validateOrg accepts two or more segments` | `com.example`, `io.acme.mobile` → `null` |
| `validateOrg rejects bad orgs` | `acme`, `Com.Example`, `io..acme`, `io.1acme` → non-null |
| `validateText rejects unsafe characters` | each of `' " \ $ < > &` inside a title, and `'   '` → non-null |
| `validateText accepts punctuation and non-ASCII` | `Ghi Chú (v2.0) \| Beta` → `null` |
| `titleFromName` | `acme_notes` → `Acme Notes`; `app` → `App` |
| `parseArgs reads values in both forms` | `['--name', 'a', '--org=io.acme', '--yes']` → name `a`, org `io.acme`, yes `true`, title `null` |
| `parseArgs collects disabled features` | `['--no-sentry', '--no-anon']` → `{Feature.sentry, Feature.anon}` |
| `parseArgs rejects unknown flags and missing values` | `['--nope']`, `['--name']` → `FormatException` |

- [ ] **Step 2: Run to see them fail**

Run: `fvm flutter test test/tool/options_test.dart`
Expected: FAIL, `options.dart` not found.

- [ ] **Step 3: Implement `tool/src/options.dart`**

- [ ] **Step 4: Run to see them pass**

Run: `fvm flutter test test/tool/options_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add tool/src/options.dart test/tool/options_test.dart && git commit -m "feat: add option parsing and validation for the init tool"
```

---

### Task 7: `tool/src/rename.dart`

**Files:**
- Create: `tool/src/rename.dart`
- Test: `test/tool/rename_test.dart`

**Interfaces:**
- Consumes: `InitOptions` from Task 6.
- Produces:
  - `const fixedId = 'com.example.blueprint_app'`, `fixedName = 'blueprint_app'`, `fixedTitle = 'Blueprint App'`, `fixedDescription = 'A Flutter + Firebase starter app'`
  - `String renameText(String text, InitOptions o)`
  - `String kotlinDir(String org, String name)`: forward-slash path relative to the repo root
  - `List<String> findLeftovers(String text, InitOptions o)`: the fixed values still present, skipping any fixed value that is a substring of one of the new values

`renameText` must be a single pass so a new value is never re-scanned: one `RegExp` alternation of the four escaped fixed values, longest first (`fixedId` before `fixedName`), applied with `replaceAllMapped`. Replacements are literal strings.

- [ ] **Step 1: Write the failing tests**

With `o = InitOptions(name: 'acme_notes', org: 'io.acme', title: 'Acme Notes', description: 'Notes for Acme')` unless stated:

| Test name | Input | Expected |
| --- | --- | --- |
| `renames the application id before the bare name` | `applicationId = "com.example.blueprint_app"` | `applicationId = "io.acme.acme_notes"` |
| `renames package imports` | `import 'package:blueprint_app/app.dart';` | `import 'package:acme_notes/app.dart';` |
| `renames title and description` | `Blueprint App: A Flutter + Firebase starter app` | `Acme Notes: Notes for Acme` |
| `inserts special characters literally` | title `Ghi Chú (v2.0) \| Beta`, input `'Blueprint App'` | `'Ghi Chú (v2.0) \| Beta'` |
| `does not re-replace a new name that contains the fixed name` | name `blueprint_app_two`, input `package:blueprint_app/a.dart` | `package:blueprint_app_two/a.dart` |
| `does not re-replace an org that contains the fixed name` | org `io.blueprint_app`, input `com.example.blueprint_app` | `io.blueprint_app.acme_notes` |
| `is the identity when values are unchanged` | name `blueprint_app`, org `com.example`, input `com.example.blueprint_app` | same string |
| `kotlinDir` | `('io.acme.mobile', 'acme_notes')` | `android/app/src/main/kotlin/io/acme/mobile/acme_notes` |
| `findLeftovers reports fixed values` | `x blueprint_app y Blueprint App` | `['blueprint_app', 'Blueprint App']` |
| `findLeftovers skips values the new identity contains` | name `blueprint_app_two`, text `package:blueprint_app_two/` | empty |

- [ ] **Step 2: Run to see them fail**

Run: `fvm flutter test test/tool/rename_test.dart`
Expected: FAIL, `rename.dart` not found.

- [ ] **Step 3: Implement `tool/src/rename.dart`**

- [ ] **Step 4: Run to see them pass**

Run: `fvm flutter test test/tool/rename_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add tool/src/rename.dart test/tool/rename_test.dart && git commit -m "feat: add single-pass rename for the init tool"
```

---

### Task 8: `tool/init.dart`, the manifest, and the end-to-end check

**Files:**
- Create: `tool/src/manifest.dart`
- Create: `tool/init.dart`
- Create: `tool/verify_init.sh` (executable)

**Interfaces:**
- Consumes: everything produced by Tasks 5 to 7.
- Produces:
  - `dart tool/init.dart [flags]`; exit `0` success, `64` invalid input, `1` failure during or after changes
  - `tool/verify_init.sh [init flags…]`: copies the working tree to a temp directory, runs init there, checks the result, runs `make setup analyze test`, prints `OK: <dir>` and exits 0; any failed check exits non-zero
  - In `manifest.dart`: `Set<String> textExtensions`, `Set<String> textFileNames`, `Set<String> skipDirs`, `class FeatureRule` with `const FeatureRule({List<String> markers = const [], List<String> paths = const []})`, `Map<Feature, FeatureRule> featureRules`, `List<String> blueprintOnlyPaths`, `String? testMirror(String libPath)`

**`manifest.dart` values**

- `textExtensions`: `.dart .yaml .yml .json .md .rules .plist .entitlements .xcprivacy .pbxproj .xcscheme .xcconfig .storyboard .xml .kts .gradle .properties .kt .swift .ts .sh .iml`
- `textFileNames`: `Makefile`, `Podfile`, `.firebaserc`, `.gitignore`, and any name starting with `.env`
- `skipDirs`: `.git`, `.dart_tool`, `.fvm`, `.idea`, `build`, `node_modules`, `Pods`
- `featureRules` (markers; required paths), from spec 4.2:
  - notifications: `NOTIFICATIONS`, `NOTIFICATIONS_IMPORTS`, `NOTIFICATIONS_SECTION`, `NOTIFICATIONS_HELPERS`, `NOTIFICATIONS_PREF`; `lib/core/services/notification_service.dart`, `lib/core/services/timezone_lifecycle_observer.dart`, `lib/core/services/timezone_sync_service.dart`, `lib/features/notifications`
  - posthog: `POSTHOG`; sentry: `SENTRY`; apple: `APPLE`; google: `GOOGLE`; anon: `ANON`; no paths
  - functions: no markers; `functions`
- `blueprintOnlyPaths`: `CHANGELOG.md`, `LICENSE`, `scaffold.sh`, `docs/repo-assets`, `docs/superpowers`, `test/tool`
- `testMirror`: `lib/features/notifications` → `test/features/notifications`; `lib/core/services/x.dart` → `test/core/services/x_test.dart`; anything not under `lib/` → `null`

A required path that does not exist is an error (exit 1). A test mirror is deleted only if it exists; this is how the spec's `test/features/notifications/` entry is satisfied without requiring the folder.

**`init.dart` behavior**

1. `parseArgs`. A `FormatException` prints the message and usage to `stderr`, exit 64.
2. Resolve each of name, org, title, description: use the flag when given; otherwise prompt (showing the default) unless `--yes`, in which case take the default. Defaults: name is the current directory's basename when `validateName` accepts it, otherwise none (with `--yes` that is exit 64 asking for `--name`); org `com.example`; title `titleFromName(name)`; description `A new Flutter app`. Feature prompts are yes/no, default yes, skipped under `--yes`.
3. Validate. Interactive answers re-prompt; flag values exit 64. Nothing on disk has changed up to here.
4. Refuse to run (exit 64) when `tool/init.dart` or `pubspec.yaml` is not in the current directory.
5. Apply, in the spec's order: rename text files and move the Kotlin folder (removing emptied parent folders); per disabled feature run `stripBlocks` for its markers over text files and delete its paths and test mirrors, and for functions also drop the `functions` key from `firebase.json` (two-space indent); `stripBlocks(…, 'BLUEPRINT')` then `stripMarkerLines` over text files; delete `blueprintOnlyPaths` and copy `tool/app_readme.md` over `README.md`; create `.env.staging` and `.env.production` from the examples; `git init` only when `.git` is absent; delete `tool/`.
6. Leftover scan over every UTF-8-decodable file outside `skipDirs`: `findLeftovers` and `hasMarkerLines`. Any hit prints `path: value` lines and exits 1.
7. Print next steps: `make setup`, the two `flutterfire configure` commands, `docs/next_steps.md`.

**`verify_init.sh` checks**

Copy with `rsync -a --files-from=<(git ls-files -co --exclude-standard)`. After init exits 0, assert: none of `tool`, `scaffold.sh`, `CHANGELOG.md`, `LICENSE`, `docs/superpowers`, `docs/repo-assets`, `test/tool` exists; `.git`, `.env.staging`, `.env.production`, `BLUEPRINT_VERSION.md` exist; exactly one `MainActivity.kt` exists under `android/app/src/main/kotlin` and that tree has no empty directory; then `make setup analyze test`. Must run on macOS and Linux (no `sed -i ''`).

- [ ] **Step 1: Write `manifest.dart`, `init.dart` and `verify_init.sh` as specified**

- [ ] **Step 2: Invalid input changes nothing (Review Focus 5)**

```bash
snap() { git status --porcelain; git diff | shasum; }
before=$(snap)
fvm dart tool/init.dart --yes --name Bad-Name; echo "exit=$?"
fvm dart tool/init.dart --nope; echo "exit=$?"
[ "$before" = "$(snap)" ] && echo unchanged
```

Expected: a message naming the package name rule, then `exit=64`; a usage message, then `exit=64`; then `unchanged`.

- [ ] **Step 3: Defaults**

Run: `tool/verify_init.sh --yes --name blueprint_ci`
Expected: last line `OK: <dir>`.

- [ ] **Step 4: Everything off**

Run: `tool/verify_init.sh --yes --name blueprint_ci --no-notifications --no-posthog --no-sentry --no-functions --no-apple --no-google --no-anon`
Expected: `OK: <dir>`. In that directory `functions/` and `lib/features/notifications/` are absent and `firebase.json` has no `functions` key.

- [ ] **Step 5: Custom identity with a deep org (Review Focus 2)**

Run: `tool/verify_init.sh --yes --name acme_notes --org io.acme.mobile --title "Acme Notes" --description "Notes for Acme"`
Expected: `OK: <dir>`, and `<dir>/android/app/src/main/kotlin/io/acme/mobile/acme_notes/MainActivity.kt` exists.

- [ ] **Step 6: Identity that contains or equals a fixed value (Review Focus 1)**

Run: `tool/verify_init.sh --yes --name blueprint_app_two` and then `tool/verify_init.sh --yes --name blueprint_app`
Expected: `OK: <dir>` for both.

- [ ] **Step 7: Root still clean**

Run: `make analyze && make test`
Expected: `No issues found!` and `All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add tool && git commit -m "feat: add tool/init.dart to rename the boilerplate in place"
```

---

### Task 9: Thin `scaffold.sh`

**Files:**
- Modify: `scaffold.sh` (full rewrite)

**Interfaces:**
- Consumes: `dart tool/init.dart` and `make setup`.
- Produces: `bash scaffold.sh [target-dir] [init flags…]`, with `BLUEPRINT_REF` (default `main`) selecting the remote ref.

- [ ] **Step 1: Rewrite the script (spec section 5)**

Keep the existing "requires bash" guard and `set -euo pipefail`. Then: require `git` and one of `fvm`/`dart`; take `$1` as the target and `shift`, or prompt on `/dev/tty`; fail if the target exists; if `tool/init.dart` sits beside the script, `git clone --depth 1 "file://<script dir>"`, otherwise `git clone --depth 1 --branch "${BLUEPRINT_REF:-main}"` from `https://github.com/loipv/flutter-boilerplate-blueprint.git`; remove the clone's `.git`; `cd` in; with `fvm` present run `fvm install` then `fvm dart tool/init.dart "$@"`, otherwise `dart tool/init.dart "$@"`; finally `make setup`. No `sed`, no `python3`, no template logic.

- [ ] **Step 2: Verify from the local checkout, with a space in the path**

Commit first (the local clone uses committed state), then:

```bash
T="$(mktemp -d)/my apps/acme_notes"; mkdir -p "$(dirname "$T")"
bash scaffold.sh "$T" --yes --org io.acme --title "Acme Notes"
(cd "$T" && make analyze && make test)
```

Expected: scaffold exits 0; `No issues found!`; `All tests passed!`; `"$T/pubspec.yaml"` starts with `name: acme_notes`.

- [ ] **Step 3: Verify the guards**

Run: `bash scaffold.sh "$T"` again.
Expected: non-zero exit with a message that the directory exists.

Run: `wc -l scaffold.sh && grep -cE '\b(sed|python3)\b' scaffold.sh`
Expected: under 60 lines; count `0`.

- [ ] **Step 4: Commit**

```bash
git add scaffold.sh && git commit -m "refactor: reduce scaffold.sh to clone and run init"
```

---

### Task 10: CI workflows

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/blueprint.yml`
- Modify: `tool/src/manifest.dart` (add `.github/workflows/blueprint.yml` to `blueprintOnlyPaths`)
- Modify: `tool/verify_init.sh` (assert `.github/workflows/blueprint.yml` is absent and `.github/workflows/ci.yml` is present)

- [ ] **Step 1: `ci.yml`**

Triggers: `push` to `main`, and `pull_request`. One job on `ubuntu-latest`: `actions/checkout@v4`; `subosito/flutter-action@v2` with `flutter-version: 3.41.4`, `channel: stable`, `cache: true`; then `make setup`, `make analyze`, `make test` as separate steps.

- [ ] **Step 2: `blueprint.yml`**

Same triggers and Flutter setup. A matrix `flags` with the three rows from spec section 7 (defaults; everything off; custom identity), `fail-fast: false`, and one step: `run: tool/verify_init.sh ${{ matrix.flags }}`.

- [ ] **Step 3: Verify locally**

Run: `ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }' .github/workflows/*.yml && echo valid`
Expected: `valid`.

Run the three matrix rows through `tool/verify_init.sh` exactly as written in `blueprint.yml`.
Expected: `OK: <dir>` three times.

The first real run happens when the maintainer pushes the branch (Task 12).

- [ ] **Step 4: Commit**

```bash
git add .github tool && git commit -m "ci: add app CI and blueprint scaffold matrix"
```

---

### Task 11: Documentation

**Files:**
- Modify: `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/testing_guide.md`, `docs/next_steps.md`
- Modify: any file under `docs/` that still says to always use `fvm flutter` where a `make` target exists
- Delete: `CODEX.md`

- [ ] **Step 1: `AGENTS.md`**

Start from the root file and compare with `git show main:template/AGENTS.md`. Where the two differ in wording about "the generated app", use the template wording. The `**App:**` line becomes ``**App:** `blueprint_app` — A Flutter + Firebase starter app``. Wrap section 2.1.1 in `<!-- BEGIN_BLUEPRINT -->` / `<!-- END_BLUEPRINT -->` and rewrite it: version lives in `BLUEPRINT_VERSION.md`; release steps are those in spec section 6; before running `flutterfire configure` in this repo run `git update-index --skip-worktree lib/firebase_options_staging.dart lib/firebase_options_production.dart`. Commands read "use the `make` target; where none exists, `fvm flutter`".

- [ ] **Step 2: `CLAUDE.md`, `CODEX.md`**

Merge root `CLAUDE.md` with `git show main:template/AGENT.md`: keep the "Also Read When Relevant" section from the template; paths are `docs/…`; the blueprint-only parts (items 5 and 6 of required reading, and the paragraph about blueprint releases) go inside `BEGIN_BLUEPRINT` markers; the project identity line is ``**Blueprint App**: A Flutter + Firebase starter app``. Delete `CODEX.md`.

- [ ] **Step 3: `README.md`**

Rewrite these sections; leave the rest:
- Quick start: the `main` one-liner; the pinned form `BLUEPRINT_REF=v1.0.0 bash -c "$(curl -fsSL https://raw.githubusercontent.com/loipv/flutter-boilerplate-blueprint/v1.0.0/scaffold.sh)"`; and "Use this template" or `git clone` followed by `dart tool/init.dart`. Remove the `v0.8.1` example.
- What the scaffold asks: the 11 prompts and flags from spec 4.1. State that tab count, colors, AI tool file and FVM are edited by hand afterwards, with a pointer to `docs/next_steps.md`.
- Generated project shape: add `test/`, `.github/workflows/ci.yml`, `BLUEPRINT_VERSION.md`; `CLAUDE.md` only.
- New section "Working on the blueprint": `make setup`, `make analyze`, `make test`, `tool/verify_init.sh`.
- Releasing: the process from spec section 6.
- Replace statements that the scaffold "overlays the template into a fresh app" with "renames a clone in place".

- [ ] **Step 4: `docs/`**

- `docs/testing_guide.md`: mocks implement `FirebaseAuthRepository` / `FirebaseUserRepository` as in `test/helpers/mocks.dart`; replace `Failure.unexpected('')` with `Failure.unknown()`; the example import uses `package:blueprint_app/…`; name the two seed test files as working examples.
- `docs/next_steps.md`: new section "Add or remove a tab" naming the two files to edit (`lib/core/router/app_router.dart`, `lib/core/presentation/main_scaffold.dart`) and the one rule: one `StatefulShellBranch` per `NavigationDestination`, same order.

- [ ] **Step 5: Verify**

Run: `tool/verify_init.sh --yes --name acme_notes --org io.acme`
Expected: `OK: <dir>`.

Run in that directory: `grep -rIl -e 'scaffold\.sh' -e 'BLUEPRINT_REF' -e 'verify_init' . --exclude-dir=.git --exclude-dir=.dart_tool --exclude-dir=node_modules`
Expected: no output.

Run at the root: the token check from Global Constraints.
Expected: only the two `ios/Podfile` lines.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "docs: merge blueprint and app docs for the root layout"
```

---

### Task 12: Release `v1.0.0`

**Files:**
- Modify: `BLUEPRINT_VERSION.md`, `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Version and changelog**

`BLUEPRINT_VERSION.md` → `Blueprint version: v1.0.0`. README "Latest stable blueprint version" → `v1.0.0`. New `CHANGELOG.md` entry `v1.0.0` covering: the app now lives at the repo root; `tool/init.dart` and the thin `scaffold.sh`; removed scaffold options (tab count, color presets, AI tool, FVM choice); complete platform folders; seed tests and CI; and under a "Breaking" heading: the `scaffold.sh` shipped in tags `v0.6.0` to `v0.9.0` clones `main` and reads `template/`, so those one-liners no longer work; use the `main` one-liner or `BLUEPRINT_REF`.

- [ ] **Step 2: Full verification against the spec's success criteria**

Run: `make setup && make analyze && make test`
Expected: `No issues found!`, `All tests passed!`

Run: the token check. Expected: only the two `ios/Podfile` lines.

Run: the three `blueprint.yml` matrix rows through `tool/verify_init.sh`. Expected: `OK` three times.

Run: `grep -cE '\b(sed|python3)\b' scaffold.sh`. Expected: `0`.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "chore: bump blueprint to v1.0.0"
```

- [ ] **Step 4: Hand off to the maintainer**

Stop here and report. The maintainer decides when to push the branch, open the PR, tag `v1.0.0`, and whether to enable "Template repository" in the GitHub settings. Criterion 5 (`make run-staging` with real Firebase config) is the maintainer's manual check.
