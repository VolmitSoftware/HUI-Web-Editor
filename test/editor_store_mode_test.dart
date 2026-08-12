/// [EditorStore] doc-kind plumbing: holding either a [HuiMenu] or a
/// [HuiPreviewDoc] for the active document, mode-aware import/export, and the
/// guarantee that every existing menu-editing path keeps working untouched
/// once a container-preview document has been in play during the same
/// session.
library;

import 'package:holoui_editor/config/defaults.dart';
import 'package:holoui_editor/logic/preview_sim_controls.dart'
    show PreviewSimController;
import 'package:holoui_editor/logic/validation.dart' show HuiIssue, HuiSeverity;
import 'package:holoui_editor/model/model.dart';
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
  workspace: Workspace(read: storage.read, write: storage.write),
  autosaveDelay: Duration.zero,
);

const String _previewJson = '''
{
  "elements": [
    { "type": "cell", "x": 0, "y": 0, "size": 8, "color": "#FF00FF00" }
  ]
}
''';

void main() {
  group('a fresh store', () {
    test('boots in menu mode', () {
      final EditorStore store = _store(_FakeStorage());
      expect(store.docKind, WorkspaceDocKind.menu);
      expect(store.isPreviewDoc, isFalse);
      expect(store.previewDoc, isNull);
    });
  });

  group('importJson auto-detection', () {
    test('a menu document keeps the store in menu mode', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('shop.json', encodeHuiMenu(createDefaultMenu()));
      expect(store.docKind, WorkspaceDocKind.menu);
      expect(store.previewDoc, isNull);
    });

    test(
      'a document with elements and no components switches to preview mode',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson);
        expect(store.docKind, WorkspaceDocKind.containerPreview);
        expect(store.previewDoc, isNotNull);
        expect(store.previewDoc!.elements, hasLength(1));
      },
    );

    test('malformed JSON is refused and the active document is untouched', () {
      final EditorStore store = _store(_FakeStorage());
      final String before = store.exportJson();
      String? reported;
      store.onError = (String message) => reported = message;
      store.importJson('broken.json', '{not json');
      expect(store.exportJson(), before);
      expect(store.docKind, WorkspaceDocKind.menu);
      expect(reported, isNotNull);
    });

    test(
      're-importing a menu after a preview import switches back cleanly',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson);
        expect(store.docKind, WorkspaceDocKind.containerPreview);

        store.importJson('shop.json', encodeHuiMenu(createDefaultMenu()));
        expect(store.docKind, WorkspaceDocKind.menu);
        expect(store.previewDoc, isNull);
        expect(store.components, isNotEmpty);
      },
    );

    test('switching kind via import clears undo/redo', () {
      final EditorStore store = _store(_FakeStorage());
      store.addComponent('decoration');
      expect(store.canUndo, isTrue);

      store.importJson('furnace.json', _previewJson);
      expect(store.canUndo, isFalse);
      expect(store.canRedo, isFalse);
    });
  });

  group('exportJson mode-awareness', () {
    test('exports HuiMenu JSON while in menu mode', () {
      final EditorStore store = _store(_FakeStorage());
      final HuiMenu roundTripped = decodeHuiMenu(store.exportJson());
      expect(roundTripped.components.length, store.components.length);
    });

    test('exports HuiPreviewDoc JSON once in preview mode', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      final HuiPreviewDoc roundTripped = decodeHuiPreviewDoc(
        store.exportJson(),
      );
      expect(roundTripped.elements.length, 1);
    });
  });

  group('menu-editing API while a preview document is active', () {
    test(
      'mutate is a documented no-op instead of corrupting the stale menu',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson);
        final int before = store.components.length;
        store.mutate('add', (HuiMenu menu) {
          menu.components.add(
            HuiComponent('x', Vec3.zero(), HuiDecorationData(HuiTextIcon('x'))),
          );
        });
        expect(store.components.length, before);
        expect(store.docKind, WorkspaceDocKind.containerPreview);
      },
    );

    test(
      'applyCode refuses menu JSON rather than emptying the preview doc',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson);
        final bool applied = store.applyCode(
          encodeHuiMenu(createDefaultMenu()),
        );
        expect(applied, isFalse);
        expect(store.codeError, isNotNull);
        expect(store.docKind, WorkspaceDocKind.containerPreview);
        expect(store.previewDoc!.elements, hasLength(1));
      },
    );

    test(
      'validation reflects the preview document, not stale menu results',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson);
        // `_previewJson` has no `match`, which earns the "will never be
        // selected" info nudge (E7's document validator) but no error/warning.
        expect(store.hasErrors, isFalse);
        expect(
          store.issues.every(
            (HuiIssue issue) => issue.severity == HuiSeverity.info,
          ),
          isTrue,
        );
      },
    );
  });

  group('newPreviewDocument / createDocumentFromPreview', () {
    test(
      'newPreviewDocument starts a fresh workspace entry in preview mode',
      () {
        final EditorStore store = _store(_FakeStorage());
        final int docsBefore = store.workspace.docs.length;
        store.newPreviewDocument(name: 'my-card');
        expect(store.docKind, WorkspaceDocKind.containerPreview);
        expect(store.workspace.docs.length, docsBefore + 1);
        expect(store.workspace.active?.kind, WorkspaceDocKind.containerPreview);
      },
    );

    test('createDocumentFromPreview applies a template as a new document', () {
      final EditorStore store = _store(_FakeStorage());
      final HuiPreviewDoc template = HuiPreviewDoc(
        elements: <HuiPreviewElement>[HuiPreviewElement('label', text: "'hi'")],
      );
      store.createDocumentFromPreview('greeting', template);
      expect(store.previewDoc?.elements.length, 1);
      expect(store.menuId, 'greeting');
    });
  });

  group('mutatePreview', () {
    test('writes the document and can be undone', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.mutatePreview('move cell', (HuiPreviewDoc doc) {
        doc.elements.first.x = 12;
      });
      expect(store.previewDoc!.elements.first.x, 12);
      expect(store.canUndo, isTrue);
      expect(store.undoLabel, 'move cell');

      expect(store.performUndo(), isTrue);
      expect(store.previewDoc!.elements.first.x, 0);
      expect(store.performRedo(), isTrue);
      expect(store.previewDoc!.elements.first.x, 12);
    });

    test('a write that changes nothing records no step', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.mutatePreview('touch', (HuiPreviewDoc doc) {});
      expect(store.canUndo, isFalse);
    });

    test('is a no-op while a menu is the active document', () {
      final EditorStore store = _store(_FakeStorage());
      store.mutatePreview('add', (HuiPreviewDoc doc) {
        doc.elements.add(HuiPreviewElement('cell'));
      });
      expect(store.previewDoc, isNull);
      expect(store.canUndo, isFalse);
    });

    test('a whole drag collapses into one undo step', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.beginDrag();
      for (int x = 1; x <= 5; x++) {
        store.editPreviewElement(0, 'move element', (HuiPreviewElement e) {
          e.x = x;
        });
      }
      store.endDrag();
      expect(store.previewDoc!.elements.first.x, 5);
      expect(store.performUndo(), isTrue);
      expect(store.previewDoc!.elements.first.x, 0);
    });

    test('editPreviewElement ignores an index the document does not have', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.editPreviewElement(7, 'move', (HuiPreviewElement e) => e.x = 3);
      expect(store.canUndo, isFalse);
    });

    test('the workspace autosaves the mutated document', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore first = _store(storage);
      first.importJson('furnace.json', _previewJson);
      first.mutatePreview('move cell', (HuiPreviewDoc doc) {
        doc.elements.first.y = -8;
      });
      first.flushAutosave();

      final EditorStore second = _store(storage);
      expect(second.previewDoc!.elements.first.y, -8);
    });
  });

  group('previewRevision', () {
    test('moves for an in-place edit, an undo and a code commit', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      final int imported = store.previewRevision;

      store.mutatePreview(
        'move',
        (HuiPreviewDoc doc) => doc.elements.first.x = 5,
      );
      final int edited = store.previewRevision;
      expect(edited, greaterThan(imported));

      store.performUndo();
      expect(store.previewRevision, greaterThan(edited));
    });

    test('does not move for a write that changed nothing', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      final int before = store.previewRevision;
      store.mutatePreview('touch', (HuiPreviewDoc doc) {});
      expect(store.previewRevision, before);
    });

    test('moves when the active document is swapped', () {
      final EditorStore store = _store(_FakeStorage());
      final int before = store.previewRevision;
      store.newPreviewDocument(name: 'card-a');
      expect(store.previewRevision, greaterThan(before));
    });

    test('never repeats a value across a document switch', () {
      final EditorStore store = _store(_FakeStorage());
      final Set<int> seen = <int>{store.previewRevision};
      store.newPreviewDocument(name: 'card-a');
      seen.add(store.previewRevision);
      store.newDocument(name: 'menu-a');
      seen.add(store.previewRevision);
      store.newPreviewDocument(name: 'card-b');
      seen.add(store.previewRevision);
      expect(seen, hasLength(4));
    });
  });

  group('preview element selection', () {
    test('selects by index and reports the element', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.selectPreviewElement(0);
      expect(store.previewSelectedIndex, 0);
      expect(store.previewSelectedElement?.type, 'cell');
    });

    test('an index the document does not have is ignored', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.selectPreviewElement(4);
      expect(store.previewSelectedIndex, isNull);
    });

    test('a selection past the end is dropped when a step removes it', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.selectPreviewElement(0);
      store.mutatePreview(
        'delete',
        (HuiPreviewDoc doc) => doc.elements.clear(),
      );
      expect(store.previewSelectedIndex, isNull);
    });

    test('opening another document clears it', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.selectPreviewElement(0);
      store.newDocument(name: 'menu-a');
      expect(store.previewSelectedIndex, isNull);
    });
  });

  group('applyCode in preview mode', () {
    const String edited = '''
{
  "elements": [
    { "type": "cell", "x": 4, "y": 0, "size": 8, "color": "#FF00FF00" },
    { "type": "label", "x": 0, "y": -20, "text": "'hi'" }
  ]
}
''';

    test('a preview document commits as one undoable step', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      expect(store.applyCode(edited), isTrue);
      expect(store.previewDoc!.elements, hasLength(2));
      expect(store.performUndo(), isTrue);
      expect(store.previewDoc!.elements, hasLength(1));
    });

    test('malformed JSON keeps the document and reports the error', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      expect(store.applyCode('{not json'), isFalse);
      expect(store.codeError, isNotNull);
      expect(store.previewDoc!.elements, hasLength(1));
    });
  });

  group('views available per document kind', () {
    test(
      'a menu keeps the original four and never offers the card surface',
      () {
        final EditorStore store = _store(_FakeStorage());
        expect(store.availableViews, <EditorView>[
          EditorView.visual,
          EditorView.preview,
          EditorView.code,
          EditorView.split,
        ]);
        store.view = EditorView.previewCard;
        expect(store.view, EditorView.visual);
      },
    );

    test('a preview document lands on the card surface', () {
      final EditorStore store = _store(_FakeStorage());
      store.view = EditorView.preview;
      store.importJson('furnace.json', _previewJson);
      expect(store.availableViews, <EditorView>[
        EditorView.previewCard,
        EditorView.code,
      ]);
      expect(store.view, EditorView.previewCard);
    });

    test('the code view survives the switch in both directions', () {
      final EditorStore store = _store(_FakeStorage());
      store.view = EditorView.code;
      store.importJson('furnace.json', _previewJson);
      expect(store.view, EditorView.code);
      store.importJson('shop.json', encodeHuiMenu(createDefaultMenu()));
      expect(store.view, EditorView.code);
    });

    test('going back to a menu leaves the card surface behind', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      expect(store.view, EditorView.previewCard);
      store.importJson('shop.json', encodeHuiMenu(createDefaultMenu()));
      expect(store.view, EditorView.visual);
    });
  });

  group('workspace round-trip across a reload', () {
    test('a preview document persists and reloads as one on the next boot', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore first = _store(storage);
      first.importJson('furnace.json', _previewJson);
      first.flushAutosave();

      final EditorStore second = _store(storage);
      expect(second.docKind, WorkspaceDocKind.containerPreview);
      expect(second.previewDoc?.elements.length, 1);
    });

    test('opening a menu document after a preview one adopts it correctly', () {
      final _FakeStorage storage = _FakeStorage();
      final EditorStore store = _store(storage);
      store.newDocument(name: 'menu-a');
      final String menuDocId = store.workspace.activeId!;
      store.newPreviewDocument(name: 'preview-b');

      expect(store.openDocument(menuDocId), isTrue);
      expect(store.docKind, WorkspaceDocKind.menu);
      expect(store.previewDoc, isNull);
    });
  });

  group('preview element list operations', () {
    test('addPreviewElement appends a default cell and selects it', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.addPreviewElement('label');
      expect(store.previewDoc!.elements, hasLength(2));
      expect(store.previewDoc!.elements[1].type, 'label');
      expect(store.previewSelectedIndex, 1);
      expect(store.canUndo, isTrue);
    });

    test('addPreviewElement falls back to cell for an unknown type', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.addPreviewElement('bogus');
      expect(store.previewDoc!.elements[1].type, 'cell');
    });

    test('addPreviewElement is a no-op while a menu is active', () {
      final EditorStore store = _store(_FakeStorage());
      store.addPreviewElement('cell');
      expect(store.previewDoc, isNull);
      expect(store.canUndo, isFalse);
    });

    test('a freshly added element validates clean', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      for (final String type in previewElementTypes) {
        store.addPreviewElement(type);
      }
      expect(
        store.issues.where((HuiIssue i) => i.severity != HuiSeverity.info),
        isEmpty,
      );
    });

    test('duplicatePreviewElement inserts a copy right after the source', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.duplicatePreviewElement(0);
      expect(store.previewDoc!.elements, hasLength(2));
      expect(
        store.previewDoc!.elements[1].type,
        store.previewDoc!.elements[0].type,
      );
      expect(store.previewSelectedIndex, 1);
    });

    test('duplicatePreviewElement ignores an out-of-range index', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.duplicatePreviewElement(9);
      expect(store.previewDoc!.elements, hasLength(1));
      expect(store.canUndo, isFalse);
    });

    test('reorderPreviewElement moves the selected element and follows it', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.addPreviewElement('label');
      store.addPreviewElement('panel');
      expect(
        store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
        <String>['cell', 'label', 'panel'],
      );

      store.selectPreviewElement(0); // the cell being moved
      store.reorderPreviewElement(0, 2);
      expect(
        store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
        <String>['label', 'panel', 'cell'],
      );
      expect(
        store.previewSelectedIndex,
        2,
      ); // followed the cell to its new slot
    });

    test(
      'reorderPreviewElement leaves an unrelated selection in place, remapped',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson); // [cell]
        store.addPreviewElement('label'); // [cell, label]
        store.addPreviewElement('panel'); // [cell, label, panel]
        expect(
          store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
          <String>['cell', 'label', 'panel'],
        );

        // panel (index 2) is selected; moving cell (index 0) forward to index 2
        // must NOT steal the selection onto cell - panel just shifts to index 1.
        store.selectPreviewElement(2);
        store.reorderPreviewElement(0, 2);
        expect(
          store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
          <String>['label', 'panel', 'cell'],
        );
        expect(store.previewSelectedIndex, 1);
        expect(store.previewSelectedElement!.type, 'panel');
      },
    );

    test(
      'reorderPreviewElement remaps a selection caught between the endpoints',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson); // [cell]
        store.addPreviewElement('label'); // [cell, label]
        store.addPreviewElement('panel'); // [cell, label, panel]
        store.addPreviewElement('slot'); // [cell, label, panel, slot]

        // Moving panel (index 2) backward to index 0 shifts cell and label
        // (indices 0 and 1, strictly between the endpoints) forward by one.
        store.selectPreviewElement(1); // label
        store.reorderPreviewElement(2, 0);
        expect(
          store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
          <String>['panel', 'cell', 'label', 'slot'],
        );
        expect(store.previewSelectedIndex, 2);
        expect(store.previewSelectedElement!.type, 'label');
      },
    );

    test('reorderPreviewElement with nothing selected selects nothing', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.addPreviewElement('label');
      store.selectPreviewElement(null);
      store.reorderPreviewElement(0, 1);
      expect(store.previewSelectedIndex, isNull);
    });

    test('reorderPreviewElement clamps an out-of-range target', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.addPreviewElement('label');
      store.reorderPreviewElement(1, 99);
      expect(store.previewDoc!.elements.last.type, 'label');
    });

    test(
      'deletePreviewElement removes the element and clears its own selection',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson);
        store.selectPreviewElement(0);
        store.deletePreviewElement(0);
        expect(store.previewDoc!.elements, isEmpty);
        expect(store.previewSelectedIndex, isNull);
        expect(store.canUndo, isTrue);

        expect(store.performUndo(), isTrue);
        expect(store.previewDoc!.elements, hasLength(1));
      },
    );

    test(
      'deletePreviewElement shifts a later selection down instead of drifting',
      () {
        // The exact repro from review: [panel, cell, label], select index 1
        // (cell), delete index 0 (panel). Before the fix this left
        // `previewSelectedIndex` at the stale value 1 - now `label`, not
        // `cell` - and the inspector's `ValueKey<int>(index)` carried its draft
        // state onto the wrong element on top of that.
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson); // [cell]
        store.addPreviewElement('label'); // [cell, label]
        store.addPreviewElement('panel'); // [cell, label, panel]
        store.reorderPreviewElement(2, 0); // -> [panel, cell, label]
        expect(
          store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
          <String>['panel', 'cell', 'label'],
        );

        store.selectPreviewElement(1); // cell
        store.deletePreviewElement(0); // delete panel
        expect(
          store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
          <String>['cell', 'label'],
        );
        expect(store.previewSelectedIndex, 0);
        expect(store.previewSelectedElement!.type, 'cell');
      },
    );

    test('deletePreviewElement leaves an earlier selection untouched', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson); // [cell]
      store.addPreviewElement('label'); // [cell, label]
      store.addPreviewElement('panel'); // [cell, label, panel]

      store.selectPreviewElement(0); // cell
      store.deletePreviewElement(2); // delete panel, after the selection
      expect(
        store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
        <String>['cell', 'label'],
      );
      expect(store.previewSelectedIndex, 0);
      expect(store.previewSelectedElement!.type, 'cell');
    });

    test(
      'deletePreviewElement of the selected element among several clears it',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson); // [cell]
        store.addPreviewElement('label'); // [cell, label]
        store.addPreviewElement('panel'); // [cell, label, panel]

        store.selectPreviewElement(1); // label
        store.deletePreviewElement(1); // delete label itself
        expect(
          store.previewDoc!.elements.map((HuiPreviewElement e) => e.type),
          <String>['cell', 'panel'],
        );
        expect(store.previewSelectedIndex, isNull);
      },
    );

    test('deletePreviewElement ignores an out-of-range index', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.deletePreviewElement(9);
      expect(store.previewDoc!.elements, hasLength(1));
      expect(store.canUndo, isFalse);
    });
  });

  group('issuesForPreviewElement', () {
    test('only returns issues whose path names that element', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.addPreviewElement('panel'); // missing width/height/color
      final List<HuiIssue> issues = store.issuesForPreviewElement(1);
      expect(issues, isEmpty); // the default panel is complete
      store.editPreviewElement(1, 'clear color', (HuiPreviewElement e) {
        e.color = null;
      });
      final List<HuiIssue> afterClear = store.issuesForPreviewElement(1);
      expect(afterClear, hasLength(1));
      expect(afterClear.single.path, 'elements[1].color');
      expect(store.issuesForPreviewElement(0), isEmpty);
    });
  });

  group('previewSim ownership', () {
    test(
      'a sim edit notifies without touching previewRevision or dirtying the document',
      () {
        final EditorStore store = _store(_FakeStorage());
        store.importJson('furnace.json', _previewJson);
        final int revisionBefore = store.previewRevision;
        final bool dirtyBefore = store.hasUnsavedChanges;
        int notifications = 0;
        store.addListener(() => notifications++);

        store.previewSim.tick(20);

        expect(notifications, greaterThan(0));
        expect(store.previewRevision, revisionBefore);
        expect(store.hasUnsavedChanges, dirtyBefore);
      },
    );

    test('the same controller instance persists across a document edit', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      final PreviewSimController controller = store.previewSim;
      store.mutatePreview('touch', (HuiPreviewDoc doc) {});
      expect(identical(store.previewSim, controller), isTrue);
    });

    test('dispose tears down the controller listener without throwing', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJson('furnace.json', _previewJson);
      store.previewSim.setSurge(true);
      expect(store.dispose, returnsNormally);
    });
  });
}
