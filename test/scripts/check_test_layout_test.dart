import 'package:flutter_test/flutter_test.dart';

import '../../scripts/check_test_layout.dart';

void main() {
  group('expectedSourceFor', () {
    test('Given a nested app test, When mapped, Then it points into lib', () {
      expect(
        expectedSourceFor(
          'test/features/auth/data/firebase_auth_repository_test.dart',
        ),
        'lib/features/auth/data/firebase_auth_repository.dart',
      );
    });

    test('Given a top-level test, When mapped, Then it points at lib', () {
      expect(expectedSourceFor('test/app_test.dart'), 'lib/app.dart');
    });

    // BEGIN_BLUEPRINT
    test('Given a tool test, When mapped, Then it points into tool/src', () {
      expect(
        expectedSourceFor('test/tool/markers_test.dart'),
        'tool/src/markers.dart',
      );
    });
    // END_BLUEPRINT

    test('Given a scripts test, When mapped, Then it points into scripts', () {
      expect(
        expectedSourceFor('test/scripts/coverage_gate_test.dart'),
        'scripts/coverage_gate.dart',
      );
    });

    test('Given exempt paths, When mapped, Then the result is null', () {
      expect(expectedSourceFor('test/helpers/mocks.dart'), isNull);
      expect(expectedSourceFor('test/helpers/x_test.dart'), isNull);
      expect(expectedSourceFor('test/flutter_test_config.dart'), isNull);
      expect(expectedSourceFor('integration_test/app_test.dart'), isNull);
    });
  });

  group('findOrphanTests', () {
    test('Given a test without a source, When checked, Then it is listed', () {
      final orphans = findOrphanTests([
        'test/foo/bar_test.dart',
        'test/foo/baz_test.dart',
      ], (p) => p == 'lib/foo/baz.dart');
      expect(orphans, ['test/foo/bar_test.dart']);
    });
  });
}
