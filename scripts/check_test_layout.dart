import 'dart:io';

/// Maps a repo-relative test path to the source file it must mirror.
///
/// Returns null for exempt paths (helpers, non-`_test.dart` files,
/// integration tests).
String? expectedSourceFor(String testPath) {
  const suffix = '_test.dart';
  if (!testPath.startsWith('test/') || !testPath.endsWith(suffix)) {
    return null;
  }
  if (testPath.startsWith('test/helpers/')) return null;
  final rest = testPath.substring('test/'.length);
  final base = rest.substring(0, rest.length - suffix.length);
  // BEGIN_BLUEPRINT
  if (base.startsWith('tool/')) {
    return 'tool/src/${base.substring('tool/'.length)}.dart';
  }
  // END_BLUEPRINT
  if (base.startsWith('scripts/')) return '$base.dart';
  return 'lib/$base.dart';
}

/// Returns, sorted, each test path whose expected source does not exist.
List<String> findOrphanTests(
  Iterable<String> testPaths,
  bool Function(String path) exists,
) {
  final orphans = <String>[];
  for (final path in testPaths) {
    final source = expectedSourceFor(path);
    if (source != null && !exists(source)) orphans.add(path);
  }
  return orphans..sort();
}

/// Forward-slash paths of every `*_test.dart` under [root], or null when
/// [root] does not exist.
List<String>? listTestFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return null;
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('_test.dart'))
      .toList();
}

void main() {
  final testPaths = listTestFiles('test');
  if (testPaths == null) {
    stderr.writeln(
      'No test/ directory found. Run this from the project root '
      '(make check-test-layout).',
    );
    exit(1);
  }
  final orphans = findOrphanTests(testPaths, (p) => File(p).existsSync());
  if (orphans.isNotEmpty) {
    stderr.writeln('Test files without a matching source file:');
    for (final o in orphans) {
      stderr.writeln('  $o (expected ${expectedSourceFor(o)})');
    }
    exit(1);
  }
  stdout.writeln('Test layout OK (${testPaths.length} files)');
}
