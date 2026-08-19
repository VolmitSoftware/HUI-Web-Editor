/// The one-time `holoui.*` -> `gloss.*` storage identity migration.
///
/// Browsers that last ran the HoloUI-branded editor hold their data under the
/// old prefix. The first storage access copies every value to the new prefix
/// (read-old, write-new; originals kept for older deployments) and records a
/// marker so removed keys are never resurrected. "Reset local data" clears
/// both prefixes so the migration cannot undo a reset.
library;

import 'dart:convert';

import 'package:gloss_editor/services/storage_service.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:gloss_editor/state/workspace_repository.dart';
import 'package:test/test.dart';

/// Writes [value] under the pre-rebrand [key], then removes the migration
/// marker so storage looks exactly like a browser the HoloUI editor left
/// behind: legacy keys present, no marker.
void _seedLegacy(String key, String value) {
  StorageService.write(key, value);
  StorageService.remove(StorageService.migrationMarkerKey);
}

Map<String, dynamic> _workspacePayload() => <String, dynamic>{
  'schemaVersion': Workspace.schemaVersion,
  'workspaceId': '00000000-0000-4000-8000-000000000001',
  'unfiledFolderId': '00000000-0000-4000-8000-000000000002',
  'folders': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000002',
      'title': Workspace.unfiledTitle,
      'parentId': null,
      'updatedAt': 0,
    },
  ],
  'documents': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000003',
      'title': 'Village Store',
      'runtimeId': 'village-store',
      'json': '{}',
      'updatedAt': 1,
      'kind': 'menu',
      'folderId': '00000000-0000-4000-8000-000000000002',
    },
  ],
  'activeDocumentId': '00000000-0000-4000-8000-000000000003',
};

void main() {
  setUp(StorageService.clearAll);

  group('StorageService one-time migration', () {
    test('copies holoui.* values to gloss.* and keeps the originals', () {
      _seedLegacy('holoui.workspace.v2', 'payload-v2');
      _seedLegacy('holoui.theme', 'dark');

      expect(StorageService.read('gloss.workspace.v2'), 'payload-v2');
      expect(StorageService.read('gloss.theme'), 'dark');
      expect(StorageService.read('holoui.workspace.v2'), 'payload-v2');
      expect(StorageService.read('holoui.theme'), 'dark');
      expect(StorageService.read(StorageService.migrationMarkerKey), '1');
    });

    test('never overwrites data already written under the new identity', () {
      StorageService.write('gloss.theme', 'new');
      _seedLegacy('holoui.theme', 'old');

      expect(StorageService.read('gloss.theme'), 'new');
    });

    test('runs once: a removed gloss key is not resurrected', () {
      _seedLegacy('holoui.custom-items', 'catalog');
      expect(StorageService.read('gloss.custom-items'), 'catalog');

      StorageService.remove('gloss.custom-items');

      expect(StorageService.read('gloss.custom-items'), isNull);
      expect(StorageService.read('holoui.custom-items'), 'catalog');
    });

    test('reset clears the pre-rebrand keys so nothing re-migrates', () {
      _seedLegacy('holoui.workspace.v2', 'payload');
      expect(StorageService.read('gloss.workspace.v2'), 'payload');

      expect(StorageService.clearAll(), isTrue);

      expect(StorageService.read('gloss.workspace.v2'), isNull);
      expect(StorageService.read('holoui.workspace.v2'), isNull);
    });

    test('ignores keys outside both prefixes', () {
      StorageService.write('other.app', 'kept');
      _seedLegacy('holoui.theme', 'dark');

      expect(StorageService.read('gloss.theme'), 'dark');
      expect(StorageService.read('gloss.app'), isNull);
      expect(StorageService.read('other.app'), 'kept');

      StorageService.remove('other.app');
    });
  });

  group('workspace repository migration', () {
    test('a workspace saved by the HoloUI editor loads unchanged', () async {
      final String payload = jsonEncode(_workspacePayload());
      _seedLegacy('holoui.workspace.v2', payload);

      final Workspace workspace = await Workspace.open(
        repository: const LocalStorageWorkspaceRepository(),
      );

      expect(workspace.docs, hasLength(1));
      expect(workspace.active?.runtimeId, 'village-store');
      expect(StorageService.read(Workspace.storageKey), payload);
    });

    test('the pre-rebrand v1 payload still walks the legacy chain', () async {
      _seedLegacy(
        'holoui.workspace.v1',
        jsonEncode(<String, dynamic>{
          'docs': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'legacy-menu',
              'name': 'Old Shop',
              'json': '{}',
              'updatedAt': 1,
            },
          ],
          'activeId': 'legacy-menu',
        }),
      );

      final Workspace workspace = await Workspace.open(
        repository: const LocalStorageWorkspaceRepository(),
      );
      await workspace.writesSettled;

      expect(workspace.docs, hasLength(1));
      expect(workspace.docs.single.title, 'Old Shop');
      expect(StorageService.read(Workspace.storageKey), isNotNull);
    });

    test('an explicit clear also drops the pre-rebrand keys', () {
      _seedLegacy('holoui.workspace.v2', 'payload');
      expect(StorageService.read('gloss.workspace.v2'), 'payload');

      const LocalStorageWorkspaceRepository repository =
          LocalStorageWorkspaceRepository();
      expect(repository.clear(), isTrue);

      expect(StorageService.read('gloss.workspace.v2'), isNull);
      expect(StorageService.read('holoui.workspace.v2'), isNull);
    });
  });
}
