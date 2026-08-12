import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  test('all protocol schemas and golden fixtures are valid JSON objects', () {
    final List<File> files = <File>[
      ...Directory('schema').listSync(followLinks: false).whereType<File>(),
      ...Directory('fixtures').listSync(followLinks: false).whereType<File>(),
    ]..sort((File left, File right) => left.path.compareTo(right.path));
    expect(files, hasLength(16));
    for (final File file in files) {
      expect(
        jsonDecode(file.readAsStringSync()),
        isA<Map<Object?, Object?>>(),
        reason: file.path,
      );
    }
  });

  test('golden project revisions follow the canonical root hash contract', () {
    for (final String name in <String>[
      'project-menu-v1.json',
      'project-menu-edited-v1.json',
    ]) {
      final Map<String, Object?> project = _object(
        jsonDecode(File('fixtures/$name').readAsStringSync()),
      );
      final String declared = project['baseRevision']! as String;
      final Map<String, Object?> content = Map<String, Object?>.of(project)
        ..remove('baseRevision');
      final String actual =
          'sha256:${sha256.convert(utf8.encode(_canonical(content)))}';
      expect(actual, declared, reason: name);
    }
  });

  test('request fixtures embed the authoritative project goldens', () {
    final Map<String, Object?> initial = _fixture('project-menu-v1.json');
    final Map<String, Object?> edited = _fixture('project-menu-edited-v1.json');
    expect(_fixture('create-request-v1.json')['snapshot'], initial);
    expect(_fixture('publish-request-v1.json')['snapshot'], edited);
    expect(_fixture('publication-response-v1.json'), contains('publication'));
    expect(_fixture('session-pending-response-v1.json')['status'], 'pending');
    expect(_fixture('project-board-canonical-v1.json')['kind'], 'board');
    expect(
      ((_fixture('ack-rejected-response-v1.json')['publication']! as Map)['ack']
          as Map)['serverRevision'],
      isNull,
    );
  });
}

Map<String, Object?> _fixture(String name) =>
    _object(jsonDecode(File('fixtures/$name').readAsStringSync()));

Map<String, Object?> _object(Object? raw) {
  if (raw is! Map) throw const FormatException('fixture must be an object');
  return raw.cast<String, Object?>();
}

String _canonical(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map<String>(_canonical).join(',')}]';
  }
  if (value is Map) {
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map<String>((String key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  throw const FormatException('fixture contains an unsupported JSON value');
}
