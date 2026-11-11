/// What the init tool touches: text-file rules, feature table and
/// blueprint-only paths. Pure data and path helpers, no I/O.
library;

import 'options.dart';

/// Extensions of files the init tool reads and rewrites as UTF-8 text.
const Set<String> textExtensions = {
  '.dart', '.yaml', '.yml', '.json', '.md', '.rules', '.plist', //
  '.entitlements', '.xcprivacy', '.pbxproj', '.xcscheme', '.xcconfig',
  '.storyboard', '.xml', '.kts', '.gradle', '.properties', '.kt', '.swift',
  '.ts', '.sh', '.iml',
};

/// Exact file names treated as text. Names starting with `.env` also count.
const Set<String> textFileNames = {
  'Makefile',
  'Podfile',
  '.firebaserc',
  '.gitignore',
};

/// Directory names never entered, at any depth.
const Set<String> skipDirs = {
  '.git',
  '.dart_tool',
  '.cxx',
  '.fvm',
  '.gradle',
  '.idea',
  'build',
  'node_modules',
  'Pods',
};

/// Marker blocks and paths removed when a feature is disabled.
class FeatureRule {
  const FeatureRule({this.markers = const [], this.paths = const []});

  /// Marker names whose `BEGIN_X` ... `END_X` blocks are removed.
  final List<String> markers;

  /// Repo-relative paths that must exist and are deleted.
  final List<String> paths;
}

/// Spec 4.2 feature table.
const Map<Feature, FeatureRule> featureRules = {
  Feature.notifications: FeatureRule(
    markers: [
      'NOTIFICATIONS',
      'NOTIFICATIONS_IMPORTS',
      'NOTIFICATIONS_SECTION',
      'NOTIFICATIONS_HELPERS',
      'NOTIFICATIONS_PREF',
    ],
    paths: [
      'lib/core/services/notification_service.dart',
      'lib/core/services/timezone_lifecycle_observer.dart',
      'lib/core/services/timezone_sync_service.dart',
      'lib/features/notifications',
    ],
  ),
  Feature.posthog: FeatureRule(markers: ['POSTHOG']),
  Feature.sentry: FeatureRule(markers: ['SENTRY']),
  Feature.functions: FeatureRule(paths: ['functions']),
  Feature.apple: FeatureRule(markers: ['APPLE']),
  Feature.google: FeatureRule(markers: ['GOOGLE']),
  Feature.anon: FeatureRule(markers: ['ANON']),
  Feature.remoteConfig: FeatureRule(markers: ['REMOTE_CONFIG']),
  Feature.ads: FeatureRule(markers: ['ADS']),
};

/// Every marker name init understands: the feature markers plus
/// `BLUEPRINT` (blueprint-only text, always stripped).
final Set<String> knownMarkers = {
  for (final rule in featureRules.values) ...rule.markers,
  'BLUEPRINT',
};

/// Paths that belong to the blueprint repository, not to a generated app.
const List<String> blueprintOnlyPaths = [
  '.github/workflows/blueprint.yml',
  'CHANGELOG.md',
  'LICENSE',
  'scaffold.sh',
  'docs/repo-assets',
  'docs/superpowers',
  'test/tool',
];

/// Whether the repo-relative, forward-slash [path] is read and rewritten as
/// text: its name is in [textFileNames] or starts with `.env`, or its
/// extension is in [textExtensions].
bool isTextFile(String path) {
  final name = path.substring(path.lastIndexOf('/') + 1);
  if (textFileNames.contains(name) || name.startsWith('.env')) return true;
  final dot = name.lastIndexOf('.');
  return dot > 0 && textExtensions.contains(name.substring(dot));
}

/// Test path mirroring [libPath], or null when [libPath] is not under `lib/`.
///
/// `lib/a/b` -> `test/a/b`; `lib/a/b.dart` -> `test/a/b_test.dart`.
String? testMirror(String libPath) {
  if (!libPath.startsWith('lib/')) return null;
  final mirrored = 'test/${libPath.substring(4)}';
  if (mirrored.endsWith('.dart')) {
    return '${mirrored.substring(0, mirrored.length - 5)}_test.dart';
  }
  return mirrored;
}
