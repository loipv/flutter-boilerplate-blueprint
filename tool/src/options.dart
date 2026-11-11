/// Option parsing and validation for the init tool. `dart:` only.
library;

/// Optional features that can be removed from the generated app.
enum Feature { notifications, posthog, sentry, functions, apple, google, anon }

/// Sign-in methods; at least one must stay on or the app cannot leave
/// onboarding.
const Set<Feature> signInFeatures = {
  Feature.apple,
  Feature.google,
  Feature.anon,
};

/// Returns null when [disabled] keeps at least one sign-in method, else the
/// message.
String? validateSignIn(Set<Feature> disabled) =>
    disabled.containsAll(signInFeatures)
    ? 'At least one sign-in method (Apple, Google, anonymous) must stay on; '
          'without one the app cannot leave onboarding.'
    : null;

/// Fully resolved answers used to rename the boilerplate.
class InitOptions {
  const InitOptions({
    required this.name,
    required this.org,
    required this.title,
    required this.description,
    this.disabled = const {},
    this.sharedAppId = false,
  });

  final String name;
  final String org;
  final String title;
  final String description;
  final Set<Feature> disabled;

  /// Staging uses the production bundle/application id (no `.staging`).
  final bool sharedAppId;
}

/// Raw command-line values; anything not given stays null.
class ParsedArgs {
  const ParsedArgs({
    this.name,
    this.org,
    this.title,
    this.description,
    this.disabled = const {},
    this.sharedAppId = false,
    this.yes = false,
  });

  final String? name;
  final String? org;
  final String? title;
  final String? description;
  final Set<Feature> disabled;

  /// Whether `--shared-app-id` was passed.
  final bool sharedAppId;
  final bool yes;
}

/// Parses CLI [args]. Throws [FormatException] naming the offending flag.
ParsedArgs parseArgs(List<String> args) {
  final values = <String, String>{};
  final disabled = <Feature>{};
  var yes = false;
  var sharedAppId = false;
  const valueFlags = {'name', 'org', 'title', 'description'};
  final features = {for (final f in Feature.values) f.name: f};

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      throw FormatException('Unknown argument: $arg');
    }
    final eq = arg.indexOf('=');
    final flag = eq == -1 ? arg.substring(2) : arg.substring(2, eq);

    if (valueFlags.contains(flag)) {
      String value;
      if (eq != -1) {
        value = arg.substring(eq + 1);
      } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        value = args[++i];
      } else {
        throw FormatException('Missing value for --$flag');
      }
      values[flag] = value;
    } else if (eq == -1 && flag == 'yes') {
      yes = true;
    } else if (eq == -1 && flag == 'shared-app-id') {
      sharedAppId = true;
    } else if (eq == -1 &&
        flag.startsWith('no-') &&
        features.containsKey(flag.substring(3))) {
      disabled.add(features[flag.substring(3)]!);
    } else {
      throw FormatException('Unknown flag: --$flag');
    }
  }

  return ParsedArgs(
    name: values['name'],
    org: values['org'],
    title: values['title'],
    description: values['description'],
    disabled: disabled,
    sharedAppId: sharedAppId,
    yes: yes,
  );
}

const _reserved = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
  'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
  'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'var', 'void', 'while', 'with', //
};

final RegExp _segment = RegExp(r'^[a-z][a-z0-9_]*$');

/// Returns null when [value] is a valid package name, else the message.
String? validateName(String value) {
  if (!_segment.hasMatch(value)) {
    return 'Use lowercase letters, digits and underscores, starting with a '
        'letter (e.g. acme_notes).';
  }
  if (_reserved.contains(value)) {
    return '"$value" is a Dart reserved word.';
  }
  return null;
}

/// Returns null when [value] is a valid organization, else the message.
String? validateOrg(String value) {
  final parts = value.split('.');
  if (parts.length < 2 || !parts.every(_segment.hasMatch)) {
    return 'Use at least two dot-separated lowercase segments '
        '(e.g. com.example).';
  }
  return null;
}

/// Returns null when [value] is safe as a title or description.
String? validateText(String value) {
  if (value.trim().isEmpty) return 'Must not be empty.';
  if (value.contains(RegExp('[\'"`\\\\\$<>&\n\r]'))) {
    return 'Must not contain quotes, backticks, backslash, \$, <, >, & or '
        'line breaks.';
  }
  return null;
}

/// `acme_notes` -> `Acme Notes`.
String titleFromName(String name) => name
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');
