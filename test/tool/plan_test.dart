import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/plan.dart';

void main() {
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

    test('Given invalid JSON, When dropped, Then it throws InitFailure', () {
      expect(() => dropFunctions('{'), throwsA(isA<InitFailure>()));
    });

    test('Given a JSON array, When dropped, Then it throws InitFailure', () {
      expect(() => dropFunctions('[]'), throwsA(isA<InitFailure>()));
    });
  });
}
