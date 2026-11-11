/// Runtime environment, selected by the build flavor (`--flavor staging` or
/// `--flavor production`). Holds the per-environment differences so a single
/// `lib/main.dart` serves both flavors. Secrets stay in `.env.<flavor>` and
/// reach the app through `--dart-define`.
enum AppEnv {
  staging(
    sentryTracesSampleRate: 0.5,
    verboseSdksInDebug: true,
    alwaysUseDebugAppCheck: true,
    // BEGIN_REMOTE_CONFIG
    remoteConfigMinFetchInterval: Duration(minutes: 5),
    // END_REMOTE_CONFIG
  ),
  production(
    sentryTracesSampleRate: 0.2,
    verboseSdksInDebug: false,
    alwaysUseDebugAppCheck: false,
    // BEGIN_REMOTE_CONFIG
    remoteConfigMinFetchInterval: Duration(hours: 1),
    // END_REMOTE_CONFIG
  );

  const AppEnv({
    required this.sentryTracesSampleRate,
    required this.verboseSdksInDebug,
    required this.alwaysUseDebugAppCheck,
    // BEGIN_REMOTE_CONFIG
    required this.remoteConfigMinFetchInterval,
    // END_REMOTE_CONFIG
  });

  /// Fraction of transactions Sentry traces.
  final double sentryTracesSampleRate;

  /// In debug builds: turns on SDK debug logs and opts PostHog out of sending.
  final bool verboseSdksInDebug;

  /// Uses App Check debug providers even in release builds. Staging builds
  /// must never be submitted to the stores.
  final bool alwaysUseDebugAppCheck;
  // BEGIN_REMOTE_CONFIG

  /// Minimum time between Remote Config network fetches. Shorter in staging so
  /// changes show up quickly during testing.
  final Duration remoteConfigMinFetchInterval;
  // END_REMOTE_CONFIG

  /// Throws [StateError] when [projectId] comes from the committed stub
  /// options file (`projectId: 'stub'`), i.e. `flutterfire configure` has not
  /// been run for this environment yet.
  void ensureFirebaseConfigured(String projectId) {
    if (projectId != 'stub') return;
    throw StateError(
      'Firebase for $name is not configured: '
      'lib/firebase_options_$name.dart is still a stub. Run '
      'flutterfire configure --project=<$name-project-id> '
      '--out=lib/firebase_options_$name.dart (see docs/setup.md).',
    );
  }

  /// Maps the build flavor (Flutter's `appFlavor`) to an environment.
  /// Throws [StateError] when the app was started without a known flavor.
  static AppEnv fromFlavor(String? flavor) => switch (flavor) {
    'staging' => AppEnv.staging,
    'production' => AppEnv.production,
    _ => throw StateError(
      'Unknown build flavor "$flavor". Run with --flavor staging or '
      '--flavor production (make run-staging / make run-prod).',
    ),
  };
}
