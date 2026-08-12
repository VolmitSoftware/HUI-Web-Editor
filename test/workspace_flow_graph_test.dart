library;

import 'package:holoui_editor/logic/workspace_flow_graph.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/state/editor_store.dart';
import 'package:holoui_editor/state/workspace.dart';
import 'package:holoui_editor/state/workspace_board.dart';
import 'package:test/test.dart';

class _MemoryWorkspace {
  final Map<String, String> values = <String, String>{};
  int _nextId = 1;

  String? read(String key) => values[key];

  bool write(String key, String value) {
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

String _menuJson(List<HuiComponent> components) =>
    encodeHuiMenu(HuiMenu(components: components));

HuiComponent _button(
  String id,
  String mode, {
  String target = '',
  List<HuiAction>? before,
  List<HuiAction>? after,
}) => HuiComponent(
  id,
  Vec3.zero(),
  HuiButtonData(0.05, <HuiAction>[
    ...?before,
    HuiNavigateAction(target, mode),
    ...?after,
  ]),
);

void main() {
  group('board metadata', () {
    test('round-trips scope, mode and stable document positions', () {
      const String folderId = '00000000-0000-4000-8000-000000000001';
      const String documentId = '00000000-0000-4000-8000-000000000002';
      const WorkspaceBoardData board = WorkspaceBoardData(
        view: WorkspaceBoardView.list,
        scopeFolderId: folderId,
        positions: <String, WorkspaceBoardPoint>{
          documentId: WorkspaceBoardPoint(12.5, 44),
        },
      );

      final WorkspaceBoardDecodeResult restored = decodeWorkspaceBoard(
        encodeWorkspaceBoard(board),
      );
      expect(restored.warning, isNull);
      expect(restored.data.view, WorkspaceBoardView.list);
      expect(restored.data.scopeFolderId, folderId);
      expect(restored.data.positions[documentId]?.x, 12.5);
      expect(restored.data.positions[documentId]?.y, 44);
    });

    test('uses safe defaults for malformed or future metadata', () {
      final WorkspaceBoardDecodeResult malformed = decodeWorkspaceBoard('[]');
      expect(malformed.warning, isNotNull);
      expect(malformed.data.view, WorkspaceBoardView.canvas);

      final WorkspaceBoardDecodeResult future = decodeWorkspaceBoard(
        '{"schemaVersion": 99, "view": "list"}',
      );
      expect(future.warning, contains('unsupported'));
      expect(future.data.view, WorkspaceBoardView.canvas);
    });

    test('board lifecycle never changes runtime menu export bytes', () {
      final _MemoryWorkspace memory = _MemoryWorkspace();
      final Workspace workspace = _workspace(memory);
      final EditorStore store = EditorStore(workspace: workspace);
      final String menuDocumentId = workspace.activeId!;
      final String before = store.exportJson();
      final WorkspaceFolder folder = workspace.createFolder(title: 'Flows');

      store.newBoardDocument(
        name: 'Main flow',
        folderId: folder.id,
        scopeFolderId: folder.id,
      );
      expect(store.docKind, WorkspaceDocKind.board);
      expect(store.view, EditorView.board);
      expect(workspace.active?.runtimeId, isNull);
      expect(store.exportJson, throwsStateError);

      final WorkspaceBoardDecodeResult board = store.activeBoard!;
      expect(
        store.updateBoard(board.data.copyWith(view: WorkspaceBoardView.list)),
        isTrue,
      );
      expect(store.activeBoard?.data.view, WorkspaceBoardView.list);

      expect(store.openDocument(menuDocumentId), isTrue);
      expect(store.docKind, WorkspaceDocKind.menu);
      expect(store.exportJson(), before);
      store.dispose();
    });
  });

  group('workspace flow graph', () {
    test('classifies local, external, dangling and native sink targets', () {
      final _MemoryWorkspace memory = _MemoryWorkspace();
      final Workspace workspace = _workspace(memory);
      final WorkspaceFolder flow = workspace.createFolder(title: 'Flow');
      final WorkspaceFolder nested = workspace.createFolder(
        title: 'Nested',
        parentId: flow.id,
      );
      final WorkspaceFolder elsewhere = workspace.createFolder(
        title: 'Elsewhere',
      );
      final WorkspaceDoc start = workspace.create(
        title: 'Start',
        runtimeId: 'start',
        folderId: flow.id,
        json: _menuJson(<HuiComponent>[
          _button('local', 'push', target: 'shop'),
          _button('external', 'replace', target: 'outside'),
          _button('missing', 'push', target: 'missing'),
          _button('back', 'back'),
          _button('home', 'home'),
          _button('close', 'close'),
        ]),
      );
      final WorkspaceDoc shop = workspace.create(
        title: 'Shop',
        runtimeId: 'shop',
        folderId: nested.id,
        json: _menuJson(const <HuiComponent>[]),
      );
      workspace.create(
        title: 'Outside',
        runtimeId: 'outside',
        folderId: elsewhere.id,
        json: _menuJson(const <HuiComponent>[]),
      );

      final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
        workspace,
        WorkspaceBoardData(scopeFolderId: flow.id),
      );
      expect(graph.documents.map((WorkspaceDoc doc) => doc.id), <String>[
        shop.id,
        start.id,
      ]);
      expect(
        graph.edges.map((WorkspaceFlowEdge edge) => edge.targetKind),
        containsAll(<WorkspaceFlowTargetKind>[
          WorkspaceFlowTargetKind.menu,
          WorkspaceFlowTargetKind.external,
          WorkspaceFlowTargetKind.dangling,
          WorkspaceFlowTargetKind.back,
          WorkspaceFlowTargetKind.home,
          WorkspaceFlowTargetKind.close,
        ]),
      );
      expect(
        graph.edges
            .singleWhere(
              (WorkspaceFlowEdge edge) =>
                  edge.targetKind == WorkspaceFlowTargetKind.menu,
            )
            .targetDocumentId,
        shop.id,
      );
      expect(graph.scopeMissing, isFalse);
    });

    test('finds cycles, orphans, invalid documents and ambiguous ids', () {
      final _MemoryWorkspace memory = _MemoryWorkspace();
      final Workspace workspace = _workspace(memory);
      final WorkspaceDoc first = workspace.create(
        title: 'First',
        runtimeId: 'first',
        json: _menuJson(<HuiComponent>[_button('to-b', 'push', target: 'b')]),
      );
      final WorkspaceDoc second = workspace.create(
        title: 'B',
        runtimeId: 'b',
        json: _menuJson(<HuiComponent>[
          _button('to-first', 'push', target: 'first'),
        ]),
      );
      final WorkspaceDoc orphan = workspace.create(
        title: 'Orphan',
        runtimeId: 'orphan',
        json: _menuJson(const <HuiComponent>[]),
      );
      workspace.create(
        title: 'First A',
        runtimeId: 'a',
        json: _menuJson(const <HuiComponent>[]),
      );
      workspace.create(
        title: 'Second A',
        runtimeId: 'a',
        json: _menuJson(<HuiComponent>[_button('to-a', 'push', target: 'a')]),
      );
      workspace.create(
        title: 'Portable C',
        runtimeId: 'C',
        json: _menuJson(const <HuiComponent>[]),
      );
      workspace.create(
        title: 'Portable c',
        runtimeId: 'c',
        json: _menuJson(const <HuiComponent>[]),
      );
      final WorkspaceDoc invalid = workspace.create(
        title: 'Invalid',
        runtimeId: 'invalid',
        json: '[]',
      );

      final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
        workspace,
        const WorkspaceBoardData(),
      );
      expect(
        graph.cycleDocumentIds,
        containsAll(<String>[first.id, second.id]),
      );
      expect(graph.orphanDocumentIds, contains(orphan.id));
      expect(graph.invalidDocumentIds, contains(invalid.id));
      expect(graph.duplicateRuntimeIds, contains('a'));
      expect(graph.duplicateRuntimeIds, containsAll(<String>['C', 'c']));
      expect(
        graph.edges
            .singleWhere((WorkspaceFlowEdge edge) => edge.target == 'a')
            .targetKind,
        WorkspaceFlowTargetKind.ambiguous,
      );
    });

    test('uses the first terminal navigation for each physical trigger', () {
      final _MemoryWorkspace memory = _MemoryWorkspace();
      final Workspace workspace = _workspace(memory);
      workspace.create(
        title: 'Start',
        runtimeId: 'start',
        json: _menuJson(<HuiComponent>[
          _button(
            'button',
            'back',
            before: <HuiAction>[HuiSoundAction()],
            after: <HuiAction>[HuiNavigateAction('', 'close')],
          ),
          HuiComponent(
            'toggle',
            Vec3.zero(),
            HuiToggleData(
              0.05,
              'yes',
              'yes',
              <HuiAction>[HuiNavigateAction('', 'home')],
              <HuiAction>[HuiNavigateAction('', 'close')],
            ),
          ),
        ]),
      );

      final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
        workspace,
        const WorkspaceBoardData(),
      );
      expect(graph.edges, hasLength(3));
      expect(
        graph.edges.map((WorkspaceFlowEdge edge) => edge.targetKind),
        <WorkspaceFlowTargetKind>[
          WorkspaceFlowTargetKind.back,
          WorkspaceFlowTargetKind.home,
          WorkspaceFlowTargetKind.close,
        ],
      );
      expect(graph.edges[1].branch, 'true');
      expect(graph.edges[2].branch, 'false');
      expect(graph.edges[0].triggers, <String>{
        'left_click',
        'right_click',
        'shift_left_click',
        'shift_right_click',
      });
    });

    test('represents different terminal routes from one branch by trigger', () {
      final _MemoryWorkspace memory = _MemoryWorkspace();
      final Workspace workspace = _workspace(memory);
      workspace.create(
        title: 'Start',
        runtimeId: 'start',
        json: _menuJson(<HuiComponent>[
          HuiComponent(
            'multi-route',
            Vec3.zero(),
            HuiButtonData(0.05, <HuiAction>[
              HuiNavigateAction('left', 'push', 'left_click'),
              HuiNavigateAction('right', 'replace', 'right_click'),
              HuiNavigateAction('', 'close', 'any'),
              HuiNavigateAction('', 'home', 'shift_left_click'),
            ]),
          ),
        ]),
      );
      final WorkspaceDoc left = workspace.create(
        title: 'Left',
        runtimeId: 'left',
        json: _menuJson(const <HuiComponent>[]),
      );
      final WorkspaceDoc right = workspace.create(
        title: 'Right',
        runtimeId: 'right',
        json: _menuJson(const <HuiComponent>[]),
      );

      final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
        workspace,
        const WorkspaceBoardData(),
      );
      final List<WorkspaceFlowEdge> routes = graph.edges
          .where((WorkspaceFlowEdge edge) => edge.componentId == 'multi-route')
          .toList(growable: false);
      expect(routes, hasLength(3));
      expect(routes[0].targetDocumentId, left.id);
      expect(routes[0].triggers, <String>{'left_click'});
      expect(routes[1].targetDocumentId, right.id);
      expect(routes[1].triggers, <String>{'right_click'});
      expect(routes[2].targetKind, WorkspaceFlowTargetKind.close);
      expect(routes[2].triggers, <String>{
        'shift_left_click',
        'shift_right_click',
      });
    });

    test('auto arrangement is deterministic and moves targets rightward', () {
      final _MemoryWorkspace memory = _MemoryWorkspace();
      final Workspace workspace = _workspace(memory);
      final WorkspaceDoc start = workspace.create(
        title: 'Start',
        runtimeId: 'start',
        json: _menuJson(<HuiComponent>[
          _button('next', 'push', target: 'finish'),
        ]),
      );
      final WorkspaceDoc finish = workspace.create(
        title: 'Finish',
        runtimeId: 'finish',
        json: _menuJson(const <HuiComponent>[]),
      );
      final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
        workspace,
        const WorkspaceBoardData(),
      );

      final Map<String, WorkspaceBoardPoint> first = arrangeWorkspaceFlowGraph(
        graph,
      );
      final Map<String, WorkspaceBoardPoint> second = arrangeWorkspaceFlowGraph(
        graph,
      );
      expect(first.keys, second.keys);
      expect(first[start.id]?.x, lessThan(first[finish.id]!.x));
      expect(first[start.id]?.y, second[start.id]?.y);
    });

    test('nested runtime ids resolve exactly and remain case-sensitive', () {
      final _MemoryWorkspace memory = _MemoryWorkspace();
      final Workspace workspace = _workspace(memory);
      workspace.create(
        title: 'Start',
        runtimeId: 'flows/start',
        json: _menuJson(<HuiComponent>[
          _button('exact', 'push', target: 'shops/tools/Confirm'),
          _button('wrong-case', 'push', target: 'shops/tools/confirm'),
          _button('whitespace', 'push', target: ' shops/tools/Confirm '),
        ]),
      );
      final WorkspaceDoc target = workspace.create(
        title: 'Confirm',
        runtimeId: 'shops/tools/Confirm',
        json: _menuJson(const <HuiComponent>[]),
      );

      final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
        workspace,
        const WorkspaceBoardData(),
      );
      expect(
        graph.edges
            .singleWhere(
              (WorkspaceFlowEdge edge) => edge.componentId == 'exact',
            )
            .targetDocumentId,
        target.id,
      );
      expect(
        graph.edges
            .singleWhere(
              (WorkspaceFlowEdge edge) => edge.componentId == 'wrong-case',
            )
            .targetKind,
        WorkspaceFlowTargetKind.dangling,
      );
      expect(
        graph.edges
            .singleWhere(
              (WorkspaceFlowEdge edge) => edge.componentId == 'whitespace',
            )
            .targetKind,
        WorkspaceFlowTargetKind.dangling,
      );
    });
  });
}
