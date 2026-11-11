import 'package:blueprint_app/core/domain/config_key.dart';

/// Backend-agnostic contract for remote configuration.
///
/// The concrete implementation lives in `core/data/`.
abstract class RemoteConfigRepository {
  /// Applies settings, defaults and the environment signal, activates cached
  /// values and starts one background fetchAndActivate. Never throws.
  Future<void> initialize({
    required String environment,
    required Duration minimumFetchInterval,
  });

  /// The active value for [key], or [ConfigKey.defaultValue] when the key is
  /// unset or its value has the wrong type. Never throws.
  T get<T extends Object>(ConfigKey<T> key);

  /// Emits after the background fetch activates new values. Broadcast; never
  /// emits an error.
  Stream<void> get onUpdated;
}
