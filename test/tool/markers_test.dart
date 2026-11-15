import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/markers.dart';

void main() {
  test('stripBlocks removes a dart block and its marker lines', () {
    const input = 'a\n  // BEGIN_SENTRY\n  x();\n  // END_SENTRY\nb\n';
    expect(stripBlocks(input, 'SENTRY'), 'a\nb\n');
  });

  test('stripBlocks removes every occurrence', () {
    const input =
        '// BEGIN_POSTHOG\np();\n// END_POSTHOG\nkeep\n'
        '// BEGIN_POSTHOG\nq();\n// END_POSTHOG\n';
    expect(stripBlocks(input, 'POSTHOG'), 'keep\n');
  });

  test('stripBlocks handles yaml and xml comment forms', () {
    expect(stripBlocks('# BEGIN_SENTRY\n  s: 1\n# END_SENTRY\n', 'SENTRY'), '');
    expect(
      stripBlocks(
        '<!-- BEGIN_NOTIFICATIONS -->\n<p/>\n<!-- END_NOTIFICATIONS -->\n',
        'NOTIFICATIONS',
      ),
      '',
    );
  });

  test('stripBlocks matches the whole marker name', () {
    const input =
        'a\n// BEGIN_NOTIFICATIONS_IMPORTS\nimport "n";\n'
        '// END_NOTIFICATIONS_IMPORTS\nb\n';
    expect(stripBlocks(input, 'NOTIFICATIONS'), input);
  });

  test('stripBlocks leaves other markers alone', () {
    const input = 'a\n// BEGIN_GOOGLE\ng();\n// END_GOOGLE\nb\n';
    expect(stripBlocks(input, 'APPLE'), input);
  });

  test('stripBlocks throws when END is missing', () {
    expect(
      () => stripBlocks('// BEGIN_SENTRY\nx\n', 'SENTRY'),
      throwsA(
        isA<MarkerException>().having(
          (e) => e.message,
          'message',
          contains('SENTRY'),
        ),
      ),
    );
  });

  test('stripBlocks throws when END has no BEGIN', () {
    expect(
      () => stripBlocks('x\n// END_SENTRY\n', 'SENTRY'),
      throwsA(
        isA<MarkerException>().having(
          (e) => e.message,
          'message',
          contains('SENTRY'),
        ),
      ),
    );
  });

  test('stripBlocks throws on nested BEGIN of the same marker', () {
    expect(
      () => stripBlocks(
        '// BEGIN_SENTRY\n// BEGIN_SENTRY\nx\n// END_SENTRY\n',
        'SENTRY',
      ),
      throwsA(isA<MarkerException>()),
    );
  });

  test('stripMarkerLines keeps the content', () {
    expect(
      stripMarkerLines("// BEGIN_GOOGLE\nimport 'g';\n// END_GOOGLE\n"),
      "import 'g';\n",
    );
  });

  test('stripMarkerLines ignores prose that mentions a marker', () {
    const input = 'see BEGIN_SENTRY in the docs\n';
    expect(stripMarkerLines(input), input);
  });

  test('hasMarkerLines', () {
    expect(hasMarkerLines('  # END_POSTHOG\n'), isTrue);
    expect(hasMarkerLines('plain\n'), isFalse);
  });

  test('markerNames lists every marker line with its 1-based line number', () {
    const input =
        'a\n// BEGIN_SENTRY\n# END_SENTRY\n<!-- BEGIN_BLUEPRINT -->\n'
        'x // BEGIN_NOT_A_MARKER\n';
    expect(markerNames(input).toList(), [
      (line: 2, name: 'SENTRY'),
      (line: 3, name: 'SENTRY'),
      (line: 4, name: 'BLUEPRINT'),
    ]);
  });

  test('stripReleaseMarkers removes an inline version marker', () {
    expect(
      stripReleaseMarkers(
        'Blueprint version: v1.4.0 <!-- x-release-please-version -->\n',
      ),
      'Blueprint version: v1.4.0\n',
    );
  });

  test('stripReleaseMarkers drops block marker lines and keeps content', () {
    expect(
      stripReleaseMarkers(
        'a\n<!-- x-release-please-start-version -->\nv1.4.0\n'
        '<!-- x-release-please-end -->\nb\n',
      ),
      'a\nv1.4.0\nb\n',
    );
  });

  test('stripReleaseMarkers leaves text without markers unchanged', () {
    const input = 'Blueprint version: v1.4.0\n<!-- BEGIN_ADS -->\n';
    expect(stripReleaseMarkers(input), input);
  });

  // release-please's generic updater rewrites only the first version on each
  // line, so a line with two versions would be half-updated on release.
  test('Given release-please marked lines in the repo, When versions are '
      'counted, Then each line holds at most one', () {
    final version = RegExp(r'\d+\.\d+\.\d+');
    final offenders = <String>[];
    for (final path in ['README.md', 'BLUEPRINT_VERSION.md']) {
      var inBlock = false;
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('x-release-please-start-version')) inBlock = true;
        if (line.contains('x-release-please-end')) inBlock = false;
        final marked = inBlock || line.contains('x-release-please-version');
        if (marked && version.allMatches(line).length > 1) {
          offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
