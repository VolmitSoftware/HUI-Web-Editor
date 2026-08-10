/// Ordered action list, shared by the button's `actions` and the toggle's
/// `trueActions` / `falseActions`.
///
/// Only two action types exist in the format. Converting between them parks the
/// outgoing shape in the session cache, so flipping command -> sound -> command
/// gets the command string back.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'action_presets.dart';
import 'extras_editor.dart';
import 'field_help.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'registry_picker.dart';

/// Which action list of a component is being edited.
enum ActionSlot { actions, trueActions, falseActions }

extension ActionSlotNames on ActionSlot {
  String get jsonKey => switch (this) {
    ActionSlot.actions => 'actions',
    ActionSlot.trueActions => 'trueActions',
    ActionSlot.falseActions => 'falseActions',
  };

  String get label => switch (this) {
    ActionSlot.actions => 'Actions',
    ActionSlot.trueActions => 'Actions on switch to TRUE',
    ActionSlot.falseActions => 'Actions on switch to FALSE',
  };

  /// Key into `huiFieldDocs`. A button's `actions` list has no doc of its own —
  /// the traps that need explaining are the toggle's two.
  String? get docKey => switch (this) {
    ActionSlot.actions => null,
    ActionSlot.trueActions => 'toggle.trueActions',
    ActionSlot.falseActions => 'toggle.falseActions',
  };
}

/// Reads the list a slot addresses. The returned list is the live one.
List<HuiAction> readActionSlot(HuiComponentData data, ActionSlot slot) {
  if (data is HuiButtonData) return data.actions;
  if (data is HuiToggleData) {
    return slot == ActionSlot.falseActions
        ? data.falseActions
        : data.trueActions;
  }
  return <HuiAction>[];
}

class ActionsEditor extends StatelessWidget {
  const ActionsEditor({
    required this.store,
    required this.catalogs,
    required this.session,
    required this.componentId,
    required this.slot,
    required this.actions,
    this.catalogsLoading = false,
    this.description,
    this.issues = const <HuiIssue>[],
    super.key,
  });

  final EditorStore store;
  final HuiCatalogs catalogs;
  final InspectorSession session;
  final String componentId;
  final ActionSlot slot;
  final List<HuiAction> actions;

  /// True until `assets/catalog/sounds.json` resolves.
  final bool catalogsLoading;

  /// Sentence under the eyebrow explaining when this list fires.
  final String? description;
  final List<HuiIssue> issues;

  List<HuiIssue> _issuesFor(int index) {
    // Leading dot matters: without it the `actions` marker also matches
    // `trueActions[0]` and `falseActions[0]`.
    final String marker = '.${slot.jsonKey}[$index]';
    return issues
        .where((HuiIssue issue) => issue.path.contains(marker))
        .toList();
  }

  void _edit(String label, void Function(List<HuiAction> list) fn) {
    store.editComponent(componentId, label, (HuiComponent component) {
      fn(readActionSlot(component.data, slot));
    });
  }

  void _add(String type) => _edit('add $type action', (List<HuiAction> list) {
    list.add(createDefaultAction(type));
  });

  void _insert(HuiAction action) =>
      _edit('add ${action.type} action', (List<HuiAction> list) {
        list.add(action);
      });

  void _remove(int index) => _edit('remove action', (List<HuiAction> list) {
    if (index >= 0 && index < list.length) list.removeAt(index);
  });

  void _move(int index, int delta) {
    final int target = index + delta;
    if (target < 0 || target >= actions.length) return;
    _edit('reorder actions', (List<HuiAction> list) {
      if (index < 0 || index >= list.length) return;
      final HuiAction moved = list.removeAt(index);
      list.insert(target.clamp(0, list.length), moved);
    });
  }

  void _replace(int index, String label, HuiAction next) =>
      _edit(label, (List<HuiAction> list) {
        if (index >= 0 && index < list.length) list[index] = next;
      });

  void _convert(int index, String nextType) {
    final HuiAction current = actions[index];
    if (current.type == nextType) return;
    final HuiAction next = session.switchAction(
      InspectorSession.actionSlot(componentId, slot.jsonKey, index),
      current,
      nextType,
    );
    _replace(index, 'action type $nextType', next);
  }

  @override
  Widget build(BuildContext context) => InspectorSection(
    title: slot.label,
    description: description,
    trailing: dom.div(classes: 'hui-field-tools', <Widget>[
      if (slot.docKey != null) HuiFieldHelp(slot.docKey!),
      dom.span(classes: 'hui-count-chip', <Widget>[Text('${actions.length}')]),
    ]),
    children: <Widget>[
      ActionPresetsRow(menuId: store.menuId, onInsert: _insert),
      if (actions.isEmpty)
        HuiEmptyState(
          icon: ArcaneIcon.listX(size: IconSize.md),
          title: 'No actions',
          body:
              'The component still clicks and highlights, it just does '
              'nothing. Start from a preset above or add one below.',
        )
      else
        for (int i = 0; i < actions.length; i++) _row(i),
      dom.div(classes: 'hui-action-add', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.terminal(size: IconSize.sm),
          onPressed: () => _add('command'),
          child: const Text('Add command'),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.volume2(size: IconSize.sm),
          onPressed: () => _add('sound'),
          child: const Text('Add sound'),
        ),
      ]),
      if (actions.length > 1)
        const HuiNote('Run top to bottom, on the same click.'),
      // One disclosure for the whole list rather than one per row: the
      // semantics are the same for every action in it.
      const HuiMore(
        summary: 'Placeholders, permissions and sound categories',
        children: <Widget>[
          HuiNote(
            'Commands are never placeholder-expanded, so %player_name% '
            'stays literal.',
          ),
          HuiNote(
            'Run as the player, a command fails silently when they lack the '
            'permission node. Use the console when the player must not need '
            'the node themselves.',
          ),
          // Category, volume and pitch all have defaults now
          // (`SoundActionData.java:24-25`), so an omitted one costs the
          // author's intent rather than the click.
          HuiNote(
            'A sound with no category plays on master, and an omitted '
            'volume or pitch is 1. The editor writes all three anyway, so '
            'the file never depends on a default that only the plugin '
            'knows.',
            tone: HuiNoteTone.warning,
            title: 'Sound defaults',
          ),
          HuiNote('Sounds are played to the clicking player only.'),
        ],
      ),
    ],
  );

  Widget _row(int index) {
    final HuiAction action = actions[index];
    return dom.div(classes: 'hui-action-row', <Widget>[
      dom.div(classes: 'hui-action-row-head', <Widget>[
        dom.span(classes: 'hui-action-index', <Widget>[Text('${index + 1}')]),
        HuiSegmented(
          value: action.type,
          onChanged: (String type) => _convert(index, type),
          segments: <HuiSegment>[
            HuiSegment(
              value: 'command',
              label: 'Command',
              icon: ArcaneIcon.terminal(size: IconSize.sm),
              hint: 'Runs a console or player command.',
            ),
            HuiSegment(
              value: 'sound',
              label: 'Sound',
              icon: ArcaneIcon.volume2(size: IconSize.sm),
              hint: 'Plays a sound to the clicking player only.',
            ),
          ],
        ),
        HuiRowTools(
          onMoveUp: index == 0 ? null : () => _move(index, -1),
          onMoveDown: index == actions.length - 1
              ? null
              : () => _move(index, 1),
          onRemove: () => _remove(index),
          removeLabel: 'Remove action ${index + 1}',
        ),
      ]),
      dom.div(classes: 'hui-action-row-body', <Widget>[
        switch (action) {
          final HuiCommandAction command => _CommandActionFields(
            action: command,
            issues: _issuesFor(index),
            onChanged: (String label, HuiAction next) =>
                _replace(index, label, next),
          ),
          final HuiSoundAction sound => _SoundActionFields(
            action: sound,
            catalogs: catalogs,
            catalogsLoading: catalogsLoading,
            issues: _issuesFor(index),
            onChanged: (String label, HuiAction next) =>
                _replace(index, label, next),
          ),
        },
        ExtrasEditor(
          title: 'Action',
          extras: action.extras,
          onChanged: (String label, Map<String, dynamic> next) =>
              _edit(label, (List<HuiAction> list) {
                if (index >= 0 && index < list.length) {
                  list[index].extras = next;
                }
              }),
        ),
      ]),
    ]);
  }
}

class _CommandActionFields extends StatelessWidget {
  const _CommandActionFields({
    required this.action,
    required this.onChanged,
    required this.issues,
  });

  final HuiCommandAction action;
  final void Function(String label, HuiAction action) onChanged;
  final List<HuiIssue> issues;

  HuiCommandAction _with({String? command, String? source}) =>
      HuiCommandAction(command ?? action.command, source ?? action.source)
        ..extras = huiDeepCopyMap(action.extras);

  List<HuiIssue> _issuesEndingWith(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-action-fields',
    <Widget>[
      HuiField(
        label: 'Command',
        required: true,
        trailing: const HuiFieldHelp('action.command.command'),
        help: 'The leading slash is optional and never expanded.',
        control: dom.div(<Widget>[
          TextInput(
            value: action.command,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: 'warp shop',
            onInput: (String value) =>
                onChanged('command', _with(command: value)),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          HuiInlineIssues(
            issues
                .where((HuiIssue issue) => issue.path.endsWith('.command'))
                .toList(),
          ),
        ]),
      ),
      HuiField(
        label: 'Run as',
        trailing: const HuiFieldHelp('action.command.source'),
        help: action.source == 'server'
            ? 'Runs from console with full privileges.'
            : huiCommandSources.contains(action.source)
            ? 'Runs with the player\'s own permissions.'
            : 'Unrecognized source; HoloUI uses the player default.',
        control: dom.div(<Widget>[
          HuiSegmented(
            value: action.source,
            onChanged: (String value) =>
                onChanged('command source', _with(source: value)),
            segments: <HuiSegment>[
              const HuiSegment(
                value: 'player',
                label: 'Player',
                hint:
                    'player.performCommand - the player runs it with their own '
                    'permissions.',
              ),
              const HuiSegment(
                value: 'server',
                label: 'Server console',
                hint:
                    'Bukkit.dispatchCommand from console - full '
                    'privileges, no permission check against the player.',
              ),
              if (!huiCommandSources.contains(action.source))
                HuiSegment(
                  value: action.source,
                  label: 'Unknown',
                  hint:
                      'Unrecognized source "${action.source}"; HoloUI uses '
                      'the player default.',
                ),
            ],
          ),
          HuiInlineIssues(_issuesEndingWith('.source')),
        ]),
      ),
    ],
  );
}

class _SoundActionFields extends StatelessWidget {
  const _SoundActionFields({
    required this.action,
    required this.catalogs,
    required this.onChanged,
    required this.issues,
    this.catalogsLoading = false,
  });

  final HuiSoundAction action;
  final HuiCatalogs catalogs;
  final void Function(String label, HuiAction action) onChanged;
  final List<HuiIssue> issues;
  final bool catalogsLoading;

  HuiSoundAction _with({
    String? sound,
    String? source,
    double? volume,
    double? pitch,
  }) => HuiSoundAction(
    sound ?? action.sound,
    source ?? action.source,
    volume ?? action.volume,
    pitch ?? action.pitch,
  )..extras = huiDeepCopyMap(action.extras);

  List<HuiIssue> _issuesEndingWith(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-action-fields', <Widget>[
        HuiField(
          label: 'Sound',
          required: true,
          trailing: const HuiFieldHelp('action.sound.sound'),
          control: dom.div(<Widget>[
            // The browse button only exists once sounds.json lands; without
            // a placeholder it appears under whatever the user is reading.
            if (catalogsLoading) const HuiSkeletonRows(rows: 1),
            RegistryPicker(
              value: action.sound,
              placeholder: 'ui.button.click',
              browseLabel: 'Browse sounds',
              searchPlaceholder: 'Search sounds',
              showThumbnail: false,
              catalogAvailable: catalogs.sounds.isNotEmpty,
              search: (String query, int limit) => catalogs
                  .searchSounds(query, limit: limit)
                  .map(RegistryOption.new)
                  .toList(),
              onChanged: (String value) =>
                  onChanged('sound', _with(sound: value)),
            ),
            HuiInlineIssues(_issuesEndingWith('.sound')),
          ]),
        ),
        HuiField(
          label: 'Category',
          required: true,
          trailing: const HuiFieldHelp('action.sound.source'),
          help: 'Decides which client volume slider applies.',
          control: dom.div(<Widget>[
            ArcaneSelect(
              value: action.source,
              fullWidth: true,
              size: ComponentSize.sm,
              onChange: (String value) =>
                  onChanged('sound category', _with(source: value)),
              options: <ArcaneSelectOption>[
                for (final String source in huiSoundSources)
                  ArcaneSelectOption(label: source, value: source),
                // Keeps an imported but unrecognised category visible instead
                // of silently showing the first entry.
                if (!huiSoundSources.contains(action.source))
                  ArcaneSelectOption(
                    label: '${action.source} (not a known category)',
                    value: action.source,
                  ),
              ],
            ),
            HuiInlineIssues(_issuesEndingWith('.source')),
          ]),
        ),
        HuiField(
          label: 'Volume',
          trailing: const HuiFieldHelp('action.sound.volume'),
          help: 'Above 1 extends the carry distance, not the loudness.',
          control: dom.div(<Widget>[
            HuiSliderField(
              label: 'Volume',
              value: action.volume,
              min: 0,
              max: 2,
              step: 0.05,
              decimals: 2,
              numberMin: 0,
              // Not the format default of 0 — that is silence, and the trap
              // this editor exists to keep people out of.
              resetTo: 1,
              onChanged: (double value) =>
                  onChanged('sound volume', _with(volume: value)),
            ),
            HuiInlineIssues(_issuesEndingWith('.volume')),
          ]),
        ),
        HuiField(
          label: 'Pitch',
          trailing: const HuiFieldHelp('action.sound.pitch'),
          help: 'Clamped by Minecraft to 0.5 - 2.0; 1 is as recorded.',
          control: dom.div(<Widget>[
            HuiSliderField(
              label: 'Pitch',
              value: action.pitch,
              min: 0.5,
              max: 2,
              step: 0.05,
              decimals: 2,
              numberMin: 0,
              // 1 is the sound as recorded; the format default of 0 clamps
              // up to 0.5, the deepest version of it.
              resetTo: 1,
              onChanged: (double value) =>
                  onChanged('sound pitch', _with(pitch: value)),
            ),
            HuiInlineIssues(_issuesEndingWith('.pitch')),
          ]),
        ),
      ]);
}
