import 'package:flutter_test/flutter_test.dart';

import '../../scripts/check_l10n.dart';

void main() {
  group('compareArb', () {
    test('Given identical keys, When compared, Then no problems', () {
      final problems = compareArb(
        {'a': 'A', 'b': 'B'},
        {'a': 'X', 'b': 'Y'},
        locale: 'vi',
      );
      expect(problems, isEmpty);
    });

    test(
      "Given a key missing from vi, When compared, Then one problem naming the key and 'vi'",
      () {
        final problems = compareArb(
          {'a': 'A', 'b': 'B'},
          {'a': 'X'},
          locale: 'vi',
        );
        expect(problems, hasLength(1));
        expect(problems.single, contains('b'));
        expect(problems.single, contains('vi'));
      },
    );

    test(
      'Given an extra key in vi, When compared, Then one problem naming the key',
      () {
        final problems = compareArb(
          {'a': 'A'},
          {'a': 'X', 'extra': 'E'},
          locale: 'vi',
        );
        expect(problems, hasLength(1));
        expect(problems.single, contains('extra'));
      },
    );

    test(
      'Given @-keys and @@locale that differ, When compared, Then they are ignored',
      () {
        final problems = compareArb(
          {
            '@@locale': 'en',
            'a': 'A',
            '@a': {'description': 'd'},
          },
          {
            '@@locale': 'vi',
            'a': 'X',
            '@other': {'description': 'z'},
          },
          locale: 'vi',
        );
        expect(problems, isEmpty);
      },
    );

    test(
      'Given {time} in en and {thoi_gian} in vi for the same key, When compared, Then one placeholder problem',
      () {
        final problems = compareArb(
          {'a': 'At {time}'},
          {'a': 'Luc {thoi_gian}'},
          locale: 'vi',
        );
        expect(problems, hasLength(1));
        expect(problems.single, contains('a'));
      },
    );
  });

  group('placeholdersOf', () {
    test(
      'Given a plural message, When placeholdersOf runs, Then only the plural argument name is returned',
      () {
        final arb = {
          'items': '{count, plural, =1{1 item} other{{count} items}}',
        };
        expect(placeholdersOf(arb, 'items'), {'count'});
      },
    );

    test(
      'Given @key placeholders, When placeholdersOf runs, Then metadata names are used',
      () {
        final arb = {
          'hi': 'Hi {name}',
          '@hi': {
            'placeholders': {'name': <String, dynamic>{}},
          },
        };
        expect(placeholdersOf(arb, 'hi'), {'name'});
      },
    );

    test(
      'Given no metadata, When placeholdersOf runs, Then tokens are parsed from the message',
      () {
        expect(placeholdersOf({'hi': 'Hi {a} and {b}'}, 'hi'), {'a', 'b'});
      },
    );
  });

  group('yamlValue', () {
    test('Given a plain value, When read, Then it is returned', () {
      expect(yamlValue('arb-dir: lib/l10n\n', 'arb-dir'), 'lib/l10n');
    });

    test(
      'Given a quoted value with a trailing comment, When read, Then quotes and comment are dropped',
      () {
        const yaml = '''
arb-dir: "lib/l10n" # where the ARB files live
template-arb-file: 'app_en.arb'
''';
        expect(yamlValue(yaml, 'arb-dir'), 'lib/l10n');
        expect(yamlValue(yaml, 'template-arb-file'), 'app_en.arb');
      },
    );

    test('Given a missing key, When read, Then null', () {
      expect(yamlValue('arb-dir: lib/l10n\n', 'output-dir'), isNull);
    });
  });

  group('decodeArb', () {
    test('Given a JSON object, When decoded, Then the map is returned', () {
      expect(decodeArb('{"a": "A"}', 'app_en.arb'), {'a': 'A'});
    });

    test(
      'Given malformed JSON, When decoded, Then an ArbException names the file',
      () {
        expect(
          () => decodeArb('{"a": ', 'app_vi.arb'),
          throwsA(
            isA<ArbException>().having(
              (e) => e.message,
              'message',
              startsWith('app_vi.arb is not valid JSON'),
            ),
          ),
        );
      },
    );

    test(
      'Given a JSON array, When decoded, Then an ArbException names the file',
      () {
        expect(
          () => decodeArb('[]', 'app_vi.arb'),
          throwsA(
            isA<ArbException>().having(
              (e) => e.message,
              'message',
              'app_vi.arb is not a JSON object',
            ),
          ),
        );
      },
    );
  });
}
