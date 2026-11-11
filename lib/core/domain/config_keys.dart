import 'package:blueprint_app/core/domain/config_key.dart';

/// Typed Remote Config keys. This is the one file app developers edit.
///
/// To add a feature flag, declare a key here and add it to [all], e.g.
/// `static const newHomeEnabled = ConfigKey<bool>('new_home_enabled', false);`
/// The blueprint does not ship an unused flag.
abstract final class ConfigKeys {
  /// Base URL for the app's HTTP API. Defaults to API_BASE_URL from .env.
  ///
  /// The value can change once, a few seconds after startup. Read it per
  /// request, or use `ref.watchConfig(ConfigKeys.apiBaseUrl)` so the HTTP
  /// client is rebuilt. A client that caches the URL when it is created keeps
  /// the old URL until the next launch.
  static const apiBaseUrl = ConfigKey<String>(
    'api_base_url',
    String.fromEnvironment('API_BASE_URL'),
  );

  /// Every key. Add new keys here too; it feeds the SDK defaults.
  static const List<ConfigKey<Object>> all = [apiBaseUrl];
}
