/// [WorkspaceDoc.kind] / [Workspace]: doc-kind round-trip and legacy-storage
/// migration. The old editor lost whole documents to a half-written payload,
/// so every corruption-tolerance rule proven for the original schema has to
/// keep holding once `kind` is added to it.
library;

import 'dart:convert';

import 'package:holoui_editor/state/workspace.dart';
import 'package:test/test.dart';

class _FakeStorage {
  final Map<String, String> values = <String, String>{};

  String? read(String key) => values[key];

  bool write(String key, String value) {
    values[key] = value;
    return true;
  }
}

Workspace _workspace(_FakeStorage storage, {bool autoLoad = true}) => Workspace(
      read: storage.read,
      write: storage.write,
      autoLoad: autoLoad,
    );

void main() {
  group('WorkspaceDocKind.fromName', () {
    test('reads its own two names back', () {
      expect(WorkspaceDocKind.fromName('menu'), WorkspaceDocKind.menu);
      expect(WorkspaceDocKind.fromName('containerPreview'),
          WorkspaceDocKind.containerPreview);
    });

    test('falls back to menu for null, an unknown string, or the wrong type', () {
      expect(WorkspaceDocKind.fromName(null), WorkspaceDocKind.menu);
      expect(WorkspaceDocKind.fromName('bogus'), WorkspaceDocKind.menu);
      expect(WorkspaceDocKind.fromName(3), WorkspaceDocKind.menu);
    });
  });

  group('WorkspaceDoc round-trip', () {
    test('a menu-kind doc round-trips through toJson/fromJson', () {
      final WorkspaceDoc doc = WorkspaceDoc(
        id: 'doc-1',
        name: 'my-menu',
        json: '{}',
        updatedAt: 42,
      );
      final WorkspaceDoc? restored = WorkspaceDoc.fromJson(doc.toJson());
      expect(restored, isNotNull);
      expect(restored!.kind, WorkspaceDocKind.menu);
      expect(doc.toJson()['kind'], 'menu');
    });

    test('a containerPreview-kind doc round-trips through toJson/fromJson', () {
      final WorkspaceDoc doc = WorkspaceDoc(
        id: 'doc-2',
        name: 'my-preview',
        json: '{"elements": []}',
        updatedAt: 42,
        kind: WorkspaceDocKind.containerPreview,
      );
      final WorkspaceDoc? restored = WorkspaceDoc.fromJson(doc.toJson());
      expect(restored, isNotNull);
      expect(restored!.kind, WorkspaceDocKind.containerPreview);
      expect(doc.toJson()['kind'], 'containerPreview');
    });

    test('a legacy entry with no kind key at all reads as menu', () {
      final Map<String, dynamic> legacy = <String, dynamic>{
        'id': 'doc-3',
        'name': 'old-menu',
        'json': '{}',
        'updatedAt': 1,
      };
      final WorkspaceDoc? restored = WorkspaceDoc.fromJson(legacy);
      expect(restored, isNotNull);
      expect(restored!.kind, WorkspaceDocKind.menu);
    });

    test('an entry with an unrecognized kind string reads as menu', () {
      final Map<String, dynamic> odd = <String, dynamic>{
        'id': 'doc-4',
        'name': 'odd',
        'json': '{}',
        'updatedAt': 1,
        'kind': 'somethingFromTheFuture',
      };
      final WorkspaceDoc? restored = WorkspaceDoc.fromJson(odd);
      expect(restored, isNotNull);
      expect(restored!.kind, WorkspaceDocKind.menu);
    });
  });

  group('Workspace legacy storage migration', () {
    test('a whole workspace payload saved before kind existed loads clean', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] = jsonEncode(<String, dynamic>{
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
      final Workspace workspace = _workspace(storage);
      expect(workspace.lastError, isNull);
      expect(workspace.docs, hasLength(1));
      expect(workspace.docs.single.kind, WorkspaceDocKind.menu);
      expect(workspace.active?.id, 'a');
    });
  });

  group('Workspace.create / updateActive kind plumbing', () {
    test('create defaults to menu when kind is omitted', () {
      final Workspace workspace = _workspace(_FakeStorage(), autoLoad: false);
      final WorkspaceDoc doc = workspace.create(name: 'menu-doc', json: '{}');
      expect(doc.kind, WorkspaceDocKind.menu);
    });

    test('create honors an explicit containerPreview kind', () {
      final Workspace workspace = _workspace(_FakeStorage(), autoLoad: false);
      final WorkspaceDoc doc = workspace.create(
        name: 'preview-doc',
        json: '{"elements": []}',
        kind: WorkspaceDocKind.containerPreview,
      );
      expect(doc.kind, WorkspaceDocKind.containerPreview);
    });

    test('updateActive can switch a document to a different kind', () {
      final Workspace workspace = _workspace(_FakeStorage(), autoLoad: false);
      workspace.create(name: 'doc', json: '{}');
      final bool stored = workspace.updateActive(
        json: '{"elements": []}',
        kind: WorkspaceDocKind.containerPreview,
      );
      expect(stored, isTrue);
      expect(workspace.active?.kind, WorkspaceDocKind.containerPreview);
    });

    test('updateActive without kind leaves the stored kind untouched', () {
      final Workspace workspace = _workspace(_FakeStorage(), autoLoad: false);
      workspace.create(
        name: 'doc',
        json: '{"elements": []}',
        kind: WorkspaceDocKind.containerPreview,
      );
      workspace.updateActive(json: '{"elements": [1]}');
      expect(workspace.active?.kind, WorkspaceDocKind.containerPreview);
    });

    test('a kind-only change persists the reloaded workspace', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace first = _workspace(storage, autoLoad: false);
      first.create(name: 'doc', json: '{"elements": []}');
      first.updateActive(kind: WorkspaceDocKind.containerPreview);

      final Workspace reloaded = _workspace(storage);
      expect(reloaded.docs.single.kind, WorkspaceDocKind.containerPreview);
    });
  });
}
