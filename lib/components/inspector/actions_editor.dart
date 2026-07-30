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
}

/// Reads the list a slot addresses. The returned list is the live one.
List<HuiAction> readActionSlot(HuiComponentData data, ActionSlot slot) {
  if (data is HuiButtonData) return data.actions;
  if (data is HuiToggleData) {
    return slot == ActionSlot.falseActions ? data.falseActions : data.trueActions;
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

  void _add(String type) =>
      _edit('add $type action', (List<HuiAction> list) {
        list.add(createDefaultAction(type));
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
        trailing: dom.span(
          classes: 'hui-count-chip',
          <Widget>[Text('${actions.length}')],
        ),
        children: <Widget>[
          if (actions.isEmpty)
            const HuiNote(
              'No actions yet. A component with an empty action list is still '
              'clickable and still highlights, it just does nothing.',
            )
          else
            for (int i = 0; i < actions.length; i++) _row(i),
          dom.div(
            classes: 'hui-action-add',
            <Widget>[
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
            ],
          ),
          if (actions.length > 1)
            const HuiNote(
              'Actions run top to bottom in this order, on the same click.',
            ),
        ],
      );

  Widget _row(int index) {
    final HuiAction action = actions[index];
    return dom.div(
      classes: 'hui-action-row',
      <Widget>[
        dom.div(
          classes: 'hui-action-row-head',
          <Widget>[
            dom.span(
              classes: 'hui-action-index',
              <Widget>[Text('${index + 1}')],
            ),
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
              onMoveDown:
                  index == actions.length - 1 ? null : () => _move(index, 1),
              onRemove: () => _remove(index),
              removeLabel: 'Remove action ${index + 1}',
            ),
          ],
        ),
        dom.div(
          classes: 'hui-action-row-body',
          <Widget>[
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
                  issues: _issuesFor(index),
                  onChanged: (String label, HuiAction next) =>
                      _replace(index, label, next),
                ),
            },
          ],
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-action-fields',
        <Widget>[
          HuiField(
            label: 'Command',
            required: true,
            help: 'A leading slash is optional, the plugin strips it. Commands '
                'are never placeholder-expanded, so %player_name% stays '
                'literal.',
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
              HuiInlineIssues(issues
                  .where((HuiIssue issue) => issue.path.endsWith('.command'))
                  .toList()),
            ]),
          ),
          HuiField(
            label: 'Run as',
            // Anything that is not exactly "player" behaves as server in game
            // (the plugin compares the enum against PLAYER), so the control
            // shows server for unknown values rather than lying.
            help: action.source == 'player'
                ? 'The player runs it with their own permissions. It fails '
                    'silently for them if they lack the node.'
                : 'Console runs it with full privileges. Use this when the '
                    'player must not need the permission themselves.',
            control: HuiSegmented(
              value: action.source == 'player' ? 'player' : 'server',
              onChanged: (String value) =>
                  onChanged('command source', _with(source: value)),
              segments: const <HuiSegment>[
                HuiSegment(
                  value: 'player',
                  label: 'Player',
                  hint: 'player.performCommand - the player runs it with their own '
                      'permissions.',
                ),
                HuiSegment(
                  value: 'server',
                  label: 'Server console',
                  hint: 'Bukkit.dispatchCommand from console - full '
                      'privileges, no permission check against the player.',
                ),
              ],
            ),
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
  });

  final HuiSoundAction action;
  final HuiCatalogs catalogs;
  final void Function(String label, HuiAction action) onChanged;
  final List<HuiIssue> issues;

  HuiSoundAction _with({
    String? sound,
    String? source,
    double? volume,
    double? pitch,
  }) =>
      HuiSoundAction(
        sound ?? action.sound,
        source ?? action.source,
        volume ?? action.volume,
        pitch ?? action.pitch,
      )..extras = huiDeepCopyMap(action.extras);

  List<HuiIssue> _issuesEndingWith(String suffix) => issues
      .where((HuiIssue issue) => issue.path.endsWith(suffix))
      .toList();

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-action-fields',
        <Widget>[
          HuiField(
            label: 'Sound',
            required: true,
            help: 'Lowercase registry key, played at the clicking player only.',
            control: dom.div(<Widget>[
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
            help: 'Required. A missing category stops the menu from opening, '
                'and the category decides which volume slider the player\'s '
                'client applies.',
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
            help: 'Above 1 does not get louder, it extends the distance the '
                'sound carries. 0 is silent.',
            control: dom.div(<Widget>[
              HuiSliderField(
                value: action.volume,
                min: 0,
                max: 2,
                step: 0.05,
                decimals: 2,
                numberMin: 0,
                onChanged: (double value) =>
                    onChanged('sound volume', _with(volume: value)),
              ),
              HuiInlineIssues(_issuesEndingWith('.volume')),
            ]),
          ),
          HuiField(
            label: 'Pitch',
            help: 'Minecraft clamps pitch to 0.5 - 2.0. 1 is the sound as '
                'recorded.',
            control: dom.div(<Widget>[
              HuiSliderField(
                value: action.pitch,
                min: 0.5,
                max: 2,
                step: 0.05,
                decimals: 2,
                numberMin: 0,
                onChanged: (double value) =>
                    onChanged('sound pitch', _with(pitch: value)),
              ),
              HuiInlineIssues(_issuesEndingWith('.pitch')),
            ]),
          ),
        ],
      );
}
