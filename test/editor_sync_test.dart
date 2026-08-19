library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/config/defaults.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/editor_sync.dart';
import 'package:gloss_editor/services/image_library.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:gloss_editor/state/workspace_panel.dart';
import 'package:gloss_editor/state/workspace_repository_contract.dart';
import 'package:gloss_editor/state/workspace_route.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const String _sessionId = 'ssssssssssssssssssssssssssssssss';
const String _editorToken = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const String _zeroRevision =
    'sha256:0000000000000000000000000000000000000000000000000000000000000000';

void main() {
  group('sync route', () {
    test('round-trips HTTPS and localhost HTTP relay capabilities', () {
      for (final Uri relay in <Uri>[
        Uri.parse('https://sync.gloss.volmitsoftware.com/v2'),
        Uri.parse('https://relay.example.net/custom/v2'),
        Uri.parse('http://localhost:8787/v2'),
      ]) {
        final WorkspaceRouteResult result = parseWorkspaceRoute(
          workspaceSyncHash(
            sessionId: _sessionId,
            editorToken: _editorToken,
            relayEndpoint: relay,
          ),
        );
        expect(result.error, isNull, reason: '$relay');
        final WorkspaceSyncRoute route = result.route! as WorkspaceSyncRoute;
        expect(route.sessionId, _sessionId);
        expect(route.editorToken, _editorToken);
        expect(route.relayEndpoint, relay);
      }
    });

    test('rejects insecure, credentialed, ambiguous and malformed relays', () {
      for (final String relay in <String>[
        'http://relay.example/v2',
        'https://user:secret@relay.example/v2',
        'https://relay.example/v2?token=leak',
        'https://relay.example/v1',
        'file:///tmp/v2',
      ]) {
        final String encoded = base64Url
            .encode(utf8.encode(relay))
            .replaceAll('=', '');
        expect(
          parseWorkspaceRoute(
            '#/sync/$_sessionId/$_editorToken?relay=$encoded',
          ).route,
          isNull,
          reason: relay,
        );
      }
      final String validRelay = base64Url
          .encode(utf8.encode('https://relay.example/v2'))
          .replaceAll('=', '');
      expect(
        parseWorkspaceRoute(
          '#/sync/short/$_editorToken?relay=$validRelay',
        ).error,
        contains('capability'),
      );
      expect(
        parseWorkspaceRoute(
          '#/sync/$_sessionId/$_editorToken?relay=$validRelay&relay=$validRelay',
        ).error,
        contains('exactly one'),
      );
      expect(
        parseWorkspaceRoute(
          '#/sync/$_sessionId/$_editorToken?relay=$validRelay=',
        ).route,
        isNull,
      );
      final String percentEncoded =
          '%${validRelay.codeUnitAt(0).toRadixString(16)}${validRelay.substring(1)}';
      expect(
        parseWorkspaceRoute(
          '#/sync/$_sessionId/$_editorToken?relay=$percentEncoded',
        ).route,
        isNull,
      );
    });
  });

  group('sync project contract', () {
    test('pins the canonicalization algorithm via the v1 reference fixture', () {
      // The v1 fixture file is retained as an ALGORITHM reference only: key
      // ordering, array order, ECMAScript number spelling, and baseRevision
      // exclusion are frozen across protocol versions even though the v1
      // project shape itself is retired.
      final Object? fixture = jsonDecode(
        File('test/fixtures/editor-sync-canonical-v1.json').readAsStringSync(),
      );
      final Map<String, dynamic> root = Map<String, dynamic>.from(
        fixture! as Map,
      );
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        root['project']! as Map,
      );
      expect(editorSyncProjectRevision(project), project['baseRevision']);
      expect(
        editorSyncCanonicalProjectContent(project),
        root['canonicalWithoutBaseRevision'],
      );
    });

    test('rejects protocol-v1 projects with a clear cutover error', () {
      final Object? fixture = jsonDecode(
        File('test/fixtures/editor-sync-canonical-v1.json').readAsStringSync(),
      );
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        (fixture! as Map)['project']! as Map,
      );
      expect(
        () => EditorSyncProject.decode(project),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('protocol-v1'),
          ),
        ),
      );
    });

    test('matches the cross-repo v2 canonical SHA-256 fixture', () {
      // Byte-copied into the Gloss plugin repo: pins the v2 project shape,
      // the canonical string, the revision, and the open kind vocabulary.
      final Object? fixture = jsonDecode(
        File('test/fixtures/editor-sync-canonical-v2.json').readAsStringSync(),
      );
      final Map<String, dynamic> root = Map<String, dynamic>.from(
        fixture! as Map,
      );
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        root['project']! as Map,
      );
      expect(project['format'], 'gloss-sync-project');
      expect(project['version'], 2);
      expect(editorSyncProjectRevision(project), project['baseRevision']);
      expect(
        editorSyncCanonicalProjectContent(project),
        root['canonicalWithoutBaseRevision'],
      );
      // The fixture's panel document text is the canonical encoding of the
      // raw panelSource map — this pins ECMAScript number canonicalization
      // (1e20, -0.0, 1e-7, trailing .0) inside document text.
      final List<dynamic> documents = project['documents']! as List<dynamic>;
      final Map<String, dynamic> panelDoc = Map<String, dynamic>.from(
        documents.firstWhere(
              (Object? document) => (document! as Map)['kind'] == 'panel',
            )
            as Map,
      );
      expect(editorSyncCanonicalJson(root['panelSource']), panelDoc['json']);
      // Kinds are OPEN slugs in v2: the hypothetical future 'hologram' kind
      // is wire-legal today. This editor build has no hologram codec, so
      // decode must fail with a clear unsupported-kind message — never a
      // shape error, and never a relay change.
      expect(
        documents.map((Object? document) => (document! as Map)['kind']).toSet(),
        containsAll(<String>['hologram', 'menu', 'panel']),
      );
      for (final Object? document in documents) {
        expect(
          editorSyncKindPattern.hasMatch(
            (document! as Map)['kind']! as String,
          ),
          isTrue,
        );
      }
      expect(
        () => EditorSyncProject.decode(project),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains("cannot sync 'hologram'"),
          ),
        ),
      );
    });

    test('requires canonical JSON text for panel documents', () {
      final Map<String, dynamic> project = _projectMap(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
        ],
        board: _boardJson('board', 'board/root'),
        newMenuPrefix: 'board/',
      );
      final List<dynamic> documents = project['documents']! as List<dynamic>;
      final Map<String, dynamic> panelDoc =
          documents.last as Map<String, dynamic>;
      panelDoc['json'] = ' ${panelDoc['json']}';
      project['baseRevision'] = editorSyncProjectRevision(project);
      expect(() => EditorSyncProject.decode(project), throwsFormatException);
    });

    test('rejects unsorted document collections', () {
      final Map<String, dynamic> project = _projectMap(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/a', json: _menuJson()),
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
        ],
        board: _boardJson('board', 'board/root'),
        newMenuPrefix: 'board/',
      );
      final List<dynamic> documents = project['documents']! as List<dynamic>;
      documents.add(documents.removeAt(0));
      project['baseRevision'] = editorSyncProjectRevision(project);
      expect(() => EditorSyncProject.decode(project), throwsFormatException);
    });

    test('passes server-owned document revisions through decode', () {
      final Map<String, dynamic> project = _projectMap(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
        ],
        board: _boardJson('board', 'board/root'),
        newMenuPrefix: 'board/',
      );
      final List<dynamic> documents = project['documents']! as List<dynamic>;
      (documents.last as Map<String, dynamic>)['revision'] = 7;
      project['baseRevision'] = editorSyncProjectRevision(project);
      final EditorSyncProject decoded = EditorSyncProject.decode(project);
      expect(decoded.documents.last.kind, 'panel');
      expect(decoded.documents.last.revision, 7);
    });

    test('counts the per-menu ceiling in UTF-8 bytes', () {
      final HuiMenu menu = createDefaultMenu()
        ..extras['unicode'] = List<String>.filled(700000, '☃').join();
      final String json = encodeHuiMenu(menu);
      expect(json.length, lessThan(2 * 1024 * 1024));
      expect(utf8.encode(json).length, greaterThan(2 * 1024 * 1024));
      expect(
        () => _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[EditorSyncDocument(kind: 'menu', id: 'fixture', json: json)],
        ),
        throwsFormatException,
      );
    });

    test('rejects panel revisions outside the JavaScript safe range', () {
      final Map<String, dynamic> board = _boardJson('board', 'board/root')
        ..['revision'] = huiEditorSyncMaxSafeInteger + 1;
      final Map<String, dynamic> project = _projectMap(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
        ],
        board: board,
        newMenuPrefix: 'board/',
      );
      expect(() => EditorSyncProject.decode(project), throwsFormatException);
    });

    test('preserves supported image media bytes without PNG normalization', () {
      final Map<String, List<int>> samples = <String, List<int>>{
        'image/png': base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
        ),
        'image/jpeg': <int>[
          0xff,
          0xd8,
          0xff,
          0xc0,
          0x00,
          0x07,
          0x08,
          0x00,
          0x01,
          0x00,
          0x01,
        ],
        'image/gif': <int>[...ascii.encode('GIF89a'), 1, 0, 1, 0],
        'image/webp': <int>[
          ...ascii.encode('RIFF'),
          22,
          0,
          0,
          0,
          ...ascii.encode('WEBPVP8X'),
          10,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ],
        'image/bmp': <int>[
          0x42,
          0x4d,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          40,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
        ],
      };
      samples.forEach((String mediaType, List<int> bytes) {
        final String uri = 'data:$mediaType;base64,${base64Encode(bytes)}';
        final StoredImageData? decoded = decodeSupportedImageData(uri);
        expect(decoded, isNotNull, reason: mediaType);
        expect(decoded!.mediaType, mediaType);
        expect(decoded.bytes, bytes);
        expect(decoded.width, 1);
        expect(decoded.height, 1);
      });
      expect(
        decodeSupportedImageData('data:application/octet-stream;base64,AA=='),
        isNull,
      );
    });

    test('rejects oversized and excessive decoded sync image assets', () {
      final Map<String, dynamic> oversized = _projectMap(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      _setProjectImages(oversized, <String, String>{
        'images/oversized.gif': _gifDataUri(65, 1),
      });
      expect(() => EditorSyncProject.decode(oversized), throwsFormatException);

      final Map<String, String> many = <String, String>{
        for (int index = 0; index < 65; index++)
          'images/${index.toString().padLeft(2, '0')}.gif': _gifDataUri(64, 64),
      };
      final Map<String, dynamic> excessive = _projectMap(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      _setProjectImages(excessive, many);
      expect(() => EditorSyncProject.decode(excessive), throwsFormatException);
    });

    test('counts duplicate animated frames against the render budget', () {
      const String path = 'images/frame.gif';
      EditorSyncProject projectWithFrames(int frameCount) {
        final HuiMenu menu = createDefaultMenu()
          ..components = <HuiComponent>[
            HuiComponent(
              'animated',
              Vec3.zero(),
              HuiButtonData(
                0.05,
                <HuiAction>[],
                HuiAnimatedImageIcon(List<String>.filled(frameCount, path), 1),
              ),
            ),
          ];
        final Map<String, dynamic> raw = _projectMap(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: encodeHuiMenu(menu)),
          ],
        );
        _setProjectImages(raw, <String, String>{path: _gifDataUri(1, 1)});
        return EditorSyncProject.decode(raw);
      }

      expect(
        projectWithFrames(huiEditorSyncMaxRenderRows).images,
        hasLength(1),
      );
      expect(
        () => projectWithFrames(huiEditorSyncMaxRenderRows + 1),
        throwsFormatException,
      );
    });

    test('rejects extra fields in menu and image entries', () {
      final Map<String, dynamic> menuExtra = _projectMap(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      (menuExtra['documents']! as List<dynamic>).single['extra'] = true;
      menuExtra['baseRevision'] = editorSyncProjectRevision(menuExtra);
      expect(() => EditorSyncProject.decode(menuExtra), throwsFormatException);

      final Map<String, dynamic> imageExtra = _projectMap(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      imageExtra['images'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'path': 'images/frame.gif',
          'data': _gifDataUri(1, 1),
          'extra': true,
        },
      ];
      imageExtra['baseRevision'] = editorSyncProjectRevision(imageExtra);
      expect(() => EditorSyncProject.decode(imageExtra), throwsFormatException);
    });

    test('rejects mutable or exceeded scope constraints', () {
      final Map<String, dynamic> deletes = _projectMap(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      (deletes['constraints']! as Map<String, dynamic>)['allowDeletes'] = true;
      deletes['baseRevision'] = editorSyncProjectRevision(deletes);
      expect(() => EditorSyncProject.decode(deletes), throwsFormatException);

      final Map<String, dynamic> escaped = _projectMap(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'root', json: _menuJson()),
          EditorSyncDocument(kind: 'menu', id: 'outside/menu', json: _menuJson()),
        ],
        board: _boardJson('board', 'root'),
        newMenuPrefix: 'root/',
      );
      (escaped['constraints']! as Map<String, dynamic>)['menuIds'] = <String>[
        'root',
      ];
      escaped['baseRevision'] = editorSyncProjectRevision(escaped);
      expect(() => EditorSyncProject.decode(escaped), throwsFormatException);
    });

    test(
      'unlinking captured assets and menu edges retains the no-delete baseline',
      () async {
        const String png =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
        final HuiMenu root = createDefaultMenu()
          ..components = <HuiComponent>[
            HuiComponent(
              'route',
              Vec3.zero(),
              HuiButtonData(0.05, <HuiAction>[
                HuiNavigateAction('board/child', 'push'),
              ], HuiTextImageIcon('icons/captured.png')),
            ),
          ];
        final Map<String, dynamic> raw = _projectMap(
          kind: 'panel',
          subjectId: 'board',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'board/root', json: encodeHuiMenu(root)),
            EditorSyncDocument(kind: 'menu', id: 'board/child', json: _menuJson()),
          ],
          board: _boardJson('board', 'board/root'),
          newMenuPrefix: 'board/',
        );
        raw['images'] = <Map<String, dynamic>>[
          <String, dynamic>{'path': 'icons/captured.png', 'data': png},
        ];
        (raw['constraints']! as Map<String, dynamic>)['imagePaths'] = <String>[
          'icons/captured.png',
        ];
        raw['baseRevision'] = editorSyncProjectRevision(raw);
        final EditorSyncProject project = EditorSyncProject.decode(raw);
        final Workspace workspace = _workspace();
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final EditorSyncBinding binding = await importEditorSyncProject(
          capability: _capability(project.constraints),
          project: project,
          workspace: workspace,
          images: images,
        );
        final WorkspaceDoc rootDocument = workspace.byId(
          binding.menuDocumentIds['board/root'],
        )!;
        expect(
          workspace.replaceDocument(
            id: rootDocument.id,
            title: rootDocument.title,
            runtimeId: rootDocument.runtimeId,
            json: _menuJson(),
            kind: rootDocument.kind,
            folderId: rootDocument.folderId,
          ),
          isTrue,
        );

        final EditorSyncProject collected = collectEditorSyncProject(
          binding: binding,
          workspace: workspace,
          images: images,
        );
        expect(collected.menus.map((EditorSyncDocument menu) => menu.id), <String>[
          'board/child',
          'board/root',
        ]);
        expect(
          collected.images.map((EditorSyncImage image) => image.path),
          <String>['icons/captured.png'],
        );
        expect(collected.constraints.toJson(), project.constraints.toJson());
        workspace.dispose();
        images.dispose();
      },
    );

    test(
      'one-character edit gets a content revision distinct from request base',
      () async {
        final Workspace workspace = _workspace();
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final EditorSyncProject base = _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
          ],
        );
        final EditorSyncBinding binding = await importEditorSyncProject(
          capability: _capability(base.constraints),
          project: base,
          workspace: workspace,
          images: images,
        );
        final WorkspaceDoc doc = workspace.byId(
          binding.menuDocumentIds['fixture'],
        )!;
        expect(
          workspace.replaceDocument(
            id: doc.id,
            title: doc.title,
            runtimeId: doc.runtimeId,
            json: '${doc.json} ',
            kind: doc.kind,
            folderId: doc.folderId,
          ),
          isTrue,
        );
        final EditorSyncProject publication = collectEditorSyncProject(
          binding: binding,
          workspace: workspace,
          images: images,
        );
        expect(publication.baseRevision, isNot(binding.baseRevision));
        expect(
          editorSyncProjectRevision(publication.toJson()),
          publication.baseRevision,
        );

        Map<String, dynamic>? requestBody;
        final EditorSyncClient client = EditorSyncClient(
          client: _HandlerClient((http.BaseRequest request) async {
            requestBody =
                jsonDecode(utf8.decode(await request.finalize().toBytes()))
                    as Map<String, dynamic>;
            return _jsonResponse(202, <String, dynamic>{
              'protocol': 2,
              'publication': <String, dynamic>{
                'revision': 1,
                'state': 'pending',
                'publishedAt': '2026-08-12T00:00:00Z',
              },
            });
          }),
        );
        await client.publish(binding, publication);
        expect(requestBody!['baseRevision'], binding.baseRevision);
        expect(
          (requestBody!['snapshot']! as Map)['baseRevision'],
          publication.baseRevision,
        );
        client.close();
        workspace.dispose();
        images.dispose();
      },
    );

    test(
      'board collection adds only new menus reachable from the root graph',
      () async {
        final EditorSyncProject project = _project(
          kind: 'panel',
          subjectId: 'board',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
          ],
          board: _boardJson('board', 'board/root'),
          newMenuPrefix: 'board/',
        );
        final Workspace workspace = _workspace();
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final EditorSyncBinding binding = await importEditorSyncProject(
          capability: _capability(project.constraints),
          project: project,
          workspace: workspace,
          images: images,
        );
        final WorkspaceDoc root = workspace.byId(
          binding.menuDocumentIds['board/root'],
        )!;
        final HuiMenu changedRoot = createDefaultMenu()
          ..components = <HuiComponent>[
            HuiComponent(
              'routes',
              Vec3.zero(),
              HuiButtonData(0.05, <HuiAction>[
                HuiCommandAction('/hui open menu=board/command-child'),
                HuiNavigateAction('board/child', 'push'),
              ]),
            ),
          ];
        expect(
          workspace.replaceDocument(
            id: root.id,
            title: root.title,
            runtimeId: root.runtimeId,
            json: encodeHuiMenu(changedRoot),
            kind: root.kind,
            folderId: root.folderId,
          ),
          isTrue,
        );
        for (final String id in <String>[
          'board/child',
          'board/command-child',
          'board/unrelated',
        ]) {
          workspace.create(
            title: id.split('/').last,
            runtimeId: id,
            json: _menuJson(),
            kind: WorkspaceDocKind.menu,
            folderId: root.folderId,
          );
        }

        final EditorSyncProject collected = collectEditorSyncProject(
          binding: binding,
          workspace: workspace,
          images: images,
        );
        expect(collected.menus.map((EditorSyncDocument menu) => menu.id), <String>[
          'board/child',
          'board/command-child',
          'board/root',
        ]);
        workspace.dispose();
        images.dispose();
      },
    );

    test(
      'applied acknowledgement reconciles unchanged scope and preserves later edits',
      () async {
        final Workspace workspace = _workspace();
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final EditorSyncProject base = _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
          ],
        );
        final EditorSyncBinding imported = await importEditorSyncProject(
          capability: _capability(base.constraints),
          project: base,
          workspace: workspace,
          images: images,
        );
        final HuiMenu changed = decodeHuiMenu(_menuJson())..followPlayer = true;
        final String normalized = encodeHuiMenu(changed);
        final WorkspaceDoc document = workspace.byId(
          imported.menuDocumentIds['fixture'],
        )!;
        expect(
          workspace.replaceDocument(
            id: document.id,
            title: document.title,
            runtimeId: document.runtimeId,
            json: '$normalized ',
            kind: document.kind,
            folderId: document.folderId,
          ),
          isTrue,
        );
        final EditorSyncProject submitted = collectEditorSyncProject(
          binding: imported,
          workspace: workspace,
          images: images,
        );
        final EditorSyncBinding pending = imported.copyWith(
          pendingContentRevision: submitted.baseRevision,
        );
        final EditorSyncProject promoted = _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: normalized),
          ],
        );

        final EditorSyncAppliedResolution reconciled =
            await resolveEditorSyncApplied(
              binding: pending,
              serverProject: promoted,
              workspace: workspace,
              images: images,
            );
        expect(reconciled.decision, EditorSyncAppliedDecision.reconcile);
        expect(reconciled.binding.baseRevision, promoted.baseRevision);
        expect(reconciled.binding.pendingContentRevision, isNull);
        expect(workspace.byId(document.id)!.json, normalized);

        expect(
          workspace.replaceDocument(
            id: document.id,
            title: document.title,
            runtimeId: document.runtimeId,
            json: '$normalized\n',
            kind: document.kind,
            folderId: document.folderId,
          ),
          isTrue,
        );
        final String localEdit = workspace.byId(document.id)!.json;
        final EditorSyncAppliedResolution conflict =
            await resolveEditorSyncApplied(
              binding: pending,
              serverProject: promoted,
              workspace: workspace,
              images: images,
            );
        expect(
          conflict.decision,
          EditorSyncAppliedDecision.preserveLocalConflict,
        );
        expect(conflict.binding.baseRevision, imported.baseRevision);
        expect(conflict.binding.pendingContentRevision, submitted.baseRevision);
        expect(workspace.byId(document.id)!.json, localEdit);
        workspace.dispose();
        images.dispose();
      },
    );

    test(
      'board refresh updates bound documents without duplicate containers',
      () async {
        final Workspace workspace = _workspace();
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final EditorSyncProject first = _project(
          kind: 'panel',
          subjectId: 'welcome',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'welcome/root', json: _menuJson()),
          ],
          board: _boardJson('welcome', 'welcome/root'),
          newMenuPrefix: 'welcome/',
        );
        final EditorSyncBinding imported = await importEditorSyncProject(
          capability: _capability(first.constraints),
          project: first,
          workspace: workspace,
          images: images,
        );
        final Map<String, dynamic> nextBoard = _boardJson(
          'welcome',
          'welcome/root',
        )..['revision'] = 2;
        (nextBoard['transform']! as Map<String, dynamic>)['x'] = 12.5;
        final HuiMenu changed = decodeHuiMenu(_menuJson())..followPlayer = true;
        final EditorSyncProject second = _project(
          kind: 'panel',
          subjectId: 'welcome',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'welcome/root', json: encodeHuiMenu(changed)),
          ],
          board: nextBoard,
          newMenuPrefix: 'welcome/',
        );
        final int folders = workspace.folders.length;
        final int documents = workspace.docs.length;
        final EditorSyncBinding refreshed = await refreshEditorSyncProject(
          binding: imported.copyWith(baseRevision: second.baseRevision),
          project: second,
          workspace: workspace,
          images: images,
        );
        expect(workspace.folders.length, folders);
        expect(workspace.docs.length, documents);
        expect(refreshed.panelDocumentId, imported.panelDocumentId);
        final WorkspacePanelData board = decodeWorkspacePanel(
          workspace.byId(refreshed.panelDocumentId)!.json,
        ).data;
        expect(
          (board.runtimeBoard!['transform']! as Map<String, dynamic>)['x'],
          12.5,
        );
        expect(
          workspace.byId(refreshed.menuDocumentIds['welcome/root'])!.json,
          encodeHuiMenu(changed),
        );
        workspace.dispose();
        images.dispose();
      },
    );

    test('board runtime metadata preserves typed identity fields', () {
      final Workspace workspace = _workspace();
      final Map<String, dynamic> runtime = _boardJson(
        'welcome',
        'welcome/root',
      );
      final WorkspaceFolder folder = workspace.createFolder(title: 'Welcome');
      final WorkspaceDoc boardDoc = workspace.create(
        title: 'Welcome board',
        runtimeId: null,
        json: encodeWorkspacePanel(
          WorkspacePanelData(
            scopeFolderId: folder.id,
            runtimeBoardId: 'welcome',
            runtimeBoard: runtime,
            syncMenuIds: const <String>['welcome/root'],
          ),
        ),
        kind: WorkspaceDocKind.panel,
        folderId: folder.id,
      );
      final WorkspacePanelData decoded = decodeWorkspacePanel(
        boardDoc.json,
      ).data;
      expect(decoded.runtimeBoardId, 'welcome');
      expect(decoded.runtimeBoard!['uuid'], runtime['uuid']);
      expect(decoded.runtimeBoard!['revision'], 1);
      workspace.dispose();
    });

    test('rejects unsupported world-board definition fields', () {
      final Map<String, dynamic> raw = _projectMap(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
        ],
        board: _boardJson('board', 'board/root')..['futureField'] = true,
        newMenuPrefix: 'board/',
      );
      expect(() => EditorSyncProject.decode(raw), throwsFormatException);
    });

    test('image failure leaves workspace documents untouched', () async {
      const String png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
      final Map<String, dynamic> raw = _projectMap(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      raw['images'] = <Map<String, dynamic>>[
        <String, dynamic>{'path': 'icons/a.png', 'data': png},
      ];
      (raw['constraints']! as Map<String, dynamic>)['imagePaths'] = <String>[
        'icons/a.png',
      ];
      raw['baseRevision'] = editorSyncProjectRevision(raw);
      final EditorSyncProject project = EditorSyncProject.decode(raw);
      final Workspace workspace = _workspace();
      final ImageLibrary images = ImageLibrary(
        autoLoad: false,
        writer: (String key, String value) => false,
      );
      final int documents = workspace.docs.length;
      final int folders = workspace.folders.length;

      await expectLater(
        importEditorSyncProject(
          capability: _capability(project.constraints),
          project: project,
          workspace: workspace,
          images: images,
        ),
        throwsA(isA<EditorSyncFailure>()),
      );
      expect(workspace.docs.length, documents);
      expect(workspace.folders.length, folders);
      expect(images.images, isEmpty);
      workspace.dispose();
      images.dispose();
    });

    test(
      'later document failure rolls back folders, menus, and images',
      () async {
        const String png =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
        final Map<String, dynamic> raw = _projectMap(
          kind: 'panel',
          subjectId: 'board',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
          ],
          board: _boardJson('board', 'board/root'),
          newMenuPrefix: 'board/',
        );
        raw['images'] = <Map<String, dynamic>>[
          <String, dynamic>{'path': 'sync/board/icon.png', 'data': png},
        ];
        raw['baseRevision'] = editorSyncProjectRevision(raw);
        final EditorSyncProject project = EditorSyncProject.decode(raw);
        final Workspace workspace = _workspaceFailingAtId(5);
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final String before = jsonEncode(workspace.exportPortableState());

        await expectLater(
          importEditorSyncProject(
            capability: _capability(project.constraints),
            project: project,
            workspace: workspace,
            images: images,
          ),
          throwsA(isA<EditorSyncFailure>()),
        );
        expect(jsonEncode(workspace.exportPortableState()), before);
        expect(images.images, isEmpty);
        workspace.dispose();
        images.dispose();
      },
    );

    test('refresh failure restores earlier document mutations', () async {
      final Workspace workspace = _workspace();
      final ImageLibrary images = ImageLibrary(
        autoLoad: false,
        writer: (String key, String value) => true,
      );
      final EditorSyncProject first = _project(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
        ],
        board: _boardJson('board', 'board/root'),
        newMenuPrefix: 'board/',
      );
      final EditorSyncBinding binding = await importEditorSyncProject(
        capability: _capability(first.constraints),
        project: first,
        workspace: workspace,
        images: images,
      );
      final WorkspaceDoc menu = workspace.byId(
        binding.menuDocumentIds['board/root'],
      )!;
      final String original = menu.json;
      expect(workspace.delete(binding.panelDocumentId!), isTrue);
      final HuiMenu changed = decodeHuiMenu(original)..followPlayer = true;
      final EditorSyncProject refreshed = _project(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: encodeHuiMenu(changed)),
        ],
        board: _boardJson('board', 'board/root'),
        newMenuPrefix: 'board/',
      );

      await expectLater(
        refreshEditorSyncProject(
          binding: binding,
          project: refreshed,
          workspace: workspace,
          images: images,
        ),
        throwsA(isA<EditorSyncConflict>()),
      );
      expect(workspace.byId(menu.id)!.json, original);
      expect(workspace.byId(binding.panelDocumentId), isNull);
      expect(images.images, isEmpty);
      workspace.dispose();
      images.dispose();
    });

    test(
      'awaits delayed workspace failure and restores before images commit',
      () async {
        const String png =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
        final Map<String, dynamic> raw = _projectMap(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
          ],
        );
        raw['images'] = <Map<String, dynamic>>[
          <String, dynamic>{'path': 'sync/menus/fixture/icon.png', 'data': png},
        ];
        raw['baseRevision'] = editorSyncProjectRevision(raw);
        final EditorSyncProject project = EditorSyncProject.decode(raw);
        final _DelayedWorkspaceRepository repository =
            _DelayedWorkspaceRepository();
        final Workspace workspace = await Workspace.open(
          repository: repository,
          idFactory: _sequentialIdFactory(),
        );
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final String before = jsonEncode(workspace.exportPortableState());
        repository.failWrites = 2;

        await expectLater(
          importEditorSyncProject(
            capability: _capability(project.constraints),
            project: project,
            workspace: workspace,
            images: images,
          ),
          throwsA(isA<EditorSyncFailure>()),
        );
        expect(jsonEncode(workspace.exportPortableState()), before);
        expect(images.images, isEmpty);
        expect(repository.value, before);
        workspace.dispose();
        images.dispose();
      },
    );

    test('menu replacement preserves its local title and folder', () async {
      final Workspace workspace = _workspace();
      final WorkspaceFolder folder = workspace.createFolder(title: 'Custom');
      final WorkspaceDoc local = workspace.create(
        title: 'My local title',
        runtimeId: 'fixture',
        json: _menuJson(),
        folderId: folder.id,
      );
      final ImageLibrary images = ImageLibrary(
        autoLoad: false,
        writer: (String key, String value) => true,
      );
      final HuiMenu changed = createDefaultMenu()..followPlayer = true;
      final EditorSyncProject project = _project(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: encodeHuiMenu(changed)),
        ],
      );

      final EditorSyncBinding binding = await importEditorSyncProject(
        capability: _capability(project.constraints),
        project: project,
        workspace: workspace,
        images: images,
        replaceExisting: true,
      );
      final WorkspaceDoc replaced = workspace.byId(
        binding.menuDocumentIds['fixture'],
      )!;
      expect(replaced.id, local.id);
      expect(replaced.folderId, folder.id);
      expect(replaced.title, 'My local title');
      workspace.dispose();
      images.dispose();
    });

    test('refresh refuses to shrink the current bound baseline', () async {
      final Map<String, dynamic> firstRaw = _projectMap(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
          EditorSyncDocument(kind: 'menu', id: 'board/added', json: _menuJson()),
        ],
        board: _boardJson('board', 'board/root'),
        newMenuPrefix: 'board/',
      );
      (firstRaw['constraints']! as Map<String, dynamic>)['menuIds'] = <String>[
        'board/root',
      ];
      firstRaw['baseRevision'] = editorSyncProjectRevision(firstRaw);
      final EditorSyncProject first = EditorSyncProject.decode(firstRaw);
      final Workspace workspace = _workspace();
      final ImageLibrary images = ImageLibrary(
        autoLoad: false,
        writer: (String key, String value) => true,
      );
      final EditorSyncBinding binding = await importEditorSyncProject(
        capability: _capability(first.constraints),
        project: first,
        workspace: workspace,
        images: images,
      );
      final EditorSyncProject shrunk = _project(
        kind: 'panel',
        subjectId: 'board',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'board/root', json: _menuJson()),
        ],
        board: _boardJson('board', 'board/root'),
        newMenuPrefix: 'board/',
      );

      await expectLater(
        refreshEditorSyncProject(
          binding: binding,
          project: shrunk,
          workspace: workspace,
          images: images,
        ),
        throwsA(isA<EditorSyncConflict>()),
      );
      expect(workspace.byId(binding.menuDocumentIds['board/added']), isNotNull);
      workspace.dispose();
      images.dispose();
    });

    test('capability token never enters portable workspace state', () {
      final Workspace workspace = _workspace();
      final EditorSyncConstraints constraints = _constraints(
        'fixture',
        <String>['fixture'],
      );
      final EditorSyncBinding binding = _capability(constraints);
      expect(jsonEncode(binding.toJson()), contains(_editorToken));
      expect(
        jsonEncode(workspace.exportPortableState()),
        isNot(contains(_editorToken)),
      );
      workspace.dispose();
    });

    test('reports tab binding storage refusal without exporting the token', () {
      final EditorSyncConstraints constraints = _constraints(
        'fixture',
        <String>['fixture'],
      );
      final EditorSyncBinding binding = _capability(constraints);
      String? attempted;
      expect(
        persistEditorSyncBinding(
          'workspace',
          binding,
          writer: (String workspaceId, String raw) {
            attempted = raw;
            return false;
          },
        ),
        isFalse,
      );
      expect(attempted, contains(_editorToken));
      final Workspace workspace = _workspace();
      expect(
        jsonEncode(workspace.exportPortableState()),
        isNot(contains(_editorToken)),
      );
      workspace.dispose();
    });

    test('retains a pending capability when tab binding persistence fails', () {
      final EditorSyncConstraints constraints = _constraints(
        'fixture',
        <String>['fixture'],
      );
      final EditorSyncBinding pending = _capability(constraints).copyWith(
        pendingContentRevision: 'sha256:${List<String>.filled(64, '1').join()}',
      );
      EditorSyncBinding? retained;

      expect(
        persistEditorSyncBinding(
          'workspace',
          pending,
          writer: (String workspaceId, String raw) => false,
          onFailure: (EditorSyncBinding binding) => retained = binding,
        ),
        isFalse,
      );
      expect(retained?.sessionId, pending.sessionId);
      expect(retained?.editorToken, pending.editorToken);
      expect(retained?.pendingContentRevision, pending.pendingContentRevision);
    });

    test(
      'rejected publication can be fixed and explicitly republished',
      () async {
        final Workspace workspace = _workspace();
        final ImageLibrary images = ImageLibrary(
          autoLoad: false,
          writer: (String key, String value) => true,
        );
        final EditorSyncProject project = _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
          ],
        );
        final EditorSyncBinding imported = await importEditorSyncProject(
          capability: _capability(project.constraints),
          project: project,
          workspace: workspace,
          images: images,
        );
        final EditorSyncBinding rejected = reconcileEditorSyncTerminalStatus(
          imported.copyWith(pendingContentRevision: project.baseRevision),
          EditorSyncStatus.rejected,
        );
        expect(rejected.pendingContentRevision, isNull);
        expect(canPublishEditorSyncStatus(EditorSyncStatus.rejected), isTrue);
        expect(canPublishEditorSyncStatus(EditorSyncStatus.conflict), isFalse);
        final WorkspaceDoc document = workspace.byId(
          rejected.menuDocumentIds['fixture'],
        )!;
        expect(
          workspace.replaceDocument(
            id: document.id,
            title: document.title,
            runtimeId: document.runtimeId,
            json: '${document.json} ',
            kind: document.kind,
            folderId: document.folderId,
          ),
          isTrue,
        );
        final EditorSyncProject corrected = collectEditorSyncProject(
          binding: rejected,
          workspace: workspace,
          images: images,
        );
        String? requestBase;
        final EditorSyncClient client = EditorSyncClient(
          client: _HandlerClient((http.BaseRequest request) async {
            final Map<String, dynamic> body =
                jsonDecode(utf8.decode(await request.finalize().toBytes()))
                    as Map<String, dynamic>;
            requestBase = body['baseRevision'] as String;
            return _jsonResponse(202, <String, dynamic>{
              'protocol': 2,
              'publication': <String, dynamic>{
                'revision': 2,
                'state': 'pending',
                'publishedAt': '2026-08-12T00:00:02Z',
              },
            });
          }),
        );
        await client.publish(rejected, corrected);
        expect(requestBase, imported.baseRevision);
        client.close();
        workspace.dispose();
        images.dispose();
      },
    );

    test('poll gate coalesces requests and discards stale responses', () {
      final EditorSyncConstraints constraints = _constraints(
        'fixture',
        <String>['fixture'],
      );
      final EditorSyncBinding first = _capability(constraints);
      final EditorSyncPollGate gate = EditorSyncPollGate();
      final EditorSyncBinding captured = gate.begin(first)!;
      expect(gate.begin(first), isNull);
      final EditorSyncBinding published = first.copyWith(
        pendingContentRevision:
            'sha256:1111111111111111111111111111111111111111111111111111111111111111',
      );
      expect(gate.shouldApply(captured, published), isFalse);
      expect(gate.complete(captured), isTrue);
      expect(gate.begin(published), same(published));
      expect(gate.complete(published), isFalse);
    });
  });

  group('relay client', () {
    test('accepts only the bounded 32 MiB protocol ceiling', () {
      expect(huiEditorSyncMaxProjectBytes, 32 * 1024 * 1024);
      expect(
        huiEditorSyncMaxResponseBytes,
        (huiEditorSyncMaxProjectBytes * 2) +
            huiEditorSyncMaxResponseEnvelopeBytes,
      );
      final EditorSyncClient maximum = EditorSyncClient(
        maximumResponseBytes: huiEditorSyncMaxResponseBytes,
      );
      maximum.close();
      expect(
        () => EditorSyncClient(
          maximumResponseBytes: huiEditorSyncMaxResponseBytes + 1,
        ),
        throwsArgumentError,
      );
    });
    test('maps lifecycle statuses and authenticated GET', () async {
      final EditorSyncProject project = _project(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      for (final String status in <String>[
        'open',
        'pending',
        'applied',
        'conflict',
        'rejected',
      ]) {
        final EditorSyncClient client = EditorSyncClient(
          client: _HandlerClient((http.BaseRequest request) async {
            expect(request.headers['authorization'], 'Bearer $_editorToken');
            return _jsonResponse(200, _sessionBody(project, status));
          }),
        );
        final EditorSyncSession fetched = await client.fetch(
          _capability(project.constraints),
          initialSnapshot: true,
        );
        expect(fetched.status.name, status == 'open' ? 'connected' : status);
        client.close();
      }
    });

    test('rejects ambiguous relay revisions and acknowledgements', () async {
      final EditorSyncProject project = _project(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      final List<Map<String, dynamic>> malformed = <Map<String, dynamic>>[];
      final Map<String, dynamic> topMismatch = _sessionBody(project, 'open');
      topMismatch['baseRevision'] = _zeroRevision;
      malformed.add(topMismatch);
      final Map<String, dynamic> ackMismatch = _sessionBody(project, 'applied');
      (((ackMismatch['publication']! as Map)['ack']!
              as Map))["serverRevision"] =
          _zeroRevision;
      malformed.add(ackMismatch);
      final Map<String, dynamic> pendingAck = _sessionBody(project, 'pending');
      (pendingAck['publication']! as Map)['ack'] = <String, dynamic>{
        'status': 'pending',
        'message': 'impossible',
        'serverRevision': project.baseRevision,
        'acknowledgedAt': '2026-08-12T00:00:01Z',
      };
      malformed.add(pendingAck);
      final Map<String, dynamic> stateMismatch = _sessionBody(
        project,
        'rejected',
      );
      (stateMismatch['publication']! as Map)['state'] = 'conflict';
      malformed.add(stateMismatch);

      for (final Map<String, dynamic> body in malformed) {
        final EditorSyncClient client = EditorSyncClient(
          client: _HandlerClient((_) async => _jsonResponse(200, body)),
        );
        await expectLater(
          client.fetch(_capability(project.constraints)),
          throwsA(isA<EditorSyncFailure>()),
        );
        client.close();
      }
    });

    test(
      'binds pending and terminal publications to the optimistic local base',
      () async {
        final EditorSyncProject base = _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
          ],
        );
        final HuiMenu editedMenu = createDefaultMenu()..followPlayer = true;
        final EditorSyncProject submitted = _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: encodeHuiMenu(editedMenu)),
          ],
        );
        final EditorSyncBinding binding = _capability(base.constraints)
            .copyWith(
              baseRevision: base.baseRevision,
              pendingContentRevision: submitted.baseRevision,
            );

        final Map<String, dynamic> pending = _sessionBody(base, 'pending');
        final Map pendingPublication = pending['publication']! as Map;
        pendingPublication['baseRevision'] = base.baseRevision;
        pendingPublication['snapshot'] = submitted.toJson();
        final EditorSyncClient pendingClient = EditorSyncClient(
          client: _HandlerClient((_) async => _jsonResponse(200, pending)),
        );
        expect(
          (await pendingClient.fetch(binding)).status,
          EditorSyncStatus.pending,
        );
        pendingClient.close();

        final Map<String, dynamic> wrongBase = Map<String, dynamic>.from(
          pending,
        );
        wrongBase['publication'] = Map<String, dynamic>.from(pendingPublication)
          ..['baseRevision'] = _zeroRevision;
        final EditorSyncClient wrongBaseClient = EditorSyncClient(
          client: _HandlerClient((_) async => _jsonResponse(200, wrongBase)),
        );
        await expectLater(
          wrongBaseClient.fetch(binding),
          throwsA(isA<EditorSyncFailure>()),
        );
        wrongBaseClient.close();

        final HuiMenu otherMenu = createDefaultMenu()..lockPosition = true;
        final EditorSyncProject other = _project(
          kind: 'menu',
          subjectId: 'fixture',
          menus: <EditorSyncDocument>[
            EditorSyncDocument(kind: 'menu', id: 'fixture', json: encodeHuiMenu(otherMenu)),
          ],
        );
        final Map<String, dynamic> wrongSnapshot = Map<String, dynamic>.from(
          pending,
        );
        wrongSnapshot['publication'] = Map<String, dynamic>.from(
          pendingPublication,
        )..['snapshot'] = other.toJson();
        final EditorSyncClient wrongSnapshotClient = EditorSyncClient(
          client: _HandlerClient(
            (_) async => _jsonResponse(200, wrongSnapshot),
          ),
        );
        await expectLater(
          wrongSnapshotClient.fetch(binding),
          throwsA(isA<EditorSyncFailure>()),
        );
        wrongSnapshotClient.close();

        final Map<String, dynamic> applied = _sessionBody(submitted, 'applied');
        final Map appliedPublication = applied['publication']! as Map;
        appliedPublication['baseRevision'] = base.baseRevision;
        appliedPublication['snapshot'] = submitted.toJson();
        final EditorSyncClient appliedClient = EditorSyncClient(
          client: _HandlerClient((_) async => _jsonResponse(200, applied)),
        );
        expect(
          (await appliedClient.fetch(binding)).status,
          EditorSyncStatus.applied,
        );
        appliedClient.close();
      },
    );

    test('distinguishes expired and revoked capabilities', () async {
      final EditorSyncProject project = _project(
        kind: 'menu',
        subjectId: 'fixture',
        menus: <EditorSyncDocument>[
          EditorSyncDocument(kind: 'menu', id: 'fixture', json: _menuJson()),
        ],
      );
      for (final String code in <String>[
        'session_expired',
        'session_revoked',
      ]) {
        final EditorSyncClient client = EditorSyncClient(
          client: _HandlerClient(
            (_) async => _jsonResponse(410, <String, dynamic>{
              'protocol': 2,
              'error': <String, dynamic>{'code': code, 'message': code},
            }),
          ),
        );
        await expectLater(
          client.fetch(_capability(project.constraints)),
          throwsA(
            isA<EditorSyncGone>().having(
              (EditorSyncGone error) => error.revoked,
              'revoked',
              code == 'session_revoked',
            ),
          ),
        );
        client.close();
      }
    });

    test('rejects wrong content type and aborts oversized streams', () async {
      final EditorSyncConstraints constraints = _constraints(
        'fixture',
        <String>['fixture'],
      );
      final EditorSyncClient wrongType = EditorSyncClient(
        client: _HandlerClient(
          (_) async => http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('{}')),
            200,
            headers: <String, String>{'content-type': 'text/html'},
          ),
        ),
      );
      await expectLater(
        wrongType.fetch(_capability(constraints)),
        throwsA(
          isA<EditorSyncFailure>().having(
            (EditorSyncFailure error) => error.message,
            'message',
            contains('application/json'),
          ),
        ),
      );
      wrongType.close();

      final EditorSyncClient oversized = EditorSyncClient(
        maximumResponseBytes: 32,
        client: _HandlerClient(
          (_) async => http.StreamedResponse(
            Stream<List<int>>.fromIterable(<List<int>>[
              List<int>.filled(20, 1),
              List<int>.filled(20, 2),
            ]),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        oversized.fetch(_capability(constraints)),
        throwsA(
          isA<EditorSyncFailure>().having(
            (EditorSyncFailure error) => error.message,
            'message',
            contains('too large'),
          ),
        ),
      );
      oversized.close();
    });

    test('bounds connection and response-stream timeouts', () async {
      final EditorSyncConstraints constraints = _constraints(
        'fixture',
        <String>['fixture'],
      );
      final EditorSyncClient connection = EditorSyncClient(
        requestTimeout: const Duration(milliseconds: 10),
        client: _HandlerClient(
          (_) => Completer<http.StreamedResponse>().future,
        ),
      );
      await expectLater(
        connection.fetch(_capability(constraints)),
        throwsA(isA<EditorSyncFailure>()),
      );
      connection.close();

      final StreamController<List<int>> stream = StreamController<List<int>>();
      final EditorSyncClient response = EditorSyncClient(
        requestTimeout: const Duration(milliseconds: 10),
        client: _HandlerClient(
          (_) async => http.StreamedResponse(
            stream.stream,
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        response.fetch(_capability(constraints)),
        throwsA(isA<EditorSyncFailure>()),
      );
      await stream.close();
      response.close();

      final EditorSyncClient slowDrip = EditorSyncClient(
        requestTimeout: const Duration(milliseconds: 20),
        client: _HandlerClient(
          (_) async => http.StreamedResponse(
            Stream<List<int>>.periodic(
              const Duration(milliseconds: 8),
              (_) => <int>[123],
            ).take(8),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        slowDrip.fetch(_capability(constraints)),
        throwsA(
          isA<EditorSyncFailure>().having(
            (EditorSyncFailure error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      slowDrip.close();
    });
  });
}

EditorSyncProject _project({
  required String kind,
  required String subjectId,
  required List<EditorSyncDocument> menus,
  Map<String, dynamic>? board,
  String? newMenuPrefix,
}) => EditorSyncProject.decode(
  _projectMap(
    kind: kind,
    subjectId: subjectId,
    menus: menus,
    board: board,
    newMenuPrefix: newMenuPrefix,
  ),
);

Map<String, dynamic> _projectMap({
  required String kind,
  required String subjectId,
  required List<EditorSyncDocument> menus,
  Map<String, dynamic>? board,
  String? newMenuPrefix,
}) {
  final List<EditorSyncDocument> orderedMenus = List<EditorSyncDocument>.of(menus)
    ..sort((EditorSyncDocument a, EditorSyncDocument b) => a.id.compareTo(b.id));
  final EditorSyncConstraints constraints = _constraints(
    subjectId,
    orderedMenus.map((EditorSyncDocument menu) => menu.id).toList(),
    newMenuPrefix: newMenuPrefix,
  );
  final Map<String, dynamic> project = <String, dynamic>{
    'format': 'gloss-sync-project',
    'version': 2,
    'kind': kind,
    'subjectId': subjectId,
    'documents': <Map<String, dynamic>>[
      for (final EditorSyncDocument menu in orderedMenus) menu.toJson(),
      if (board != null)
        <String, dynamic>{
          'kind': 'panel',
          'id': subjectId,
          'json': editorSyncCanonicalJson(board),
        },
    ],
    'images': <Object>[],
    'constraints': constraints.toJson(),
    'warnings': <Object>[],
    'baseRevision': _zeroRevision,
  };
  project['baseRevision'] = editorSyncProjectRevision(project);
  return project;
}

void _setProjectImages(
  Map<String, dynamic> project,
  Map<String, String> images,
) {
  final List<String> paths = images.keys.toList()..sort();
  project['images'] = <Map<String, dynamic>>[
    for (final String path in paths)
      <String, dynamic>{'path': path, 'data': images[path]},
  ];
  (project['constraints']! as Map<String, dynamic>)['imagePaths'] = paths;
  project['baseRevision'] = editorSyncProjectRevision(project);
}

String _gifDataUri(int width, int height) {
  final List<int> bytes = <int>[
    ...ascii.encode('GIF89a'),
    width & 0xff,
    (width >> 8) & 0xff,
    height & 0xff,
    (height >> 8) & 0xff,
  ];
  return 'data:image/gif;base64,${base64Encode(bytes)}';
}

EditorSyncConstraints _constraints(
  String subjectId,
  List<String> menuIds, {
  String? newMenuPrefix,
}) => EditorSyncConstraints(
  subjectId: subjectId,
  menuIds: menuIds,
  imagePaths: const <String>[],
  newMenuPrefix: newMenuPrefix,
  newImagePrefix: newMenuPrefix == null
      ? 'sync/menus/$subjectId/'
      : 'sync/$subjectId/',
);

EditorSyncBinding _capability(EditorSyncConstraints constraints) =>
    EditorSyncBinding(
      sessionId: _sessionId,
      editorToken: _editorToken,
      relayEndpoint: Uri.parse('https://relay.example/v2'),
      kind: constraints.newMenuPrefix == null ? 'menu' : 'panel',
      subjectId: constraints.subjectId,
      baseRevision: _zeroRevision,
      menuDocumentIds: const <String, String>{},
      imagePaths: constraints.imagePaths,
      constraints: constraints,
      warnings: const <String>[],
    );

Map<String, dynamic> _boardJson(String id, String rootMenuId) =>
    <String, dynamic>{
      'schemaVersion': 1,
      'id': id,
      'uuid': '00000000-0000-4000-8000-000000000042',
      'revision': 1,
      'rootMenuId': rootMenuId,
      'transform': <String, dynamic>{
        'worldKey': 'minecraft:overworld',
        'worldUuid': '00000000-0000-4000-8000-000000000043',
        'x': 0.0,
        'y': 64.0,
        'z': 0.0,
        'yaw': 0.0,
        'pitch': 0.0,
        'roll': 0.0,
        'scale': 1.0,
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
        'viewRange': 64.0,
        'interactionRange': 8.0,
      },
    };

String _menuJson() => encodeHuiMenu(createDefaultMenu());

Workspace _workspace() {
  return Workspace(
    read: (String key) => null,
    write: (String key, String value) => true,
    idFactory: _sequentialIdFactory(),
  );
}

WorkspaceIdFactory _sequentialIdFactory() {
  int nextId = 1;
  return () {
    final String tail = '${nextId++}'.padLeft(12, '0');
    return '00000000-0000-4000-8000-$tail';
  };
}

Workspace _workspaceFailingAtId(int failureCall) {
  int nextId = 1;
  return Workspace(
    read: (String key) => null,
    write: (String key, String value) => true,
    idFactory: () {
      if (nextId == failureCall) {
        throw StateError('Injected workspace document failure.');
      }
      final String tail = '${nextId++}'.padLeft(12, '0');
      return '00000000-0000-4000-8000-$tail';
    },
  );
}

Map<String, dynamic> _sessionBody(EditorSyncProject project, String status) =>
    <String, dynamic>{
      'protocol': 2,
      'sessionId': _sessionId,
      'status': status,
      'expiresAt': '2026-08-13T00:00:00Z',
      'baseRevision': project.baseRevision,
      'snapshot': project.toJson(),
      'publication': status == 'open'
          ? null
          : <String, dynamic>{
              'revision': 1,
              'baseRevision': project.baseRevision,
              'snapshot': project.toJson(),
              'publishedAt': '2026-08-12T00:00:00Z',
              'state': status,
              'ack': status == 'pending'
                  ? null
                  : <String, dynamic>{
                      'status': status,
                      'message': status,
                      'serverRevision': status == 'rejected'
                          ? null
                          : project.baseRevision,
                      'acknowledgedAt': '2026-08-12T00:00:01Z',
                    },
            },
    };

http.StreamedResponse _jsonResponse(int status, Object body) =>
    http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

typedef _RequestHandler =
    Future<http.StreamedResponse> Function(http.BaseRequest request);

final class _HandlerClient extends http.BaseClient {
  _HandlerClient(this.handler);

  final _RequestHandler handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

final class _DelayedWorkspaceRepository implements WorkspaceRepository {
  String? value;
  int failWrites = 0;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<bool> write(String key, String next) async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    if (failWrites > 0) {
      failWrites--;
      return false;
    }
    value = next;
    return true;
  }
}
