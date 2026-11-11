import 'dart:io';

/// Gated architecture layers and their minimum line coverage.
enum Layer {
  domain(100),
  data(90),
  application(80);

  const Layer(this.threshold);

  /// Minimum line coverage, in percent.
  final double threshold;
}

typedef Counts = ({int found, int hit});

/// Classifies a repo-relative `lib/...` path, or returns null if not gated.
Layer? layerOf(String libPath) {
  if (!libPath.startsWith('lib/') || !libPath.endsWith('.dart')) return null;
  if (libPath.endsWith('.g.dart') || libPath.endsWith('.freezed.dart')) {
    return null;
  }
  if (libPath.contains('/domain/')) return Layer.domain;
  if (libPath.contains('/data/')) return Layer.data;
  if (libPath.contains('/application/') ||
      libPath.startsWith('lib/core/router/') ||
      libPath.startsWith('lib/core/config/') ||
      libPath.startsWith('lib/core/providers/')) {
    return Layer.application;
  }
  return null;
}

/// Parses lcov text into per-file line counts keyed by repo-relative path.
Map<String, Counts> parseLcov(String lcov) {
  final result = <String, Counts>{};
  String? file;
  int? found;
  var hit = 0;
  for (final raw in lcov.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      file = _normalize(line.substring(3));
      found = null;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.tryParse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.tryParse(line.substring(3)) ?? 0;
    } else if (line == 'end_of_record' && file != null) {
      if (found != null) result[file] = (found: found, hit: hit);
      file = null;
    }
  }
  return result;
}

String _normalize(String path) {
  final p = path.replaceAll(r'\', '/');
  if (p.startsWith('lib/')) return p;
  final i = p.lastIndexOf('/lib/');
  return i == -1 ? p : p.substring(i + 1);
}

final _lineComment = RegExp(r'//.*');
final _body = RegExp(r'\)\s*(async\*|sync\*|async)?\s*\{');
final _getterBody = RegExp(r'\bget\s+\w+\s*\{');
final _initializerBody = RegExp(r'\)\s*:[^;{]*\{');

/// Whether the source has any function body (so it would appear in lcov).
///
/// Strips `//` line comments, then is true when the source contains `=>`,
/// a `) [async|async*|sync*] {` body, a block-bodied getter
/// (`get x {`), or a constructor with an initializer list (`) : x = 1 {`).
bool hasExecutableCode(String dartSource) {
  final code = dartSource.replaceAll(_lineComment, '');
  return code.contains('=>') ||
      _body.hasMatch(code) ||
      _getterBody.hasMatch(code) ||
      _initializerBody.hasMatch(code);
}

class GateResult {
  GateResult(this.totals, this.unloaded);

  final Map<Layer, Counts> totals;
  final List<String> unloaded;

  bool get passed =>
      unloaded.isEmpty &&
      Layer.values.every((l) {
        final c = totals[l];
        if (c == null || c.found == 0) return true;
        return _percent(c) >= l.threshold;
      });
}

double _percent(Counts c) => c.found == 0 ? 100 : c.hit * 100 / c.found;

/// One report line for [layer]. The percentage is floored to one decimal so
/// a failing layer never prints as 100.0%.
String formatLayerLine(Layer layer, Counts c) {
  final percent = _percent(c);
  final shown = (percent * 10).floor() / 10;
  final status = percent >= layer.threshold ? 'OK' : 'FAIL';
  return '${layer.name.padRight(12)}${shown.toStringAsFixed(1).padLeft(5)}% '
      '(${c.hit}/${c.found})  >= ${layer.threshold.toStringAsFixed(0)}% '
      '$status';
}

/// Aggregates lcov counts per layer and finds gated files missing from lcov.
GateResult evaluate(
  Map<String, Counts> lcov,
  Map<String, String> gatedSources,
) {
  final found = {for (final l in Layer.values) l: 0};
  final hit = {for (final l in Layer.values) l: 0};
  for (final entry in lcov.entries) {
    final layer = layerOf(entry.key);
    if (layer == null) continue;
    found[layer] = found[layer]! + entry.value.found;
    hit[layer] = hit[layer]! + entry.value.hit;
  }
  final unloaded = <String>[
    for (final entry in gatedSources.entries)
      if (!lcov.containsKey(entry.key) && hasExecutableCode(entry.value))
        entry.key,
  ]..sort();
  return GateResult({
    for (final l in Layer.values) l: (found: found[l]!, hit: hit[l]!),
  }, unloaded);
}

void main(List<String> args) {
  final lcovPath = args.isEmpty ? 'coverage/lcov.info' : args.first;
  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln('coverage gate: $lcovPath not found');
    exit(1);
  }
  final sources = <String, String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File) continue;
    final path = f.path.replaceAll(r'\', '/');
    if (layerOf(path) != null) sources[path] = f.readAsStringSync();
  }
  final result = evaluate(parseLcov(lcovFile.readAsStringSync()), sources);
  for (final l in Layer.values) {
    stdout.writeln(formatLayerLine(l, result.totals[l]!));
  }
  for (final path in result.unloaded) {
    stdout.writeln('UNLOADED (has code, never loaded by tests): $path');
  }
  if (!result.passed) exit(1);
}
