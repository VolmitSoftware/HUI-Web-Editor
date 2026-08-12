/// Multi-selection rules on [EditorStore].
///
/// Selection is an insertion-ordered set whose LAST member is the primary, so
/// every pre-existing single-select call site keeps working through the
/// `selectedId` getter. Selection is deliberately NOT part of the undo
/// snapshot: restoring a step prunes ids the restored document no longer has
/// rather than resurrecting an old selection.
library;

import 'package:holoui_editor/config/defaults.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/preview/preview_types.dart';
import 'package:holoui_editor/state/editor_store.dart';
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

EditorStore _store(_FakeStorage storage) => EditorStore(
  workspace: Workspace(
    read: storage.read,
    write: storage.write,
    autoLoad: true,
  ),
  autosaveDelay: Duration.zero,
);

/// Three decorations plus the default `title`, so ids are known and stable.
EditorStore _populated(_FakeStorage storage, {int count = 3}) {
  final EditorStore store = _store(storage);
  for (int i = 0; i < count; i++) {
    store.addComponent('decoration', id: 'c$i');
  }
  store.select(null);
  return store;
}

void main() {
  group('selection set', () {
    test('starts empty and reports no primary', () {
      final EditorStore store = _populated(_FakeStorage());
      expect(store.selectionIds, isEmpty);
      expect(store.selectedId, isNull);
      expect(store.selected, isNull);
      expect(store.selectedComponents, isEmpty);
    });

    test('select replaces the whole set', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1']);
      expect(store.selectionIds, <String>{'c0', 'c1'});
      store.select('c2');
      expect(store.selectionIds, <String>{'c2'});
      expect(store.selectedId, 'c2');
    });

    test('select(null) clears the whole set', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1']);
      store.select(null);
      expect(store.selectionIds, isEmpty);
      expect(store.selectedId, isNull);
    });

    test('select ignores an unknown id and keeps the current set', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1']);
      store.select('nope');
      expect(store.selectionIds, <String>{'c0', 'c1'});
    });

    test('addToSelection adds and makes the addition primary', () {
      final EditorStore store = _populated(_FakeStorage());
      store.select('c0');
      store.addToSelection('c1');
      store.addToSelection('c2');
      expect(store.selectionIds, <String>{'c0', 'c1', 'c2'});
      expect(store.selectedId, 'c2');
    });

    test('addToSelection re-primaries an existing member without growing', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1', 'c2']);
      expect(store.selectedId, 'c2');
      store.addToSelection('c0');
      expect(store.selectionIds.length, 3);
      expect(store.selectedId, 'c0');
    });

    test('addToSelection ignores unknown ids', () {
      final EditorStore store = _populated(_FakeStorage());
      store.select('c0');
      store.addToSelection('ghost');
      expect(store.selectionIds, <String>{'c0'});
    });

    test('toggleInSelection adds then removes', () {
      final EditorStore store = _populated(_FakeStorage());
      store.toggleInSelection('c0');
      expect(store.isSelected('c0'), isTrue);
      store.toggleInSelection('c1');
      expect(store.selectedId, 'c1');
      store.toggleInSelection('c1');
      expect(store.isSelected('c1'), isFalse);
      expect(store.selectedId, 'c0');
    });

    test('removing the primary promotes the previous member', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1', 'c2']);
      store.toggleInSelection('c2');
      expect(store.selectedId, 'c1');
      store.toggleInSelection('c1');
      expect(store.selectedId, 'c0');
    });

    test(
      'selectMany keeps iteration order and honours an explicit primary',
      () {
        final EditorStore store = _populated(_FakeStorage());
        store.selectMany(<String>['c0', 'c1', 'c2'], primary: 'c0');
        expect(store.selectionIds.toList(), <String>['c1', 'c2', 'c0']);
        expect(store.selectedId, 'c0');
      },
    );

    test('selectMany drops unknown ids', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'ghost', 'c2']);
      expect(store.selectionIds, <String>{'c0', 'c2'});
    });

    test('selectMany with an empty iterable clears', () {
      final EditorStore store = _populated(_FakeStorage());
      store.select('c0');
      store.selectMany(const <String>[]);
      expect(store.selectionIds, isEmpty);
    });

    test('selectAll selects every component in document order', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectAll();
      expect(store.selectionIds.toList(), <String>['title', 'c0', 'c1', 'c2']);
      expect(store.selectedId, 'c2');
    });

    test('selectedComponents come back in document order', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c2', 'title']);
      expect(
        store.selectedComponents.map((HuiComponent c) => c.id).toList(),
        <String>['title', 'c2'],
      );
    });

    test('isSelected reflects membership, not primacy', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1']);
      expect(store.isSelected('c0'), isTrue);
      expect(store.isSelected('c1'), isTrue);
      expect(store.isSelected('c2'), isFalse);
    });

    test('addComponent selects exactly the new component', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1']);
      final String? added = store.addComponent('button');
      expect(added, isNotNull);
      expect(store.selectionIds, <String>{added!});
    });

    test('duplicateComponent selects exactly the copy', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1']);
      final String? copy = store.duplicateComponent('c0');
      expect(copy, isNotNull);
      expect(store.selectionIds, <String>{copy!});
    });

    test('delete prunes the deleted id and leaves the rest selected', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1', 'c2']);
      store.deleteComponent('c1');
      expect(store.selectionIds, <String>{'c0', 'c2'});
      expect(store.selectedId, 'c2');
    });

    test('deleting one of two namesakes keeps the id selected', () {
      final EditorStore store = _populated(_FakeStorage());
      store.mutate('add namesake', (HuiMenu menu) {
        menu.components.add(
          HuiComponent(
            'c0',
            Vec3(1, 1, 0),
            createDefaultComponentData('decoration'),
          ),
        );
      });
      store.select('c0');
      store.deleteComponent('c0');
      expect(store.isSelected('c0'), isTrue);
    });

    test('renameComponent remaps the id in place', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1', 'c2']);
      store.renameComponent('c1', 'renamed');
      expect(store.selectionIds.toList(), <String>['c0', 'renamed', 'c2']);
      expect(store.selectedId, 'c2');
    });

    test('import clears the selection', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectAll();
      store.importJson('other.json', store.exportJson());
      expect(store.selectionIds, isEmpty);
    });

    test('opening another document clears the selection', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _populated(storage);
      store.selectAll();
      store.newDocument(name: 'second');
      expect(store.selectionIds, isEmpty);
    });

    test('undo prunes ids the restored document no longer has', () {
      final EditorStore store = _populated(_FakeStorage());
      final String? added = store.addComponent('button');
      store.selectMany(<String>['c0', added!]);
      store.performUndo();
      expect(store.menu.componentById(added), isNull);
      expect(store.selectionIds, <String>{'c0'});
    });

    test('redo does not resurrect a pruned selection', () {
      final EditorStore store = _populated(_FakeStorage());
      final String? added = store.addComponent('button');
      store.selectMany(<String>['c0', added!]);
      store.performUndo();
      store.performRedo();
      expect(store.menu.componentById(added), isNotNull);
      expect(store.selectionIds, <String>{'c0'});
    });
  });

  group('group mutations', () {
    test('setOffsets moves every listed component in one undo step', () {
      final EditorStore store = _populated(_FakeStorage());
      final int before = store.undo.undoDepth;
      store.setOffsets('align left', <String, Vec3>{
        'c0': Vec3(1, 1, 0),
        'c1': Vec3(2, 2, 0),
      });
      expect(store.menu.componentById('c0')!.offset, Vec3(1, 1, 0));
      expect(store.menu.componentById('c1')!.offset, Vec3(2, 2, 0));
      expect(store.undo.undoDepth, before + 1);
    });

    test('setOffsets undo restores every moved component at once', () {
      final EditorStore store = _populated(_FakeStorage());
      final Vec3 c0 = store.menu.componentById('c0')!.offset.copy();
      final Vec3 c1 = store.menu.componentById('c1')!.offset.copy();
      store.setOffsets('align left', <String, Vec3>{
        'c0': Vec3(1, 1, 0),
        'c1': Vec3(2, 2, 0),
      });
      store.performUndo();
      expect(store.menu.componentById('c0')!.offset, c0);
      expect(store.menu.componentById('c1')!.offset, c1);
    });

    test('setOffsets does not snap; callers own the grid', () {
      final EditorStore store = _populated(_FakeStorage());
      store.snapToGrid = true;
      store.gridSize = 0.25;
      store.setOffsets('nudge', <String, Vec3>{'c0': Vec3(0.13, 0.07, 0.42)});
      expect(store.menu.componentById('c0')!.offset, Vec3(0.13, 0.07, 0.42));
    });

    test('setOffsets ignores unknown ids', () {
      final EditorStore store = _populated(_FakeStorage());
      store.setOffsets('move', <String, Vec3>{'ghost': Vec3(9, 9, 9)});
      expect(store.menu.componentById('ghost'), isNull);
    });

    test(
      'duplicateSelection copies each source in place and selects the copies',
      () {
        final EditorStore store = _populated(_FakeStorage());
        store.selectMany(<String>['c0', 'c2']);
        final List<String> copies = store.duplicateSelection();
        expect(copies.length, 2);
        expect(store.selectionIds, copies.toSet());
        expect(
          store.menu.components.map((HuiComponent c) => c.id).toList(),
          <String>['title', 'c0', copies[0], 'c1', 'c2', copies[1]],
        );
        // Alt-drag duplicates must land exactly on their sources; the caller
        // moves them afterwards.
        expect(
          store.menu.componentById(copies[0])!.offset,
          store.menu.componentById('c0')!.offset,
        );
      },
    );

    test('duplicateSelection is one undo step', () {
      final EditorStore store = _populated(_FakeStorage());
      store.selectMany(<String>['c0', 'c1', 'c2']);
      final int before = store.undo.undoDepth;
      store.duplicateSelection();
      expect(store.undo.undoDepth, before + 1);
      store.performUndo();
      expect(store.menu.components.length, 4);
    });

    test('duplicateSelection on an empty selection does nothing', () {
      final EditorStore store = _populated(_FakeStorage());
      final int before = store.undo.undoDepth;
      expect(store.duplicateSelection(), isEmpty);
      expect(store.undo.undoDepth, before);
    });
  });

  group('preview preferences', () {
    test('defaults match the documented preview settings', () {
      final EditorStore store = _store(_FakeStorage());
      expect(store.previewShowPlanes, isFalse);
      expect(store.previewShowNormals, isFalse);
      expect(store.previewShowAnchors, isFalse);
      expect(store.previewShowCenter, isTrue);
      expect(store.previewShowDistanceSphere, isFalse);
      expect(store.previewShowGroundGrid, isTrue);
      expect(store.previewLogOpen, isTrue);
      expect(store.previewBannerDismissed, isFalse);
      expect(store.previewCameraMode, PreviewCameraMode.orbit);
    });

    test('preview settings round-trip through the preference blob', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore first = _store(storage);
      first.previewShowPlanes = true;
      first.previewShowNormals = true;
      first.previewShowAnchors = true;
      first.previewShowCenter = false;
      first.previewShowDistanceSphere = true;
      first.previewShowGroundGrid = false;
      first.previewLogOpen = false;
      first.previewBannerDismissed = true;
      first.previewCameraMode = PreviewCameraMode.player;
      first.view = EditorView.preview;
      first.flushAutosave();

      final EditorStore second = _store(storage);
      expect(second.previewShowPlanes, isTrue);
      expect(second.previewShowNormals, isTrue);
      expect(second.previewShowAnchors, isTrue);
      expect(second.previewShowCenter, isFalse);
      expect(second.previewShowDistanceSphere, isTrue);
      expect(second.previewShowGroundGrid, isFalse);
      expect(second.previewLogOpen, isFalse);
      expect(second.previewBannerDismissed, isTrue);
      expect(second.previewCameraMode, PreviewCameraMode.player);
      expect(second.view, EditorView.preview);
    });

    test('a preference blob written before the preview keys still loads', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[EditorStore.preferencesKey] =
          '{"view":"split","previewUiScale":2.0,"gridSize":0.25,'
          '"showHitboxes":true,"showAnchors":false,"showGrid":false,'
          '"snapToGrid":false,"trueRender":true,"backdrop":"dark"}';
      final EditorStore store = _store(storage);
      expect(store.view, EditorView.split);
      expect(store.previewUiScale, 2.0);
      expect(store.trueRender, isTrue);
      expect(store.previewShowCenter, isTrue);
      // A blob that predates the facing note shows it again, once.
      expect(store.previewBannerDismissed, isFalse);
      expect(store.previewCameraMode, PreviewCameraMode.orbit);
    });
  });

  group('overlap plumbing', () {
    test('overlapping clickable hitboxes reach validation', () {
      final EditorStore store = _store(_FakeStorage());
      store.mutate('two buttons', (HuiMenu menu) {
        menu.components
          ..clear()
          ..add(
            HuiComponent(
              'a',
              Vec3(0, 0, 0),
              createDefaultComponentData('button'),
            ),
          )
          ..add(
            HuiComponent(
              'b',
              Vec3(0.01, 0, 0),
              createDefaultComponentData('button'),
            ),
          );
      });
      // W1 lands the rule itself; W0 only guarantees the store computes the
      // overlaps and hands them to the validator.
      expect(store.overlapPairs.length, 1);
      expect(store.overlapPairs.single.firstId, 'a');
      expect(store.overlapPairs.single.secondId, 'b');
    });
  });
}
