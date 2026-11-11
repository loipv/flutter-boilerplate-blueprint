/// Turns this copy of the boilerplate into your app, in place.
///
/// Run from the repository root before `pub get`: `dart tool/init.dart`.
/// Exit codes: 0 success, 64 invalid input (nothing changed), 1 failure.
library;

import 'dart:io';

import 'src/options.dart';
import 'src/plan.dart';

const _usage = '''
Usage: dart tool/init.dart [options]

Renames this boilerplate to your app and removes the features you turn off.
Run it from the repository root, before `make setup`.

  --name <name>           Package name (default: current directory name)
  --org <org>             Organization, e.g. com.acme (default: com.example)
  --title <title>         Display name (default: package name in Title Case)
  --description <text>    Description (default: A new Flutter app)
  --no-notifications      Remove local notifications
  --no-posthog            Remove PostHog analytics
  --no-sentry             Remove Sentry crash reporting
  --no-functions          Remove Cloud Functions
  --no-apple              Remove Apple Sign-In
  --no-google             Remove Google Sign-In
  --no-anon               Remove anonymous sign-in
  --no-remote-config      Remove Firebase Remote Config
  --no-ads                Remove Google AdMob ads
  --shared-app-id         Staging uses the production bundle/application id
                          (one store app; see docs/release_guide.md)
  --yes                   Accept defaults for anything not passed
''';

const _featureLabels = {
  Feature.notifications: 'local notifications',
  Feature.posthog: 'PostHog analytics',
  Feature.sentry: 'Sentry crash reporting',
  Feature.functions: 'Cloud Functions',
  Feature.apple: 'Apple Sign-In',
  Feature.google: 'Google Sign-In',
  Feature.anon: 'anonymous sign-in',
  Feature.remoteConfig: 'Firebase Remote Config',
  Feature.ads: 'Google AdMob ads',
};

/// Invalid input: exit 64, nothing changed.
class _InputError implements Exception {
  _InputError(this.message);

  final String message;
}

void main(List<String> args) {
  try {
    exitCode = _run(args);
  } on _InputError catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
  } on InitFailure catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  }
}

int _run(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage);
    return 0;
  }
  final ParsedArgs parsed;
  try {
    parsed = parseArgs(args);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..write(_usage);
    return 64;
  }

  final options = _resolve(parsed);

  if (!File('tool/init.dart').existsSync() ||
      !File('pubspec.yaml').existsSync()) {
    throw _InputError(
      'Run this from the root of the boilerplate: tool/init.dart and '
      'pubspec.yaml must be in the current directory.',
    );
  }

  final plan = InitPlan.prepare(options);
  try {
    plan.apply();
  } on Exception catch (e) {
    final hint = plan.hadGit
        ? 'Restore the tree (for example `git checkout . && git clean -fd`) '
              'and run it again.'
        : 'Delete this directory and start again.';
    throw InitFailure('init stopped partway: $e\n$hint');
  }

  final leftovers = scanLeftovers(options);
  if (leftovers.isNotEmpty) {
    stderr.writeln('init finished, but these leftovers remain:');
    leftovers.forEach(stderr.writeln);
    return 1;
  }

  _printNextSteps(options);
  return 0;
}

InitOptions _resolve(ParsedArgs p) {
  String ask(
    String label,
    String flag,
    String? given,
    String? fallback,
    String? Function(String) validate,
  ) => _ask(label, flag, given, fallback, validate, yes: p.yes);

  final dirName = Directory.current.path.split(Platform.pathSeparator).last;
  final dirDefault = validateName(dirName) == null ? dirName : null;
  final name = ask('Package name', 'name', p.name, dirDefault, validateName);
  final org = ask('Organization', 'org', p.org, 'com.example', validateOrg);
  final title = ask(
    'Display name',
    'title',
    p.title,
    titleFromName(name),
    validateText,
  );
  final description = ask(
    'Description',
    'description',
    p.description,
    'A new Flutter app',
    validateText,
  );

  final disabled = {...p.disabled};
  final flagError = validateSignIn(disabled);
  if (flagError != null) throw _InputError(flagError);
  if (!p.yes) {
    for (final feature in Feature.values) {
      if (disabled.contains(feature)) continue;
      if (_confirm('Include ${_featureLabels[feature]}?')) continue;
      if (validateSignIn({...disabled, feature}) != null) {
        stderr.writeln(
          'Keeping ${_featureLabels[feature]}: at least one sign-in method '
          'must stay on.',
        );
        continue;
      }
      disabled.add(feature);
    }
  }
  final sharedAppId =
      p.sharedAppId ||
      (!p.yes &&
          _confirm(
            'Use one bundle/application id for staging and production '
            '(one store app; see docs/release_guide.md)?',
            defaultYes: false,
          ));
  return InitOptions(
    name: name,
    org: org,
    title: title,
    description: description,
    disabled: disabled,
    sharedAppId: sharedAppId,
  );
}

/// Flag value (validated, exit 64 when invalid), else the default under
/// `--yes`, else an interactive prompt that re-asks until valid. EOF on stdin
/// takes the default.
String _ask(
  String label,
  String flag,
  String? given,
  String? fallback,
  String? Function(String) validate, {
  required bool yes,
}) {
  if (given != null) {
    final error = validate(given);
    if (error != null) throw _InputError('Invalid --$flag "$given": $error');
    return given;
  }
  final missing = _InputError('No default for $label; pass --$flag.');
  if (yes) return fallback ?? (throw missing);
  while (true) {
    stdout.write(fallback == null ? '$label: ' : '$label [$fallback]: ');
    final line = stdin.readLineSync();
    if (line == null) {
      stdout.writeln();
      return fallback ?? (throw missing);
    }
    final answer = line.trim();
    if (answer.isEmpty && fallback != null) return fallback;
    final error = answer.isEmpty ? 'A value is required.' : validate(answer);
    if (error == null) return answer;
    stderr.writeln(error);
  }
}

/// Yes/no prompt; EOF on stdin or an empty answer takes [defaultYes].
bool _confirm(String question, {bool defaultYes = true}) {
  while (true) {
    stdout.write('$question ${defaultYes ? '[Y/n]' : '[y/N]'}: ');
    final line = stdin.readLineSync();
    if (line == null) {
      stdout.writeln();
      return defaultYes;
    }
    switch (line.trim().toLowerCase()) {
      case '':
        return defaultYes;
      case 'y' || 'yes':
        return true;
      case 'n' || 'no':
        return false;
    }
    stderr.writeln('Answer y or n.');
  }
}

void _printNextSteps(InitOptions options) {
  final removed = options.disabled.map((f) => f.cliName).toList()..sort();
  stdout
    ..writeln()
    ..writeln('Created ${options.title} (${options.org}.${options.name}).')
    ..writeln(
      removed.isEmpty
          ? 'All optional features kept.'
          : 'Removed: ${removed.join(', ')}.',
    )
    ..writeln(
      options.sharedAppId
          ? 'Staging and production share the app id '
                '${options.org}.${options.name}.'
          : 'Staging uses the app id ${options.org}.${options.name}.staging.',
    )
    ..writeln()
    ..writeln('Next steps:')
    ..writeln('  1. make setup')
    ..writeln('  2. Connect Firebase, once per flavor (see docs/setup.md):')
    ..writeln(
      '     flutterfire configure --project=<staging-id> '
      '--out=lib/firebase_options_staging.dart',
    )
    ..writeln(
      '     flutterfire configure --project=<production-id> '
      '--out=lib/firebase_options_production.dart',
    )
    ..writeln('  3. Work through docs/next_steps.md');
}
