import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/state/editor_store.dart';
import 'package:holoui_editor/state/workspace.dart';
import 'package:holoui_editor/state/workspace_board.dart';
import 'package:test/test.dart';

void main() {
  test('menu rename updates navigation and linked world-board references', () {
    final EditorStore store = _store();
    store.setMenuId('shop');
    store.flushAutosave();
    final WorkspaceDoc target = store.workspace.active!;

    store.newDocument(name: 'navigator');
    final String buttonId = store.addComponent('button')!;
    store.editComponent(buttonId, 'add route', (HuiComponent component) {
      (component.data as HuiButtonData).actions.add(
        HuiNavigateAction('shop', 'push'),
      );
    });
    store.flushAutosave();
    final WorkspaceDoc navigator = store.workspace.active!;

    store.newBoardDocument(name: 'World board');
    store.updateBoard(
      store.activeBoard!.data.copyWith(
        runtimeBoard: <String, dynamic>{'rootMenuId': 'shop'},
        syncMenuIds: const <String>['shop'],
      ),
    );
    final WorkspaceDoc board = store.workspace.active!;
    final int revision = store.workspace.saveRevision;

    expect(store.renameDocumentRuntimeId(target.id, 'store'), isTrue);

    expect(store.workspace.byId(target.id)!.runtimeId, 'store');
    final HuiMenu changedNavigator = decodeHuiMenu(
      store.workspace.byId(navigator.id)!.json,
    );
    final HuiButtonData changedButton =
        changedNavigator.components
                .firstWhere(
                  (HuiComponent component) => component.id == buttonId,
                )
                .data
            as HuiButtonData;
    expect((changedButton.actions.single as HuiNavigateAction).target, 'store');
    final WorkspaceBoardData changedBoard = decodeWorkspaceBoard(
      store.workspace.byId(board.id)!.json,
    ).data;
    expect(changedBoard.runtimeBoard!['rootMenuId'], 'store');
    expect(changedBoard.syncMenuIds, const <String>['store']);
    expect(store.workspace.saveRevision, revision + 1);
  });

  test('menu rename refuses a case-insensitive runtime-id collision', () {
    final EditorStore store = _store();
    final WorkspaceDoc first = store.workspace.active!;
    store.newDocument(name: 'Shop');

    expect(store.renameDocumentRuntimeId(first.id, 'shop'), isFalse);
    expect(store.workspace.byId(first.id)!.runtimeId, isNot('shop'));
  });

  test('menu rename refuses to leave unreadable menu references behind', () {
    final EditorStore store = _store();
    final WorkspaceDoc target = store.workspace.active!;
    store.workspace.create(
      title: 'Broken',
      runtimeId: 'broken',
      json: '[]',
      kind: WorkspaceDocKind.menu,
    );

    expect(store.renameDocumentRuntimeId(target.id, 'renamed'), isFalse);
    expect(store.workspace.byId(target.id)!.runtimeId, target.runtimeId);
  });
}

EditorStore _store() {
  final Map<String, String> storage = <String, String>{};
  return EditorStore(
    workspace: Workspace(
      read: (String key) => storage[key],
      write: (String key, String value) {
        storage[key] = value;
        return true;
      },
    ),
    autosaveDelay: const Duration(days: 1),
  );
}
