import 'dart:convert';
import 'dart:io';

/// Placeholder names of [key]: from `@key.placeholders` when present, else the
/// top-level `{name}` / `{name, plural|select, ...}` tokens of the message.
Set<String> placeholdersOf(Map<String, dynamic> arb, String key) {
  final meta = arb['@$key'];
  if (meta is Map && meta['placeholders'] is Map) {
    return (meta['placeholders'] as Map).keys.cast<String>().toSet();
  }
  final message = arb[key];
  if (message is! String) return {};
  final names = <String>{};
  var depth = 0;
  var start = -1;
  for (var i = 0; i < message.length; i++) {
    final c = message[i];
    if (c == '{') {
      if (depth == 0) start = i + 1;
      depth++;
    } else if (c == '}' && depth > 0) {
      depth--;
      if (depth == 0) {
        final inner = message.substring(start, i);
        final comma = inner.indexOf(',');
        final name = (comma < 0 ? inner : inner.substring(0, comma)).trim();
        if (name.isNotEmpty) names.add(name);
      }
    }
  }
  return names;
}

/// One human-readable problem per line; empty when [other] matches [template].
List<String> compareArb(
  Map<String, dynamic> template,
  Map<String, dynamic> other, {
  required String locale,
}) {
  Set<String> keysOf(Map<String, dynamic> m) =>
      m.keys.where((k) => !k.startsWith('@')).toSet();
  final templateKeys = keysOf(template);
  final otherKeys = keysOf(other);
  final problems = <String>[];
  for (final k in templateKeys.difference(otherKeys).toList()..sort()) {
    problems.add('[$locale] missing key "$k"');
  }
  for (final k in otherKeys.difference(templateKeys).toList()..sort()) {
    problems.add('[$locale] extra key "$k" not in the template');
  }
  for (final k in (templateKeys.intersection(otherKeys).toList()..sort())) {
    final expected = placeholdersOf(template, k);
    final actual = placeholdersOf(other, k);
    if (expected.length != actual.length || !expected.containsAll(actual)) {
      problems.add(
        '[$locale] placeholders of "$k" differ: expected '
        '${(expected.toList()..sort())}, found ${(actual.toList()..sort())}',
      );
    }
  }
  return problems;
}

/// The scalar value of top-level [key] in [yaml], without surrounding quotes
/// or a trailing `# comment`; null when the key is absent.
String? yamlValue(String yaml, String key) {
  final match = RegExp(
    '^${RegExp.escape(key)}:\\s*(.*?)\\s*(?:\\s#.*)?\$',
    multiLine: true,
  ).firstMatch(yaml);
  final value = match?.group(1);
  if (value == null || value.isEmpty) return null;
  final quoted = RegExp(
    r'^"(.*)"$|'
    r"^'(.*)'$",
  ).firstMatch(value);
  return quoted == null ? value : (quoted.group(1) ?? quoted.group(2));
}

/// A malformed ARB file.
class ArbException implements Exception {
  ArbException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Decodes the ARB [text] of the file [name]. Throws [ArbException] when it
/// is not a JSON object.
Map<String, dynamic> decodeArb(String text, String name) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    throw ArbException('$name is not valid JSON: ${e.message}');
  }
  if (json is! Map<String, dynamic>) {
    throw ArbException('$name is not a JSON object');
  }
  return json;
}

Map<String, dynamic> _readArb(File f) =>
    decodeArb(f.readAsStringSync(), f.uri.pathSegments.last);

void main() {
  final config = File('l10n.yaml');
  if (!config.existsSync()) {
    stderr.writeln('l10n.yaml not found; run from the project root.');
    exit(1);
  }
  final yaml = config.readAsStringSync();
  final dir = yamlValue(yaml, 'arb-dir');
  final templateName = yamlValue(yaml, 'template-arb-file');
  if (dir == null || templateName == null) {
    stderr.writeln('l10n.yaml needs arb-dir and template-arb-file.');
    exit(1);
  }
  try {
    _check(dir, templateName);
  } on ArbException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }
}

void _check(String dir, String templateName) {
  final template = _readArb(File('$dir/$templateName'));
  final others = Directory(dir).listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return name.startsWith('app_') &&
        name.endsWith('.arb') &&
        name != templateName;
  }).toList()..sort((a, b) => a.path.compareTo(b.path));
  final problems = <String>[];
  for (final f in others) {
    final name = f.uri.pathSegments.last;
    final locale = name.substring('app_'.length, name.length - '.arb'.length);
    problems.addAll(compareArb(template, _readArb(f), locale: locale));
  }
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    exit(1);
  }
  final keyCount = template.keys.where((k) => !k.startsWith('@')).length;
  stdout.writeln('l10n OK (${others.length + 1} locales, $keyCount keys)');
}
