library;

import 'dart:convert';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, ListenableBuilder;

import '../../logic/workspace_flow_graph.dart';
import '../../model/runtime_board_definition.dart';
import '../../model/vec3.dart';
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
          title: 'Menu flow map',
          children: <Widget>[
            HuiNote(
              decoded.data.runtimeBoard == null
                  ? 'The flow layout stays in this browser workspace. Menu JSON '
                        'exports are unchanged.'
                  : 'The flow layout stays local. The linked world-board JSON '
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
          title: 'Reading the map',
          nested: true,
          children: <Widget>[
            HuiNote(
              'External means the target exists elsewhere in this workspace '
              'but outside the selected folder scope.',
            ),
            HuiNote(
              'Orphan means no menu in this map links inward. It can still '
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
  RuntimeBoardDefinition? _draft;
  int _generation = 0;
  bool _typedDirty = false;
  String? _error;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _permissionPattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

  @override
  void initState() {
    super.initState();
    _adopt();
  }

  @override
  void didUpdateComponent(_RuntimeBoardEditor oldComponent) {
    super.didUpdateComponent(oldComponent);
    final String source = _encode(component.board.runtimeBoard!);
    if (source != _source && _text == _source && !_typedDirty) {
      _adopt();
    }
  }

  void _adopt() {
    _adoptBoard(component.board.runtimeBoard!);
  }

  void _adoptBoard(Map<String, dynamic> board) {
    _source = _encode(board);
    _text = _source;
    _generation++;
    _typedDirty = false;
    try {
      _draft = RuntimeBoardDefinition.fromJson(board);
      _error = null;
    } on FormatException catch (error) {
      _draft = null;
      _error = 'Typed controls are unavailable: ${error.message}';
    }
  }

  void _changeDraft(RuntimeBoardDefinition next) {
    setState(() {
      _draft = next;
      _typedDirty = true;
      _error = null;
    });
  }

  void _discardTypedChanges() {
    setState(_adopt);
  }

  void _applyTyped() {
    final RuntimeBoardDefinition? draft = _draft;
    if (draft == null) return;
    final String? problem = _typedProblem(draft);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    _applyBoard(draft.toJson());
  }

  void _applyJson() {
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
    _applyBoard(board);
  }

  void _applyBoard(Map<String, dynamic> board) {
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
    try {
      RuntimeBoardDefinition.fromJson(board);
    } on FormatException catch (error) {
      setState(() => _error = error.message.toString());
      return;
    }
    if (!component.store.updateBoard(
      component.board.copyWith(runtimeBoard: board),
    )) {
      setState(() => _error = 'The linked world board could not be saved.');
      return;
    }
    setState(() {
      _adoptBoard(board);
    });
  }

  @override
  Widget build(BuildContext context) => HuiPanel(
    title: 'Linked world board',
    children: <Widget>[
      const HuiNote(
        'These controls edit the board players see in the world. Apply stores '
        'the changes in this workspace; Publish sends them to the server.',
      ),
      if (_error != null) HuiNote(_error!, tone: HuiNoteTone.danger),
      if (_draft != null) ..._typedControls(_draft!),
      _advancedJson(),
    ],
  );

  List<Widget> _typedControls(RuntimeBoardDefinition draft) => <Widget>[
    _identity(draft),
    _placement(draft),
    _follow(draft),
    _visibility(draft),
    if (_typedProblem(draft) case final String problem)
      HuiNote(problem, tone: HuiNoteTone.warning),
    dom.div(classes: 'hui-dialog-actions', <Widget>[
      Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.sm,
        disabled: !_typedDirty || _typedProblem(draft) != null,
        onPressed: _applyTyped,
        icon: ArcaneIcon.check(size: IconSize.sm),
        label: 'Apply board settings',
      ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        disabled: !_typedDirty,
        onPressed: _discardTypedChanges,
        label: 'Discard changes',
      ),
    ]),
  ];

  Widget _identity(RuntimeBoardDefinition draft) {
    final List<WorkspaceDoc> menus =
        component.store.workspace.docs
            .where(
              (WorkspaceDoc doc) =>
                  doc.kind == WorkspaceDocKind.menu && doc.runtimeId != null,
            )
            .toList()
          ..sort(
            (WorkspaceDoc a, WorkspaceDoc b) =>
                a.runtimeId!.compareTo(b.runtimeId!),
          );
    return InspectorSection(
      title: 'Content',
      children: <Widget>[
        HuiField(
          label: 'Root menu',
          required: true,
          help: 'The menu shown when a player first interacts with this board.',
          control: ArcaneSelect(
            value: draft.rootMenuId,
            size: ComponentSize.sm,
            fullWidth: true,
            options: <ArcaneSelectOption>[
              for (final WorkspaceDoc menu in menus)
                ArcaneSelectOption(
                  label: menu.runtimeId!,
                  value: menu.runtimeId!,
                ),
            ],
            onChange: (String value) =>
                _changeDraft(draft.copyWith(rootMenuId: value)),
          ),
        ),
        HuiMore(
          summary: 'Server-owned identity',
          children: <Widget>[
            HuiDetailRow('Board id', draft.id),
            HuiDetailRow('Board UUID', draft.uuid),
            HuiDetailRow('Revision', '${draft.revision}'),
          ],
        ),
      ],
    );
  }

  Widget _placement(RuntimeBoardDefinition draft) {
    final RuntimeBoardTransform transform = draft.transform;
    return InspectorSection(
      title: 'Placement',
      description:
          'Coordinates are world-space blocks; rotation is in degrees.',
      children: <Widget>[
        HuiField(
          label: 'Position',
          required: true,
          control: HuiVec3Field(
            value: Vec3(transform.x, transform.y, transform.z),
            axisHints: const <String>[
              'x: east or west in the board world',
              'y: height in the board world',
              'z: north or south in the board world',
            ],
            onChanged: (Vec3 value) => _changeDraft(
              draft.copyWith(
                transform: transform.copyWith(
                  x: value.x,
                  y: value.y,
                  z: value.z,
                ),
              ),
            ),
          ),
        ),
        HuiField(
          label: 'Rotation',
          required: true,
          help: 'Yaw turns left/right, pitch tilts up/down, and roll banks.',
          control: HuiVec3Field(
            value: Vec3(transform.yaw, transform.pitch, transform.roll),
            labels: const <String>['Yaw', 'Pitch', 'Roll'],
            axisHints: const <String>[
              'yaw: rotation around the vertical axis',
              'pitch: tilt around the side axis',
              'roll: rotation around the forward axis',
            ],
            step: 1,
            decimals: 2,
            onChanged: (Vec3 value) => _changeDraft(
              draft.copyWith(
                transform: transform.copyWith(
                  yaw: value.x,
                  pitch: value.y,
                  roll: value.z,
                ),
              ),
            ),
          ),
        ),
        HuiField(
          label: 'Scale',
          required: true,
          help: '0.05 to 16. A value of 1 uses the menu at its authored size.',
          control: HuiNumberField(
            value: transform.scale,
            min: 0.05,
            max: 16,
            step: 0.05,
            decimals: 3,
            onChanged: (double value) => _changeDraft(
              draft.copyWith(transform: transform.copyWith(scale: value)),
            ),
          ),
        ),
        HuiMore(
          summary: 'World binding',
          children: <Widget>[
            HuiDetailRow('World', transform.worldKey),
            HuiDetailRow('World UUID', transform.worldUuid),
            const HuiNote(
              'The server owns the world binding. Use the in-game board move '
              'commands to move this board to another world.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _follow(RuntimeBoardDefinition draft) {
    final RuntimeBoardFollow follow = draft.follow;
    final String? targetProblem = follow.mode == RuntimeBoardFollowMode.player
        ? _uuidProblem(follow.targetPlayerUuid)
        : null;
    return InspectorSection(
      title: 'Follow',
      description:
          'Attach the board to one player or leave it fixed in the world.',
      children: <Widget>[
        HuiField(
          label: 'Follow mode',
          control: ArcaneSelect(
            value: follow.mode.name,
            size: ComponentSize.sm,
            fullWidth: true,
            options: const <ArcaneSelectOption>[
              ArcaneSelectOption(label: 'Fixed in world', value: 'none'),
              ArcaneSelectOption(label: 'Follow a player', value: 'player'),
            ],
            onChange: (String value) => _setFollowMode(draft, value),
          ),
        ),
        if (follow.mode == RuntimeBoardFollowMode.player) ...<Widget>[
          HuiField(
            label: 'Player UUID',
            required: true,
            error: targetProblem,
            help:
                'Names are not accepted because the board stores a stable UUID.',
            control: TextInput(
              value: follow.targetPlayerUuid ?? '',
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: '00000000-0000-4000-8000-000000000000',
              onInput: (String value) => _changeDraft(
                draft.copyWith(
                  follow: RuntimeBoardFollow(
                    mode: RuntimeBoardFollowMode.player,
                    targetPlayerUuid: _optionalText(value),
                    rotation: follow.rotation,
                  ),
                ),
              ),
              attributes: const <String, String>{
                'autocomplete': 'off',
                'spellcheck': 'false',
                'autocapitalize': 'off',
              },
            ),
          ),
          HuiField(
            label: 'Rotation behavior',
            help: 'Yaw follows horizontal turning; Full also follows pitch.',
            control: ArcaneSelect(
              value: follow.rotation.name,
              size: ComponentSize.sm,
              fullWidth: true,
              options: const <ArcaneSelectOption>[
                ArcaneSelectOption(
                  label: 'Keep fixed orientation',
                  value: 'fixed',
                ),
                ArcaneSelectOption(label: 'Follow yaw', value: 'yaw'),
                ArcaneSelectOption(
                  label: 'Follow yaw and pitch',
                  value: 'full',
                ),
              ],
              onChange: (String value) => _setFollowRotation(draft, value),
            ),
          ),
        ],
      ],
    );
  }

  Widget _visibility(RuntimeBoardDefinition draft) {
    final RuntimeBoardVisibility visibility = draft.visibility;
    final String? viewPermissionProblem =
        visibility.mode == RuntimeBoardVisibilityMode.permission
        ? _permissionProblem(visibility.viewPermission, required: true)
        : null;
    final String? interactPermissionProblem = _permissionProblem(
      visibility.interactPermission,
    );
    return InspectorSection(
      title: 'Audience and reach',
      description: 'Choose who can see the board and how close they must be.',
      children: <Widget>[
        HuiField(
          label: 'Audience',
          control: ArcaneSelect(
            value: visibility.mode.name,
            size: ComponentSize.sm,
            fullWidth: true,
            options: const <ArcaneSelectOption>[
              ArcaneSelectOption(label: 'Public', value: 'public'),
              ArcaneSelectOption(
                label: 'Permission required',
                value: 'permission',
              ),
              ArcaneSelectOption(label: 'Hidden', value: 'hidden'),
            ],
            onChange: (String value) => _setVisibilityMode(draft, value),
          ),
        ),
        if (visibility.mode == RuntimeBoardVisibilityMode.permission)
          HuiField(
            label: 'View permission',
            required: true,
            error: viewPermissionProblem,
            help: 'Only players with this permission can see the board.',
            control: _permissionInput(
              visibility.viewPermission,
              (String? value) => _changeDraft(
                draft.copyWith(
                  visibility: RuntimeBoardVisibility(
                    mode: visibility.mode,
                    viewPermission: value,
                    interactPermission: visibility.interactPermission,
                    viewRange: visibility.viewRange,
                    interactionRange: visibility.interactionRange,
                  ),
                ),
              ),
            ),
          ),
        if (visibility.mode != RuntimeBoardVisibilityMode.hidden)
          HuiField(
            label: 'Interaction permission',
            error: interactPermissionProblem,
            help: 'Optional. Leave empty to let every visible player interact.',
            control: _permissionInput(
              visibility.interactPermission,
              (String? value) => _changeDraft(
                draft.copyWith(
                  visibility: RuntimeBoardVisibility(
                    mode: visibility.mode,
                    viewPermission: visibility.viewPermission,
                    interactPermission: value,
                    viewRange: visibility.viewRange,
                    interactionRange: visibility.interactionRange,
                  ),
                ),
              ),
            ),
          ),
        HuiField(
          label: 'View range',
          help: 'Players farther away stop receiving this board.',
          control: HuiNumberField(
            value: visibility.viewRange,
            min: 0.05,
            max: 256,
            step: 1,
            decimals: 2,
            suffix: 'blocks',
            onChanged: (double value) => _setViewRange(draft, value),
          ),
        ),
        HuiField(
          label: 'Interaction range',
          help: 'Cannot exceed the view range or 32 blocks.',
          control: HuiNumberField(
            value: visibility.interactionRange,
            min: 0.05,
            max: visibility.viewRange < 32 ? visibility.viewRange : 32,
            step: 0.5,
            decimals: 2,
            suffix: 'blocks',
            onChanged: (double value) => _changeDraft(
              draft.copyWith(
                visibility: RuntimeBoardVisibility(
                  mode: visibility.mode,
                  viewPermission: visibility.viewPermission,
                  interactPermission: visibility.interactPermission,
                  viewRange: visibility.viewRange,
                  interactionRange: value,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _advancedJson() => HuiMore(
    summary: 'Advanced: world-board JSON',
    children: <Widget>[
      const HuiNote(
        'Use this only for exact contract edits. Identity, schema and revision '
        'are server-owned, and applying JSON replaces any unapplied controls.',
      ),
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
          'aria-label': 'Advanced world-board JSON',
        },
      ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: _applyJson,
        icon: ArcaneIcon.check(size: IconSize.sm),
        label: 'Apply advanced JSON',
      ),
    ],
  );

  void _setFollowMode(RuntimeBoardDefinition draft, String raw) {
    final RuntimeBoardFollowMode mode = RuntimeBoardFollowMode.values
        .firstWhere(
          (RuntimeBoardFollowMode candidate) => candidate.name == raw,
        );
    _changeDraft(
      draft.copyWith(
        follow: mode == RuntimeBoardFollowMode.none
            ? const RuntimeBoardFollow(
                mode: RuntimeBoardFollowMode.none,
                targetPlayerUuid: null,
                rotation: RuntimeBoardFollowRotation.fixed,
              )
            : RuntimeBoardFollow(
                mode: RuntimeBoardFollowMode.player,
                targetPlayerUuid: draft.follow.targetPlayerUuid,
                rotation:
                    draft.follow.rotation == RuntimeBoardFollowRotation.fixed
                    ? RuntimeBoardFollowRotation.yaw
                    : draft.follow.rotation,
              ),
      ),
    );
  }

  void _setFollowRotation(RuntimeBoardDefinition draft, String raw) {
    final RuntimeBoardFollowRotation rotation = RuntimeBoardFollowRotation
        .values
        .firstWhere(
          (RuntimeBoardFollowRotation candidate) => candidate.name == raw,
        );
    _changeDraft(
      draft.copyWith(
        follow: RuntimeBoardFollow(
          mode: draft.follow.mode,
          targetPlayerUuid: draft.follow.targetPlayerUuid,
          rotation: rotation,
        ),
      ),
    );
  }

  void _setVisibilityMode(RuntimeBoardDefinition draft, String raw) {
    final RuntimeBoardVisibilityMode mode = RuntimeBoardVisibilityMode.values
        .firstWhere(
          (RuntimeBoardVisibilityMode candidate) => candidate.name == raw,
        );
    final RuntimeBoardVisibility current = draft.visibility;
    _changeDraft(
      draft.copyWith(
        visibility: RuntimeBoardVisibility(
          mode: mode,
          viewPermission: mode == RuntimeBoardVisibilityMode.permission
              ? current.viewPermission
              : null,
          interactPermission: mode == RuntimeBoardVisibilityMode.hidden
              ? null
              : current.interactPermission,
          viewRange: current.viewRange,
          interactionRange: current.interactionRange,
        ),
      ),
    );
  }

  void _setViewRange(RuntimeBoardDefinition draft, double value) {
    final RuntimeBoardVisibility current = draft.visibility;
    final double interactionRange = current.interactionRange > value
        ? value
        : current.interactionRange;
    _changeDraft(
      draft.copyWith(
        visibility: RuntimeBoardVisibility(
          mode: current.mode,
          viewPermission: current.viewPermission,
          interactPermission: current.interactPermission,
          viewRange: value,
          interactionRange: interactionRange,
        ),
      ),
    );
  }

  Widget _permissionInput(
    String? value,
    void Function(String? value) onChanged,
  ) => TextInput(
    value: value ?? '',
    size: ComponentSize.sm,
    fullWidth: true,
    placeholder: 'myserver.holoui.board',
    onInput: (String raw) => onChanged(_optionalText(raw)),
    attributes: const <String, String>{
      'autocomplete': 'off',
      'spellcheck': 'false',
      'autocapitalize': 'off',
    },
  );

  String? _typedProblem(RuntimeBoardDefinition draft) {
    if (draft.transform.scale < 0.05 || draft.transform.scale > 16) {
      return 'Scale must be between 0.05 and 16.';
    }
    if (draft.follow.mode == RuntimeBoardFollowMode.player) {
      final String? problem = _uuidProblem(draft.follow.targetPlayerUuid);
      if (problem != null) return problem;
    }
    if (draft.visibility.mode == RuntimeBoardVisibilityMode.permission) {
      final String? problem = _permissionProblem(
        draft.visibility.viewPermission,
        required: true,
      );
      if (problem != null) return problem;
    }
    final String? interactionProblem = _permissionProblem(
      draft.visibility.interactPermission,
    );
    if (interactionProblem != null) return interactionProblem;
    if (draft.visibility.viewRange <= 0 || draft.visibility.viewRange > 256) {
      return 'View range must be greater than 0 and no more than 256 blocks.';
    }
    if (draft.visibility.interactionRange <= 0 ||
        draft.visibility.interactionRange > 32 ||
        draft.visibility.interactionRange > draft.visibility.viewRange) {
      return 'Interaction range must fit inside the view range and be no more than 32 blocks.';
    }
    return null;
  }

  String? _uuidProblem(String? value) {
    if (value == null || value.isEmpty) return 'Enter the player UUID.';
    if (!_uuidPattern.hasMatch(value)) return 'Enter a valid player UUID.';
    return null;
  }

  String? _permissionProblem(String? value, {bool required = false}) {
    if (value == null || value.isEmpty) {
      return required ? 'Enter a view permission.' : null;
    }
    if (!_permissionPattern.hasMatch(value)) {
      return 'Use lowercase letters, digits, dots, underscores, and hyphens.';
    }
    return null;
  }

  String? _optionalText(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _encode(Map<String, dynamic> value) =>
      const JsonEncoder.withIndent('  ').convert(value);
}
