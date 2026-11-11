import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
// BEGIN_REMOTE_CONFIG
import 'package:firebase_remote_config/firebase_remote_config.dart';
// END_REMOTE_CONFIG
// BEGIN_GOOGLE
import 'package:google_sign_in/google_sign_in.dart';
// END_GOOGLE
// BEGIN_POSTHOG
import 'package:posthog_flutter/posthog_flutter.dart';
// END_POSTHOG
// BEGIN_SENTRY
import 'package:sentry_flutter/sentry_flutter.dart';
// END_SENTRY
import 'package:blueprint_app/app.dart';
import 'package:blueprint_app/core/config/app_env.dart';
// BEGIN_NOTIFICATIONS
import 'package:blueprint_app/core/services/timezone_sync_service.dart';
import 'package:workmanager/workmanager.dart';
// END_NOTIFICATIONS
// BEGIN_REMOTE_CONFIG
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
// END_REMOTE_CONFIG
import 'package:blueprint_app/core/utils/app_logger.dart';

// TODO: Generate one file per Firebase project with:
//   flutterfire configure --project=<staging-project-id> --out=lib/firebase_options_staging.dart
//   flutterfire configure --project=<production-project-id> --out=lib/firebase_options_production.dart
import 'package:blueprint_app/firebase_options_production.dart'
    as production_firebase;
import 'package:blueprint_app/firebase_options_staging.dart'
    as staging_firebase;

// Keys injected via --dart-define at build time from .env.<flavor>.
// Use `make run-staging` / `make run-prod`. If these are empty at runtime,
// run `fvm flutter clean` first.
// BEGIN_POSTHOG
const _postHogKey = String.fromEnvironment('POSTHOG_API_KEY');
const _postHogHost = String.fromEnvironment('POSTHOG_HOST');
// END_POSTHOG
// BEGIN_SENTRY
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');
// END_SENTRY
// BEGIN_REMOTE_CONFIG
const _remoteConfigEnv = String.fromEnvironment('REMOTE_CONFIG_ENV');
// END_REMOTE_CONFIG
const _firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The flavor picks the environment, so bundle id and config cannot diverge.
  final env = AppEnv.fromFlavor(appFlavor);
  // Debug-build diagnostics (SDK logs, PostHog opt-out) for this environment.
  // Unused only when both PostHog and Sentry are removed.
  // ignore: unused_local_variable
  final verboseSdks = kDebugMode && env.verboseSdksInDebug;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // BEGIN_POSTHOG
  assert(
    _postHogKey.isNotEmpty,
    'POSTHOG_API_KEY missing: run fvm flutter clean then make run-staging '
    'or make run-prod',
  );

  // 1. PostHog: fully anonymous, no person profiles
  final postHogConfig = PostHogConfig(_postHogKey)
    ..debug = verboseSdks
    ..optOut =
        verboseSdks // silence events in staging debug/simulator runs
    ..captureApplicationLifecycleEvents = true
    ..personProfiles = PostHogPersonProfiles.never;
  if (_postHogHost.isNotEmpty) {
    postHogConfig.host = _postHogHost;
  }
  await Posthog().setup(postHogConfig);
  await Posthog().register('environment', env.name);
  // END_POSTHOG

  // 2. Logging (must be before Firebase/Sentry init)
  initLogging();

  // 3. Firebase
  final firebaseOptions = switch (env) {
    AppEnv.staging => staging_firebase.DefaultFirebaseOptions.currentPlatform,
    AppEnv.production =>
      production_firebase.DefaultFirebaseOptions.currentPlatform,
  };
  env.ensureFirebaseConfigured(firebaseOptions.projectId);
  await Firebase.initializeApp(
    options: _firebaseAuthDomain.isEmpty
        ? firebaseOptions
        : FirebaseOptions(
            apiKey: firebaseOptions.apiKey,
            appId: firebaseOptions.appId,
            messagingSenderId: firebaseOptions.messagingSenderId,
            projectId: firebaseOptions.projectId,
            authDomain: _firebaseAuthDomain,
            storageBucket: firebaseOptions.storageBucket,
            databaseURL: firebaseOptions.databaseURL,
            measurementId: firebaseOptions.measurementId,
            trackingId: firebaseOptions.trackingId,
            deepLinkURLScheme: firebaseOptions.deepLinkURLScheme,
            androidClientId: firebaseOptions.androidClientId,
            iosClientId: firebaseOptions.iosClientId,
            iosBundleId: firebaseOptions.iosBundleId,
            appGroupId: firebaseOptions.appGroupId,
          ),
  );

  // BEGIN_GOOGLE
  const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  await GoogleSignIn.instance.initialize(
    serverClientId: googleServerClientId.isNotEmpty
        ? googleServerClientId
        : null,
  );
  // END_GOOGLE

  // App Check: debug providers outside production release builds.
  // Staging always uses them, so never submit a staging build to the stores.
  const appCheckTokenIos = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN_IOS');
  const appCheckTokenAndroid = String.fromEnvironment(
    'APP_CHECK_DEBUG_TOKEN_ANDROID',
  );
  final useDebugAppCheck = env.alwaysUseDebugAppCheck || !kReleaseMode;
  await FirebaseAppCheck.instance.activate(
    providerAndroid: useDebugAppCheck
        ? AndroidDebugProvider(
            debugToken: appCheckTokenAndroid.isNotEmpty
                ? appCheckTokenAndroid
                : null,
          )
        : const AndroidPlayIntegrityProvider(),
    providerApple: useDebugAppCheck
        ? AppleDebugProvider(
            debugToken: appCheckTokenIos.isNotEmpty ? appCheckTokenIos : null,
          )
        : const AppleDeviceCheckProvider(),
  );
  // Pre-warm token so the first Firestore request is not denied
  try {
    await FirebaseAppCheck.instance.getToken(true);
  } catch (_) {}

  // BEGIN_REMOTE_CONFIG
  final remoteConfig = FirebaseRemoteConfigRepository(
    FirebaseRemoteConfig.instance,
  );
  await remoteConfig.initialize(
    environment: _remoteConfigEnv.isNotEmpty ? _remoteConfigEnv : env.name,
    minimumFetchInterval: env.remoteConfigMinFetchInterval,
  );
  // END_REMOTE_CONFIG

  // BEGIN_NOTIFICATIONS
  await Workmanager().initialize(timezoneSyncCallbackDispatcher);
  await TimezoneSyncService.registerPeriodicTask();
  // END_NOTIFICATIONS

  final overrides = <Override>[
    // BEGIN_REMOTE_CONFIG
    remoteConfigRepositoryProvider.overrideWithValue(remoteConfig),
    // END_REMOTE_CONFIG
  ];

  void startApp() =>
      runApp(ProviderScope(overrides: overrides, child: const App()));

  // BEGIN_SENTRY
  // 4. Sentry wraps runApp; captures Flutter framework errors automatically
  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      options.environment = env.name;
      options.tracesSampleRate = env.sentryTracesSampleRate;
      options.sendDefaultPii = false;
      options.debug = verboseSdks;
    }, appRunner: startApp);
    return;
  }
  // END_SENTRY
  startApp();
}
