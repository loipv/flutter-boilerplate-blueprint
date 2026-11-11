import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/plan.dart';

void main() {
  group('dropAdmobAppId', () {
    test('Given ADMOB_APP_ID lines in several configurations, When dropped, '
        'Then only those lines are removed', () {
      const input =
          '\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n'
          '\t\t\t\tADMOB_APP_ID = "ca-app-pub-1~2";\n'
          '\t\t\t\tPRODUCT_NAME = Runner;\n'
          '\t\t\t\tADMOB_APP_ID = "ca-app-pub-3~4";\n';
      expect(
        dropAdmobAppId(input),
        '\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n'
        '\t\t\t\tPRODUCT_NAME = Runner;\n',
      );
    });

    test('Given no ADMOB_APP_ID line, When dropped, '
        'Then text is unchanged', () {
      expect(dropAdmobAppId('a = b;\n'), 'a = b;\n');
    });
  });

  group('dropFunctions', () {
    test('Given functions and emulators.functions, '
        'When dropped, Then both are removed and other keys stay', () {
      const input = '''
{
  "firestore": {"rules": "firestore.rules"},
  "functions": [{"source": "functions"}],
  "emulators": {
    "auth": {"port": 9099},
    "functions": {"port": 5001},
    "ui": {"enabled": false},
    "singleProjectMode": true
  }
}
''';
      final json = jsonDecode(dropFunctions(input)) as Map<String, dynamic>;

      expect(json.containsKey('functions'), isFalse);
      expect(json['firestore'], {'rules': 'firestore.rules'});
      expect(json['emulators'], {
        'auth': {'port': 9099},
        'ui': {'enabled': false},
        'singleProjectMode': true,
      });
    });

    test(
      'Given no emulators key, When dropped, Then only functions is removed',
      () {
        const input =
            '{"storage": {"rules": "storage.rules"}, '
            '"functions": []}';
        final json = jsonDecode(dropFunctions(input)) as Map<String, dynamic>;

        expect(json, {
          'storage': {'rules': 'storage.rules'},
        });
      },
    );

    test(
      'Given a non-object emulators value, When dropped, Then it is left as is',
      () {
        const input = '{"emulators": [], "functions": []}';
        final json = jsonDecode(dropFunctions(input)) as Map<String, dynamic>;

        expect(json, {'emulators': <dynamic>[]});
      },
    );

    test('Given invalid JSON, When dropped, Then it throws InitFailure', () {
      expect(() => dropFunctions('{'), throwsA(isA<InitFailure>()));
    });

    test('Given a JSON array, When dropped, Then it throws InitFailure', () {
      expect(() => dropFunctions('[]'), throwsA(isA<InitFailure>()));
    });
  });

  group('dropArbKeys', () {
    test('Given adsPrivacyOptions and @adsPrivacyOptions, '
        'When dropped with [ads], Then both are gone and other keys remain '
        'in their original order', () {
      const input =
          '{"@@locale": "en", "appTitle": "A", "adsPrivacyOptions": "P", '
          '"@adsPrivacyOptions": {"description": "d"}, "zebra": "z"}';
      final json = jsonDecode(dropArbKeys(input, ['ads'])) as Map;

      expect(json.keys.toList(), ['@@locale', 'appTitle', 'zebra']);
    });

    test('Given a key address, When dropped with [ads], Then it is kept', () {
      final json =
          jsonDecode(dropArbKeys('{"address": "a", "ads": "x"}', ['ads']))
              as Map;

      expect(json.keys.toList(), ['address']);
    });

    test('Given non-ASCII values, When dropped, Then they are written '
        'unescaped with 2-space indentation and a trailing newline', () {
      final out = dropArbKeys('{"a": "Xin chào", "adsX": "y"}', ['ads']);

      expect(out, '{\n  "a": "Xin chào"\n}\n');
    });

    test(
      'Given invalid JSON, When dropped, Then the InitFailure names the file',
      () {
        expect(
          () => dropArbKeys('{', ['ads'], path: 'lib/l10n/app_vi.arb'),
          throwsA(
            isA<InitFailure>().having(
              (e) => e.message,
              'message',
              startsWith('lib/l10n/app_vi.arb: '),
            ),
          ),
        );
      },
    );

    test(
      'Given a JSON array, When dropped, Then the InitFailure names the file',
      () {
        expect(
          () => dropArbKeys('[]', ['ads'], path: 'lib/l10n/app_vi.arb'),
          throwsA(
            isA<InitFailure>().having(
              (e) => e.message,
              'message',
              'lib/l10n/app_vi.arb is not a JSON object; nothing was changed.',
            ),
          ),
        );
      },
    );
  });
}
