import 'package:flutter_test/flutter_test.dart';

import 'package:blueprint_app/core/config/app_env.dart';

void main() {
  group('AppEnv.fromFlavor', () {
    test('maps staging flavor to staging', () {
      expect(AppEnv.fromFlavor('staging'), AppEnv.staging);
    });

    test('maps production flavor to production', () {
      expect(AppEnv.fromFlavor('production'), AppEnv.production);
    });

    test('throws when no flavor was passed', () {
      expect(() => AppEnv.fromFlavor(null), throwsStateError);
    });

    test('throws on an unknown flavor', () {
      expect(() => AppEnv.fromFlavor('dev'), throwsStateError);
      expect(() => AppEnv.fromFlavor('Staging'), throwsStateError);
    });
  });

  group('per-environment values', () {
    test('staging', () {
      const env = AppEnv.staging;
      expect(env.name, 'staging');
      expect(env.sentryTracesSampleRate, 0.5);
      expect(env.verboseSdksInDebug, isTrue);
      expect(env.alwaysUseDebugAppCheck, isTrue);
    });

    test('production', () {
      const env = AppEnv.production;
      expect(env.name, 'production');
      expect(env.sentryTracesSampleRate, 0.2);
      expect(env.verboseSdksInDebug, isFalse);
      expect(env.alwaysUseDebugAppCheck, isFalse);
    });
  });
}
