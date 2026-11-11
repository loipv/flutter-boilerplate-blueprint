import 'package:flutter_test/flutter_test.dart';

import '../../scripts/coverage_gate.dart';

void main() {
  group('layerOf', () {
    test('Given a domain file, When classified, Then it is domain', () {
      expect(
        layerOf('lib/features/auth/domain/user_entity.dart'),
        Layer.domain,
      );
    });

    test('Given a core data file, When classified, Then it is data', () {
      expect(
        layerOf('lib/core/data/posthog_analytics_repository.dart'),
        Layer.data,
      );
    });

    test('Given a router file, When classified, Then it is application', () {
      expect(layerOf('lib/core/router/app_router.dart'), Layer.application);
    });

    test('Given config and providers, When classified, Then application', () {
      expect(layerOf('lib/core/config/app_env.dart'), Layer.application);
      expect(layerOf('lib/core/providers/p.dart'), Layer.application);
    });

    test('Given a feature application file, When classified, Then app', () {
      expect(layerOf('lib/features/x/application/y.dart'), Layer.application);
    });

    test('Given generated files, When classified, Then they are null', () {
      expect(layerOf('lib/features/x/application/y.g.dart'), isNull);
      expect(layerOf('lib/features/x/domain/y.freezed.dart'), isNull);
    });

    test('Given ungated files, When classified, Then they are null', () {
      expect(
        layerOf('lib/features/home/presentation/home_screen.dart'),
        isNull,
      );
      expect(layerOf('lib/core/services/notification_service.dart'), isNull);
      expect(layerOf('lib/main.dart'), isNull);
    });
  });

  group('Layer.threshold', () {
    test('Given each layer, When read, Then thresholds match the policy', () {
      expect(Layer.domain.threshold, 100);
      expect(Layer.data.threshold, 90);
      expect(Layer.application.threshold, 80);
    });
  });

  group('parseLcov', () {
    test(
      'Given a record, When parsed, Then found and hit are keyed by path',
      () {
        expect(
          parseLcov('SF:lib/a/data/b.dart\nLF:10\nLH:9\nend_of_record\n'),
          {'lib/a/data/b.dart': (found: 10, hit: 9)},
        );
      },
    );

    test(
      'Given an absolute SF path, When parsed, Then it is repo-relative',
      () {
        expect(
          parseLcov(
            'SF:/home/u/app/lib/a/data/b.dart\nLF:4\nLH:2\n'
            'end_of_record\n',
          ),
          {'lib/a/data/b.dart': (found: 4, hit: 2)},
        );
      },
    );
  });

  group('parseLcov malformed records', () {
    test('Given a record without LF, When parsed, Then it is absent', () {
      expect(parseLcov('SF:lib/a/data/b.dart\nLH:3\nend_of_record\n'), isEmpty);
    });

    test('Given LF without LH, When parsed, Then hit is 0', () {
      expect(parseLcov('SF:lib/a/data/b.dart\nLF:5\nend_of_record\n'), {
        'lib/a/data/b.dart': (found: 5, hit: 0),
      });
    });
  });

  group('hasExecutableCode', () {
    test('Given a block getter, When checked, Then true', () {
      expect(hasExecutableCode('int get x { return 1; }'), true);
    });

    test('Given an initializer-list constructor, When checked, Then true', () {
      expect(
        hasExecutableCode('class A { final int x; A() : x = 1 { } }'),
        true,
      );
    });

    test('Given an abstract getter, When checked, Then false', () {
      expect(hasExecutableCode('abstract class A { int get x; }'), false);
    });

    test('Given an abstract interface, When checked, Then false', () {
      expect(
        hasExecutableCode('abstract class A { Future<void> f(); }'),
        false,
      );
    });

    test('Given only commented code, When checked, Then false', () {
      expect(hasExecutableCode('// int f() => 1;\nclass A {}'), false);
    });

    test('Given bodies, When checked, Then true', () {
      expect(hasExecutableCode('class A { void f() { } }'), true);
      expect(hasExecutableCode('int f() => 1;'), true);
      expect(hasExecutableCode('Future<void> f() async {}'), true);
      expect(hasExecutableCode('Stream<int> f() async* {}'), true);
      expect(hasExecutableCode('Iterable<int> f() sync* {}'), true);
    });
  });

  group('evaluate', () {
    test('Given data at 80%, When evaluated, Then it fails', () {
      final r = evaluate({'lib/x/data/y.dart': (found: 10, hit: 8)}, {});
      expect(r.passed, false);
      expect(r.totals[Layer.data], (found: 10, hit: 8));
    });

    test('Given data at 90%, When evaluated, Then it passes', () {
      final r = evaluate({'lib/x/data/y.dart': (found: 10, hit: 9)}, {});
      expect(r.passed, true);
    });

    test('Given an empty layer, When evaluated, Then it passes', () {
      expect(evaluate({}, {}).passed, true);
    });

    test('Given an unloaded file with code, When evaluated, Then it fails', () {
      final r = evaluate({}, {'lib/x/data/y.dart': 'int f() => 1;'});
      expect(r.unloaded, ['lib/x/data/y.dart']);
      expect(r.passed, false);
    });

    test('Given a gated source with coverage:ignore-file missing from lcov, '
        'When evaluated, Then it is not reported as unloaded', () {
      final result = evaluate({}, {
        'lib/features/x/data/gateway.dart':
            '// coverage:ignore-file\nclass G { void f() {} }',
      });
      expect(result.unloaded, isEmpty);
    });

    test(
      'Given an unloaded interface-only file, When evaluated, Then pass',
      () {
        final r = evaluate({}, {
          'lib/x/data/y.dart': 'abstract class Y { void f(); }',
        });
        expect(r.unloaded, isEmpty);
        expect(r.passed, true);
      },
    );

    test('Given domain at 99%, When evaluated, Then it fails', () {
      final r = evaluate({'lib/x/domain/y.dart': (found: 100, hit: 99)}, {});
      expect(r.passed, false);
    });

    test('Given two data files, When evaluated, Then counts are summed', () {
      final r = evaluate({
        'lib/a/data/x.dart': (found: 10, hit: 10),
        'lib/b/data/y.dart': (found: 10, hit: 7),
      }, {});
      expect(r.totals[Layer.data], (found: 20, hit: 17));
      expect(r.passed, false);
    });
  });

  group('parseLcov line endings', () {
    test('Given CRLF lcov, When parsed, Then the record is read', () {
      expect(
        parseLcov('SF:lib/a/data/b.dart\r\nLF:4\r\nLH:3\r\nend_of_record\r\n'),
        {'lib/a/data/b.dart': (found: 4, hit: 3)},
      );
    });
  });

  group('formatLayerLine', () {
    test('Given 99.96% domain, When formatted, Then it never shows 100.0', () {
      final line = formatLayerLine(Layer.domain, (found: 10000, hit: 9996));
      expect(line, contains('99.9%'));
      expect(line, isNot(contains('100.0%')));
      expect(line, endsWith('FAIL'));
    });

    test('Given full domain coverage, When formatted, Then it is OK', () {
      final line = formatLayerLine(Layer.domain, (found: 6, hit: 6));
      expect(line, contains('100.0%'));
      expect(line, endsWith('OK'));
    });
  });
}
