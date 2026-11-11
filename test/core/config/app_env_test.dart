import 'package:flutter_test/flutter_test.dart';

import 'package:blueprint_app/core/config/app_env.dart';

void main() {
  group('AppEnv.fromFlavor', () {
    test(
      'Given the staging flavor, When fromFlavor is called, Then it returns staging',
      () {
        expect(AppEnv.fromFlavor('staging'), AppEnv.staging);
      },
    );

    test(
      'Given the production flavor, When fromFlavor is called, Then it returns production',
      () {
        expect(AppEnv.fromFlavor('production'), AppEnv.production);
      },
    );

    test(
      'Given no flavor, When fromFlavor is called, Then it throws a StateError',
      () {
        expect(() => AppEnv.fromFlavor(null), throwsStateError);
      },
    );

    test(
      'Given an unknown flavor, When fromFlavor is called, Then it throws a StateError',
      () {
        expect(() => AppEnv.fromFlavor('dev'), throwsStateError);
        expect(() => AppEnv.fromFlavor('Staging'), throwsStateError);
      },
    );
  });

  group('ensureFirebaseConfigured', () {
    test(
      'Given a real project id, When ensureFirebaseConfigured is called, Then it returns normally',
      () {
        expect(
          () => AppEnv.production.ensureFirebaseConfigured('my-app-prod'),
          returnsNormally,
        );
      },
    );

    test(
      'Given a stub project id, When ensureFirebaseConfigured is called, Then it throws with the flutterfire command',
      () {
        expect(
          () => AppEnv.production.ensureFirebaseConfigured('stub'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Firebase for production is not configured'),
                contains('--out=lib/firebase_options_production.dart'),
              ),
            ),
          ),
        );
      },
    );
  });

  group('per-environment values', () {
    test(
      'Given the staging env, When reading its values, Then they match the staging config',
      () {
        const env = AppEnv.staging;
        expect(env.name, 'staging');
        expect(env.sentryTracesSampleRate, 0.5);
        expect(env.verboseSdksInDebug, isTrue);
        expect(env.alwaysUseDebugAppCheck, isTrue);
      },
    );

    test(
      'Given the production env, When reading its values, Then they match the production config',
      () {
        const env = AppEnv.production;
        expect(env.name, 'production');
        expect(env.sentryTracesSampleRate, 0.2);
        expect(env.verboseSdksInDebug, isFalse);
        expect(env.alwaysUseDebugAppCheck, isFalse);
      },
    );
    // BEGIN_REMOTE_CONFIG

    test(
      'Given each env, When remoteConfigMinFetchInterval is read, Then staging is 5 min and production 1 h',
      () {
        expect(
          AppEnv.staging.remoteConfigMinFetchInterval,
          const Duration(minutes: 5),
        );
        expect(
          AppEnv.production.remoteConfigMinFetchInterval,
          const Duration(hours: 1),
        );
      },
    );
    // END_REMOTE_CONFIG
  });
}
