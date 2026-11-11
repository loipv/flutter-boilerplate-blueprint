/// Marker-line handling for the init tool. Pure string functions, `dart:` only.
library;

/// Thrown when BEGIN/END markers are unbalanced.
class MarkerException implements Exception {
  MarkerException(this.message);

  final String message;

  @override
  String toString() => 'MarkerException: $message';
}

final RegExp _markerLine = RegExp(
  r'^\s*(?://|#|<!--)\s*(BEGIN|END)_([A-Z][A-Z0-9_]*)\s*(?:-->)?\s*$',
);

/// Removes each `BEGIN_<marker>` ... `END_<marker>` block, marker lines included.
String stripBlocks(String text, String marker) {
  final kept = <String>[];
  var open = false;
  var openLine = 0;
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = _markerLine.firstMatch(lines[i]);
    if (match != null && match.group(2) == marker) {
      final isBegin = match.group(1) == 'BEGIN';
      if (isBegin) {
        if (open) {
          throw MarkerException(
            'Nested BEGIN_$marker at line ${i + 1} '
            '(already open since line $openLine)',
          );
        }
        open = true;
        openLine = i + 1;
      } else {
        if (!open) {
          throw MarkerException(
            'END_$marker without BEGIN_$marker at line ${i + 1}',
          );
        }
        open = false;
      }
      continue;
    }
    if (!open) kept.add(lines[i]);
  }
  if (open) {
    throw MarkerException('Unclosed BEGIN_$marker at line $openLine');
  }
  return kept.join('\n');
}

/// Removes every marker line of any name, keeping the content between them.
String stripMarkerLines(String text) =>
    text.split('\n').where((line) => !_markerLine.hasMatch(line)).join('\n');

/// Whether [text] contains at least one marker line.
bool hasMarkerLines(String text) => text.split('\n').any(_markerLine.hasMatch);

/// Every marker line in [text]: its 1-based line number and marker name.
Iterable<({int line, String name})> markerNames(String text) sync* {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = _markerLine.firstMatch(lines[i]);
    if (match != null) yield (line: i + 1, name: match.group(2)!);
  }
}
