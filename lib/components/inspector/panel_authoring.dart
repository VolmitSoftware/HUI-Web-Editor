library;

import 'dart:convert';
import 'package:arcane_jaspr/arcane_jaspr.dart';
import '../../doctype/doctype.dart';
import '../../l10n/hui_localizations.dart';
import '../../model/runtime_panel_definition.dart';
import '../../services/editor_sync.dart';
import '../../services/file_transfer.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../../state/workspace_panel.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class PanelAuthoring extends StatefulWidget {
  const PanelAuthoring({required this.store, super.key});
  final EditorStore store;

  @override
  State<PanelAuthoring> createState() => _PanelAuthoringState();
}

class _PanelAuthoringState extends State<PanelAuthoring> {
  String _id = 'panel';
  String _worldKey = 'minecraft:overworld';
  String _worldUuid = '';
  String? _rootMenu;
  String? _error;

  List<String> get _menus => <String>[
    for (final WorkspaceDoc doc in component.store.workspace.docs)
      if (doc.kind == DocumentTypes.menu.kind && doc.runtimeId != null)
        doc.runtimeId!,
  ];

  @override
  Widget build(BuildContext context) {
    final WorkspacePanelData panel = component.store.activePanel!.data;
    final Map<String, dynamic>? definition = panel.runtimeBoard;
    return HuiPanel(
      title: huiText('World panel'),
      children: <Widget>[
        if (definition != null)
          Button(
            variant: ButtonVariant.outline,
            onPressed: () => downloadText(
              '${panel.runtimeBoardId}.json',
              const JsonEncoder.withIndent('  ').convert(definition),
            ),
            label: huiText('Export world panel'),
          )
        else ...<Widget>[
          _field('Panel id', _id, (String value) => _id = value),
          _field('World key', _worldKey, (String value) => _worldKey = value),
          _field(
            'World UUID',
            _worldUuid,
            (String value) => _worldUuid = value,
          ),
          HuiField(
            label: huiText('Root menu'),
            control: ArcaneSelect(
              value: _rootMenu ?? (_menus.isEmpty ? null : _menus.first),
              options: <ArcaneSelectOption>[
                for (final String id in _menus)
                  ArcaneSelectOption(value: id, label: id),
              ],
              onChanged: (String value) => setState(() => _rootMenu = value),
            ),
          ),
          HuiNote(
            huiText(
              'Use the world key and UUID from the target server. Placement can be edited after creation.',
            ),
          ),
          Button(
            variant: ButtonVariant.outline,
            onPressed: _create,
            label: huiText('Create world panel'),
          ),
          Button(
            variant: ButtonVariant.outline,
            onPressed: _import,
            label: huiText('Import world panel'),
          ),
        ],
        if (_error != null) HuiNote(_error!, tone: HuiNoteTone.danger),
      ],
    );
  }

  Widget _field(String label, String value, void Function(String) changed) =>
      HuiField(
        label: huiText(label),
        control: TextInput(
          value: value,
          onChanged: (String value) => setState(() => changed(value)),
        ),
      );

  void _create() {
    if (_menus.isEmpty) {
      setState(
        () => _error = huiText('Create a menu before creating a world panel.'),
      );
      return;
    }
    _save(
      RuntimePanelDefinition(
        schemaVersion: 1,
        id: _id.trim(),
        uuid: newWorkspaceUuid(),
        revision: 1,
        rootMenuId: _rootMenu ?? _menus.first,
        transform: RuntimePanelTransform(
          worldKey: _worldKey.trim(),
          worldUuid: _worldUuid.trim(),
          x: 0,
          y: 64,
          z: 0,
          yaw: 0,
          pitch: 0,
          roll: 0,
          scale: 1,
        ),
        follow: const RuntimePanelFollow(
          mode: RuntimePanelFollowMode.none,
          targetPlayerUuid: null,
          rotation: RuntimePanelFollowRotation.fixed,
        ),
        visibility: const RuntimePanelVisibility(
          mode: RuntimePanelVisibilityMode.public,
          viewPermission: null,
          interactPermission: null,
          viewRange: 32,
          interactionRange: 5,
        ),
      ).toJson(),
    );
  }

  Future<void> _import() async {
    final (String, String)? file = await pickJsonFile();
    if (file == null || !mounted) return;
    try {
      final Object? raw = jsonDecode(file.$2);
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Expected a world-panel object.');
      }
      _save(RuntimePanelDefinition.fromJson(raw).toJson());
    } on FormatException catch (error) {
      setState(() => _error = huiText(error.message.toString()));
    }
  }

  void _save(Map<String, dynamic> definition) {
    final String? problem = editorSyncPanelDefinitionProblem(
      definition,
      _menus,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    for (final WorkspaceDoc doc in component.store.workspace.docs) {
      if (doc.kind != DocumentTypes.panel.kind ||
          doc.id == component.store.workspace.activeId) {
        continue;
      }
      final WorkspacePanelData other = decodeWorkspacePanel(doc.json).data;
      if (other.runtimeBoardId == definition['id'] ||
          other.runtimeBoard?['uuid'] == definition['uuid']) {
        setState(
          () => _error = huiText(
            'A world panel with this id or UUID already exists.',
          ),
        );
        return;
      }
    }
    component.store.updatePanel(
      component.store.activePanel!.data.copyWith(
        runtimeBoardId: definition['id'] as String,
        runtimeBoard: definition,
      ),
      coalesce: false,
    );
    setState(() => _error = null);
  }
}
