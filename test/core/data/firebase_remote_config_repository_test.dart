// BEGIN_REMOTE_CONFIG
import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
// END_REMOTE_CONFIG
import 'package:flutter_test/flutter_test.dart';
// BEGIN_REMOTE_CONFIG
import 'package:mocktail/mocktail.dart';
// END_REMOTE_CONFIG
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/domain/config_key.dart';
// BEGIN_REMOTE_CONFIG
import 'package:blueprint_app/core/domain/config_keys.dart';

class MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}

RemoteConfigValue remote(String v) =>
    RemoteConfigValue(utf8.encode(v), ValueSource.valueRemote);

// END_REMOTE_CONFIG

void main() {
  const s = ConfigKey<String>('s', 'd');
  const b = ConfigKey<bool>('b', true);
  const i = ConfigKey<int>('i', 7);
  const d = ConfigKey<double>('d', 1.5);

  // BEGIN_REMOTE_CONFIG
  late MockFirebaseRemoteConfig sdk;
  // END_REMOTE_CONFIG
  late FirebaseRemoteConfigRepository repo;

  // BEGIN_REMOTE_CONFIG
  setUpAll(() {
    registerFallbackValue(
      RemoteConfigSettings(
        fetchTimeout: Duration.zero,
        minimumFetchInterval: Duration.zero,
      ),
    );
  });

  // END_REMOTE_CONFIG
  setUp(() {
    // BEGIN_REMOTE_CONFIG
    sdk = MockFirebaseRemoteConfig();
    when(() => sdk.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => sdk.setDefaults(any())).thenAnswer((_) async {});
    when(() => sdk.setCustomSignals(any())).thenAnswer((_) async {});
    when(() => sdk.activate()).thenAnswer((_) async => false);
    when(() => sdk.fetchAndActivate()).thenAnswer((_) async => false);
    when(
      () => sdk.getValue(any()),
    ).thenReturn(RemoteConfigValue(null, ValueSource.valueStatic));
    // END_REMOTE_CONFIG
    repo = FirebaseRemoteConfigRepository(
      // BEGIN_REMOTE_CONFIG
      sdk,
      // END_REMOTE_CONFIG
    );
  });

  test(
    'Given an unset key, When get is called, Then the default is returned',
    () {
      expect(repo.get(s), 'd');
      expect(repo.get(b), true);
      expect(repo.get(i), 7);
      expect(repo.get(d), 1.5);
    },
  );

  test('Given initialize, When called, Then it completes', () async {
    await expectLater(
      repo.initialize(
        environment: 'staging',
        minimumFetchInterval: const Duration(minutes: 5),
      ),
      completes,
    );
  });

  // BEGIN_REMOTE_CONFIG
  group('initialize', () {
    Future<void> init() => repo.initialize(
      environment: 'staging',
      minimumFetchInterval: const Duration(minutes: 5),
    );

    test(
      'Given the SDK, When initialize runs, Then it calls settings, defaults, '
      'signals, activate, fetchAndActivate in order',
      () async {
        await init();
        final calls = verifyInOrder([
          () => sdk.setConfigSettings(captureAny()),
          () => sdk.setDefaults(captureAny()),
          () => sdk.setCustomSignals(captureAny()),
          () => sdk.activate(),
          () => sdk.fetchAndActivate(),
        ]);

        final settings = calls[0].captured.single as RemoteConfigSettings;
        expect(settings.fetchTimeout, const Duration(seconds: 10));
        expect(settings.minimumFetchInterval, const Duration(minutes: 5));
        expect(calls[1].captured.single, {
          'api_base_url': ConfigKeys.apiBaseUrl.defaultValue,
        });
        expect(calls[2].captured.single, {'environment': 'staging'});
      },
    );

    test('Given fetchAndActivate never completes, When initialize is awaited, '
        'Then it still completes', () async {
      when(
        () => sdk.fetchAndActivate(),
      ).thenAnswer((_) => Completer<bool>().future);

      await expectLater(init(), completes);
    });

    test('Given fetchAndActivate returns true, When initialize runs, '
        'Then onUpdated emits once', () async {
      when(() => sdk.fetchAndActivate()).thenAnswer((_) async => true);
      final emitted = expectLater(repo.onUpdated, emits(null));

      await init();
      await emitted;
    });

    test('Given fetchAndActivate returns false, When initialize runs, '
        'Then onUpdated does not emit', () async {
      var count = 0;
      final sub = repo.onUpdated.listen((_) => count++);

      await init();
      await pumpEventQueue();

      expect(count, 0);
      await sub.cancel();
    });

    test('Given fetchAndActivate fails after initialize returned, '
        'When it later fails, Then there is no uncaught error', () async {
      final completer = Completer<bool>();
      when(() => sdk.fetchAndActivate()).thenAnswer((_) => completer.future);
      var count = 0;
      final sub = repo.onUpdated.listen((_) => count++);

      await init();
      completer.completeError(Exception('offline'));
      await pumpEventQueue();

      expect(count, 0);
      await sub.cancel();
    });

    test('Given initialize, When it finishes, Then fetchAndActivate is called '
        'exactly once', () async {
      await init();
      await pumpEventQueue();

      verify(() => sdk.fetchAndActivate()).called(1);
    });

    final failures = <String, void Function()>{
      'setConfigSettings': () =>
          when(() => sdk.setConfigSettings(any())).thenThrow(Exception('x')),
      'setDefaults': () =>
          when(() => sdk.setDefaults(any())).thenThrow(Exception('x')),
      'setCustomSignals': () =>
          when(() => sdk.setCustomSignals(any())).thenThrow(Exception('x')),
      'activate': () => when(() => sdk.activate()).thenThrow(Exception('x')),
      'fetchAndActivate': () =>
          when(() => sdk.fetchAndActivate()).thenThrow(Exception('x')),
    };
    final order = failures.keys.toList();

    for (final entry in failures.entries) {
      test('Given ${entry.key} throws synchronously, When initialize runs, '
          'Then initialize completes and later steps still run', () async {
        entry.value();

        await expectLater(init(), completes);
        await pumpEventQueue();

        final later = order.skip(order.indexOf(entry.key) + 1);
        for (final step in later) {
          switch (step) {
            case 'setDefaults':
              verify(() => sdk.setDefaults(any())).called(1);
            case 'setCustomSignals':
              verify(() => sdk.setCustomSignals(any())).called(1);
            case 'activate':
              verify(() => sdk.activate()).called(1);
            case 'fetchAndActivate':
              verify(() => sdk.fetchAndActivate()).called(1);
          }
        }
      });
    }
  });

  group('get', () {
    test('Given a string value, When get is called, Then it is returned', () {
      when(() => sdk.getValue('s')).thenReturn(remote('hello'));
      expect(repo.get(s), 'hello');
    });

    test('Given an empty string, When get is called, Then it is returned', () {
      when(() => sdk.getValue('s')).thenReturn(remote(''));
      expect(repo.get(s), '');
    });

    for (final (raw, expected) in [
      ('true', true),
      ('false', false),
      ('TRUE', true),
      ('1', true),
      ('yes', true),
    ]) {
      test('Given bool "$raw", When get is called, Then it is $expected', () {
        when(() => sdk.getValue('b')).thenReturn(remote(raw));
        expect(repo.get(b), expected);
      });
    }

    for (final (raw, expected) in [('42', 42), ('abc', 7), ('3.0', 7)]) {
      test('Given int "$raw", When get is called, Then it is $expected', () {
        when(() => sdk.getValue('i')).thenReturn(remote(raw));
        expect(repo.get(i), expected);
      });
    }

    test(
      'Given a whitespace-padded int, When get is called, Then it parses',
      () {
        when(() => sdk.getValue('i')).thenReturn(remote(' 8 '));
        expect(repo.get(i), 8);
      },
    );

    for (final raw in ['TRUE', '1', 'True', 'yes']) {
      test('Given bool "$raw" and default false, When get is called, '
          'Then the default is returned', () {
        const bf = ConfigKey<bool>('b', false);
        when(() => sdk.getValue('b')).thenReturn(remote(raw));
        expect(repo.get(bf), false);
      });
    }

    for (final (raw, expected) in [('2.5', 2.5), ('3', 3.0), ('x', 1.5)]) {
      test('Given double "$raw", When get is called, Then it is $expected', () {
        when(() => sdk.getValue('d')).thenReturn(remote(raw));
        expect(repo.get(d), expected);
      });
    }

    test('Given a static value, When get is called, Then default', () {
      when(() => sdk.getValue('s')).thenReturn(
        RemoteConfigValue(utf8.encode('x'), ValueSource.valueStatic),
      );
      expect(repo.get(s), 'd');
    });

    test('Given an unsupported type, When get is called, Then default', () {
      final when0 = DateTime(2020);
      final key = ConfigKey<DateTime>('t', when0);
      when(() => sdk.getValue('t')).thenReturn(remote('2021'));

      expect(repo.get(key), when0);
      expect(repo.get(key), when0);
    });

    test('Given getValue throws, When get is called, Then default', () {
      when(() => sdk.getValue(any())).thenThrow(Exception('boom'));
      expect(repo.get(s), 'd');
    });
  });
  // END_REMOTE_CONFIG
}
