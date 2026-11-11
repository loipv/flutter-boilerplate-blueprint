# Firebase Remote Config Design

Date: 2026-11-11
Status: approved in conversation, pending written-spec review

## 1. Goal

The blueprint ships Firebase Remote Config as an optional feature. Apps use it to set values such as the base API endpoint and feature flags from the Firebase Console without a new release.

Staging and production may share one Firebase project. Remote Config values must still differ per environment.

### Success criteria

1. A feature reads a typed value with one call: `ref.read(remoteConfigRepositoryProvider).get(ConfigKeys.someKey)`. Adding a key means adding one line to `ConfigKeys`.
2. Cold start never waits on the network for Remote Config, and a Remote Config failure never stops the app from starting.
3. One parameter in the Console, plus a condition on the `environment` custom signal, gives staging and production different values inside one Firebase project.
4. On first install or offline, `apiBaseUrl` falls back to the per-flavor `API_BASE_URL` from `.env`, so a staging build never defaults to the production API.
5. `tool/init.dart` can turn Remote Config off. Code that reads `ConfigKeys` still compiles and gets the defaults.
6. `make analyze`, `make check-test-layout` and `make coverage` pass. `tool/verify_init.sh` passes with Remote Config both on and off.

## 2. Decisions

| # | Decision | Chosen |
|---|---|---|
| D1 | Place in the blueprint | Optional init feature `remoteConfig`, marker `REMOTE_CONFIG`, following the PostHog pattern: with the feature off, the repository class stays and its SDK code is stripped. |
| D2 | Per-environment values in one project | Custom signal `environment`, set on the client. The value comes from `REMOTE_CONFIG_ENV` in `.env`, or `AppEnv.name` when blank. The Console uses conditions on this signal. This works even with `--shared-app-id`. |
| D3 | Base API endpoint | Only exposed as a typed value (`ConfigKeys.apiBaseUrl`). No HTTP client is added. |
| D4 | Loading strategy | Activate cached values at startup, fetch in the background, use the new values on the next launch. Values do not change within a session. No real-time updates. |
| D5 | Key declaration | A central registry of `ConfigKey<T>` constants in `ConfigKeys`. Defaults sent to the SDK come from `ConfigKeys.all`. |
| D6 | Supported types | `String`, `bool`, `int`, `double`. No JSON values. |

## 3. Architecture

Remote Config is shared by the whole app, so it lives in `lib/core/`, next to `AnalyticsRepository`.

### 3.1 Domain (pure Dart)

**`lib/core/domain/config_key.dart`**

```dart
/// A typed Remote Config parameter. [T] is String, bool, int or double.
class ConfigKey<T extends Object> {
  const ConfigKey(this.key, this.defaultValue);
  final String key;
  final T defaultValue;
}
```

**`lib/core/domain/config_keys.dart`**: the one file app developers edit.

```dart
abstract final class ConfigKeys {
  /// Base URL for the app's HTTP API. Defaults to API_BASE_URL from .env.
  static const apiBaseUrl = ConfigKey<String>(
    'api_base_url',
    String.fromEnvironment('API_BASE_URL'),
  );

  /// Every key. Add new keys here too; it feeds the SDK defaults.
  static const List<ConfigKey<Object>> all = [apiBaseUrl];
}
```

The doc comment shows how to add a feature flag, for example `static const newHomeEnabled = ConfigKey<bool>('new_home_enabled', false);`. The blueprint does not ship an unused flag.

**`lib/core/domain/remote_config_repository.dart`**

```dart
abstract class RemoteConfigRepository {
  /// Applies settings, defaults and the environment signal, activates cached
  /// values and starts a background fetch for the next launch.
  /// Never throws.
  Future<void> initialize({
    required String environment,
    required Duration minimumFetchInterval,
  });

  /// The active value for [key], or [ConfigKey.defaultValue] when the key is
  /// unset or its value has the wrong type. Never throws.
  T get<T extends Object>(ConfigKey<T> key);
}
```

### 3.2 Data

**`lib/core/data/firebase_remote_config_repository.dart`** is the only file that imports `firebase_remote_config`.

- `FirebaseRemoteConfigRepository implements RemoteConfigRepository` takes a `FirebaseRemoteConfig` through its constructor, so tests can pass a mock.
- `@Riverpod(keepAlive: true) RemoteConfigRepository remoteConfigRepository(Ref ref)` returns `FirebaseRemoteConfigRepository(FirebaseRemoteConfig.instance)`.
- `FirebaseRemoteConfig.instance` is a singleton. The instance that `main.dart` initializes and the one the provider returns share the activated values. `main.dart` therefore does not override the provider, and `ProviderScope` stays `const`.
- SDK code is wrapped in `// BEGIN_REMOTE_CONFIG` / `// END_REMOTE_CONFIG`. With the feature off, `initialize()` does nothing and `get()` returns `key.defaultValue`. The provider then builds the class without an SDK instance, the same way `PostHogAnalyticsRepository` drops its `Posthog` field.
- `static const _log = AppLogger('FirebaseRemoteConfigRepository')`.

### 3.3 Config and entrypoint

- `AppEnv` gets `remoteConfigMinFetchInterval`: 5 minutes for staging, 1 hour for production. This field is wrapped in the marker.
- `lib/main.dart` (inside the marker): `const _remoteConfigEnv = String.fromEnvironment('REMOTE_CONFIG_ENV');`. After App Check activation and before `runApp`:

```dart
await FirebaseRemoteConfigRepository(FirebaseRemoteConfig.instance).initialize(
  environment: _remoteConfigEnv.isNotEmpty ? _remoteConfigEnv : env.name,
  minimumFetchInterval: env.remoteConfigMinFetchInterval,
);
```

Remote Config runs after App Check, so fetches carry an App Check token if the project enforces it.

## 4. Data flow

`initialize()` runs these steps in order. Each step has its own try/catch.

1. `setConfigSettings(RemoteConfigSettings(fetchTimeout: 10s, minimumFetchInterval: <param>))`
2. `setDefaults({for k in ConfigKeys.all: k.key: k.defaultValue})`
3. `setCustomSignals({'environment': environment})`. This must come before the fetch, because the server evaluates conditions on fetch.
4. `await activate()`: applies the values fetched on a previous launch. This is a local read and does not wait on the network.
5. `unawaited(fetch())`: fetches in the background. The new values are activated at step 4 of the next launch.

`get<T>(key)` reads `getValue(key.key)`:

- If `source == ValueSource.valueStatic` (no server value and no default), return `key.defaultValue`.
- `String`: `asString()`.
- `bool`: `"true"` → true, `"false"` → false, anything else → default. The SDK's `asBool()` is not used because it silently returns false.
- `int`: `int.tryParse(asString())`, or default on null.
- `double`: `double.tryParse(asString())`, or default on null.
- Any other `T`: return default, and log a warning once per key.

## 5. Error handling

- `initialize()` never throws and never blocks startup on the network.
  - `fetch()` failures (offline, throttled, timeout) are expected. Log them with `_log.warning`, so they do not reach Sentry.
  - `setConfigSettings`, `setDefaults`, `setCustomSignals` and `activate` failures are logged with `_log.error`. Later steps still run.
- `get()` never throws. Bad or missing values fall back to `defaultValue`.
- Neither method lets an exception out, so no `Failure` mapping is needed. `FirebaseException` stays in the data layer, as `AnalyticsRepository` does.

## 6. Environment variables

These are added to `.env.staging.example` and `.env.production.example`. `docs/setup.md` documents them.

```
# Base URL for your HTTP API. Default for ConfigKeys.apiBaseUrl when Remote
# Config has no value yet (first install, offline).
API_BASE_URL=

# BEGIN_REMOTE_CONFIG
# Optional. Value of the Remote Config custom signal "environment".
# Blank = flavor name (staging / production).
REMOTE_CONFIG_ENV=
# END_REMOTE_CONFIG
```

`API_BASE_URL` stays when Remote Config is off, because it is still the default.

The `Makefile` `dart_defines` helper already turns every `KEY=VALUE` line of the env file into a `--dart-define`, so the `make` targets need no change.

## 7. Init integration

- `tool/src/options.dart`: add `Feature.remoteConfig`, with CLI flag `--no-remote-config` and an interactive prompt, the same way the PostHog and Sentry features work.
- `tool/src/manifest.dart`: `Feature.remoteConfig: FeatureRule(markers: ['REMOTE_CONFIG'])`.
- Markers wrap:
  - the `firebase_remote_config` dependency in `pubspec.yaml`
  - the import, the `REMOTE_CONFIG_ENV` constant and the initialize block in `main.dart`
  - `remoteConfigMinFetchInterval` in `AppEnv`, and its test
  - SDK code in `FirebaseRemoteConfigRepository`, and the SDK-dependent tests
  - `REMOTE_CONFIG_ENV` in the `.env.*.example` files
  - Remote Config-only sections in docs
- Not wrapped: `ConfigKey`, `ConfigKeys`, `RemoteConfigRepository`, the provider, and `API_BASE_URL`.
- `test/tool/` tests are updated for the new feature. `tool/verify_init.sh` adds a `--no-remote-config` run.

## 8. Dependencies

- `firebase_remote_config`: pick the newest version that is compatible with `firebase_core ^4.6.0` and has `setCustomSignals`. Check this at implementation time.
- No new dev dependencies. Tests use Mocktail.

## 9. Testing

All tests use Mocktail. None of them need Firebase.

**`test/core/data/firebase_remote_config_repository_test.dart`**
- `initialize()` calls settings → defaults → signals → activate → fetch, in that order, with the right arguments. The defaults map matches `ConfigKeys.all`.
- `initialize()` completes before a pending `fetch()` does. The fetch is not awaited.
- `initialize()` completes without throwing when `fetch`, `activate`, `setCustomSignals` or `setDefaults` throws, and the later steps still run.
- `get()` covers:
  - each of the 4 types with a valid remote value
  - `valueStatic` → default
  - an `int` key with a non-numeric value → default
  - a `bool` key with a value other than `"true"`/`"false"` → default
  - an empty string for a `String` key → empty string, because an empty value is a valid remote value
- Tests use test-local `ConfigKey`s, so they do not depend on what `ConfigKeys` ships.

**`test/core/domain/config_keys_test.dart`**
- Keys in `ConfigKeys.all` are unique.
- `ConfigKeys.apiBaseUrl` is in `all`.

**`test/core/config/app_env_test.dart`**: the fetch interval for each environment.

**Coverage**: the new data file meets the data-layer threshold of the coverage gate.

**Integration**: the Firebase Emulator does not support Remote Config. The existing `make test-integration` flow must still pass, with a failed fetch logged as a warning and the app running on defaults.

## 10. Documentation

- `docs/setup.md` gets a Remote Config section covering:
  - enabling Remote Config in the Console
  - creating the custom signal condition `environment == staging` (and production)
  - adding a key: one line in `ConfigKeys`, then the parameter in the Console
  - the loading strategy: new values apply on the next launch
  - a note that sharing one project for both flavors also shares Auth, Firestore and App Check
- `AGENTS.md`:
  - add `FirebaseRemoteConfigRepository` (as `RemoteConfigRepository`) to the keepAlive list
  - restrict `firebase_remote_config` imports to `core/data/` and entrypoints
  - read Remote Config only through `RemoteConfigRepository` and `ConfigKeys`
- `docs/tech.md`: add the package and directory tree entries.
- `CHANGELOG.md`: add an Unreleased entry. Releasing a blueprint version is a separate task.

## 11. Out of scope

- An HTTP client or API layer.
- Real-time Remote Config updates (`onConfigUpdated`).
- JSON-valued parameters.
- Remote Config UI (debug screens, overrides).
- Splitting staging and production into one shared Firebase project. This design only makes Remote Config work if a team does that.
