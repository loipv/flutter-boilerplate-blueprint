import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/fs.dart';
import '../../tool/src/manifest.dart';
import '../../tool/src/markers.dart';

void main() {
  test('every marker in the repo has a known name', () {
    final unknown = <String>[];
    for (final path in listFiles(skipDirs)) {
      if (!isTextFile(path)) continue;
      final text = readUtf8OrNull(path);
      if (text == null) continue;
      for (final m in markerNames(text)) {
        if (!knownMarkers.contains(m.name)) {
          unknown.add('$path:${m.line}: ${m.name}');
        }
      }
    }
    expect(unknown, isEmpty);
  });

  test('knownMarkers holds every feature marker plus BLUEPRINT', () {
    expect(knownMarkers, containsAll(['BLUEPRINT', 'SENTRY', 'ANON']));
    for (final rule in featureRules.values) {
      expect(knownMarkers, containsAll(rule.markers));
    }
  });
}
