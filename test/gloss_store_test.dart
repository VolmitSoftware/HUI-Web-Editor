/// [EditorStore] plumbing for the Gloss document kinds: creation, the
/// mutate/undo/dirty path, code commits, import auto-detection, runtime-id
/// rename, the workspace-scoped animation resolver, and the full
/// template -> mutate -> export -> reimport -> equal loop plus a workspace
/// bundle round-trip.
library;

import 'dart:convert';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/validation.dart' show HuiIssue;
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:gloss_editor/state/workspace_bundle.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

class _FakeStorage {
  final Map<String, String> values = <String, String>{};

  String? read(String key) => values[key];

  bool write(String key, String value) {
    values[key] = value;
    return true;
  }
}

EditorStore _store(_FakeStorage storage) => EditorStore(
  workspace: Workspace(read: storage.read, write: storage.write),
  autosaveDelay: Duration.zero,
);

void main() {
  group('creation', () {
    test('newGlossDocument opens a blank hologram on the hologram view', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      expect(store.docKind, WorkspaceDocKind.hologram);
      expect(store.isGlossDoc, isTrue);
      expect(store.hologramDoc, isNotNull);
      expect(store.view, EditorView.hologram);
      expect(store.workspace.active!.kind, WorkspaceDocKind.hologram);
      expect(store.workspace.active!.runtimeId, 'new-hologram');
      // Canonical text, not shipped bytes — but the same document.
      expect(
        jsonDecode(store.exportJson()),
        jsonDecode(kGlossHologramBaselineJson),
      );
    });

    test('duplicate names pick a free runtime id', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      store.newGlossDocument(DocumentTypes.hologram);
      final List<String?> ids = <String?>[
        for (final WorkspaceDoc doc in store.workspace.docs)
          if (doc.kind == WorkspaceDocKind.hologram) doc.runtimeId,
      ];
      expect(ids.toSet().length, 2);
    });
  });

  group('mutate, undo, dirty', () {
    test('mutateHologram is undoable and marks the document dirty', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      store.flushAutosave();
      expect(store.hasUnsavedChanges, isFalse);
      store.mutateHologram(
        'add line',
        (GlossHologramDoc doc) => doc.lines.add('&aSecond'),
      );
      expect(store.hologramDoc!.lines, hasLength(2));
      expect(store.canUndo, isTrue);
      expect(store.performUndo(), isTrue);
      expect(store.hologramDoc!.lines, hasLength(1));
      expect(store.performRedo(), isTrue);
      expect(store.hologramDoc!.lines, hasLength(2));
    });

    test('a no-op mutation pushes nothing', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      final bool couldUndo = store.canUndo;
      store.mutateHologram('nothing', (GlossHologramDoc doc) {});
      expect(store.canUndo, couldUndo);
    });

    test('mutateHologram is a no-op while a menu is open', () {
      final EditorStore store = _store(_FakeStorage());
      expect(store.docKind, WorkspaceDocKind.menu);
      store.mutateHologram(
        'ghost',
        (GlossHologramDoc doc) => doc.lines.add('x'),
      );
      expect(store.canUndo, isFalse);
    });

    test('the gloss revision moves with every edit', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      final int before = store.glossRevision;
      store.mutateHologram(
        'edit',
        (GlossHologramDoc doc) => doc.anchor.world = 'nether',
      );
      expect(store.glossRevision, greaterThan(before));
    });
  });

  group('applyCode', () {
    test('commits valid hologram JSON', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      final bool applied = store.applyCode(
        '{"schemaVersion": 1, "revision": 5, '
        '"anchor": {"world": "w", "position": [1, 2, 3]}, '
        '"lines": ["&bnew"]}',
      );
      expect(applied, isTrue);
      expect(store.codeError, isNull);
      expect(store.hologramDoc!.revision, 5);
      expect(store.hologramDoc!.lines, <String>['&bnew']);
    });

    test('refuses non-hologram shapes without touching the document', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      final String before = store.exportJson();
      expect(store.applyCode('{"elements": []}'), isFalse);
      expect(store.codeError, isNotNull);
      expect(store.exportJson(), before);
    });

    test('refuses a wrong schemaVersion with the decoder message', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      expect(
        store.applyCode(
          '{"schemaVersion": 9, "revision": 1, "anchor": {"world": "w"}}',
        ),
        isFalse,
      );
      expect(store.codeError, contains('schemaVersion'));
    });
  });

  group('import auto-detection', () {
    const String hologramJson =
        '{"schemaVersion": 1, "revision": 2, '
        '"anchor": {"world": "world", "position": [0, 70, 0]}, '
        '"lines": ["&dHi"]}';

    test('importJson recognizes a hologram document', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('spawn-holo.json', hologramJson);
      expect(store.docKind, WorkspaceDocKind.hologram);
      expect(store.hologramDoc!.revision, 2);
      expect(store.menuId, 'spawn-holo');
    });

    test('importJsonAsNewDocument creates a hologram workspace entry', () {
      final EditorStore store = _store(_FakeStorage());
      expect(
        store.importJsonAsNewDocument('spawn-holo.json', hologramJson),
        isTrue,
      );
      final WorkspaceDoc doc = store.workspace.docs.singleWhere(
        (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.hologram,
      );
      expect(doc.runtimeId, 'spawn-holo');
      expect(doc.json, hologramJson);
      expect(store.docKind, WorkspaceDocKind.hologram);
    });

    test('menu and preview detection are unaffected', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson(
        'card.json',
        '{"elements": [{"type": "cell", "x": 0, "y": 0}]}',
      );
      expect(store.docKind, WorkspaceDocKind.containerPreview);
      store.importJson('menu.json', '{"components": []}');
      expect(store.docKind, WorkspaceDocKind.menu);
    });

    test('a versioned document with a title routes to the scoreboard kind',
        () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson(
        'mystery.json',
        '{"schemaVersion": 1, "revision": 1, "title": "x"}',
      );
      expect(store.docKind, WorkspaceDocKind.scoreboard);
    });

    test('a versioned document with no kind marker falls through to menu',
        () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson(
        'mystery.json',
        '{"schemaVersion": 1, "revision": 1, "lines": ["x"]}',
      );
      expect(store.docKind, WorkspaceDocKind.menu,
          reason: 'unrecognized shapes fall through to the menu decoder');
    });
  });

  group('runtime id rename', () {
    test('renames a hologram document without menu-project rewrites', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram);
      expect(store.renameActiveRuntimeId('holograms/spawn'), isTrue);
      expect(store.workspace.active!.runtimeId, 'holograms/spawn');
      expect(store.menuId, 'holograms/spawn');
    });

    test('rejects a duplicate id within the kind', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.hologram, name: 'first');
      store.newGlossDocument(DocumentTypes.hologram, name: 'second');
      expect(store.renameActiveRuntimeId('first'), isFalse);
    });
  });

  group('workspace animation resolver', () {
    test('resolves saved animation documents by runtime id', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(
        DocumentTypes.animation,
        name: 'rainbow',
        from: buildRainbowGlossAnimation(),
      );
      store.flushAutosave();
      expect(store.workspaceAnimations.ids, contains('rainbow'));
      expect(store.workspaceAnimations.byId('rainbow')!.frames, hasLength(4));
      expect(store.workspaceAnimations.byId('missing'), isNull);
    });

    test('the open animation resolves from its live model', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(
        DocumentTypes.animation,
        name: 'live',
        from: buildRainbowGlossAnimation(),
      );
      store.mutateAnimation(
        'edit frame',
        (GlossAnimationDoc doc) => doc.frames[0] = '&5edited',
      );
      expect(
        store.workspaceAnimations.byId('live')!.frames.first,
        '&5edited',
        reason: 'the resolver must not lag the autosave debounce',
      );
    });

    test('a satisfied reference clears the hologram warning', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(
        DocumentTypes.animation,
        name: 'rainbow',
        from: buildRainbowGlossAnimation(),
      );
      store.newGlossDocument(
        DocumentTypes.hologram,
        name: 'welcome',
        from: buildShowcaseGlossHologram(),
      );
      expect(
        store.issues.where(
          (HuiIssue issue) => issue.message.contains('animation.rainbow'),
        ),
        isEmpty,
        reason: 'the showcase references animation.rainbow, which now exists',
      );
    });
  });

  group('animation documents', () {
    test('create, mutate, undo', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.animation);
      expect(store.docKind, WorkspaceDocKind.animation);
      expect(store.view, EditorView.animation);
      expect(store.animationDoc!.frames, hasLength(1));
      store.mutateAnimation(
        'add frame',
        (GlossAnimationDoc doc) => doc.frames.add('&bnew'),
      );
      expect(store.animationDoc!.frames, hasLength(2));
      expect(store.performUndo(), isTrue);
      expect(store.animationDoc!.frames, hasLength(1));
    });

    test('importJson recognizes an animation document', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson(
        'glow.json',
        '{"schemaVersion": 1, "revision": 1, "mode": "descend", '
        '"frameIntervalMs": 250, "frames": ["a", "b"]}',
      );
      expect(store.docKind, WorkspaceDocKind.animation);
      expect(store.animationDoc!.mode, 'descend');
    });

    test('end to end: template -> mutate -> export -> reimport -> equal', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(
        DocumentTypes.animation,
        name: 'rainbow',
        from: buildRainbowGlossAnimation(),
      );
      store.mutateAnimation('edit', (GlossAnimationDoc doc) {
        doc.mode = 'random';
        doc.frameIntervalMs = 125;
        doc.frames.add('&dNew frame');
      });
      final String exported = store.exportJson();
      final EditorStore other = _store(_FakeStorage());
      other.importJson('rainbow.json', exported);
      expect(other.docKind, WorkspaceDocKind.animation);
      expect(other.exportJson(), exported);
      expect(other.animationDoc!.mode, 'random');
      expect(other.animationDoc!.frames.last, '&dNew frame');
    });
  });

  group('scoreboard documents', () {
    test('create, mutate, undo', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.scoreboard);
      expect(store.docKind, WorkspaceDocKind.scoreboard);
      expect(store.view, EditorView.scoreboard);
      expect(store.scoreboardDoc!.lines, hasLength(3));
      store.mutateScoreboard(
        'add line',
        (GlossScoreboardDoc doc) => doc.lines.add('&bnew'),
      );
      expect(store.scoreboardDoc!.lines, hasLength(4));
      expect(store.performUndo(), isTrue);
      expect(store.scoreboardDoc!.lines, hasLength(3));
    });

    test('importJson recognizes a scoreboard document', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson(
        'vip.json',
        '{"schemaVersion": 1, "revision": 3, "title": "&6VIP", '
        '"lines": ["&fone"], "primary": false, "permission": "vip", '
        '"groups": ["vip"]}',
      );
      expect(store.docKind, WorkspaceDocKind.scoreboard);
      expect(store.scoreboardDoc!.permission, 'vip');
      expect(store.scoreboardDoc!.revision, 3);
    });

    test('a scoreboard warning clears when the referenced animation lands',
        () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(
        DocumentTypes.scoreboard,
        name: 'showcase',
        from: buildShowcaseGlossScoreboard(),
      );
      expect(
        store.issues.any(
          (HuiIssue issue) => issue.message.contains('animation.rainbow'),
        ),
        isTrue,
      );
      store.newGlossDocument(
        DocumentTypes.animation,
        name: 'rainbow',
        from: buildRainbowGlossAnimation(),
      );
      // Back on the scoreboard, the warning is gone.
      final WorkspaceDoc board = store.workspace.docs.singleWhere(
        (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.scoreboard,
      );
      expect(store.openDocument(board.id), isTrue);
      expect(
        store.issues.any(
          (HuiIssue issue) => issue.message.contains('animation.rainbow'),
        ),
        isFalse,
      );
    });

    test('end to end: template -> mutate -> export -> reimport -> equal', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(
        DocumentTypes.scoreboard,
        name: 'showcase',
        from: buildShowcaseGlossScoreboard(),
      );
      store.mutateScoreboard('edit', (GlossScoreboardDoc doc) {
        doc.title = '[00FFAA]&lEdited';
        doc.primary = false;
        doc.groups.add('admin');
      });
      final String exported = store.exportJson();
      final EditorStore other = _store(_FakeStorage());
      other.importJson('showcase.json', exported);
      expect(other.docKind, WorkspaceDocKind.scoreboard);
      expect(other.exportJson(), exported);
      expect(other.scoreboardDoc!.title, '[00FFAA]&lEdited');
      expect(other.scoreboardDoc!.groups.last, 'admin');
    });
  });

  group('end to end', () {
    test('template -> mutate -> export -> reimport -> equal', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(
        DocumentTypes.hologram,
        name: 'welcome',
        from: buildShowcaseGlossHologram(),
      );
      store.mutateHologram('edit', (GlossHologramDoc doc) {
        doc.anchor.setPosition(12, 80.5, -7);
        doc.lines.add('&badded line');
      });
      final String exported = store.exportJson();
      final EditorStore other = _store(_FakeStorage());
      other.importJson('welcome.json', exported);
      expect(other.docKind, WorkspaceDocKind.hologram);
      expect(other.exportJson(), exported);
      expect(
        jsonDecode(other.exportJson()),
        jsonDecode(exported),
      );
      expect(other.hologramDoc!.anchor.position, <double>[12, 80.5, -7]);
      expect(other.hologramDoc!.lines.last, '&badded line');
    });

    test('a workspace bundle round-trips all three Gloss kinds', () async {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _store(storage);
      store.newGlossDocument(
        DocumentTypes.hologram,
        name: 'bundled',
        from: buildShowcaseGlossHologram(),
      );
      store.newGlossDocument(
        DocumentTypes.animation,
        name: 'rainbow',
        from: buildRainbowGlossAnimation(),
      );
      store.newGlossDocument(
        DocumentTypes.scoreboard,
        name: 'board',
        from: buildDefaultGlossScoreboard(),
      );
      store.flushAutosave();
      final String bundle = encodeWorkspaceBundle(store.workspace, null);

      final _FakeStorage freshStorage = _FakeStorage();
      final EditorStore fresh = _store(freshStorage);
      final WorkspaceBundleDecodeResult decoded = decodeWorkspaceBundle(
        bundle,
        fresh.workspace,
      );
      expect(decoded.error, isNull);
      expect(await fresh.importBundle(decoded.bundle!), isTrue);
      final WorkspaceDoc hologram = fresh.workspace.docs.singleWhere(
        (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.hologram,
      );
      expect(hologram.runtimeId, 'bundled');
      expect(
        decodeGlossHologramDoc(hologram.json).lines,
        buildShowcaseGlossHologram().lines,
      );
      final WorkspaceDoc animation = fresh.workspace.docs.singleWhere(
        (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.animation,
      );
      expect(
        decodeGlossAnimationDoc(animation.json).frames,
        buildRainbowGlossAnimation().frames,
      );
      final WorkspaceDoc scoreboard = fresh.workspace.docs.singleWhere(
        (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.scoreboard,
      );
      expect(
        decodeGlossScoreboardDoc(scoreboard.json).title,
        buildDefaultGlossScoreboard().title,
      );
      // The restored workspace's resolver serves the restored animation.
      expect(fresh.workspaceAnimations.ids, contains('rainbow'));
    });
  });
}
