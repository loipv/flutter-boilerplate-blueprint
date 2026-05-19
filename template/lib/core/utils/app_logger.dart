import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
// BEGIN_SENTRY
import 'package:sentry_flutter/sentry_flutter.dart';
// END_SENTRY

/// Initialise the root logging listener. Call once in `main()` before
/// `SentryFlutter.init`.
///
/// - DEBUG: console output + DevTools + Sentry error forwarding
/// - RELEASE: console silenced; only SEVERE (AppLogger.error) goes to Sentry
///
/// If you remove Sentry, delete the `sentry_flutter` import and the
/// `Sentry.captureException` block below.
void initLogging() {
  Logger.root.level = kReleaseMode ? Level.SEVERE : Level.ALL;

  Logger.root.onRecord.listen((record) {
    if (!kReleaseMode) {
      debugPrint(
        '[${record.level.name}] ${record.loggerName}: ${record.message}',
      );
      developer.log(
        record.message,
        name: record.loggerName,
        level: record.level.value,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    }

    // BEGIN_SENTRY
    // Forward SEVERE (AppLogger.error) to Sentry in all modes.
    if (record.level >= Level.SEVERE && record.error != null) {
      Sentry.captureException(
        record.error,
        stackTrace: record.stackTrace,
        withScope: (scope) async {
          await scope.setTag('logger', record.loggerName);
          scope.setContexts('log', {'message': record.message});
        },
      );
    }
    // END_SENTRY
  });
}

/// Lightweight structured logger backed by `package:logging`.
///
/// Usage:
/// ```dart
/// static const _log = AppLogger('MyRepository');
/// _log.info('Fetched 10 items');
/// _log.warning('Cache miss');
/// _log.error('Firestore timeout', error: e, stackTrace: st);
/// ```
class AppLogger {
  const AppLogger(this.name);
  final String name;

  Logger get _logger => Logger(name);

  void info(String message) => _logger.info(message);

  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.warning(message, error, stackTrace);

  /// Logs at SEVERE level. Automatically forwarded to Sentry in all modes.
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.severe(message, error, stackTrace);
}
