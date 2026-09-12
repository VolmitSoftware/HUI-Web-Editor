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
    expect(files, hasLength(19));
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
      'project-menu-v3.json',
      'project-menu-edited-v3.json',
      'project-panel-canonical-v3.json',
      'project-workspace-empty-v3.json',
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
    final Map<String, Object?> initial = _fixture('project-menu-v3.json');
    final Map<String, Object?> edited = _fixture('project-menu-edited-v3.json');
    expect(_fixture('create-request-v3.json')['snapshot'], initial);
    expect(_fixture('publish-request-v3.json')['snapshot'], edited);
    expect(_fixture('publication-response-v3.json'), contains('publication'));
    expect(_fixture('session-pending-response-v3.json')['status'], 'pending');
    expect(_fixture('project-panel-canonical-v3.json')['kind'], 'panel');
    expect(_fixture('project-workspace-empty-v3.json')['documents'], isEmpty);
    expect(
      ((_fixture('ack-rejected-response-v3.json')['publication']! as Map)['ack']
          as Map)['serverRevision'],
      isNull,
    );
    expect(
      ((_fixture('ack-applied-response-v3.json')['publication']! as Map)['ack']
          as Map)['conflicts'],
      <Object?>[
        <String, Object?>{'kind': 'menu', 'id': 'admin'},
      ],
    );
    expect(_fixture('history-response-v3.json')['found'], isTrue);
    expect(_fixture('history-request-v3.json')['protocol'], 3);
  });

  test('fixture document kinds are open slugs the relay never interprets', () {
    for (final String name in <String>[
      'project-menu-v3.json',
      'project-menu-edited-v3.json',
      'project-panel-canonical-v3.json',
      'project-workspace-empty-v3.json',
    ]) {
      final Map<String, Object?> project = _fixture(name);
      expect(project['format'], 'gloss-sync-project', reason: name);
      expect(project['version'], 3, reason: name);
      expect(
        relayKindSlug.hasMatch(project['kind']! as String),
        isTrue,
        reason: name,
      );
      final List<Object?> documents = project['documents']! as List<Object?>;
      if (project['kind'] == 'workspace') {
        expect(documents, isEmpty, reason: name);
      } else {
        expect(documents, isNotEmpty, reason: name);
      }
      for (final Object? document in documents) {
        expect(
          relayKindSlug.hasMatch((document! as Map)['kind']! as String),
          isTrue,
          reason: name,
        );
      }
    }
  });

  test('every project entry carries its own base revision', () {
    // The server stamps the content revision of each served document on its
    // entry, and a publication echoes the served value back — that is what
    // lets the server reconcile a publication document by document. A served
    // or applied project's entry revision is the revision of its own text; a
    // publication's is the revision of the text it started from.
    for (final String name in <String>[
      'project-menu-v3.json',
      'project-menu-edited-v3.json',
      'project-panel-canonical-v3.json',
      'create-request-v3.json',
      'publish-request-v3.json',
      'ack-applied-request-v3.json',
    ]) {
      final Map<String, Object?> fixture = _fixture(name);
      final Map<String, Object?> project = fixture.containsKey('snapshot')
          ? _object(fixture['snapshot'])
          : fixture;
      final List<Object?> documents = project['documents']! as List<Object?>;
      expect(documents, isNotEmpty, reason: name);
      for (final Object? entry in documents) {
        final Map<String, Object?> document = _object(entry);
        final Object? revision = document['baseRevision'];
        expect(revision, isA<String>(), reason: name);
        expect(
          RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(revision! as String),
          isTrue,
          reason: name,
        );
      }
    }

    final String served =
        _object(
              (_fixture('project-menu-v3.json')['documents']!
                  as List<Object?>)[0],
            )['baseRevision']!
            as String;
    expect(
      served,
      'sha256:${sha256.convert(utf8.encode(_canonical(jsonDecode('{"components":[]}'))))}',
    );
    expect(
      _object(
        (_fixture('project-menu-edited-v3.json')['documents']!
            as List<Object?>)[0],
      )['baseRevision'],
      served,
      reason: 'a publication echoes the served revision, not its own',
    );
  });

  test('the panel golden pins canonical document text', () {
    // The panel document's json is required to be canonical JSON text under
    // the frozen cross-repo canonicalization: sorted keys, array order, and
    // ECMAScript number spelling (1e20 in decimal, -0.0 as 0, 1e-7 in
    // lowercase exponent form).
    final Map<String, Object?> project = _fixture(
      'project-panel-canonical-v3.json',
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
