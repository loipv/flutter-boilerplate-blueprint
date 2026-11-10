import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/options.dart';
import '../../tool/src/rename.dart';

InitOptions opts({
  String name = 'acme_notes',
  String org = 'io.acme',
  String title = 'Acme Notes',
  String description = 'Notes for Acme',
}) => InitOptions(name: name, org: org, title: title, description: description);

void main() {
  test('renames the application id before the bare name', () {
    expect(
      renameText('applicationId = "com.example.blueprint_app"', opts()),
      'applicationId = "io.acme.acme_notes"',
    );
  });

  test('renames package imports', () {
    expect(
      renameText("import 'package:blueprint_app/app.dart';", opts()),
      "import 'package:acme_notes/app.dart';",
    );
  });

  test('renames title and description', () {
    expect(
      renameText('Blueprint App: A Flutter + Firebase starter app', opts()),
      'Acme Notes: Notes for Acme',
    );
  });

  test('inserts special characters literally', () {
    expect(
      renameText("'Blueprint App'", opts(title: r'Ghi Chú (v2.0) | Beta')),
      r"'Ghi Chú (v2.0) | Beta'",
    );
  });

  test('does not re-replace a new name that contains the fixed name', () {
    expect(
      renameText(
        'package:blueprint_app/a.dart',
        opts(name: 'blueprint_app_two'),
      ),
      'package:blueprint_app_two/a.dart',
    );
  });

  test('does not re-replace an org that contains the fixed name', () {
    expect(
      renameText('com.example.blueprint_app', opts(org: 'io.blueprint_app')),
      'io.blueprint_app.acme_notes',
    );
  });

  test('is the identity when values are unchanged', () {
    expect(
      renameText(
        'com.example.blueprint_app',
        opts(
          name: 'blueprint_app',
          org: 'com.example',
          title: 'Blueprint App',
          description: 'A Flutter + Firebase starter app',
        ),
      ),
      'com.example.blueprint_app',
    );
  });

  test('kotlinDir', () {
    expect(
      kotlinDir('io.acme.mobile', 'acme_notes'),
      'android/app/src/main/kotlin/io/acme/mobile/acme_notes',
    );
  });

  test('findLeftovers reports fixed values', () {
    expect(findLeftovers('x blueprint_app y Blueprint App', opts()), [
      'blueprint_app',
      'Blueprint App',
    ]);
  });

  test('findLeftovers skips values the new identity contains', () {
    expect(
      findLeftovers(
        'package:blueprint_app_two/',
        opts(name: 'blueprint_app_two'),
      ),
      isEmpty,
    );
  });
}
