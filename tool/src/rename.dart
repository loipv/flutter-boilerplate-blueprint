/// Single-pass text renaming for the init tool. `dart:` only.
library;

import 'options.dart';

const fixedId = 'com.example.blueprint_app';
const fixedName = 'blueprint_app';
const fixedTitle = 'Blueprint App';
const fixedDescription = 'A Flutter + Firebase starter app';

// Longest first so the id wins over the bare name.
final _pattern = RegExp(
  [
    fixedId,
    fixedName,
    fixedTitle,
    fixedDescription,
  ].map(RegExp.escape).join('|'),
);

/// Replaces every fixed value in [text] with its new value, in one pass so a
/// replacement is never re-scanned.
String renameText(String text, InitOptions o) {
  final replacements = {
    fixedId: '${o.org}.${o.name}',
    fixedName: o.name,
    fixedTitle: o.title,
    fixedDescription: o.description,
  };
  return text.replaceAllMapped(_pattern, (m) => replacements[m[0]]!);
}

/// Forward-slash path of the Kotlin package directory, relative to the root.
String kotlinDir(String org, String name) =>
    'android/app/src/main/kotlin/${'$org.$name'.replaceAll('.', '/')}';

/// Fixed values still present in [text], skipping any that is a substring of
/// one of the new values.
List<String> findLeftovers(String text, InitOptions o) {
  final newValues = ['${o.org}.${o.name}', o.name, o.title, o.description];
  return [
    for (final v in [fixedId, fixedName, fixedTitle, fixedDescription])
      if (text.contains(v) && !newValues.any((n) => n.contains(v))) v,
  ];
}
