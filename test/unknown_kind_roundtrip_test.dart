import 'dart:convert';

import 'package:gloss_editor/services/editor_sync.dart';
import 'package:test/test.dart';

/// Eight lanes add document kinds to the plugin after this editor build ships.
/// A workspace session that carries one must still open, and the kind must
/// travel back to the server byte for byte rather than disappearing into a
/// workspace mirror that no longer mentions it.
void main() {
  test('a workspace project carrying an unknown kind decodes', () {
    final EditorSyncProject project = EditorSyncProject.decode(
      _workspaceProject(),
    );

    expect(project.documents, hasLength(2));
    expect(
      project.documents.map((EditorSyncDocument d) => d.kind),
      containsAll(<String>['menu', 'zzz-future-kind']),
    );
    expect(project.carriedDocuments, hasLength(1));
    expect(project.carriedDocuments.single.kind, 'zzz-future-kind');
  });

  test('an unknown kind survives an encode round trip byte for byte', () {
    final EditorSyncProject project = EditorSyncProject.decode(
      _workspaceProject(),
    );

    final EditorSyncProject again = EditorSyncProject.decode(project.toJson());

    expect(
      again.carriedDocuments.single.json,
      project.carriedDocuments.single.json,
    );
    expect(
      jsonEncode(again.toJson()['documents']),
      jsonEncode(project.toJson()['documents']),
    );
  });

  test('the kinds this build has no adapter for are named', () {
    final EditorSyncProject project = EditorSyncProject.decode(
      _workspaceProject(),
    );

    expect(project.unknownKinds, <String>['zzz-future-kind']);
  });

  test('a binding restored from storage refuses to publish blind', () {
    final EditorSyncBinding binding = EditorSyncBinding(
      sessionId: 'session_id_123456789ab',
      editorToken: 'editor_token_123456789',
      relayEndpoint: Uri.parse('https://relay.test/v3'),
      kind: 'workspace',
      subjectId: 'workspace',
      baseRevision: 'sha256:${List<String>.filled(64, '0').join()}',
      documentIds: const <String, String>{},
      imagePaths: const <String>[],
      constraints: const EditorSyncConstraints(
        subjectId: 'workspace',
        documentKinds: <String>[],
        createDocumentKinds: <String>[],
        allowDeletes: true,
      ),
      warnings: const <String>[],
      unknownKinds: const <String>['zzz-future-kind'],
    );

    expect(binding.carriesEveryUnknownKind, isFalse);
    expect(
      binding
          .copyWith(
            carriedDocuments: const <EditorSyncDocument>[
              EditorSyncDocument(
                kind: 'zzz-future-kind',
                id: 'pedestal',
                json: '{}',
                revision: 1,
              ),
            ],
          )
          .carriesEveryUnknownKind,
      isTrue,
    );
    expect(binding.toJson()['unknownKinds'], <String>['zzz-future-kind']);
  });

  test('the server-owned sections ride along untouched', () {
    final Map<String, dynamic> raw = _workspaceProject();
    raw.remove('baseRevision');
    raw['history'] = <Object?>[
      <String, Object?>{
        'kind': 'menus',
        'id': 'shop',
        'version': 1700,
        'source': 'watchdog',
        'bytes': 18,
      },
    ];
    raw['schemas'] = <String, Object?>{
      'menu': <String, Object?>{'type': 'object'},
    };
    raw['defaults'] = <String, Object?>{
      'menu': <Object?>[
        <String, Object?>{'id': 'default', 'json': '{"components":[]}'},
      ],
    };
    raw['baseRevision'] = editorSyncProjectRevision(raw);

    final EditorSyncProject project = EditorSyncProject.decode(raw);

    expect(project.history, hasLength(1));
    expect(project.schemas!.keys, <String>['menu']);
    expect(project.defaults!.keys, <String>['menu']);
    expect(EditorSyncProject.decode(project.toJson()).history, hasLength(1));
  });

  test('a section of the wrong shape is refused', () {
    final Map<String, dynamic> raw = _workspaceProject();
    raw.remove('baseRevision');
    raw['history'] = <String, Object?>{'not': 'a list'};
    raw['baseRevision'] = editorSyncProjectRevision(raw);

    expect(
      () => EditorSyncProject.decode(raw),
      throwsA(isA<FormatException>()),
    );
  });

  test('a kind slug that is not a slug is still refused', () {
    final Map<String, dynamic> project = _workspaceProject();
    (project['documents']! as List<Object?>)
        .cast<Map<String, dynamic>>()
        .last['kind'] = 'Not A Slug';

    expect(
      () => EditorSyncProject.decode(project),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _workspaceProject() {
  final Map<String, dynamic> project = <String, dynamic>{
    'format': 'gloss-sync-project',
    'version': 3,
    'kind': 'workspace',
    'subjectId': 'workspace',
    'documents': <Object?>[
      <String, dynamic>{
        'kind': 'menu',
        'id': 'shop',
        'json': '{"components":[]}',
      },
      <String, dynamic>{
        'kind': 'zzz-future-kind',
        'id': 'pedestal',
        'revision': 3,
        'json': '{"schemaVersion":1,"revision":3}',
      },
    ],
    'images': <Object?>[],
    'constraints': <String, dynamic>{
      'subjectId': 'workspace',
      'documentKinds': <String>[...huiEditorSyncDocumentKinds, 'zzz-future-kind'],
      'createDocumentKinds': <String>[
        ...huiEditorSyncDocumentKinds,
        'zzz-future-kind',
      ],
      'allowDeletes': true,
    },
    'warnings': <Object?>[],
  };
  project['baseRevision'] = editorSyncProjectRevision(project);
  return project;
}
