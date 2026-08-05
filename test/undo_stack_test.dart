/// Editor state-layer tests: the undo stack, the multi-document workspace and
/// the store mutations built on top of them. All three are pure Dart, so the
/// whole layer is exercised on the VM with injected storage functions.
library;

import 'package:holoui_editor/config/defaults.dart';
import 'package:holoui_editor/logic/validation.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/state/editor_store.dart';
import 'package:holoui_editor/state/undo_stack.dart';
import 'package:holoui_editor/state/workspace.dart';
import 'package:test/test.dart';

/// In-memory stand-in for `localStorage` so no test touches the shared
/// `StorageService` backing map.
class _FakeStorage {
  final Map<String, String> values = <String, String>{};
  bool refuseWrites = false;
  int writeCount = 0;

  String? read(String key) => values[key];

  bool write(String key, String value) {
    writeCount++;
    if (refuseWrites) return false;
    values[key] = value;
    return true;
  }
}

Workspace _workspace(_FakeStorage storage, {bool autoLoad = true}) =>
    Workspace(read: storage.read, write: storage.write, autoLoad: autoLoad);

EditorStore _store(_FakeStorage storage) =>
    EditorStore(workspace: _workspace(storage), autosaveDelay: Duration.zero);

void main() {
  group('UndoStack', () {
    test('starts empty', () {
      final UndoStack stack = UndoStack();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
      expect(stack.undoLabel, isNull);
      expect(stack.redoLabel, isNull);
      expect(stack.undo('a'), isNull);
      expect(stack.redo('a'), isNull);
    });

    test('push records the pre-mutation snapshot with its label', () {
      final UndoStack stack = UndoStack();
      stack.push('move component', 'v1');
      expect(stack.canUndo, isTrue);
      expect(stack.undoLabel, 'move component');
      expect(stack.undoDepth, 1);
    });

    test('undo returns the previous snapshot and arms redo', () {
      final UndoStack stack = UndoStack();
      stack.push('edit', 'v1');
      expect(stack.undo('v2'), 'v1');
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isTrue);
      expect(stack.redoLabel, 'edit');
    });

    test('redo returns the snapshot that was current when undo ran', () {
      final UndoStack stack = UndoStack();
      stack.push('edit', 'v1');
      stack.undo('v2');
      expect(stack.redo('v1'), 'v2');
      expect(stack.canUndo, isTrue);
      expect(stack.canRedo, isFalse);
      expect(stack.undoLabel, 'edit');
    });

    test('a new push discards the redo branch', () {
      final UndoStack stack = UndoStack();
      stack.push('first', 'v1');
      stack.undo('v2');
      expect(stack.canRedo, isTrue);
      stack.push('second', 'v1');
      expect(stack.canRedo, isFalse);
      expect(stack.redoDepth, 0);
    });

    test('capacity drops the oldest entries', () {
      final UndoStack stack = UndoStack(capacity: 3);
      for (int i = 0; i < 6; i++) {
        stack.push('edit $i', 'v$i');
      }
      expect(stack.undoDepth, 3);
      expect(stack.undoLabel, 'edit 5');
      expect(stack.undo('current'), 'v5');
      expect(stack.undo('v5'), 'v4');
      expect(stack.undo('v4'), 'v3');
      expect(stack.canUndo, isFalse);
    });

    test('capacity below one still keeps a single step', () {
      final UndoStack stack = UndoStack(capacity: 0);
      stack.push('edit', 'v1');
      expect(stack.undoDepth, 1);
    });

    test('clear drops both branches', () {
      final UndoStack stack = UndoStack();
      stack.push('edit', 'v1');
      stack.undo('v2');
      stack.clear();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
    });

    test('round trips a long alternating undo and redo run', () {
      final UndoStack stack = UndoStack();
      String current = 'v0';
      for (int i = 1; i <= 20; i++) {
        stack.push('edit $i', current);
        current = 'v$i';
      }
      for (int i = 20; i >= 1; i--) {
        final String? restored = stack.undo(current);
        expect(restored, 'v${i - 1}');
        current = restored!;
      }
      for (int i = 1; i <= 20; i++) {
        final String? restored = stack.redo(current);
        expect(restored, 'v$i');
        current = restored!;
      }
      expect(stack.canRedo, isFalse);
    });
  });

  group('Workspace', () {
    test('create makes the document active and persists it', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace workspace = _workspace(storage);
      final WorkspaceDoc doc = workspace.create(
        name: 'shop',
        json: '{"components": []}',
      );
      expect(workspace.activeId, doc.id);
      expect(workspace.docs.length, 1);
      expect(storage.values[Workspace.storageKey], isNotNull);
    });

    test('round-trips through storage', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace first = _workspace(storage);
      final WorkspaceDoc a = first.create(name: 'a', json: '{"a": 1}');
      first.create(name: 'b', json: '{"b": 2}');
      first.switchTo(a.id);

      final Workspace second = _workspace(storage);
      expect(second.docs.length, 2);
      expect(second.activeId, a.id);
      expect(second.active?.name, 'a');
      expect(second.active?.json, '{"a": 1}');
    });

    test('skips corrupt entries instead of throwing', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] =
          '{"docs":['
          '{"id":"1","name":"good","json":"{}","updatedAt":5},'
          '{"id":"2","name":"bad-json","json":"{not json","updatedAt":6},'
          '{"id":"3"},'
          '"nonsense",'
          'null'
          '],"activeId":"2"}';
      final Workspace workspace = _workspace(storage);
      expect(workspace.docs.length, 1);
      expect(workspace.docs.single.id, '1');
      expect(workspace.activeId, '1');
    });

    test('survives a payload that is not JSON at all', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] = 'not json at all';
      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, isEmpty);
      expect(workspace.activeId, isNull);
      expect(workspace.lastError, isNotNull);
    });

    test('survives a payload of the wrong shape', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] = '[1, 2, 3]';
      final Workspace workspace = _workspace(storage);
      expect(workspace.docs, isEmpty);
    });

    test('rename sanitizes and persists', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace workspace = _workspace(storage);
      final WorkspaceDoc doc = workspace.create(name: 'a', json: '{}');
      expect(workspace.rename(doc.id, 'Warp Compass'), isTrue);
      expect(workspace.byId(doc.id)?.name, 'warp-compass');
      expect(workspace.rename('missing', 'x'), isFalse);
    });

    test('delete picks a new active document', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace workspace = _workspace(storage);
      final WorkspaceDoc a = workspace.create(name: 'a', json: '{}');
      final WorkspaceDoc b = workspace.create(name: 'b', json: '{}');
      expect(workspace.activeId, b.id);
      expect(workspace.delete(b.id), isTrue);
      expect(workspace.activeId, a.id);
      expect(workspace.delete(a.id), isTrue);
      expect(workspace.docs, isEmpty);
      expect(workspace.activeId, isNull);
    });

    test('switchTo rejects unknown ids', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace workspace = _workspace(storage);
      workspace.create(name: 'a', json: '{}');
      expect(workspace.switchTo('nope'), isFalse);
    });

    test(
      'a refused write is reported without losing the in-memory document',
      () {
        final _FakeStorage storage = _FakeStorage();
        final Workspace workspace = _workspace(storage);
        storage.refuseWrites = true;
        final WorkspaceDoc doc = workspace.create(name: 'a', json: '{}');
        expect(workspace.byId(doc.id), isNotNull);
        expect(workspace.lastError, isNotNull);
        expect(workspace.quotaExceeded, isTrue);
      },
    );

    test('recent orders by updatedAt descending', () {
      final _FakeStorage storage = _FakeStorage();
      final Workspace workspace = _workspace(storage);
      final WorkspaceDoc a = workspace.create(name: 'a', json: '{}');
      final WorkspaceDoc b = workspace.create(name: 'b', json: '{}');
      workspace.switchTo(a.id);
      workspace.updateActive(json: '{"x":1}');
      expect(workspace.recent.first.id, a.id);
      expect(workspace.recent.last.id, b.id);
    });
  });

  group('defaults', () {
    test('the new document matches the documented defaults', () {
      final HuiMenu menu = createDefaultMenu();
      expect(menu.offset, Vec3(0, 1.7, 2.5));
      expect(menu.followPlayer, isTrue);
      expect(menu.closeOnDeath, isTrue);
      expect(menu.closeOnTeleport, isTrue);
      expect(menu.lockPosition, isFalse);
      expect(menu.maxDistance, isNull);
      expect(menu.components.length, 1);
      final HuiComponent title = menu.components.single;
      expect(title.offset, Vec3(0, 0.85, 0));
      expect(title.data, isA<HuiDecorationData>());
      expect(
        ((title.data as HuiDecorationData).icon! as HuiTextIcon).text,
        '&6&lMy Menu',
      );
    });

    test('the default document validates without errors', () {
      final List<HuiIssue> issues = validateHuiMenu(createDefaultMenu());
      expect(
        issues.where((HuiIssue i) => i.severity == HuiSeverity.error),
        isEmpty,
      );
    });

    test('new component defaults follow the format contract', () {
      final HuiButtonData button =
          createDefaultComponentData('button') as HuiButtonData;
      expect(button.highlightModifier, 0.05);
      expect(button.hitbox, isNull);

      final HuiSoundAction sound =
          createDefaultAction('sound') as HuiSoundAction;
      expect(sound.sound, 'ui.button.click');
      expect(sound.source, 'master');
      expect(sound.volume, 1);
      expect(sound.pitch, 1);

      final HuiCommandAction command =
          createDefaultAction('command') as HuiCommandAction;
      expect(command.source, 'player');
    });

    test('every default component and icon validates clean', () {
      for (final String type in huiComponentTypes) {
        final HuiMenu menu = HuiMenu()
          ..components.add(
            createDefaultComponent(type: type, takenIds: const <String>{}),
          );
        expect(
          validateHuiMenu(
            menu,
          ).where((HuiIssue i) => i.severity == HuiSeverity.error),
          isEmpty,
          reason: 'default $type component must not start in an error state',
        );
      }
    });

    test('unique ids read like button, button-2, button-3', () {
      expect(uniqueComponentId('button', const <String>{}), 'button');
      expect(uniqueComponentId('button', const <String>{'button'}), 'button-2');
      expect(
        uniqueComponentId('button', const <String>{'button', 'button-2'}),
        'button-3',
      );
    });

    test('component ids are sanitized to the plugin character set', () {
      expect(sanitizeComponentId('Buy Now!'), 'Buy-Now');
      expect(sanitizeComponentId('   '), 'component');
      expect(sanitizeComponentId('a' * 200).length, 64);
    });

    test('menu ids are sanitized to a safe file base name', () {
      expect(sanitizeMenuId('My Shop Menu'), 'my-shop-menu');
      expect(sanitizeMenuId('  ../weird:name  '), 'weird-name');
      expect(sanitizeMenuId(''), huiDefaultMenuId);
    });

    test('nextFreeOffset avoids offsets already in use', () {
      final HuiMenu menu = createDefaultMenu();
      final Vec3 first = nextFreeOffset(menu);
      menu.components.add(HuiComponent('a', first, HuiDecorationData()));
      final Vec3 second = nextFreeOffset(menu);
      expect(second, isNot(first));
    });
  });

  group('EditorStore', () {
    test('boots on the default document', () {
      final EditorStore store = _store(_FakeStorage());
      expect(store.menuId, huiDefaultMenuId);
      expect(store.menu.components.length, 1);
      expect(store.canUndo, isFalse);
      expect(
        store.issues.where((HuiIssue i) => i.severity == HuiSeverity.error),
        isEmpty,
      );
      store.dispose();
    });

    test('mutate records one undo step and revalidates', () {
      final EditorStore store = _store(_FakeStorage());
      int notifications = 0;
      store.addListener(() => notifications++);

      store.mutate('clear icon', (HuiMenu menu) {
        (menu.components.first.data as HuiDecorationData).icon = null;
      });

      expect(notifications, 1);
      expect(store.canUndo, isTrue);
      expect(store.undo.undoLabel, 'clear icon');
      expect(
        store.issues.any((HuiIssue i) => i.severity == HuiSeverity.warning),
        isTrue,
      );

      store.performUndo();
      expect(
        (store.menu.components.first.data as HuiDecorationData).icon,
        isNotNull,
      );
      expect(store.canRedo, isTrue);

      store.performRedo();
      expect(
        (store.menu.components.first.data as HuiDecorationData).icon,
        isNull,
      );
      store.dispose();
    });

    test('a mutation that changes nothing records no undo step', () {
      final EditorStore store = _store(_FakeStorage());
      store.mutate('no-op', (HuiMenu menu) {});
      expect(store.canUndo, isFalse);
      store.dispose();
    });

    test('drag coalescing collapses a stream of moves into one step', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      final int depthBefore = store.undo.undoDepth;

      store.beginDrag();
      for (int i = 1; i <= 5; i++) {
        store.setComponentOffset(id, Vec3(i * 0.1, 0, 0));
      }
      store.endDrag();

      expect(store.undo.undoDepth, depthBefore + 1);
      store.performUndo();
      expect(store.menu.componentById(id)?.offset.x, isNot(0.5));
      store.dispose();
    });

    test('a burst of same-label edits collapses into one undo step', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      final int depthBefore = store.undo.undoDepth;

      for (final String text in <String>['S', 'Sh', 'Sho', 'Shop']) {
        store.editComponent(id, 'text', (HuiComponent component) {
          (component.data as HuiButtonData).icon = HuiTextIcon(text);
        });
      }

      expect(store.undo.undoDepth, depthBefore + 1);
      store.performUndo();
      expect(
        ((store.menu.componentById(id)!.data as HuiButtonData).icon!
                as HuiTextIcon)
            .text,
        isNot('Shop'),
      );
      store.dispose();
    });

    test('structural edits are never coalesced with each other', () {
      final EditorStore store = _store(_FakeStorage());
      final int depthBefore = store.undo.undoDepth;
      store.addComponent('button');
      store.addComponent('button');
      expect(store.undo.undoDepth, depthBefore + 2);
      store.dispose();
    });

    test('a different label starts a fresh undo step', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      final int depthBefore = store.undo.undoDepth;
      store.editComponent(id, 'text', (HuiComponent component) {
        (component.data as HuiButtonData).icon = HuiTextIcon('a');
      });
      store.editComponent(id, 'highlight modifier', (HuiComponent component) {
        (component.data as HuiButtonData).highlightModifier = 0.5;
      });
      expect(store.undo.undoDepth, depthBefore + 2);
      store.dispose();
    });

    test('custom hitbox edits undo and redo as one component change', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      store.editComponent(id, 'enable custom hitbox', (HuiComponent component) {
        (component.data as HuiButtonData).hitbox = HuiHitbox(1.25, 0.35);
      });
      expect(
        (store.menu.componentById(id)!.data as HuiButtonData).hitbox!.width,
        1.25,
      );

      expect(store.performUndo(), isTrue);
      expect(
        (store.menu.componentById(id)!.data as HuiButtonData).hitbox,
        isNull,
      );
      expect(store.performRedo(), isTrue);
      expect(
        (store.menu.componentById(id)!.data as HuiButtonData).hitbox!.height,
        0.35,
      );
      store.dispose();
    });

    test(
      'addComponent generates readable unique ids and selects the result',
      () {
        final EditorStore store = _store(_FakeStorage());
        expect(store.addComponent('button'), 'button');
        expect(store.selectedId, 'button');
        expect(store.addComponent('button'), 'button-2');
        expect(store.addComponent('toggle'), 'toggle');
        expect(store.menu.components.length, 4);
        store.dispose();
      },
    );

    test('duplicateComponent copies deeply and never reuses an id', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      final String copy = store.duplicateComponent(id)!;
      expect(copy, isNot(id));
      final HuiButtonData original =
          store.menu.componentById(id)!.data as HuiButtonData;
      final HuiButtonData clone =
          store.menu.componentById(copy)!.data as HuiButtonData;
      expect(identical(original.icon, clone.icon), isFalse);
      store.dispose();
    });

    test('duplicating an id that already ends in a number increments it', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button', id: 'slot-1')!;
      expect(id, 'slot-1');
      expect(store.duplicateComponent(id), 'slot-2');
      store.dispose();
    });

    test('deleteComponent removes one row, never its duplicate namesakes', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson(
        'dupes.json',
        '{"offset":[0,1.7,2.5],"components":['
            '{"id":"btn","offset":[0,0,0],"data":{"type":"decoration",'
            '"icon":{"type":"text","text":"first"}}},'
            '{"id":"btn","offset":[0,-0.5,0],"data":{"type":"decoration",'
            '"icon":{"type":"text","text":"second"}}}]}',
      );
      expect(store.menu.components.length, 2);

      store.deleteComponent('btn');
      expect(store.menu.components.length, 1);
      expect(
        ((store.menu.components.single.data as HuiDecorationData).icon!
                as HuiTextIcon)
            .text,
        'second',
      );
      store.dispose();
    });

    test('deleteComponent clears a stale selection', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      store.select(id);
      store.deleteComponent(id);
      expect(store.selectedId, isNull);
      expect(store.menu.componentById(id), isNull);
      store.dispose();
    });

    test('reorder moves a component within the dispatch order', () {
      final EditorStore store = _store(_FakeStorage());
      final String first = store.addComponent('button')!;
      store.addComponent('decoration');
      store.reorder(first, store.menu.components.length - 1);
      expect(store.menu.components.last.id, first);
      store.dispose();
    });

    test('snapping rounds offsets to the grid step', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      store.snapToGrid = true;
      store.gridSize = 0.05;
      store.setComponentOffset(id, Vec3(0.123, -0.077, 0));
      expect(store.menu.componentById(id)!.offset.x, closeTo(0.1, 1e-9));
      expect(store.menu.componentById(id)!.offset.y, closeTo(-0.1, 1e-9));

      store.snapToGrid = false;
      store.setComponentOffset(id, Vec3(0.123, 0, 0));
      expect(store.menu.componentById(id)!.offset.x, closeTo(0.123, 1e-9));
      store.dispose();
    });

    test('a nudge snaps only the axis it moves', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      store.snapToGrid = true;
      store.gridSize = 0.05;
      store.editComponent(id, 'offset', (HuiComponent component) {
        component.offset = Vec3(0, 0, 0.13);
      });

      store.moveComponent(id, Vec3(0, 0.05, 0));
      expect(store.menu.componentById(id)!.offset.z, closeTo(0.13, 1e-9));
      expect(store.menu.componentById(id)!.offset.y, closeTo(0.05, 1e-9));
      store.dispose();
    });

    test('importJson replaces the document undo-ably', () {
      final EditorStore store = _store(_FakeStorage());
      final HuiMenu replacement = HuiMenu(offset: Vec3(1, 2, 3))
        ..components.add(
          HuiComponent(
            'imported',
            Vec3.zero(),
            HuiDecorationData(HuiTextIcon('&aImported')),
          ),
        );

      store.importJson('Warp Compass.json', encodeHuiMenu(replacement));

      expect(store.lastError, isNull);
      expect(store.menuId, 'warp-compass');
      expect(store.menu.components.single.id, 'imported');
      expect(store.canUndo, isTrue);

      store.performUndo();
      expect(store.menu.components.single.id, 'title');
      store.dispose();
    });

    test('a failed import leaves the document untouched', () {
      final EditorStore store = _store(_FakeStorage());
      final String before = store.exportJson();
      store.importJson('broken.json', '{ not json');
      expect(store.lastError, isNotNull);
      expect(store.exportJson(), before);
      expect(store.canUndo, isFalse);
      store.dispose();
    });

    test('an import error is reported to the message sink', () {
      final EditorStore store = _store(_FakeStorage());
      final List<String> errors = <String>[];
      store.onError = errors.add;
      store.importJson('broken.json', '[]');
      expect(errors, isNotEmpty);
      store.dispose();
    });

    test('exportJson round-trips through the decoder', () {
      final EditorStore store = _store(_FakeStorage());
      store.addComponent('toggle');
      final HuiMenu reparsed = decodeHuiMenu(store.exportJson());
      expect(reparsed.components.length, store.menu.components.length);
      store.dispose();
    });

    test('applyCode commits valid JSON and refuses invalid JSON', () {
      final EditorStore store = _store(_FakeStorage());
      final HuiMenu edited = createDefaultMenu()..lockPosition = true;

      expect(store.applyCode(encodeHuiMenu(edited)), isTrue);
      expect(store.menu.lockPosition, isTrue);
      expect(store.codeError, isNull);

      final String good = store.exportJson();
      expect(store.applyCode('{"components": [ '), isFalse);
      expect(store.codeError, isNotNull);
      expect(store.exportJson(), good);
      store.dispose();
    });

    test('autosave persists the document to the workspace', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _store(storage);
      store.addComponent('button');
      store.flushAutosave();
      final String? payload = storage.values[Workspace.storageKey];
      expect(payload, isNotNull);
      expect(payload!.contains('button'), isTrue);
      expect(store.lastSavedAt, isNotNull);
      store.dispose();
    });

    test('the flush that clears the dirty flags also notifies', () {
      final EditorStore store = _store(_FakeStorage());
      store.addComponent('button');
      int notifications = 0;
      store.addListener(() => notifications++);

      store.flushAutosave();
      expect(store.hasUnsavedChanges, isFalse);
      expect(store.lastSavedAt, isNotNull);
      expect(notifications, 1);

      // Nothing pending: no write, no notification.
      store.flushAutosave();
      expect(notifications, 1);
      store.dispose();
    });

    test('the debounced autosave clears the dirty flag and notifies', () async {
      final EditorStore store = _store(_FakeStorage());
      store.addComponent('button');
      expect(store.hasUnsavedChanges, isTrue);
      int notifications = 0;
      store.addListener(() => notifications++);

      await Future<void>.delayed(Duration.zero);

      expect(store.hasUnsavedChanges, isFalse);
      expect(store.lastSavedAt, isNotNull);
      expect(notifications, greaterThan(0));
      store.dispose();
    });

    test('a preferences-only flush notifies too', () {
      final EditorStore store = _store(_FakeStorage());
      store.flushAutosave();
      int notifications = 0;
      store.showHitboxes = true;
      store.addListener(() => notifications++);
      store.flushAutosave();
      expect(store.hasUnsavedChanges, isFalse);
      expect(notifications, 1);
      store.dispose();
    });

    test('the document reloads from the workspace on the next boot', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore first = _store(storage);
      first.setMenuId('shop');
      first.addComponent('button');
      first.flushAutosave();
      first.dispose();

      final EditorStore second = _store(storage);
      expect(second.menuId, 'shop');
      expect(second.menu.components.length, 2);
      expect(second.canUndo, isFalse);
      second.dispose();
    });

    test('a corrupt stored document degrades to a fresh default menu', () {
      final _FakeStorage storage = _FakeStorage();
      storage.values[Workspace.storageKey] =
          '{"docs":[{"id":"1","name":"broken","json":"[1,2,3]","updatedAt":1}],'
          '"activeId":"1"}';
      final EditorStore store = _store(storage);
      expect(store.menu.components.length, 1);
      expect(store.lastError, isNotNull);
      store.dispose();
    });

    test('newDocument starts a second workspace entry', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _store(storage);
      final String firstDoc = store.workspace.activeId!;
      store.newDocument(name: 'second');
      expect(store.workspace.activeId, isNot(firstDoc));
      expect(store.workspace.docs.length, 2);
      expect(store.menuId, 'second');
      expect(store.canUndo, isFalse);
      store.dispose();
    });

    test('switching documents preserves both', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _store(storage);
      final String first = store.workspace.activeId!;
      store.addComponent('button');
      store.newDocument(name: 'second');
      store.addComponent('toggle');
      store.openDocument(first);
      expect(
        store.menu.components.any((HuiComponent c) => c.id == 'button'),
        isTrue,
      );
      expect(
        store.menu.components.any((HuiComponent c) => c.id == 'toggle'),
        isFalse,
      );
      store.dispose();
    });

    test('deleting the active document falls back to another one', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _store(storage);
      final String first = store.workspace.activeId!;
      store.newDocument(name: 'second');
      final String second = store.workspace.activeId!;
      store.deleteDocument(second);
      expect(store.workspace.activeId, first);
      store.dispose();
    });

    test('deleting the last document leaves a usable default document', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _store(storage);
      store.deleteDocument(store.workspace.activeId!);
      expect(store.workspace.docs.length, 1);
      expect(store.menu.components.length, 1);
      store.dispose();
    });

    test('view flags persist across boots', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore first = _store(storage);
      first.showHitboxes = true;
      first.previewUiScale = 2;
      first.view = EditorView.split;
      first.flushAutosave();
      first.dispose();

      final EditorStore second = _store(storage);
      expect(second.showHitboxes, isTrue);
      expect(second.previewUiScale, 2);
      expect(second.view, EditorView.split);
      second.dispose();
    });

    test('toggle preview state defaults to the true icon', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('toggle')!;
      expect(store.togglePreviewFor(id), isTrue);
      store.setTogglePreview(id, false);
      expect(store.togglePreviewFor(id), isFalse);
      store.dispose();
    });

    test('issue helpers group by severity and component', () {
      final EditorStore store = _store(_FakeStorage());
      final String id = store.addComponent('button')!;
      store.editComponent(id, 'break icon', (HuiComponent component) {
        (component.data as HuiButtonData).icon = null;
      });
      expect(store.warningCount, greaterThan(0));
      expect(store.issuesFor(id), isNotEmpty);
      store.dispose();
    });

    test('export file name follows the sanitized menu id', () {
      final EditorStore store = _store(_FakeStorage());
      store.setMenuId('Warp Compass');
      expect(store.menuId, 'warp-compass');
      expect(store.exportFileName, 'warp-compass.json');
      store.dispose();
    });
  });
}
