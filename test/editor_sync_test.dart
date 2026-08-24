library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/editor_sync.dart';
import 'package:gloss_editor/services/image_library.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:gloss_editor/state/workspace_panel.dart';
import 'package:gloss_editor/state/workspace_repository_contract.dart';
import 'package:gloss_editor/state/workspace_route.dart';
import 'package:test/test.dart';

const String _sessionId = 'ssssssssssssssssssssssssssssssss';
const String _editorToken = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const String _zeroRevision =
    'sha256:0000000000000000000000000000000000000000000000000000000000000000';
const String _validPng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

void main() {
  test('v3 route accepts HTTPS and localhost relay endpoints', () {
    for (final Uri relay in <Uri>[
      Uri.parse('https://sync.gloss.volmitsoftware.com/v3'),
      Uri.parse('http://localhost:8787/v3'),
    ]) {
      final WorkspaceRouteResult result = parseWorkspaceRoute(
        workspaceSyncHash(
          sessionId: _sessionId,
          editorToken: _editorToken,
          relayEndpoint: relay,
        ),
      );
      expect(result.error, isNull);
      expect((result.route! as WorkspaceSyncRoute).relayEndpoint, relay);
    }
  });

  test('empty workspace projects are valid and revision checked', () {
    final EditorSyncProject project = _workspaceProject(
      const <EditorSyncDocument>[],
    );
    expect(project.kind, 'workspace');
    expect(project.documents, isEmpty);
    expect(project.constraints.allowDeletes, isTrue);

    final Map<String, dynamic> changed = project.toJson();
    changed['subjectId'] = 'other';
    expect(
      () => EditorSyncProject.decode(changed),
      throwsA(isA<FormatException>()),
    );
  });

  test('all registered runtime kinds have v3 wire codecs', () {
    expect(huiEditorSyncDocumentKinds, <String>[
      'animation',
      'bubble-style',
      'container-preview',
      'emoji',
      'hologram',
      'menu',
      'motd',
      'panel',
      'real-drops',
      'scoreboard',
      'tablist',
    ]);
    expect(DocumentTypes.containerPreview.syncWireKind, 'container-preview');
  });

  test('matches the cross-repo v3 canonical revision fixture', () {
    final Map<String, dynamic> fixture =
        jsonDecode(
              File(
                'test/fixtures/editor-sync-canonical-v3.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final Map<String, dynamic> project =
        fixture['project']! as Map<String, dynamic>;
    expect(
      editorSyncCanonicalJson(<String, dynamic>{
        for (final MapEntry<String, dynamic> entry in project.entries)
          if (entry.key != 'baseRevision') entry.key: entry.value,
      }),
      fixture['canonicalWithoutBaseRevision'],
    );
    expect(editorSyncProjectRevision(project), project['baseRevision']);
    expect(EditorSyncProject.decode(project).kind, 'workspace');
  });

  test(
    'workspace collection includes all kinds and excludes unlinked panels',
    () {
      final Workspace workspace = Workspace(autoLoad: false);
      final ImageLibrary images = ImageLibrary(autoLoad: false);
      final EditorStore store = EditorStore(
        workspace: workspace,
        images: images,
      );
      for (final DocumentTypeAdapter adapter in DocumentTypeRegistry.all) {
        adapter.createNew(store);
      }
      store.flushAutosave();

      final WorkspaceDoc menu = workspace.docs.firstWhere(
        (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.menu,
      );
      final WorkspaceDoc panel = workspace.docs.firstWhere(
        (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.panel,
      );
      final Map<String, dynamic> definition = _panelDefinition(menu.runtimeId!);
      expect(
        workspace.replaceDocument(
          id: panel.id,
          title: panel.title,
          json: encodeWorkspacePanel(
            WorkspacePanelData(
              runtimeBoardId: 'main',
              runtimeBoard: definition,
            ),
          ),
          kind: WorkspaceDocKind.panel,
          folderId: panel.folderId,
        ),
        isTrue,
      );
      workspace.create(
        title: 'Local flow',
        runtimeId: null,
        json: encodeWorkspacePanel(const WorkspacePanelData()),
        kind: WorkspaceDocKind.panel,
      );

      final EditorSyncProject collected = collectEditorSyncProject(
        binding: _binding(),
        workspace: workspace,
        images: images,
      );
      expect(
        collected.documents
            .map((EditorSyncDocument value) => value.kind)
            .toSet(),
        huiEditorSyncDocumentKinds.toSet(),
      );
      expect(
        collected.documents.where(
          (EditorSyncDocument value) => value.kind == 'panel',
        ),
        hasLength(1),
      );
      for (final EditorSyncDocument document in collected.documents) {
        expect(
          document.revision != null,
          document.kind != 'menu' && document.kind != 'container-preview',
        );
      }
    },
  );

  test('workspace import replaces documents and assets exactly', () async {
    final Workspace workspace = Workspace(autoLoad: false);
    workspace.create(
      title: 'Local',
      runtimeId: 'local',
      json: '{"components":[]}',
    );
    final ImageLibrary images = ImageLibrary(autoLoad: false);
    images.upsertAll(const <StoredImage>[
      StoredImage(path: 'old.png', dataUri: _validPng, width: 1, height: 1),
    ]);
    final EditorSyncProject project = _workspaceProject(
      const <EditorSyncDocument>[
        EditorSyncDocument(
          kind: 'menu',
          id: 'server',
          json: '{"components":[]}',
        ),
      ],
      images: const <EditorSyncImage>[
        EditorSyncImage(path: 'server.png', data: _validPng),
      ],
    );
    final EditorSyncBinding binding = await importEditorSyncProject(
      capability: _binding(),
      project: project,
      workspace: workspace,
      images: images,
    );
    expect(
      workspace.docs.map((WorkspaceDoc value) => value.runtimeId),
      <String?>['server'],
    );
    expect(images.paths, <String>{'server.png'});
    expect(binding.documentId('menu', 'server'), isNotNull);
  });

  test(
    'workspace refresh mirrors server deletes and preserves local flow maps',
    () async {
      final Workspace workspace = Workspace(autoLoad: false);
      final ImageLibrary images = ImageLibrary(autoLoad: false);
      final EditorSyncBinding imported = await importEditorSyncProject(
        capability: _binding(),
        project: _workspaceProject(
          const <EditorSyncDocument>[
            EditorSyncDocument(
              kind: 'menu',
              id: 'server',
              json: '{"components":[]}',
            ),
          ],
          images: const <EditorSyncImage>[
            EditorSyncImage(path: 'old.png', data: _validPng),
          ],
        ),
        workspace: workspace,
        images: images,
      );
      workspace.create(
        title: 'Local flow',
        runtimeId: null,
        json: encodeWorkspacePanel(const WorkspacePanelData()),
        kind: WorkspaceDocKind.panel,
      );

      final EditorSyncBinding refreshed = await refreshEditorSyncProject(
        binding: imported,
        project: _workspaceProject(
          const <EditorSyncDocument>[],
          images: const <EditorSyncImage>[
            EditorSyncImage(path: 'new.png', data: _validPng),
          ],
        ),
        workspace: workspace,
        images: images,
      );

      expect(workspace.docs, hasLength(1));
      expect(workspace.docs.single.kind, WorkspaceDocKind.panel);
      expect(
        decodeWorkspacePanel(workspace.docs.single.json).data.runtimeBoard,
        isNull,
      );
      expect(images.paths, <String>{'new.png'});
      expect(refreshed.documentIds, isEmpty);
    },
  );

  test('focused panel collection includes only reachable prefixed menus', () {
    final Workspace workspace = Workspace(autoLoad: false);
    final ImageLibrary images = ImageLibrary(autoLoad: false);
    final HuiMenu rootMenu = HuiMenu(
      components: <HuiComponent>[
        HuiComponent(
          'next',
          Vec3.zero(),
          HuiButtonData(0.05, <HuiAction>[HuiNavigateAction('scope/child')]),
        ),
      ],
    );
    final WorkspaceDoc root = workspace.create(
      title: 'Root',
      runtimeId: 'root',
      json: encodeHuiMenu(rootMenu),
      kind: WorkspaceDocKind.menu,
    );
    workspace.create(
      title: 'Child',
      runtimeId: 'scope/child',
      json: encodeHuiMenu(HuiMenu()),
      kind: WorkspaceDocKind.menu,
    );
    workspace.create(
      title: 'Unrelated',
      runtimeId: 'scope/unrelated',
      json: encodeHuiMenu(HuiMenu()),
      kind: WorkspaceDocKind.menu,
    );
    final WorkspaceDoc panel = workspace.create(
      title: 'Panel',
      runtimeId: null,
      json: encodeWorkspacePanel(
        WorkspacePanelData(
          runtimeBoardId: 'main',
          runtimeBoard: _panelDefinition('root'),
        ),
      ),
      kind: WorkspaceDocKind.panel,
    );
    final EditorSyncBinding binding = EditorSyncBinding(
      sessionId: _sessionId,
      editorToken: _editorToken,
      relayEndpoint: Uri.parse('https://relay.example/v3'),
      kind: 'panel',
      subjectId: 'main',
      baseRevision: _zeroRevision,
      documentIds: <String, String>{
        'menu\u0000root': root.id,
        'panel\u0000main': panel.id,
      },
      imagePaths: const <String>[],
      constraints: const EditorSyncConstraints(
        subjectId: 'main',
        documentKinds: <String>['menu', 'panel'],
        createDocumentKinds: <String>['menu'],
        allowDeletes: false,
        newMenuPrefix: 'scope/',
        newImagePrefix: 'sync/main/',
      ),
      warnings: const <String>[],
    );

    final EditorSyncProject collected = collectEditorSyncProject(
      binding: binding,
      workspace: workspace,
      images: images,
    );
    expect(
      collected.menus.map((EditorSyncDocument document) => document.id),
      <String>['root', 'scope/child'],
    );
  });

  test('workspace assets may be unreferenced and larger than text images', () {
    const String largeGif = 'data:image/gif;base64,R0lGODlhIAAgAA==';
    expect(
      _workspaceProject(
        const <EditorSyncDocument>[],
        images: const <EditorSyncImage>[
          EditorSyncImage(path: 'unused.gif', data: largeGif),
        ],
      ).images,
      hasLength(1),
    );

    final Map<String, dynamic> focused = _focusedProject(
      kind: 'menu',
      id: 'main',
      json: '{"components":[]}',
      images: const <EditorSyncImage>[
        EditorSyncImage(path: 'unused.gif', data: largeGif),
      ],
    );
    expect(
      () => EditorSyncProject.decode(focused),
      throwsA(isA<FormatException>()),
    );
  });

  test('v3 enforces kind-specific ids and revision fields', () {
    final Map<String, dynamic> menuRevision = _focusedProject(
      kind: 'menu',
      id: 'main',
      json: '{"components":[]}',
      revision: 1,
    );
    final Map<String, dynamic> missingAnimationRevision = _focusedProject(
      kind: 'animation',
      id: 'pulse',
      json: '{}',
    );
    final Map<String, dynamic> nestedAnimation = _focusedProject(
      kind: 'animation',
      id: 'nested/pulse',
      json: '{"revision":1}',
      revision: 1,
    );
    final Map<String, dynamic> wrongMotdId = _focusedProject(
      kind: 'motd',
      id: 'other',
      json: '{"revision":1}',
      revision: 1,
    );
    for (final Map<String, dynamic> raw in <Map<String, dynamic>>[
      menuRevision,
      missingAnimationRevision,
      nestedAnimation,
      wrongMotdId,
    ]) {
      expect(
        () => EditorSyncProject.decode(raw),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test(
    'image persistence is workspace-scoped and queued through repository',
    () async {
      final Map<String, String> stored = <String, String>{};
      final CallbackWorkspaceRepository repository =
          CallbackWorkspaceRepository(
            reader: (String key) => stored[key],
            writer: (String key, String value) {
              stored[key] = value;
              return true;
            },
          );
      final ImageLibrary first = await ImageLibrary.open(
        workspaceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        repository: repository,
      );
      expect(
        first.upsertAll(const <StoredImage>[
          StoredImage(
            path: 'icon.png',
            dataUri: _validPng,
            width: 1,
            height: 1,
          ),
        ]),
        isTrue,
      );
      await first.writesSettled;
      expect(
        stored.keys.single,
        'gloss.workspace.images.v3.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      final ImageLibrary other = await ImageLibrary.open(
        workspaceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        repository: repository,
      );
      expect(other.images, isEmpty);
    },
  );
}

EditorSyncBinding _binding() => EditorSyncBinding(
  sessionId: _sessionId,
  editorToken: _editorToken,
  relayEndpoint: Uri.parse('https://relay.example/v3'),
  kind: 'workspace',
  subjectId: 'workspace',
  baseRevision: _zeroRevision,
  documentIds: const <String, String>{},
  imagePaths: const <String>[],
  constraints: EditorSyncConstraints(
    subjectId: 'workspace',
    documentKinds: huiEditorSyncDocumentKinds,
    createDocumentKinds: huiEditorSyncDocumentKinds,
    allowDeletes: true,
  ),
  warnings: const <String>[],
);

EditorSyncProject _workspaceProject(
  List<EditorSyncDocument> documents, {
  List<EditorSyncImage> images = const <EditorSyncImage>[],
}) {
  final List<EditorSyncDocument> ordered =
      List<EditorSyncDocument>.of(documents)
        ..sort((EditorSyncDocument first, EditorSyncDocument second) {
          final int kind = first.kind.compareTo(second.kind);
          return kind == 0 ? first.id.compareTo(second.id) : kind;
        });
  final List<EditorSyncImage> orderedImages = List<EditorSyncImage>.of(images)
    ..sort(
      (EditorSyncImage first, EditorSyncImage second) =>
          first.path.compareTo(second.path),
    );
  final Map<String, dynamic> raw = <String, dynamic>{
    'format': huiEditorSyncFormat,
    'version': huiEditorSyncProtocol,
    'kind': 'workspace',
    'subjectId': 'workspace',
    'baseRevision': _zeroRevision,
    'documents': ordered
        .map((EditorSyncDocument value) => value.toJson())
        .toList(),
    'images': orderedImages
        .map((EditorSyncImage value) => value.toJson())
        .toList(),
    'constraints': <String, dynamic>{
      'subjectId': 'workspace',
      'documentKinds': huiEditorSyncDocumentKinds,
      'createDocumentKinds': huiEditorSyncDocumentKinds,
      'allowDeletes': true,
    },
    'warnings': <String>[],
  };
  raw['baseRevision'] = editorSyncProjectRevision(raw);
  return EditorSyncProject.decode(raw);
}

Map<String, dynamic> _focusedProject({
  required String kind,
  required String id,
  required String json,
  int? revision,
  List<EditorSyncImage> images = const <EditorSyncImage>[],
}) {
  final bool menu = kind == 'menu';
  final Map<String, dynamic> raw = <String, dynamic>{
    'format': huiEditorSyncFormat,
    'version': huiEditorSyncProtocol,
    'kind': kind,
    'subjectId': id,
    'baseRevision': _zeroRevision,
    'documents': <Map<String, dynamic>>[
      EditorSyncDocument(
        kind: kind,
        id: id,
        json: json,
        revision: revision,
      ).toJson(),
    ],
    'images': images
        .map((EditorSyncImage image) => image.toJson())
        .toList(growable: false),
    'constraints': <String, dynamic>{
      'subjectId': id,
      'documentKinds': <String>[kind],
      'createDocumentKinds': <String>[],
      'allowDeletes': false,
      if (menu) 'newImagePrefix': 'sync/menus/$id/',
    },
    'warnings': <String>[],
  };
  raw['baseRevision'] = editorSyncProjectRevision(raw);
  return raw;
}

Map<String, dynamic> _panelDefinition(String rootMenuId) => <String, dynamic>{
  'schemaVersion': 1,
  'id': 'main',
  'uuid': '00000000-0000-4000-8000-000000000042',
  'revision': 1,
  'rootMenuId': rootMenuId,
  'transform': <String, dynamic>{
    'worldKey': 'minecraft:overworld',
    'worldUuid': '00000000-0000-4000-8000-000000000043',
    'x': 0,
    'y': 64,
    'z': 0,
    'yaw': 0,
    'pitch': 0,
    'roll': 0,
    'scale': 1,
  },
  'follow': <String, dynamic>{
    'mode': 'none',
    'targetPlayerUuid': null,
    'rotation': 'fixed',
  },
  'visibility': <String, dynamic>{
    'mode': 'public',
    'viewPermission': null,
    'interactPermission': null,
    'viewRange': 64,
    'interactionRange': 8,
  },
};
