/// The changes init makes, computed in memory first so that missing paths,
/// bad encodings, malformed markers and bad JSON fail before the first write.
/// `dart:` only.
library;

import 'dart:convert';
import 'dart:io';

import 'app_id.dart';
import 'fs.dart';
import 'manifest.dart';
import 'markers.dart';
import 'options.dart';
import 'rename.dart';

const _kotlinRoot = 'android/app/src/main/kotlin';
const _appReadme = 'tool/app_readme.md';
const _envFiles = ['.env.staging', '.env.production'];
const _firebaseOptions = [
  'lib/firebase_options_staging.dart',
  'lib/firebase_options_production.dart',
];

/// A check failed, before any change ([InitPlan.prepare]) or during them.
class InitFailure implements Exception {
  InitFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every write, move and deletion init performs.
class InitPlan {
  InitPlan._(
    this.options,
    this.writes,
    this.readme,
    this.removals, {
    required this.hadGit,
  });

  /// Reads the tree and computes all new file contents without writing.
  /// Throws [InitFailure] when the tree does not match the manifest.
  factory InitPlan.prepare(InitOptions options) {
    final disabled = options.disabled;
    final featurePaths = [for (final f in disabled) ...featureRules[f]!.paths];

    final required = [
      ...featurePaths,
      ...blueprintOnlyPaths,
      _appReadme,
      for (final env in _envFiles) '$env.example',
      '${kotlinDir('com.example', fixedName)}/MainActivity.kt',
      if (disabled.contains(Feature.functions)) 'firebase.json',
      if (options.sharedAppId) ...[gradlePath, pbxprojPath],
    ];
    final missing = required.where((p) => !pathExists(p)).toList();
    if (missing.isNotEmpty) {
      throw InitFailure(
        'These paths are missing, so nothing was changed:\n'
        '${missing.map((p) => '  $p').join('\n')}',
      );
    }

    final removals = [
      ...featurePaths,
      ...featurePaths.map(testMirror).nonNulls.where(pathExists),
      ...blueprintOnlyPaths,
    ];
    // Every known marker is checked for balance, so a malformed block fails
    // here even for a kept feature; only the stripped ones change the text.
    final stripped = {
      for (final f in disabled) ...featureRules[f]!.markers,
      'BLUEPRINT',
    };
    final checked = {
      for (final rule in featureRules.values) ...rule.markers,
      ...stripped,
    };

    final writes = <String, String>{};
    String? readme;
    for (final path in listFiles(skipDirs)) {
      // README.md is replaced, removals are deleted and tool/ is deleted, so
      // none of them is rewritten; tool/app_readme.md becomes README.md.
      if (!isTextFile(path) || path == 'README.md') continue;
      if (removals.any((r) => isUnder(path, r))) continue;
      if (isUnder(path, 'tool') && path != _appReadme) continue;

      final original =
          readUtf8OrNull(path) ??
          (throw InitFailure('$path is not valid UTF-8; nothing was changed.'));
      var text = original;
      if (options.sharedAppId && (path == gradlePath || path == pbxprojPath)) {
        try {
          text = path == gradlePath
              ? shareAppIdInGradle(text)
              : shareAppIdInPbxproj(text);
        } on AppIdException catch (e) {
          throw InitFailure('$path: ${e.message}; nothing was changed.');
        }
      }
      text = renameText(text, options);
      try {
        for (final marker in checked) {
          final result = stripBlocks(text, marker);
          if (stripped.contains(marker)) text = result;
        }
      } on MarkerException catch (e) {
        throw InitFailure('$path: ${e.message}; nothing was changed.');
      }
      text = stripMarkerLines(text);
      if (path == 'firebase.json' && disabled.contains(Feature.functions)) {
        text = _dropFunctions(text);
      }

      if (path == _appReadme) {
        readme = text;
      } else if (text != original) {
        writes[path] = text;
      }
    }

    return InitPlan._(
      options,
      writes,
      readme!,
      removals,
      hadGit: pathExists('.git'),
    );
  }

  final InitOptions options;

  /// New contents of each changed text file.
  final Map<String, String> writes;

  /// Renamed and stripped `tool/app_readme.md`, written over `README.md`.
  final String readme;

  /// Feature paths, existing test mirrors and blueprint-only paths.
  final List<String> removals;

  /// Whether `.git` existed before init (a clone or "Use this template").
  final bool hadGit;

  /// Applies the plan in spec order, ending with the deletion of `tool/`.
  void apply() {
    writes.forEach((path, text) => File(path).writeAsStringSync(text));

    final oldDir = kotlinDir('com.example', fixedName);
    final newDir = kotlinDir(options.org, options.name);
    if (newDir != oldDir) {
      moveFile('$oldDir/MainActivity.kt', '$newDir/MainActivity.kt');
      removeEmptyDirs(oldDir, _kotlinRoot);
    }

    removals.forEach(deletePath);
    File('README.md').writeAsStringSync(readme);

    for (final env in _envFiles) {
      if (!pathExists(env)) File('$env.example').copySync(env);
    }

    if (!hadGit) _gitInit();

    deletePath('tool');

    if (hadGit) _untrackFirebaseOptions();
  }
}

/// `path: value` for every fixed value or marker line left in a UTF-8 file.
List<String> scanLeftovers(InitOptions options) {
  final hits = <String>[];
  for (final path in listFiles(skipDirs)) {
    final text = readUtf8OrNull(path);
    if (text == null) continue;
    for (final value in findLeftovers(text, options)) {
      hits.add('$path: $value');
    }
    for (final line in text.split('\n')) {
      if (hasMarkerLines(line)) hits.add('$path: ${line.trim()}');
    }
  }
  return hits;
}

String _dropFunctions(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    throw InitFailure('firebase.json: ${e.message}; nothing was changed.');
  }
  if (json is! Map<String, dynamic>) {
    throw InitFailure(
      'firebase.json is not a JSON object; nothing was changed.',
    );
  }
  json.remove('functions');
  return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}

void _gitInit() {
  try {
    var result = Process.runSync('git', ['init', '--quiet', '-b', 'main']);
    // `-b` needs git 2.28 or later.
    if (result.exitCode != 0) {
      result = Process.runSync('git', ['init', '--quiet']);
    }
    if (result.exitCode != 0) {
      stderr.writeln('Warning: git init failed: ${result.stderr}'.trim());
    }
  } on ProcessException {
    stderr.writeln('Warning: git not found; run `git init` yourself.');
  }
}

/// The blueprint tracks the Firebase options stubs, but they are gitignored
/// in your app: `flutterfire configure` writes your Firebase config there.
/// The files stay on disk.
void _untrackFirebaseOptions() {
  final args = ['rm', '--cached', '--quiet', '--ignore-unmatch'];
  try {
    final result = Process.runSync('git', [...args, ..._firebaseOptions]);
    if (result.exitCode != 0) {
      stderr.writeln('Warning: git rm failed: ${result.stderr}'.trim());
      return;
    }
    stdout.writeln(
      'Untracked lib/firebase_options_*.dart (kept on disk): they are '
      'gitignored because flutterfire configure writes your Firebase config '
      'into them.',
    );
  } on ProcessException {
    stderr.writeln(
      'Warning: git not found; run `git rm --cached '
      '${_firebaseOptions.join(' ')}` yourself.',
    );
  }
}
