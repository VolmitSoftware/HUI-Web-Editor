library;

import 'dart:convert';

import 'package:gloss_editor/config/defaults.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/image_library.dart';
import 'package:gloss_editor/services/storage_service.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:gloss_editor/state/workspace_panel.dart';
import 'package:gloss_editor/state/workspace_bundle.dart';
import 'package:test/test.dart';

class _MemoryWorkspace {
  final Map<String, String> values = <String, String>{};
  bool refuseWrites = false;
  int _nextId = 1;

  String? read(String key) => values[key];

  bool write(String key, String value) {
    if (refuseWrites) return false;
    values[key] = value;
    return true;
  }

  String nextUuid() {
    final String tail = '${_nextId++}'.padLeft(12, '0');
    return '00000000-0000-4000-8000-$tail';
  }
}

Workspace _workspace(_MemoryWorkspace memory) => Workspace(
  read: memory.read,
  write: memory.write,
  idFactory: memory.nextUuid,
);

StoredImage _image(String path) => StoredImage(
  path: path,
  dataUri:
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
  width: 1,
  height: 1,
);

void main() {
  setUp(StorageService.clearAll);

  test(
    'portable bundle preserves folders, kinds, ids, JSON bytes and images',
    () async {
      final Workspace source = _workspace(_MemoryWorkspace());
      final WorkspaceFolder shops = source.createFolder(title: 'Shops');
      final WorkspaceFolder tools = source.createFolder(
        title: 'Tools',
        parentId: shops.id,
      );
      final String menuJson = encodeHuiMenu(createDefaultMenu());
      source.create(
        title: 'Confirm purchase',
        runtimeId: 'shops/tools/Confirm',
        json: menuJson,
        folderId: tools.id,
      );
      source.create(
        title: 'Chest card',
        runtimeId: 'cards/chest',
        json: '{"elements":[]}',
        folderId: tools.id,
        kind: WorkspaceDocKind.containerPreview,
      );
      source.create(
        title: 'Shop flow',
        runtimeId: null,
        json: encodeWorkspacePanel(WorkspacePanelData(scopeFolderId: shops.id)),
        folderId: shops.id,
        kind: WorkspaceDocKind.panel,
      );
      final ImageLibrary sourceImages = ImageLibrary(autoLoad: false);
      expect(
        sourceImages.replaceAll(<StoredImage>[_image('shops/icon.png')]),
        isTrue,
      );

      final String encoded = encodeWorkspaceBundle(source, sourceImages);
      final Workspace target = _workspace(_MemoryWorkspace());
      final WorkspaceBundleDecodeResult decoded = decodeWorkspaceBundle(
        encoded,
        target,
      );
      expect(decoded.error, isNull);
      expect(decoded.workspaceCheck?.documentCount, 3);
      expect(decoded.workspaceCheck?.folderCount, 2);
      expect(decoded.bundle?.images.single.path, 'shops/icon.png');

      final ImageLibrary targetImages = ImageLibrary(autoLoad: false);
      expect(
        (await importWorkspaceBundle(
          decoded.bundle!,
          target,
          targetImages,
        )).isSuccess,
        isTrue,
      );
      expect(target.id, source.id);
      expect(target.docs, hasLength(3));
      expect(
        target.docs
            .singleWhere(
              (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.menu,
            )
            .runtimeId,
        'shops/tools/Confirm',
      );
      expect(
        target.docs
            .singleWhere(
              (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.menu,
            )
            .json,
        menuJson,
      );
      expect(
        target.docs
            .singleWhere(
              (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.panel,
            )
            .runtimeId,
        isNull,
      );
      expect(targetImages.images.single.path, 'shops/icon.png');
    },
  );

  test(
    'bundle decoder rejects malformed workspace and duplicate image paths',
    () {
      final Workspace workspace = _workspace(_MemoryWorkspace());
      final Map<String, dynamic> bundle = <String, dynamic>{
        'format': WorkspaceBundle.format,
        'version': WorkspaceBundle.version,
        'workspace': <String, dynamic>{'schemaVersion': 99},
        'images': <Object?>[],
      };
      expect(
        decodeWorkspaceBundle(jsonEncode(bundle), workspace).error,
        contains('newer editor'),
      );

      bundle['workspace'] = workspace.exportPortableState();
      bundle['images'] = <Object?>[
        _image('same.png').toJson(),
        _image('same.png').toJson(),
      ];
      expect(
        decodeWorkspaceBundle(jsonEncode(bundle), workspace).error,
        contains('invalid entry'),
      );
    },
  );

  test('accepts pre-rebrand HoloUI bundles but writes the new format', () {
    final Workspace workspace = _workspace(_MemoryWorkspace());
    final Map<String, dynamic> bundle = <String, dynamic>{
      'format': WorkspaceBundle.legacyFormat,
      'version': WorkspaceBundle.version,
      'workspace': workspace.exportPortableState(),
      'images': <Object?>[],
    };

    final WorkspaceBundleDecodeResult decoded = decodeWorkspaceBundle(
      jsonEncode(bundle),
      workspace,
    );
    expect(decoded.error, isNull);
    expect(decoded.bundle, isNotNull);

    expect(WorkspaceBundle.format, 'gloss-editor-workspace');
    expect(WorkspaceBundle.legacyFormat, 'holoui-editor-workspace');
    expect(
      encodeWorkspaceBundle(workspace, null),
      contains('"format": "gloss-editor-workspace"'),
    );

    bundle['format'] = 'unrelated-format';
    expect(
      decodeWorkspaceBundle(jsonEncode(bundle), workspace).error,
      contains('not a supported'),
    );
  });

  test('image replacement validates the whole set before mutation', () {
    final ImageLibrary images = ImageLibrary(autoLoad: false);
    expect(images.replaceAll(<StoredImage>[_image('safe.png')]), isTrue);
    expect(
      images.replaceAll(<StoredImage>[
        _image('duplicate.png'),
        _image('duplicate.png'),
      ]),
      isFalse,
    );
    expect(images.images.single.path, 'safe.png');
  });

  test(
    'a refused workspace write restores the previous image library',
    () async {
      final Workspace source = _workspace(_MemoryWorkspace());
      source.create(title: 'Imported', runtimeId: 'imported', json: '{}');
      final WorkspaceBundle bundle = WorkspaceBundle(
        workspaceState: source.exportPortableState(),
        images: <StoredImage>[_image('imported.png')],
      );

      final _MemoryWorkspace targetMemory = _MemoryWorkspace();
      final Workspace target = _workspace(targetMemory);
      target.create(title: 'Existing', runtimeId: 'existing', json: '{}');
      final ImageLibrary targetImages = ImageLibrary(autoLoad: false);
      expect(
        targetImages.replaceAll(<StoredImage>[_image('existing.png')]),
        isTrue,
      );
      targetMemory.refuseWrites = true;

      expect(
        (await importWorkspaceBundle(bundle, target, targetImages)).isSuccess,
        isFalse,
      );
      expect(target.docs.single.runtimeId, 'existing');
      expect(targetImages.images.single.path, 'existing.png');
    },
  );

  test('a failed image compensation is surfaced to the caller', () async {
    final Workspace source = _workspace(_MemoryWorkspace());
    source.create(title: 'Imported', runtimeId: 'imported', json: '{}');
    final WorkspaceBundle bundle = WorkspaceBundle(
      workspaceState: source.exportPortableState(),
      images: <StoredImage>[_image('imported.png')],
    );
    final _MemoryWorkspace targetMemory = _MemoryWorkspace();
    final Workspace target = _workspace(targetMemory);
    target.create(title: 'Existing', runtimeId: 'existing', json: '{}');
    int imageWrites = 0;
    final ImageLibrary targetImages = ImageLibrary(
      autoLoad: false,
      writer: (String key, String value) {
        imageWrites++;
        if (imageWrites == 3) return false;
        return StorageService.write(key, value);
      },
    );
    expect(
      targetImages.replaceAll(<StoredImage>[_image('existing.png')]),
      isTrue,
    );
    targetMemory.refuseWrites = true;

    final WorkspaceBundleImportResult result = await importWorkspaceBundle(
      bundle,
      target,
      targetImages,
    );

    expect(result.isSuccess, isFalse);
    expect(result.compensationFailed, isTrue);
    expect(result.error, contains('could not be restored'));
    expect(targetImages.images.single.path, 'imported.png');
  });

  test(
    'bundle images require normalized PNG bytes and matching dimensions',
    () {
      final Workspace workspace = _workspace(_MemoryWorkspace());
      final Map<String, dynamic> bundle = <String, dynamic>{
        'format': WorkspaceBundle.format,
        'version': WorkspaceBundle.version,
        'workspace': workspace.exportPortableState(),
        'images': <Object?>[
          <String, Object>{
            'path': 'fake.png',
            'dataUri': 'data:image/png;base64,${base64Encode(<int>[1, 2, 3])}',
            'width': 1,
            'height': 1,
          },
        ],
      };
      expect(
        decodeWorkspaceBundle(jsonEncode(bundle), workspace).error,
        contains('invalid entry'),
      );
      bundle['images'] = <Object?>[
        _image('wrong-size.png').copyWith(width: 2).toJson(),
      ];
      expect(
        decodeWorkspaceBundle(jsonEncode(bundle), workspace).error,
        contains('invalid entry'),
      );
    },
  );
}
