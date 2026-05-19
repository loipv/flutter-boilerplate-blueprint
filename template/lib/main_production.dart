import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// BEGIN_GOOGLE
import 'package:google_sign_in/google_sign_in.dart';
// END_GOOGLE
// BEGIN_POSTHOG
import 'package:posthog_flutter/posthog_flutter.dart';
// END_POSTHOG
// BEGIN_SENTRY
import 'package:sentry_flutter/sentry_flutter.dart';
// END_SENTRY
import 'package:__APP_PACKAGE__/app.dart';
// BEGIN_NOTIFICATIONS
import 'package:__APP_PACKAGE__/core/services/timezone_sync_service.dart';
import 'package:workmanager/workmanager.dart';
// END_NOTIFICATIONS
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';

// TODO: Generate with:
//   flutterfire configure --project=<production-project-id> --out=lib/firebase_options_production.dart
import 'firebase_options_production.dart';

// BEGIN_POSTHOG
const _postHogKey = String.fromEnvironment('POSTHOG_API_KEY');
const _postHogHost = String.fromEnvironment('POSTHOG_HOST');
// END_POSTHOG
// BEGIN_SENTRY
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');
// END_SENTRY
const _firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // BEGIN_SENTRY
  assert(
    _sentryDsn.isNotEmpty,
    'SENTRY_DSN missing: run __FLUTTER_CMD__ clean then make run-prod',
  );
  // END_SENTRY
  // BEGIN_POSTHOG
  assert(
    _postHogKey.isNotEmpty,
    'POSTHOG_API_KEY missing: run __FLUTTER_CMD__ clean then make run-prod',
  );

  // 1. PostHog
  final postHogConfig = PostHogConfig(_postHogKey)
    ..debug = false
    ..optOut = false
    ..captureApplicationLifecycleEvents = true
    ..personProfiles = PostHogPersonProfiles.never;
  if (_postHogHost.isNotEmpty) {
    postHogConfig.host = _postHogHost;
  }
  await Posthog().setup(postHogConfig);
  await Posthog().register('environment', 'production');
  // END_POSTHOG

  // 2. Logging
  initLogging();

  // 3. Firebase
  final firebaseOptions = ProductionFirebaseOptions.currentPlatform;
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

  const appCheckTokenIos = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN_IOS');
  const appCheckTokenAndroid = String.fromEnvironment(
    'APP_CHECK_DEBUG_TOKEN_ANDROID',
  );
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : AndroidDebugProvider(
            debugToken: appCheckTokenAndroid.isNotEmpty
                ? appCheckTokenAndroid
                : null,
          ),
    providerApple: kReleaseMode
        ? const AppleDeviceCheckProvider()
        : AppleDebugProvider(
            debugToken: appCheckTokenIos.isNotEmpty ? appCheckTokenIos : null,
          ),
  );
  try {
    await FirebaseAppCheck.instance.getToken(true);
  } catch (_) {}

  // BEGIN_NOTIFICATIONS
  await Workmanager().initialize(timezoneSyncCallbackDispatcher);
  await TimezoneSyncService.registerPeriodicTask();
  // END_NOTIFICATIONS

  // BEGIN_SENTRY
  // 4. Sentry
  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.environment = 'production';
    options.tracesSampleRate = 0.2;
    options.sendDefaultPii = false;
  }, appRunner: () => runApp(const ProviderScope(child: App())));
  // END_SENTRY
  // BEGIN_NO_SENTRY
  runApp(const ProviderScope(child: App()));
  // END_NO_SENTRY
}
