/// Bulk delete on [EditorStore].
///
/// The HoloUi format can contain two components with the same id, although the
/// runtime keeps only the first. Editor deletion still has to be index-based:
/// the selection is a set, so it can name a duplicated id only once, and
/// removing every namesake takes rows the user never selected.
library;

import 'package:holoui_editor/config/defaults.dart';
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

EditorStore _store() => EditorStore(
  workspace: Workspace(
    read: _FakeStorage().read,
    write: _FakeStorage().write,
    autoLoad: true,
  ),
  autosaveDelay: Duration.zero,
);

/// Ids as authored, in document order.
List<String> _ids(EditorStore store) =>
    store.components.map((HuiComponent c) => c.id).toList(growable: false);

/// Seeds a document whose ids are exactly [ids], duplicates included.
///
/// `addComponent` uniquifies, so duplicates can only arrive the way they do in
/// life: through a decode of an authored file, which `mutate` stands in for.
EditorStore _seeded(List<String> ids) {
  final EditorStore store = _store();
  store.mutate('seed', (HuiMenu menu) {
    menu.components
      ..clear()
      ..addAll(<HuiComponent>[
        for (final String id in ids)
          HuiComponent(
            id,
            Vec3(0, 0, 0),
            createDefaultComponentData('decoration'),
          ),
      ]);
  });
  return store;
}

void main() {
  group('deleteComponents', () {
    test('removes one row per id, never a namesake', () {
      final EditorStore store = _seeded(<String>['a', 'a', 'b', 'c']);
      store.selectMany(<String>['a', 'b']);

      store.deleteComponents(store.selectionIds.toList(growable: false));

      // The old id-keyed path removed BOTH `a` rows here.
      expect(_ids(store), <String>['a', 'c']);
    });

    test('deletes every selected row when no ids are duplicated', () {
      final EditorStore store = _seeded(<String>['a', 'b', 'c']);
      store.selectMany(<String>['a', 'c']);

      store.deleteComponents(store.selectionIds.toList(growable: false));

      expect(_ids(store), <String>['b']);
    });

    test('a repeated id in the request takes successive rows', () {
      final EditorStore store = _seeded(<String>['a', 'a', 'a', 'b']);

      store.deleteComponents(<String>['a', 'a']);

      expect(_ids(store), <String>['a', 'b']);
    });

    test('is one undo step, and one undo brings every row back', () {
      final EditorStore store = _seeded(<String>['a', 'b', 'c']);
      store.selectMany(<String>['a', 'b', 'c']);

      store.deleteComponents(store.selectionIds.toList(growable: false));
      expect(_ids(store), isEmpty);

      expect(store.performUndo(), isTrue);
      expect(_ids(store), <String>['a', 'b', 'c']);
    });

    test('labels the step by count, not by the first id', () {
      final EditorStore store = _seeded(<String>['deco_a', 'deco_b', 'deco_c']);
      store.selectMany(<String>['deco_a', 'deco_b', 'deco_c']);

      store.deleteComponents(store.selectionIds.toList(growable: false));

      // Was `delete deco_a` after deleting three.
      expect(store.undoLabel, 'delete 3 components');
    });

    test('a single id keeps the naming and behaviour of deleteComponent', () {
      final EditorStore store = _seeded(<String>['a', 'a', 'b']);

      store.deleteComponents(<String>['a']);

      expect(_ids(store), <String>['a', 'b']);
      expect(store.undoLabel, 'delete a');
    });

    test('drops the selection only for ids with no row left', () {
      final EditorStore store = _seeded(<String>['a', 'a', 'b']);
      store.selectMany(<String>['a', 'b']);

      store.deleteComponents(store.selectionIds.toList(growable: false));

      // `a` still names a live row, so it stays addressable; `b` is gone.
      expect(store.selectionIds, <String>{'a'});
    });

    test('an empty request is a no-op with no undo step', () {
      final EditorStore store = _seeded(<String>['a', 'b']);
      final String? labelBefore = store.undoLabel;

      store.deleteComponents(const <String>[]);

      expect(_ids(store), <String>['a', 'b']);
      expect(store.undoLabel, labelBefore);
    });

    test('unknown ids are ignored rather than shifting the wrong row', () {
      final EditorStore store = _seeded(<String>['a', 'b']);

      store.deleteComponents(<String>['nope', 'b']);

      expect(_ids(store), <String>['a']);
    });
  });
}
