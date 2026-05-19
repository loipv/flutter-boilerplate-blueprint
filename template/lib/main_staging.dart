import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:__APP_PACKAGE__/app.dart';
// BEGIN_NOTIFICATIONS
import 'package:__APP_PACKAGE__/core/services/timezone_sync_service.dart';
import 'package:workmanager/workmanager.dart';
// END_NOTIFICATIONS
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';

// TODO: Generate with:
//   flutterfire configure --project=<staging-project-id> --out=lib/firebase_options_staging.dart
import 'firebase_options_staging.dart';

// Keys injected via --dart-define at build time. Source via `make run-staging`.
// If these are empty at runtime, run `__FLUTTER_CMD__ clean` first.
const _postHogKey = String.fromEnvironment('POSTHOG_API_KEY');
const _postHogHost = String.fromEnvironment('POSTHOG_HOST');
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const _firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  assert(
    _sentryDsn.isNotEmpty,
    'SENTRY_DSN missing: run __FLUTTER_CMD__ clean then make run-staging',
  );
  assert(
    _postHogKey.isNotEmpty,
    'POSTHOG_API_KEY missing: run __FLUTTER_CMD__ clean then make run-staging',
  );

  // 1. PostHog: fully anonymous, no person profiles
  final postHogConfig = PostHogConfig(_postHogKey)
    ..debug = kDebugMode
    ..optOut =
        kDebugMode // silence events in debug/simulator runs
    ..captureApplicationLifecycleEvents = true
    ..personProfiles = PostHogPersonProfiles.never;
  if (_postHogHost.isNotEmpty) {
    postHogConfig.host = _postHogHost;
  }
  await Posthog().setup(postHogConfig);
  await Posthog().register('environment', 'staging');

  // 2. Logging (must be before Firebase/Sentry init)
  initLogging();

  // 3. Firebase
  final firebaseOptions = StagingFirebaseOptions.currentPlatform;
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

  const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  await GoogleSignIn.instance.initialize(
    serverClientId: googleServerClientId.isNotEmpty
        ? googleServerClientId
        : null,
  );

  // App Check: debug providers for staging (never submit to stores)
  const appCheckTokenIos = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN_IOS');
  const appCheckTokenAndroid = String.fromEnvironment(
    'APP_CHECK_DEBUG_TOKEN_ANDROID',
  );
  await FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidDebugProvider(
      debugToken: appCheckTokenAndroid.isNotEmpty ? appCheckTokenAndroid : null,
    ),
    providerApple: AppleDebugProvider(
      debugToken: appCheckTokenIos.isNotEmpty ? appCheckTokenIos : null,
    ),
  );
  // Pre-warm token so the first Firestore request is not denied
  try {
    await FirebaseAppCheck.instance.getToken(true);
  } catch (_) {}

  // BEGIN_NOTIFICATIONS
  await Workmanager().initialize(timezoneSyncCallbackDispatcher);
  await TimezoneSyncService.registerPeriodicTask();
  // END_NOTIFICATIONS

  // 4. Sentry wraps runApp; captures Flutter framework errors automatically
  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.environment = 'staging';
    options.tracesSampleRate = 0.5;
    options.sendDefaultPii = false;
    options.debug = kDebugMode;
  }, appRunner: () => runApp(const ProviderScope(child: App())));
}
