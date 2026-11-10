/// File-system helpers for the init tool. `dart:` only; every path is
/// relative to the current directory and uses forward slashes.
library;

import 'dart:convert';
import 'dart:io';

/// Whether anything (file, directory or link) exists at [path].
bool pathExists(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) !=
    FileSystemEntityType.notFound;

/// Whether [path] is [prefix] or lies inside it.
bool isUnder(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// Every file below the current directory, sorted, never entering a directory
/// whose name is in [skipDirs] and never following links.
List<String> listFiles(Set<String> skipDirs) {
  final result = <String>[];
  void walk(Directory dir, String prefix) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final rel = prefix.isEmpty ? name : '$prefix/$name';
      if (entity is Directory) {
        if (!skipDirs.contains(name)) walk(entity, rel);
      } else if (entity is File) {
        result.add(rel);
      }
    }
  }

  walk(Directory.current, '');
  return result..sort();
}

/// Decodes [path] as strict UTF-8, or returns null when it is not UTF-8.
String? readUtf8OrNull(String path) {
  try {
    return utf8.decode(File(path).readAsBytesSync());
  } on FormatException {
    return null;
  }
}

/// Deletes the file, link or directory tree at [path], if any.
void deletePath(String path) {
  switch (FileSystemEntity.typeSync(path, followLinks: false)) {
    case FileSystemEntityType.directory:
      Directory(path).deleteSync(recursive: true);
    case FileSystemEntityType.link:
      Link(path).deleteSync();
    case FileSystemEntityType.notFound:
      break;
    default:
      File(path).deleteSync();
  }
}

/// Moves [from] to [to], creating the parents of [to].
void moveFile(String from, String to) {
  Directory(to.substring(0, to.lastIndexOf('/'))).createSync(recursive: true);
  File(from).renameSync(to);
}

/// Removes [dir] and then each parent while it is empty, stopping before
/// [stopAt] (which is never removed).
void removeEmptyDirs(String dir, String stopAt) {
  var current = dir;
  while (current != stopAt && current.startsWith('$stopAt/')) {
    final directory = Directory(current);
    if (!directory.existsSync() || directory.listSync().isNotEmpty) return;
    directory.deleteSync();
    current = current.substring(0, current.lastIndexOf('/'));
  }
}
