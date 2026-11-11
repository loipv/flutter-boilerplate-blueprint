import 'dart:async';

// BEGIN_REMOTE_CONFIG
import 'package:firebase_remote_config/firebase_remote_config.dart';
// END_REMOTE_CONFIG
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/domain/config_key.dart';
// BEGIN_REMOTE_CONFIG
import 'package:blueprint_app/core/domain/config_keys.dart';
// END_REMOTE_CONFIG
import 'package:blueprint_app/core/domain/remote_config_repository.dart';
// BEGIN_REMOTE_CONFIG
import 'package:blueprint_app/core/utils/app_logger.dart';
// END_REMOTE_CONFIG

part 'firebase_remote_config_repository.g.dart';

/// Firebase Remote Config implementation of [RemoteConfigRepository].
///
/// This is the ONLY file in the codebase (besides `main.dart`) that imports
/// `firebase_remote_config`. When Remote Config is disabled at scaffold time
/// the SDK calls are removed: [get] returns defaults and [onUpdated] never
/// emits, so callers remain unchanged.
class FirebaseRemoteConfigRepository implements RemoteConfigRepository {
  FirebaseRemoteConfigRepository(
    // BEGIN_REMOTE_CONFIG
    this._remoteConfig,
    // END_REMOTE_CONFIG
  );

  // BEGIN_REMOTE_CONFIG
  final FirebaseRemoteConfig _remoteConfig;
  static const _log = AppLogger('FirebaseRemoteConfigRepository');
  final Set<String> _warnedKeys = {};
  // END_REMOTE_CONFIG

  final StreamController<void> _updates = StreamController<void>.broadcast();

  @override
  Future<void> initialize({
    required String environment,
    required Duration minimumFetchInterval,
  }) async {
    // BEGIN_REMOTE_CONFIG
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: minimumFetchInterval,
        ),
      );
    } catch (e, st) {
      _log.error('setConfigSettings failed', error: e, stackTrace: st);
    }
    try {
      await _remoteConfig.setDefaults({
        for (final k in ConfigKeys.all) k.key: k.defaultValue,
      });
    } catch (e, st) {
      _log.error('setDefaults failed', error: e, stackTrace: st);
    }
    try {
      await _remoteConfig.setCustomSignals({'environment': environment});
    } catch (e, st) {
      _log.error('setCustomSignals failed', error: e, stackTrace: st);
    }
    try {
      await _remoteConfig.activate();
    } catch (e, st) {
      _log.error('activate failed', error: e, stackTrace: st);
    }
    unawaited(_fetchInBackground());
    // END_REMOTE_CONFIG
  }

  // BEGIN_REMOTE_CONFIG
  Future<void> _fetchInBackground() async {
    try {
      final activated = await _remoteConfig.fetchAndActivate();
      if (activated) _updates.add(null);
    } catch (e, st) {
      _log.warning('fetchAndActivate failed', error: e, stackTrace: st);
    }
  }

  // END_REMOTE_CONFIG

  @override
  T get<T extends Object>(ConfigKey<T> key) {
    // BEGIN_REMOTE_CONFIG
    final value = _read(key);
    if (value != null) return value;
    // END_REMOTE_CONFIG
    return key.defaultValue;
  }

  @override
  Stream<void> get onUpdated => _updates.stream;

  // BEGIN_REMOTE_CONFIG
  T? _read<T extends Object>(ConfigKey<T> key) {
    try {
      final raw = _remoteConfig.getValue(key.key);
      if (raw.source == ValueSource.valueStatic) return null;
      final text = raw.asString();
      final Object? parsed;
      switch (key.defaultValue) {
        case String _:
          parsed = text;
        case bool _:
          parsed = switch (text) {
            'true' => true,
            'false' => false,
            _ => null,
          };
        case int _:
          parsed = int.tryParse(text);
        case double _:
          parsed = double.tryParse(text);
        default:
          if (_warnedKeys.add(key.key)) {
            _log.warning(
              'Unsupported ConfigKey type for "${key.key}": '
              '${key.defaultValue.runtimeType}',
            );
          }
          return null;
      }
      return parsed as T?;
    } catch (e, st) {
      _log.warning('get failed for "${key.key}"', error: e, stackTrace: st);
      return null;
    }
  }

  // END_REMOTE_CONFIG
}

/// Exposes the ABSTRACT type so consumers never depend on Firebase directly.
@Riverpod(keepAlive: true)
RemoteConfigRepository remoteConfigRepository(Ref ref) {
  return FirebaseRemoteConfigRepository(
    // BEGIN_REMOTE_CONFIG
    FirebaseRemoteConfig.instance,
    // END_REMOTE_CONFIG
  );
}
