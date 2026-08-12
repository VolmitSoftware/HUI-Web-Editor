library;

import 'dart:convert';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, ListenableBuilder;

import '../../logic/workspace_flow_graph.dart';
import '../../services/editor_sync.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../../state/workspace_board.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class BoardInspector extends StatelessWidget {
  const BoardInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store.workspace,
    builder: (BuildContext context) {
      final WorkspaceBoardDecodeResult? decoded = store.activeBoard;
      if (decoded == null) return const dom.div(<Widget>[]);
      final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
        store.workspace,
        decoded.data,
      );
      final int broken = graph.edges
          .where(
            (WorkspaceFlowEdge edge) =>
                edge.targetKind == WorkspaceFlowTargetKind.dangling ||
                edge.targetKind == WorkspaceFlowTargetKind.ambiguous ||
                edge.targetKind == WorkspaceFlowTargetKind.invalid,
          )
          .length;
      final int external = graph.edges
          .where(
            (WorkspaceFlowEdge edge) =>
                edge.targetKind == WorkspaceFlowTargetKind.external,
          )
          .length;
      return dom.div(classes: 'hui-board-inspector', <Widget>[
        HuiPanel(
          title: 'Flow board',
          children: <Widget>[
            HuiNote(
              decoded.data.runtimeBoard == null
                  ? 'Flow layout stays in the browser workspace. Menu JSON '
                        'exports are unchanged.'
                  : 'Flow layout stays local. The linked world-board JSON '
                        'below is included only when you explicitly publish.',
              tone: HuiNoteTone.info,
            ),
            _row('Menus in scope', graph.documents.length),
            _row('Native routes', graph.edges.length),
            _row('Dangling or ambiguous', broken, danger: broken > 0),
            _row('External targets', external),
            _row('Menus in cycles', graph.cycleDocumentIds.length),
            _row('Menus without inbound links', graph.orphanDocumentIds.length),
            _row('Unreadable menus', graph.invalidDocumentIds.length),
          ],
        ),
        if (decoded.data.runtimeBoard != null)
          _RuntimeBoardEditor(store: store, board: decoded.data),
        const HuiPanel(
          title: 'Reading the board',
          nested: true,
          children: <Widget>[
            HuiNote(
              'External means the target exists elsewhere in this workspace '
              'but outside the selected folder scope.',
            ),
            HuiNote(
              'Orphan means no menu in this board links inward. It can still '
              'be a valid entry menu opened by command or API.',
            ),
          ],
        ),
      ]);
    },
  );

  Widget _row(String label, int value, {bool danger = false}) => dom.div(
    classes: 'hui-board-inspector-row${danger ? ' is-danger' : ''}',
    <Widget>[
      dom.span(<Widget>[Text(label)]),
      dom.strong(<Widget>[Text('$value')]),
    ],
  );
}

class _RuntimeBoardEditor extends StatefulWidget {
  const _RuntimeBoardEditor({required this.store, required this.board});

  final EditorStore store;
  final WorkspaceBoardData board;

  @override
  State<_RuntimeBoardEditor> createState() => _RuntimeBoardEditorState();
}

class _RuntimeBoardEditorState extends State<_RuntimeBoardEditor> {
  late String _text;
  late String _source;
  int _generation = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _adopt();
  }

  @override
  void didUpdateComponent(_RuntimeBoardEditor oldComponent) {
    super.didUpdateComponent(oldComponent);
    final String source = _encode(component.board.runtimeBoard!);
    if (source != _source && _text == _source) {
      _source = source;
      _text = source;
      _generation++;
      _error = null;
    }
  }

  void _adopt() {
    _source = _encode(component.board.runtimeBoard!);
    _text = _source;
  }

  void _apply() {
    final Object? decoded;
    try {
      decoded = jsonDecode(_text);
    } catch (_) {
      setState(() => _error = 'World-board JSON is not valid.');
      return;
    }
    if (decoded is! Map) {
      setState(() => _error = 'World-board JSON must be an object.');
      return;
    }
    final Map<String, dynamic> board = <String, dynamic>{};
    for (final MapEntry<Object?, Object?> entry in decoded.entries) {
      if (entry.key is! String) {
        setState(() => _error = 'World-board keys must be strings.');
        return;
      }
      board[entry.key! as String] = entry.value;
    }
    final Map<String, dynamic> original = component.board.runtimeBoard!;
    for (final String key in <String>[
      'schemaVersion',
      'id',
      'uuid',
      'revision',
    ]) {
      if (board[key] != original[key]) {
        setState(
          () => _error = '$key is owned by the server and cannot change.',
        );
        return;
      }
    }
    final Object? rootMenuId = board['rootMenuId'];
    if (rootMenuId is! String ||
        !component.store.workspace.docs.any(
          (WorkspaceDoc doc) =>
              doc.kind == WorkspaceDocKind.menu && doc.runtimeId == rootMenuId,
        )) {
      setState(() => _error = 'rootMenuId must name a menu in this workspace.');
      return;
    }
    final String? boardProblem = editorSyncBoardDefinitionProblem(
      board,
      component.store.workspace.docs
          .where((WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.menu)
          .map((WorkspaceDoc doc) => doc.runtimeId)
          .whereType<String>(),
    );
    if (boardProblem != null) {
      setState(() => _error = boardProblem);
      return;
    }
    if (!component.store.updateBoard(
      component.board.copyWith(runtimeBoard: board),
    )) {
      setState(() => _error = 'The linked world board could not be saved.');
      return;
    }
    setState(() {
      _source = _encode(board);
      _text = _source;
      _generation++;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => HuiPanel(
    title: 'Linked world board',
    children: <Widget>[
      const HuiNote(
        'Edit placement, follow and visibility here. Identity, schema and '
        'revision are server-owned. Only the runtime board contract fields '
        'are accepted.',
      ),
      if (_error != null) HuiNote(_error!, tone: HuiNoteTone.danger),
      dom.textarea(
        <Widget>[Component.text(_text)],
        key: ValueKey<int>(_generation),
        classes: 'hui-board-runtime-json',
        rows: 18,
        onInput: (String value) => _text = value,
        attributes: const <String, String>{
          'wrap': 'off',
          'spellcheck': 'false',
          'autocapitalize': 'off',
          'autocomplete': 'off',
          'autocorrect': 'off',
        },
      ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: _apply,
        icon: ArcaneIcon.check(size: IconSize.sm),
        label: 'Apply world-board JSON',
      ),
    ],
  );

  static String _encode(Map<String, dynamic> value) =>
      const JsonEncoder.withIndent('  ').convert(value);
}
