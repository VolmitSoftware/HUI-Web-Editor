/// Reads the client jar as a plain archive. Only `assets/minecraft/` is ever
/// touched; classes are never loaded.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

final class JarAssets {
  JarAssets._(this._byPath);

  factory JarAssets.fromBytes(Uint8List bytes) {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    return JarAssets._(<String, ArchiveFile>{
      for (final ArchiveFile file in archive.files)
        if (file.isFile) file.name: file,
    });
  }

  factory JarAssets.fromFile(File file) =>
      JarAssets.fromBytes(file.readAsBytesSync());

  final Map<String, ArchiveFile> _byPath;

  Uint8List? bytes(String path) {
    final ArchiveFile? file = _byPath[path];
    if (file == null) return null;
    return Uint8List.fromList(file.content as List<int>);
  }

  String? text(String path) {
    final Uint8List? raw = bytes(path);
    return raw == null ? null : utf8.decode(raw);
  }

  /// Every entry path starting with [prefix] and ending with [suffix], sorted.
  Iterable<String> paths(String prefix, String suffix) {
    final List<String> found = <String>[
      for (final String path in _byPath.keys)
        if (path.startsWith(prefix) && path.endsWith(suffix)) path,
    ]..sort();
    return found;
  }
}
