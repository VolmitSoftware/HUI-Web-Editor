import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gloss_sync_relay/gloss_sync_relay.dart';
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
      'project-menu-v2.json',
      'project-menu-edited-v2.json',
      'project-panel-canonical-v2.json',
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
    final Map<String, Object?> initial = _fixture('project-menu-v2.json');
    final Map<String, Object?> edited = _fixture('project-menu-edited-v2.json');
    expect(_fixture('create-request-v2.json')['snapshot'], initial);
    expect(_fixture('publish-request-v2.json')['snapshot'], edited);
    expect(_fixture('publication-response-v2.json'), contains('publication'));
    expect(_fixture('session-pending-response-v2.json')['status'], 'pending');
    expect(_fixture('project-panel-canonical-v2.json')['kind'], 'panel');
    expect(
      ((_fixture('ack-rejected-response-v2.json')['publication']! as Map)['ack']
          as Map)['serverRevision'],
      isNull,
    );
  });

  test('fixture document kinds are open slugs the relay never interprets', () {
    for (final String name in <String>[
      'project-menu-v2.json',
      'project-menu-edited-v2.json',
      'project-panel-canonical-v2.json',
    ]) {
      final Map<String, Object?> project = _fixture(name);
      expect(project['format'], 'gloss-sync-project', reason: name);
      expect(project['version'], 2, reason: name);
      expect(
        relayKindSlug.hasMatch(project['kind']! as String),
        isTrue,
        reason: name,
      );
      final List<Object?> documents = project['documents']! as List<Object?>;
      expect(documents, isNotEmpty, reason: name);
      for (final Object? document in documents) {
        expect(
          relayKindSlug.hasMatch((document! as Map)['kind']! as String),
          isTrue,
          reason: name,
        );
      }
    }
  });

  test('the panel golden pins canonical document text', () {
    // The panel document's json is required to be canonical JSON text under
    // the frozen cross-repo canonicalization: sorted keys, array order, and
    // ECMAScript number spelling (1e20 in decimal, -0.0 as 0, 1e-7 in
    // lowercase exponent form).
    final Map<String, Object?> project = _fixture(
      'project-panel-canonical-v2.json',
    );
    final List<Object?> documents = project['documents']! as List<Object?>;
    final Map<String, Object?> panelDocument = _object(
      documents.lastWhere(
        (Object? document) => (document! as Map)['kind'] == 'panel',
      ),
    );
    final String json = panelDocument['json']! as String;
    expect(_canonical(jsonDecode(json)), json);
    expect(json, contains('"x":100000000000000000000'));
    expect(json, contains('"yaw":0'));
    expect(json, contains('"z":1e-7'));
  });
}

Map<String, Object?> _fixture(String name) =>
    _object(jsonDecode(File('fixtures/$name').readAsStringSync()));

Map<String, Object?> _object(Object? raw) {
  if (raw is! Map) throw const FormatException('fixture must be an object');
  return raw.cast<String, Object?>();
}

String _canonical(Object? value) {
  if (value is num) return _canonicalNumber(value);
  if (value == null || value is bool || value is String) {
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

String _canonicalNumber(num value) {
  final double numeric = value.toDouble();
  if (!numeric.isFinite) {
    throw const FormatException('canonical JSON numbers must be finite');
  }
  if (numeric == 0) return '0';
  final String encoded = numeric.toString();
  if (encoded.endsWith('.0')) {
    return encoded.substring(0, encoded.length - 2);
  }
  return encoded.replaceFirstMapped(
    RegExp(r'e([+-]?)0+(\d+)'),
    (Match match) => 'e${match.group(1)}${match.group(2)}',
  );
}
