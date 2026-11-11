import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/options.dart';

void main() {
  test('validateName accepts snake_case', () {
    expect(validateName('acme_notes'), isNull);
    expect(validateName('a1'), isNull);
  });

  test('validateName rejects bad names', () {
    for (final v in [
      'Bad-Name',
      '1app',
      'acme notes',
      '',
      'class',
      'void',
      'null',
    ]) {
      expect(validateName(v), isNotNull, reason: v);
    }
  });

  test('validateOrg accepts two or more segments', () {
    expect(validateOrg('com.example'), isNull);
    expect(validateOrg('io.acme.mobile'), isNull);
  });

  test('validateOrg rejects bad orgs', () {
    for (final v in ['acme', 'Com.Example', 'io..acme', 'io.1acme']) {
      expect(validateOrg(v), isNotNull, reason: v);
    }
  });

  test('validateText rejects unsafe characters', () {
    for (final c in ["'", '"', '`', r'\', r'$', '<', '>', '&']) {
      expect(validateText('My${c}App'), isNotNull, reason: c);
    }
    expect(validateText('   '), isNotNull);
    expect(validateText('My\nApp'), isNotNull);
  });

  test('validateText accepts punctuation and non-ASCII', () {
    expect(validateText('Ghi Chú (v2.0) | Beta'), isNull);
  });

  test('titleFromName', () {
    expect(titleFromName('acme_notes'), 'Acme Notes');
    expect(titleFromName('app'), 'App');
  });

  test('parseArgs reads values in both forms', () {
    final p = parseArgs(['--name', 'a', '--org=io.acme', '--yes']);
    expect(p.name, 'a');
    expect(p.org, 'io.acme');
    expect(p.yes, isTrue);
    expect(p.title, isNull);
  });

  test('parseArgs collects disabled features', () {
    final p = parseArgs(['--no-sentry', '--no-anon']);
    expect(p.disabled, {Feature.sentry, Feature.anon});
  });

  test('parseArgs reads --shared-app-id, off by default', () {
    expect(parseArgs([]).sharedAppId, isFalse);
    expect(parseArgs(['--shared-app-id']).sharedAppId, isTrue);
    expect(() => parseArgs(['--shared-app-id=yes']), throwsFormatException);
  });

  test('parseArgs rejects unknown flags and missing values', () {
    expect(() => parseArgs(['--nope']), throwsFormatException);
    expect(() => parseArgs(['--name']), throwsFormatException);
    expect(() => parseArgs(['--name', '--yes']), throwsFormatException);
    expect(() => parseArgs(['stray']), throwsFormatException);
  });

  test('validateSignIn requires at least one sign-in method', () {
    expect(validateSignIn({}), isNull);
    expect(validateSignIn({Feature.apple, Feature.google}), isNull);
    expect(validateSignIn({Feature.apple, Feature.anon}), isNull);
    expect(
      validateSignIn({Feature.apple, Feature.google, Feature.anon}),
      contains('At least one sign-in method'),
    );
  });

  test('signInFeatures are Apple, Google and anonymous', () {
    expect(signInFeatures, {Feature.apple, Feature.google, Feature.anon});
  });

  test(
    'Given --no-remote-config, When parsed, Then remoteConfig is disabled',
    () {
      expect(parseArgs(['--no-remote-config']).disabled, {
        Feature.remoteConfig,
      });
    },
  );

  test(
    'Given the camelCase flag, When parsed, Then it throws FormatException',
    () {
      expect(() => parseArgs(['--no-remoteConfig']), throwsFormatException);
    },
  );

  test('Given each feature, When cliName is read, Then it is kebab-case', () {
    expect(Feature.remoteConfig.cliName, 'remote-config');
    expect(Feature.posthog.cliName, 'posthog');
  });
}
