library;

import 'dart:async';
import 'dart:convert';

import 'package:holoui_editor/state/workspace.dart';
import 'package:holoui_editor/state/workspace_repository.dart';
import 'package:test/test.dart';

class _FakeStorage {
  final Map<String, String> values = <String, String>{};
  final Set<String> refusedKeys = <String>{};
  int writeCount = 0;
  int _nextId = 1;

  String? read(String key) => values[key];

  bool write(String key, String value) {
    writeCount++;
    if (refusedKeys.contains(key)) return false;
    values[key] = value;
    return true;
  }

  String nextUuid() {
    final String tail = '${_nextId++}'.padLeft(12, '0');
    return '00000000-0000-4000-8000-$tail';
  }
}

class _AsyncRepository implements WorkspaceRepository {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> write(String key, String value) async {
    values[key] = value;
    return true;
  }
}

Workspace _workspace(_FakeStorage storage, {bool autoLoad = true}) => Workspace(
  read: storage.read,
  write: storage.write,
  idFactory: storage.nextUuid,
  autoLoad: autoLoad,
);

void main() {
  group('document kinds and v2 records', () {
    test('recognizes only explicit document kind names', () {
      expect(WorkspaceDocKind.fromName('menu'), WorkspaceDocKind.menu);
      expect(
        WorkspaceDocKind.fromName('containerPreview'),
        WorkspaceDocKind.containerPreview,
      );
      expect(WorkspaceDocKind.fromName('board'), WorkspaceDocKind.board);
      expect(WorkspaceDocKind.fromName(null), isNull);
      expect(WorkspaceDocKind.fromName('future-kind'), isNull);
    });

    test('round-trips title, runtime id, folder and kind separately', () {
      final WorkspaceDoc doc = WorkspaceDoc(
        id: '00000000-0000-4000-8000-000000000001',
        title: 'Village Store',
        runtimeId: 'village-store',
        json: '{}',
        updatedAt: 42,
        folderId: '00000000-0000-4000-8000-000000000002',
      );
      final WorkspaceDoc? restored = WorkspaceDoc.fromJson(doc.toJson());
      expect(restored, isNotNull);
      expect(restored!.title, 'Village Store');
      expect(restored.runtimeId, 'village-store');
      expect(restored.folderId, doc.folderId);
      expect(restored.kind, WorkspaceDocKind.menu);
    });

    test('a board has no runtime id', () {
      final WorkspaceDoc doc = WorkspaceDoc(
        id: '00000000-0000-4000-8000-000000000001',
        title: 'Main flow',
        runtimeId: null,
        json: '{}',
        updatedAt: 42,
        folderId: '00000000-0000-4000-8000-000000000002',
        kind: WorkspaceDocKind.board,
      );
      final WorkspaceDoc? restored = WorkspaceDoc.fromJson(doc.toJson());
      expect(restored?.kind, WorkspaceDocKind.board);
      expect(restored?.runtimeId, isNull);
    });

    test(
      'rejects invalid UUIDs and unknown kinds instead of coercing them',
      () {
        final Map<String, dynamic> raw = <String, dynamic>{
          'id': 'not-a-uuid',
          'title': 'Broken',
          'runtimeId': 'broken',
          'json': '{}',
          'updatedAt': 1,
          'folderId': '00000000-0000-4000-8000-000000000002',
          'kind': 'menu',
        };
        expect(WorkspaceDoc.fromJson(raw), isNull);
        raw['id'] = '00000000-0000-4000-8000-000000000001';
        raw['kind'] = 'future-kind';
        expect(WorkspaceDoc.fromJson(raw), isNull);
      },
    );
  });

  group('v1 migration', () {
    test('atomically migrates every valid document into Unfiled', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.legacyStorageKey] = jsonEncode(<String, dynamic>{
        'docs': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'legacy-menu',
            'name': 'Village Store',
            'json': '{}',
            'updatedAt': 1,
          },
          <String, dynamic>{
            'id': 'legacy-preview',
            'name': 'Furnace Card',
            'json': '{"elements":[]}',
            'updatedAt': 2,
            'kind': 'containerPreview',
          },
        ],
        'activeId': 'legacy-preview',
      });

      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, hasLength(2));
      expect(workspace.folders, hasLength(1));
      expect(workspace.folders.single.title, Workspace.unfiledTitle);
      expect(
        workspace.docs.every(
          (WorkspaceDoc doc) =>
              doc.folderId == workspace.unfiledFolderId &&
              isWorkspaceUuid(doc.id),
        ),
        isTrue,
      );
      expect(workspace.active?.runtimeId, 'Furnace-Card');
      expect(workspace.active?.kind, WorkspaceDocKind.containerPreview);
      expect(storage.values[Workspace.legacyStorageKey], isNotNull);

      final String? v2 = storage.values[Workspace.storageKey];
      expect(v2, isNotNull);
      final Map<String, dynamic> decoded =
          jsonDecode(v2!) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], Workspace.schemaVersion);
      expect(decoded['folders'], hasLength(1));
      expect(decoded['documents'], hasLength(2));
      expect(storage.writeCount, 1);
    });

    test('keeps the complete legacy payload when the v2 write is refused', () {
      final _FakeStorage storage = _FakeStorage();
      final String legacy = jsonEncode(<String, dynamic>{
        'docs': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a',
            'name': 'shop',
            'json': '{}',
            'updatedAt': 1,
          },
        ],
        'activeId': 'a',
      });
      storage.values[Workspace.legacyStorageKey] = legacy;
      storage.refusedKeys.add(Workspace.storageKey);

      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, hasLength(1));
      expect(workspace.quotaExceeded, isTrue);
      expect(workspace.lastError, contains('could not be saved'));
      expect(storage.values[Workspace.legacyStorageKey], legacy);
      expect(storage.values[Workspace.storageKey], isNull);
    });

    test('skips a corrupt legacy entry without losing healthy siblings', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.legacyStorageKey] = jsonEncode(<String, dynamic>{
        'docs': <Object?>[
          <String, dynamic>{
            'id': 'good',
            'name': 'good',
            'json': '{}',
            'updatedAt': 1,
          },
          <String, dynamic>{
            'id': 'bad',
            'name': 'bad',
            'json': '{not json',
            'updatedAt': 2,
          },
        ],
        'activeId': 'bad',
      });
      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, hasLength(1));
      expect(workspace.active?.runtimeId, 'good');
      expect(workspace.lastError, contains('damaged'));
    });
  });

  group('v2 corruption handling', () {
    test('a malformed payload resets without throwing', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] = 'not json';
      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, isEmpty);
      expect(workspace.lastError, isNotNull);
      expect(workspace.folders.single.title, Workspace.unfiledTitle);
    });

    test('a future schema version is left untouched', () {
      final _FakeStorage storage = _FakeStorage();
      const String future = '{"schemaVersion":99,"documents":[]}';
      storage.values[Workspace.storageKey] = future;
      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, isEmpty);
      expect(workspace.lastError, contains('newer editor'));
      expect(storage.values[Workspace.storageKey], future);
      expect(storage.writeCount, 0);
    });

    test('repairs missing folders and skips unknown document kinds', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] = jsonEncode(<String, dynamic>{
        'schemaVersion': Workspace.schemaVersion,
        'workspaceId': '00000000-0000-4000-8000-000000000001',
        'unfiledFolderId': '00000000-0000-4000-8000-000000000002',
        'folders': <Object?>[],
        'documents': <Object?>[
          <String, dynamic>{
            'id': '00000000-0000-4000-8000-000000000003',
            'title': 'Good',
            'runtimeId': 'good',
            'json': '{}',
            'updatedAt': 1,
            'kind': 'menu',
            'folderId': '00000000-0000-4000-8000-000000000099',
          },
          <String, dynamic>{
            'id': '00000000-0000-4000-8000-000000000004',
            'title': 'Future',
            'runtimeId': 'future',
            'json': '{}',
            'updatedAt': 2,
            'kind': 'future-kind',
            'folderId': '00000000-0000-4000-8000-000000000099',
          },
        ],
        'activeDocumentId': '00000000-0000-4000-8000-000000000004',
      });
      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, hasLength(1));
      expect(workspace.docs.single.runtimeId, 'good');
      expect(workspace.docs.single.folderId, workspace.unfiledFolderId);
      expect(workspace.lastError, contains('repaired or skipped'));
    });

    test('skips a folder whose parent id is malformed', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] = jsonEncode(<String, dynamic>{
        'schemaVersion': Workspace.schemaVersion,
        'workspaceId': '00000000-0000-4000-8000-000000000001',
        'unfiledFolderId': '00000000-0000-4000-8000-000000000002',
        'folders': <Object?>[
          <String, dynamic>{
            'id': '00000000-0000-4000-8000-000000000002',
            'title': Workspace.unfiledTitle,
            'parentId': null,
            'updatedAt': 0,
          },
          <String, dynamic>{
            'id': '00000000-0000-4000-8000-000000000003',
            'title': 'Broken',
            'parentId': 'not-a-uuid',
            'updatedAt': 1,
          },
        ],
        'documents': <Object?>[],
        'activeDocumentId': null,
      });

      final Workspace workspace = _workspace(storage);
      expect(workspace.folders, hasLength(1));
      expect(
        workspace.folderById('00000000-0000-4000-8000-000000000003'),
        isNull,
      );
      expect(workspace.lastError, contains('repaired or skipped'));
    });
  });

  group('document identity and conflicts', () {
    test('keeps display title separate from canonical runtime id', () {
      final Workspace workspace = _workspace(_FakeStorage());
      final WorkspaceDoc doc = workspace.create(
        title: 'Warp Compass',
        runtimeId: 'Warp Compass',
        json: '{}',
      );
      expect(doc.title, 'Warp Compass');
      expect(doc.runtimeId, 'Warp-Compass');

      expect(workspace.renameDocumentTitle(doc.id, 'Travel Tools'), isTrue);
      expect(doc.title, 'Travel Tools');
      expect(doc.runtimeId, 'Warp-Compass');

      expect(workspace.renameDocumentRuntimeId(doc.id, 'Fast Travel'), isTrue);
      expect(doc.title, 'Travel Tools');
      expect(doc.runtimeId, 'Fast-Travel');
    });

    test('reports duplicate runtime ids without renaming either document', () {
      final Workspace workspace = _workspace(_FakeStorage());
      final WorkspaceDoc first = workspace.create(
        title: 'Shop A',
        runtimeId: 'shop',
        json: '{}',
      );
      final WorkspaceDoc second = workspace.create(
        title: 'Shop B',
        runtimeId: 'SHOP',
        json: '{}',
      );
      workspace.create(
        title: 'Shop preview',
        runtimeId: 'shop',
        json: '{}',
        kind: WorkspaceDocKind.containerPreview,
      );

      expect(first.runtimeId, 'shop');
      expect(second.runtimeId, 'SHOP');
      expect(workspace.runtimeIdConflicts, hasLength(1));
      expect(workspace.runtimeIdConflicts.single.kind, WorkspaceDocKind.menu);
      expect(workspace.runtimeIdConflicts.single.documents, hasLength(2));
    });

    test('new documents receive stable UUIDs across reloads', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace first = _workspace(storage);
      final WorkspaceDoc doc = first.create(
        title: 'Shop',
        runtimeId: 'shop',
        json: '{}',
      );
      expect(isWorkspaceUuid(doc.id), isTrue);

      final Workspace second = _workspace(storage);
      expect(second.docs.single.id, doc.id);
    });

    test('does not evict documents after the former forty-document limit', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace workspace = _workspace(storage);
      for (int index = 0; index < 65; index++) {
        workspace.create(
          title: 'Menu $index',
          runtimeId: 'menu-$index',
          json: '{}',
        );
      }
      expect(workspace.docs, hasLength(65));
      expect(_workspace(storage).docs, hasLength(65));
    });

    test('delete picks the newest remaining document', () {
      final Workspace workspace = _workspace(_FakeStorage());
      final WorkspaceDoc first = workspace.create(
        title: 'First',
        runtimeId: 'first',
        json: '{}',
      );
      final WorkspaceDoc second = workspace.create(
        title: 'Second',
        runtimeId: 'second',
        json: '{}',
      );
      expect(workspace.delete(second.id), isTrue);
      expect(workspace.activeId, first.id);
      expect(workspace.delete(first.id), isTrue);
      expect(workspace.activeId, isNull);
    });
  });

  group('nested folders', () {
    test('creates, renames and nests folders', () {
      final Workspace workspace = _workspace(_FakeStorage());
      final WorkspaceFolder menus = workspace.createFolder(title: 'Menus');
      final WorkspaceFolder shops = workspace.createFolder(
        title: 'Shops',
        parentId: menus.id,
      );
      expect(shops.parentId, menus.id);
      expect(workspace.renameFolder(shops.id, 'Storefronts'), isTrue);
      expect(workspace.folderById(shops.id)?.title, 'Storefronts');
      expect(workspace.childFolders(menus.id).single.id, shops.id);
    });

    test('rejects a folder cycle', () {
      final Workspace workspace = _workspace(_FakeStorage());
      final WorkspaceFolder parent = workspace.createFolder(title: 'Parent');
      final WorkspaceFolder child = workspace.createFolder(
        title: 'Child',
        parentId: parent.id,
      );
      expect(workspace.moveFolder(parent.id, child.id), isFalse);
      expect(parent.parentId, isNull);
      expect(
        workspace.moveFolder(workspace.unfiledFolderId, parent.id),
        isFalse,
      );
      expect(
        workspace.renameFolder(workspace.unfiledFolderId, 'Renamed'),
        isFalse,
      );
    });

    test('deleting a folder rehomes its children instead of deleting them', () {
      final Workspace workspace = _workspace(_FakeStorage());
      final WorkspaceFolder parent = workspace.createFolder(title: 'Parent');
      final WorkspaceFolder child = workspace.createFolder(
        title: 'Child',
        parentId: parent.id,
      );
      final WorkspaceDoc doc = workspace.create(
        title: 'Shop',
        runtimeId: 'shop',
        json: '{}',
        folderId: parent.id,
      );
      expect(workspace.deleteFolder(parent.id), isTrue);
      expect(workspace.folderById(parent.id), isNull);
      expect(child.parentId, workspace.unfiledFolderId);
      expect(doc.folderId, workspace.unfiledFolderId);
      expect(workspace.deleteFolder(workspace.unfiledFolderId), isFalse);
    });

    test('deleting a nested folder rehomes documents to its parent', () {
      final Workspace workspace = _workspace(_FakeStorage());
      final WorkspaceFolder parent = workspace.createFolder(title: 'Parent');
      final WorkspaceFolder child = workspace.createFolder(
        title: 'Child',
        parentId: parent.id,
      );
      final WorkspaceDoc doc = workspace.create(
        title: 'Shop',
        runtimeId: 'shop',
        json: '{}',
        folderId: child.id,
      );
      expect(workspace.deleteFolder(child.id), isTrue);
      expect(doc.folderId, parent.id);
    });
  });

  test(
    'an asynchronous repository can be awaited before store creation',
    () async {
      final _AsyncRepository repository = _AsyncRepository();
      int nextId = 1;
      final Workspace workspace = await Workspace.open(
        repository: repository,
        idFactory: () {
          final String tail = '${nextId++}'.padLeft(12, '0');
          return '00000000-0000-4000-8000-$tail';
        },
      );
      expect(workspace.isReady, isTrue);
      workspace.create(title: 'Shop', runtimeId: 'shop', json: '{}');
      await Future<void>.delayed(Duration.zero);
      expect(repository.values[Workspace.storageKey], isNotNull);
    },
  );
}
