# Firebase Remote Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Firebase Remote Config to the blueprint as an optional init feature. It provides typed values such as `apiBaseUrl` and feature flags, separated per environment by an `environment` custom signal.

**Architecture:**
- Domain (`lib/core/domain/`): a `ConfigKey<T>` registry and a `RemoteConfigRepository` interface.
- Data (`lib/core/data/`): `FirebaseRemoteConfigRepository`, the only file that imports the SDK. With the feature off, its SDK code is stripped by `REMOTE_CONFIG` markers.
- Startup (`main.dart`): activates cached values, then runs one background `fetchAndActivate()`. When that brings new values, `onUpdated` fires, `remoteConfigRevisionProvider` bumps, and callers of `ref.watchConfig(key)` rebuild.

**Tech Stack:** Flutter, Riverpod 3 code-gen, `firebase_remote_config ^6.2.0`, Mocktail.

**Spec:** `docs/superpowers/specs/2026-11-11-remote-config-design.md`

## Global Constraints

- Commands: use `make` targets, otherwise `fvm flutter` / `fvm dart`. Never use bare `flutter`.
- Imports are absolute (`package:blueprint_app/...`). Log with `AppLogger`, never `print`.
- `firebase_remote_config` is imported only in `lib/core/data/firebase_remote_config_repository.dart`, its test, and `lib/main.dart`.
- Marker name `REMOTE_CONFIG`. Each `// BEGIN_REMOTE_CONFIG` / `// END_REMOTE_CONFIG` line stands alone (`#` in YAML and `.env`, `<!-- -->` in Markdown).
- Both variants must pass `make analyze` with no warnings: markers present, and markers stripped. In particular, no `dead_code` or unused-field warnings in either variant.
- Coverage gate (`scripts/coverage_gate.dart`): `domain` 100%, `data` 90%, application/`core/config`/`core/providers` 80%. Both variants must meet it.
- One source file maps to exactly one test file at the mirrored path (`make check-test-layout`).
- Test names follow `Given ..., When ..., Then ...`.
- Values from the spec:
  - fetch timeout: 10 seconds
  - `minimumFetchInterval`: staging 5 minutes, production 1 hour
  - custom signal key: `environment`
  - env vars: `API_BASE_URL`, `REMOTE_CONFIG_ENV`
  - `apiBaseUrl` key: `api_base_url`
- Run `make codegen` after editing any `@riverpod` file.

## Review Focus

1. A `fetchAndActivate()` that fails after `initialize()` has returned must not surface as an uncaught async error. The error is logged and swallowed. Covered in Task 4.
2. Every SDK step may throw **synchronously** (not only through a failed Future). `initialize()` still completes, and the later steps still run. Covered in Task 4.
3. New values activated before anything watches the revision. A later `watchConfig` returns the new value, not a stale one. Covered in Task 5.
4. Numeric edge strings: `"3.0"` for an `int` key → default; `"3"` for a `double` key → `3.0`; `" 8 "` for an `int` key → `8` (Dart's tryParse trims). Covered in Task 4.
5. A `bool` key with `"TRUE"` or `"1"` → default. Only exact `"true"`/`"false"` count. Covered in Task 4.

---

### Task 1: Register the `remoteConfig` init feature

**Files:**
- Modify: `tool/src/options.dart` (the `Feature` enum, plus a kebab-case CLI name used by `parseArgs`)
- Modify: `tool/src/manifest.dart` (`featureRules`)
- Modify: `tool/init.dart` (usage text, `_featureLabels`, removed-features summary)
- Modify: `.github/workflows/blueprint.yml` (second matrix row)
- Modify: `README.md` (init feature table near line 134)
- Test: `test/tool/options_test.dart`, `test/tool/manifest_test.dart`

**Interfaces:**
- Produces:
  - `Feature.remoteConfig`
  - `extension FeatureCli on Feature { String get cliName; }`: camelCase becomes kebab-case (`remoteConfig` → `remote-config`; single-word names stay as they are)
  - marker `REMOTE_CONFIG` in `knownMarkers`

- [ ] **Step 1: Write the failing tests**

`test/tool/options_test.dart`:
```dart
test('Given --no-remote-config, When parsed, Then remoteConfig is disabled', () {
  expect(parseArgs(['--no-remote-config']).disabled, {Feature.remoteConfig});
});
test('Given the camelCase flag, When parsed, Then it throws FormatException', () {
  expect(() => parseArgs(['--no-remoteConfig']), throwsFormatException);
});
test('Given each feature, When cliName is read, Then it is kebab-case', () {
  expect(Feature.remoteConfig.cliName, 'remote-config');
  expect(Feature.posthog.cliName, 'posthog');
});
```

`test/tool/manifest_test.dart`:
```dart
test('Given remoteConfig, When its rule is read, Then it strips REMOTE_CONFIG only', () {
  expect(featureRules[Feature.remoteConfig]!.markers, ['REMOTE_CONFIG']);
  expect(featureRules[Feature.remoteConfig]!.paths, isEmpty);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/tool/options_test.dart test/tool/manifest_test.dart`
Expected: FAIL. `Feature.remoteConfig` is undefined.

- [ ] **Step 3: Implement**

- Add `remoteConfig` at the end of the `Feature` enum.
- Add the `cliName` extension. `parseArgs` builds its feature map from `f.cliName` instead of `f.name`.
- Add `Feature.remoteConfig: FeatureRule(markers: ['REMOTE_CONFIG'])` to `featureRules`.
- In `tool/init.dart`:
  - add the usage line `--no-remote-config      Remove Firebase Remote Config`
  - add the label `Feature.remoteConfig: 'Firebase Remote Config'`
  - the removed-features summary (line ~229) uses `cliName`
- In `blueprint.yml`, append `--no-remote-config` to the matrix row that disables everything.
- In `README.md`, add the row `| Firebase Remote Config | \`--no-remote-config\` | on |`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/tool/`
Expected: PASS, including the existing marker-scan test.

- [ ] **Step 5: Commit**

```bash
git add tool/ test/tool/ .github/workflows/blueprint.yml README.md
git commit -m "feat(init): add optional remoteConfig feature"
```

---

### Task 2: Domain types: `ConfigKey`, `ConfigKeys`, `RemoteConfigRepository`

**Files:**
- Create: `lib/core/domain/config_key.dart`
- Create: `lib/core/domain/config_keys.dart`
- Create: `lib/core/domain/remote_config_repository.dart`
- Test: `test/core/domain/config_key_test.dart`, `test/core/domain/config_keys_test.dart`

**Interfaces:**
- Produces:
  - `class ConfigKey<T extends Object> { const ConfigKey(String key, T defaultValue); final String key; final T defaultValue; }`
  - `abstract final class ConfigKeys { static const ConfigKey<String> apiBaseUrl; static const List<ConfigKey<Object>> all; }`
    - `apiBaseUrl` = `ConfigKey<String>('api_base_url', String.fromEnvironment('API_BASE_URL'))`
    - `all` = `[apiBaseUrl]`
  - `abstract class RemoteConfigRepository`:
    - `Future<void> initialize({required String environment, required Duration minimumFetchInterval})`
    - `T get<T extends Object>(ConfigKey<T> key)`
    - `Stream<void> get onUpdated`
  - Doc comments (from spec §3.1 and §3.1a):
    - The `ConfigKeys` doc comment shows how to add a bool flag.
    - The `apiBaseUrl` doc comment states the per-request convention.
    - The interface doc comments state "never throws".

- [ ] **Step 1: Write the failing tests**

`config_key_test.dart`:
```dart
test('Given a key and default, When constructed at runtime, Then both are kept', () {
  final k = ConfigKey<int>('n', 3); // non-const on purpose: covers the constructor
  expect(k.key, 'n');
  expect(k.defaultValue, 3);
});
```

`config_keys_test.dart`:
```dart
test('Given ConfigKeys.all, When keys are compared, Then they are unique', () {
  final names = ConfigKeys.all.map((k) => k.key).toList();
  expect(names.toSet().length, names.length);
});
test('Given ConfigKeys.all, When read, Then it contains apiBaseUrl', () {
  expect(ConfigKeys.all, contains(ConfigKeys.apiBaseUrl));
  expect(ConfigKeys.apiBaseUrl.key, 'api_base_url');
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/core/domain/`
Expected: FAIL with an import error.

- [ ] **Step 3: Create the three files** with the signatures above. None of them is wrapped in markers.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/core/domain/ && make analyze`
Expected: PASS, and analyze is clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain/config_key.dart lib/core/domain/config_keys.dart lib/core/domain/remote_config_repository.dart test/core/domain/
git commit -m "feat: add Remote Config domain types"
```

---

### Task 3: `AppEnv.remoteConfigMinFetchInterval`

**Files:**
- Modify: `lib/core/config/app_env.dart`
- Test: `test/core/config/app_env_test.dart`

**Interfaces:**
- Produces: `final Duration remoteConfigMinFetchInterval` on `AppEnv`. Staging is `Duration(minutes: 5)`, production is `Duration(hours: 1)`.

- [ ] **Step 1: Write the failing test** (inside `// BEGIN_REMOTE_CONFIG` / `// END_REMOTE_CONFIG`)

```dart
test('Given each env, When remoteConfigMinFetchInterval is read, Then staging is 5 min and production 1 h', () {
  expect(AppEnv.staging.remoteConfigMinFetchInterval, const Duration(minutes: 5));
  expect(AppEnv.production.remoteConfigMinFetchInterval, const Duration(hours: 1));
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm flutter test test/core/config/app_env_test.dart`
Expected: FAIL, the getter is undefined.

- [ ] **Step 3: Implement.** Add the constructor parameter, the field and the two enum arguments. Each of those lines sits inside its own `REMOTE_CONFIG` marker block, so that stripping leaves valid code. That means separate marker blocks inside `staging(...)`, inside `production(...)`, in the constructor and on the field.

- [ ] **Step 4: Run the test to verify it passes**

Run: `fvm flutter test test/core/config/app_env_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/app_env.dart test/core/config/app_env_test.dart
git commit -m "feat: add per-environment Remote Config fetch interval"
```

---

### Task 4: `FirebaseRemoteConfigRepository` and provider

**Files:**
- Modify: `pubspec.yaml`. Add `firebase_remote_config: ^6.2.0` under `# --- Firebase ---`, inside `# BEGIN_REMOTE_CONFIG` / `# END_REMOTE_CONFIG`.
- Create: `lib/core/data/firebase_remote_config_repository.dart` (+ generated `.g.dart`)
- Test: `test/core/data/firebase_remote_config_repository_test.dart`

**Interfaces:**
- Consumes: `ConfigKey`, `ConfigKeys.all`, `RemoteConfigRepository` (Task 2).
- Produces:
  - `class FirebaseRemoteConfigRepository implements RemoteConfigRepository`, constructed as `FirebaseRemoteConfigRepository(FirebaseRemoteConfig remoteConfig)`. The parameter and its field sit inside markers, the same way `PostHogAnalyticsRepository` handles `Posthog`.
  - `@Riverpod(keepAlive: true) RemoteConfigRepository remoteConfigRepository(Ref ref)`, which returns `FirebaseRemoteConfigRepository(FirebaseRemoteConfig.instance)`. The argument sits inside markers.
  - `remoteConfigRepositoryProvider` (generated)

**Behavior (spec §4–§5):**
- `initialize()` steps, each with its own try/catch that also catches synchronous throws:
  1. `setConfigSettings(RemoteConfigSettings(fetchTimeout: Duration(seconds: 10), minimumFetchInterval: minimumFetchInterval))`
  2. `setDefaults({for (final k in ConfigKeys.all) k.key: k.defaultValue})`
  3. `setCustomSignals({'environment': environment})`
  4. `await activate()`
  5. `unawaited(_fetchInBackground())`
- Log levels: `_log.error` for failures in steps 1–4, `_log.warning` for a fetch failure.
- `_fetchInBackground()`: if `fetchAndActivate()` returns `true`, add to a `StreamController<void>.broadcast()`. It catches every error; nothing escapes.
- `onUpdated` returns `_updates.stream`. The controller is **outside** the markers, so the stripped variant compiles and simply never emits.
- `get()` structure, so that both variants are free of dead code:

```dart
@override
T get<T extends Object>(ConfigKey<T> key) {
  // BEGIN_REMOTE_CONFIG
  final value = _read(key);
  if (value != null) return value;
  // END_REMOTE_CONFIG
  return key.defaultValue;
}
```

- `T? _read<T extends Object>(ConfigKey<T> key)` lives inside markers. It wraps `getValue` in a try/catch and returns null when:
  - the source is `ValueSource.valueStatic`
  - a `bool` value is not exactly `"true"`/`"false"`
  - `int.tryParse` / `double.tryParse` on the raw string return null (tryParse is applied to the raw string; Dart's tryParse trims surrounding whitespace itself)
  - `T` is an unsupported type, which also logs a warning once per key
  - `String` returns `asString()` as-is, including `""`.

- [ ] **Step 1: Add the dependency**

Run: `fvm flutter pub get`
Expected: resolves. `pubspec.lock` gets `firebase_remote_config 6.2.x`.

- [ ] **Step 2: Write the failing tests**

Test file layout follows `posthog_analytics_repository_test.dart`:
- `class MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}` sits in markers.
- `setUp` (SDK part in markers) stubs every SDK method to succeed: `getValue` returns `RemoteConfigValue(null, ValueSource.valueStatic)` and `fetchAndActivate` returns `false`.
- `registerFallbackValue(RemoteConfigSettings(fetchTimeout: Duration.zero, minimumFetchInterval: Duration.zero))` is called in `setUpAll`.
- Tests use local keys: `const s = ConfigKey<String>('s', 'd'); const b = ConfigKey<bool>('b', true); const i = ConfigKey<int>('i', 7); const d = ConfigKey<double>('d', 1.5);`.
- Helper: `RemoteConfigValue remote(String v) => RemoteConfigValue(utf8.encode(v), ValueSource.valueRemote);`

**Unmarked group** (runs in both variants):
- `Given an unset key, When get is called, Then the default is returned`: each of `s`, `b`, `i`, `d` returns its default.
- `Given initialize, When called, Then it completes`: use `expectLater(..., completes)`.

**Marked group `initialize`:**
- `Then it calls settings, defaults, signals, activate, fetchAndActivate in order`: uses `verifyInOrder`.
  - The settings are captured and have `fetchTimeout == Duration(seconds: 10)` and the passed interval.
  - The defaults equal `{'api_base_url': ConfigKeys.apiBaseUrl.defaultValue}`.
  - The signals equal `{'environment': 'staging'}`.
- `Given fetchAndActivate never completes, When initialize is awaited, Then it still completes`: stub with a `Completer<bool>().future`.
- `Given fetchAndActivate returns true, Then onUpdated emits once`: `expectLater(repo.onUpdated, emits(null))` is set up before `initialize`.
- `Given fetchAndActivate returns false, Then onUpdated does not emit`: listen, `await pumpEventQueue()`, then expect no events.
- `Given fetchAndActivate fails after initialize returned, Then no uncaught error`: stub with a completer, call `initialize`, then `completer.completeError(Exception('offline'))` and `await pumpEventQueue()`. The test zone would fail on an uncaught error, and no emit is expected.
- `Then fetchAndActivate is called exactly once`.
- For each of `setConfigSettings`, `setDefaults`, `setCustomSignals`, `activate`, `fetchAndActivate`: `Given <step> throws synchronously, Then initialize completes and later steps still run`. Use `thenThrow`, then `verify` each later step `.called(1)`.

**Marked group `get`, with values stubbed through `remote(...)`:**
- String `'hello'` → `'hello'`; `''` → `''`
- bool `'true'` → true, `'false'` → false; `'TRUE'`, `'1'` and `'yes'` → default `true`
- int `'42'` → 42; `'abc'`, `'3.0'` → default 7; `' 8 '` → 8
- double `'2.5'` → 2.5; `'3'` → 3.0; `'x'` → default 1.5
- `valueStatic` → default
- `ConfigKey<DateTime>` → default, with no throw
- `getValue` throws → default

- [ ] **Step 3: Run the tests to verify they fail**

Run: `fvm flutter test test/core/data/firebase_remote_config_repository_test.dart`
Expected: FAIL with an import error.

- [ ] **Step 4: Implement the repository and provider, then generate code**

Run: `make codegen`
Expected: `firebase_remote_config_repository.g.dart` is generated.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `fvm flutter test test/core/data/firebase_remote_config_repository_test.dart && make analyze`
Expected: PASS, and analyze is clean.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/data/firebase_remote_config_repository*.dart test/core/data/firebase_remote_config_repository_test.dart
git commit -m "feat: add FirebaseRemoteConfigRepository"
```

---

### Task 5: `remoteConfigRevisionProvider` and `watchConfig`

**Files:**
- Create: `lib/core/providers/remote_config_revision_provider.dart` (+ `.g.dart`)
- Test: `test/core/providers/remote_config_revision_provider_test.dart`
- Modify: `test/helpers/fakes.dart`, to add `FakeRemoteConfigRepository`

**Interfaces:**
- Consumes: `remoteConfigRepositoryProvider`, `RemoteConfigRepository` (Tasks 2 and 4).
- Produces:
  - `@Riverpod(keepAlive: true) class RemoteConfigRevision extends _$RemoteConfigRevision { int build(); }`, generated as `remoteConfigRevisionProvider`. It starts at 0 and increments on each `onUpdated` event. It cancels its subscription in `ref.onDispose`.
  - `extension RemoteConfigRef on Ref { T watchConfig<T extends Object>(ConfigKey<T> key); }`
  - `extension RemoteConfigWidgetRef on WidgetRef { T watchConfig<T extends Object>(ConfigKey<T> key); }`
  - Both extensions watch the revision first, then `read` the repository and call `get(key)`.
  - `FakeRemoteConfigRepository implements RemoteConfigRepository` (in `test/helpers/fakes.dart`):
    - `Map<String, Object> values`
    - `void update(Map<String, Object> next)`: replaces the values and emits `onUpdated`
    - `get` returns `values[key.key] as T? ?? key.defaultValue`
    - `initialize` is a no-op

- [ ] **Step 1: Write the failing tests**

Use `ProviderContainer(overrides: [remoteConfigRepositoryProvider.overrideWithValue(fake)])`. Test-local key: `const flag = ConfigKey<bool>('flag', false);`.
- `Given no updates, When read, Then the revision is 0`.
- `Given two onUpdated events, When read, Then the revision is 2`: call `fake.update` twice, then `await pumpEventQueue()`.
- `Given a provider using ref.watchConfig, When the fake updates flag to true, Then the provider recomputes to true`. Define a test-local `final probe = Provider<bool>((ref) => ref.watchConfig(flag));`, and keep it alive with `container.listen`.
- `Given values changed before anything watched, When watchConfig is first read, Then it returns the new value`. Call `fake.update({'flag': true})` before creating `probe`. This is Review Focus 3.
- Widget test: `Given a ConsumerWidget showing ref.watchConfig(flag), When the fake updates, Then the text changes from "false" to "true"`. Pump with `pumpApp(..., overrides: [...])`, call `fake.update`, then `await tester.pump()`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/core/providers/remote_config_revision_provider_test.dart`
Expected: FAIL with an import error.

- [ ] **Step 3: Implement, then run `make codegen`**

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/core/providers/ && make analyze`
Expected: PASS, and analyze is clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/remote_config_revision_provider*.dart test/core/providers/remote_config_revision_provider_test.dart test/helpers/fakes.dart
git commit -m "feat: add watchConfig with Remote Config revision provider"
```

---

### Task 6: Wire into `main.dart` and env files

**Files:**
- Modify: `lib/main.dart`
- Modify: `.env.staging.example`, `.env.production.example`

**Interfaces:**
- Consumes: `FirebaseRemoteConfigRepository`, `remoteConfigRepositoryProvider` (Task 4), and `AppEnv.remoteConfigMinFetchInterval` (Task 3).

- [ ] **Step 1: Edit `main.dart`**, with every addition inside `REMOTE_CONFIG` markers:
  - Imports: `firebase_remote_config`, and `firebase_remote_config_repository.dart`.
  - `const _remoteConfigEnv = String.fromEnvironment('REMOTE_CONFIG_ENV');` goes next to the other env constants.
  - After the App Check token pre-warm and before the notifications block:
    - create `final remoteConfig = FirebaseRemoteConfigRepository(FirebaseRemoteConfig.instance);`
    - `await remoteConfig.initialize(...)`, as in spec §3.3
  - Build the overrides as a variable, so the stripped variant (an empty list) does not trigger a `prefer_const_constructors` lint:
    - `final overrides = <Override>[` (`Override` from `package:flutter_riverpod/misc.dart`)
    - inside markers: `remoteConfigRepositoryProvider.overrideWithValue(remoteConfig),`
    - `];`
    - `startApp` becomes `runApp(ProviderScope(overrides: overrides, child: const App()))`.

- [ ] **Step 2: Edit both `.env.*.example` files.** Add the block from spec §6 verbatim, after `FIREBASE_AUTH_DOMAIN`. `API_BASE_URL` stays outside markers. `REMOTE_CONFIG_ENV` goes inside `# BEGIN_REMOTE_CONFIG` / `# END_REMOTE_CONFIG`.

- [ ] **Step 3: Verify the enabled variant**

Run: `make analyze && make test && make check-test-layout && make coverage`
Expected: all pass, and the coverage gate reports no failing layer.

- [ ] **Step 4: Verify both init variants**

Run: `tool/verify_init.sh --yes --name blueprint_ci`
Then: `tool/verify_init.sh --yes --name blueprint_ci --no-notifications --no-posthog --no-sentry --no-functions --no-apple --no-google --no-remote-config`
Expected: both end successfully (analyze, check-test-layout and coverage pass in the generated copy). In the second copy, `grep -r firebase_remote_config lib pubspec.yaml` prints nothing.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart .env.staging.example .env.production.example
git commit -m "feat: initialize Remote Config at startup"
```

---

### Task 7: Documentation and changelog

**Files:**
- Modify: `docs/setup.md`: a new "Remote Config" section, plus `API_BASE_URL` / `REMOTE_CONFIG_ENV` in the env var list near line 128
- Modify: `AGENTS.md`: the keepAlive list (§2.3), the SDK-confinement veto (§1.2), and a rule to read only through `RemoteConfigRepository` / `ConfigKeys`
- Modify: `docs/tech.md`: the Key Packages table and the `core/domain`, `core/data`, `core/providers` lines in the tree
- Modify: `CHANGELOG.md`: an `Unreleased` entry

- [ ] **Step 1: Write the docs.** Content to cover is in spec §10:
  - creating the `environment` custom-signal conditions in the Console
  - adding a key (one line in `ConfigKeys`, then the Console parameter)
  - the loading strategy (cache → defaults → one background fetch per launch, new values applied in the same session)
  - `watchConfig` compared with `get`
  - the `apiBaseUrl` per-request convention
  - the shared-project note (Auth, Firestore and App Check are shared too)

  Remote Config-only sections are wrapped in `<!-- BEGIN_REMOTE_CONFIG -->` / `<!-- END_REMOTE_CONFIG -->`. The `API_BASE_URL` line is not wrapped.

- [ ] **Step 2: Verify that markers stay valid**

Run: `fvm flutter test test/tool/`
Expected: PASS. The marker scan accepts the new Markdown markers.

- [ ] **Step 3: Commit**

```bash
git add docs/setup.md AGENTS.md docs/tech.md CHANGELOG.md
git commit -m "docs: document Firebase Remote Config"
```

---

### Task 8: Final verification

- [ ] **Step 1:** Run `make release-preflight`. Expected: format, analyze, layout and coverage all pass.
- [ ] **Step 2 (needs a simulator or emulator):** Run `make test-integration DEVICE=<id>`. Expected: PASS. The app runs on defaults, since the emulator has no Remote Config. If no device is available, report the step as skipped rather than passed.
