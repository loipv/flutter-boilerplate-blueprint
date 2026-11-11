import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/app_id.dart';

void main() {
  group('shareAppIdInGradle', () {
    const gradle = '''
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "[S] Blueprint App")
        }
''';

    test('removes the staging suffix line and nothing else', () {
      expect(shareAppIdInGradle(gradle), '''
        create("staging") {
            dimension = "env"
            resValue("string", "app_name", "[S] Blueprint App")
        }
''');
    });

    test('throws when the suffix line is missing', () {
      expect(
        () => shareAppIdInGradle('dimension = "env"\n'),
        throwsA(isA<AppIdException>()),
      );
    });

    test('throws when the suffix line appears twice', () {
      expect(
        () => shareAppIdInGradle(gradle + gradle),
        throwsA(isA<AppIdException>()),
      );
    });
  });

  group('shareAppIdInPbxproj', () {
    const pbxproj = '''
				PRODUCT_BUNDLE_IDENTIFIER = com.example.blueprint_app.staging;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.blueprint_app.RunnerTests;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.blueprint_app;
''';

    test('points staging configs at the production id, keeps RunnerTests', () {
      expect(shareAppIdInPbxproj(pbxproj), '''
				PRODUCT_BUNDLE_IDENTIFIER = com.example.blueprint_app;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.blueprint_app.RunnerTests;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.blueprint_app;
''');
    });

    test('throws when no staging id is present', () {
      expect(
        () => shareAppIdInPbxproj(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.blueprint_app;\n',
        ),
        throwsA(isA<AppIdException>()),
      );
    });
  });

  test('the committed platform files match what init expects', () {
    final gradle = File(gradlePath).readAsStringSync();
    final pbxproj = File(pbxprojPath).readAsStringSync();

    expect(shareAppIdInGradle(gradle), isNot(contains('applicationIdSuffix')));
    final shared = shareAppIdInPbxproj(pbxproj);
    expect(shared, isNot(contains('blueprint_app.staging')));
    expect(
      'blueprint_app.RunnerTests;'.allMatches(shared).length,
      'blueprint_app.RunnerTests;'.allMatches(pbxproj).length,
    );
  });
}
