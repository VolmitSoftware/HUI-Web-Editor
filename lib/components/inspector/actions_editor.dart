/// Ordered action list, shared by the button's `actions` and the toggle's
/// `trueActions` / `falseActions`.
///
/// Converting between action types parks the
/// outgoing shape in the session cache, so flipping command -> sound -> command
/// gets the command string back.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../doctype/doctype.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../common/common.dart';
import 'action_presets.dart';
import 'extras_editor.dart';
import 'field_help.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'registry_picker.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Which action list of a component is being edited.
enum ActionSlot { actions, trueActions, falseActions }

String _soundSourceLabel(String source) => switch (source) {
  'master' => huiTextKey('sound_category.master', 'Master'),
  'music' => huiTextKey('sound_category.music', 'Music'),
  'record' => huiTextKey('sound_category.record', 'Records'),
  'weather' => huiTextKey('sound_category.weather', 'Weather'),
  'block' => huiTextKey('sound_category.block', 'Blocks'),
  'hostile' => huiTextKey('sound_category.hostile', 'Hostile creatures'),
  'neutral' => huiTextKey('sound_category.neutral', 'Neutral creatures'),
  'player' => huiTextKey('sound_category.player', 'Players'),
  'ambient' => huiTextKey('sound_category.ambient', 'Ambient environment'),
  'voice' => huiTextKey('sound_category.voice', 'Voice'),
  _ => source,
};

String _navigationModeLabel(String mode) => switch (mode) {
  'push' => huiText('Push'),
  'replace' => huiText('Replace'),
  'back' => huiText('Back'),
  'home' => huiText('Home'),
  'close' => huiText('Close'),
  _ => mode,
};

extension ActionSlotNames on ActionSlot {
  String get jsonKey => switch (this) {
    ActionSlot.actions => 'actions',
    ActionSlot.trueActions => 'trueActions',
    ActionSlot.falseActions => 'falseActions',
  };

  String get label => switch (this) {
    ActionSlot.actions => huiText('Actions'),
    ActionSlot.trueActions => huiText('Actions on switch to TRUE'),
    ActionSlot.falseActions => huiText('Actions on switch to FALSE'),
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
      dom.span(classes: 'hui-count-chip', <Widget>[
        Text(huiText("{length}", <String, Object?>{'length': actions.length})),
      ]),
    ]),
    children: <Widget>[
      ActionPresetsRow(menuId: store.menuId, onInsert: _insert),
      if (actions.isEmpty)
        HuiEmptyState(
          icon: ArcaneIcon.listX(size: IconSize.md),
          title: huiText('No actions'),
          body: huiText(
            'The component still clicks and highlights, it just does '
            'nothing. Start from a preset above or add one below.',
          ),
        )
      else
        for (int i = 0; i < actions.length; i++) _row(i),
      dom.div(classes: 'hui-action-add', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.terminal(size: IconSize.sm),
          onPressed: () => _add('command'),
          label: huiText('Add command'),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.volume2(size: IconSize.sm),
          onPressed: () => _add('sound'),
          label: huiText('Add sound'),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.externalLink(size: IconSize.sm),
          onPressed: () => _add('navigate'),
          label: huiText('Add navigation'),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.messageCircle(size: IconSize.sm),
          onPressed: () => _add('message'),
          label: huiText('Add message'),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.locateFixed(size: IconSize.sm),
          onPressed: () => _add('teleport'),
          label: huiText('Add teleport'),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.share2(size: IconSize.sm),
          onPressed: () => _add('connect'),
          label: huiText('Add connect'),
        ),
      ]),
      if (actions.length > 1)
        HuiNote(
          huiText(
            'Matching actions run top to bottom. Navigation stops only the '
            'actions matching that click.',
          ),
        ),
      // One disclosure for the whole list rather than one per row: the
      // semantics are the same for every action in it.
      HuiMore(
        summary: huiText('Placeholders, permissions and sound categories'),
        children: <Widget>[
          HuiNote(
            huiText(
              "%player% and %player_name% become the clicking player's name; all other command tokens stay literal.",
            ),
          ),
          HuiNote(
            huiText(
              'Run as the player, a command fails silently when they lack the '
              'permission node. Use the console when the player must not need '
              'the node themselves.',
            ),
          ),
          // Category, volume and pitch all have defaults now
          // (`SoundActionData.java:24-25`), so an omitted one costs the
          // author's intent rather than the click.
          HuiNote(
            huiText(
              'A sound with no category plays on master, and an omitted '
              'volume or pitch is 1. The editor writes all three anyway, so '
              'the file never depends on a default that only the plugin '
              'knows.',
            ),
            tone: HuiNoteTone.warning,
            title: huiText('Sound defaults'),
          ),
          HuiNote(huiText('Sounds are played to the clicking player only.')),
        ],
      ),
    ],
  );

  Widget _row(int index) {
    final HuiAction action = actions[index];
    return dom.div(classes: 'hui-action-row', <Widget>[
      dom.div(classes: 'hui-action-row-head', <Widget>[
        dom.span(classes: 'hui-action-index', <Widget>[
          Text(huiText("{value}", <String, Object?>{'value': index + 1})),
        ]),
        HuiSegmented(
          value: action.type,
          onChanged: (String type) => _convert(index, type),
          segments: <HuiSegment>[
            HuiSegment(
              value: 'command',
              label: huiText('Command'),
              icon: ArcaneIcon.terminal(size: IconSize.sm),
              hint: huiText('Runs a console or player command.'),
            ),
            HuiSegment(
              value: 'sound',
              label: huiText('Sound'),
              icon: ArcaneIcon.volume2(size: IconSize.sm),
              hint: huiText('Plays a sound to the clicking player only.'),
            ),
            HuiSegment(
              value: 'navigate',
              label: huiText('Navigate'),
              icon: ArcaneIcon.externalLink(size: IconSize.sm),
              hint: huiText('Moves this viewer to another menu page.'),
            ),
            HuiSegment(
              value: 'message',
              label: huiText('Message'),
              icon: ArcaneIcon.messageCircle(size: IconSize.sm),
              hint: huiText('Sends MiniMessage text to the clicking player.'),
            ),
            HuiSegment(
              value: 'teleport',
              label: huiText('Teleport'),
              icon: ArcaneIcon.locateFixed(size: IconSize.sm),
              hint: huiText('Teleports the clicking player to a loaded world.'),
            ),
            HuiSegment(
              value: 'connect',
              label: huiText('Connect'),
              icon: ArcaneIcon.share2(size: IconSize.sm),
              hint: huiText(
                'Moves the clicking player through the server proxy.',
              ),
            ),
          ],
        ),
        HuiRowTools(
          onMoveUp: index == 0 ? null : () => _move(index, -1),
          onMoveDown: index == actions.length - 1
              ? null
              : () => _move(index, 1),
          onRemove: () => _remove(index),
          removeLabel: huiText('Remove action {number}', <String, Object?>{
            'number': index + 1,
          }),
        ),
      ]),
      dom.div(classes: 'hui-action-row-body', <Widget>[
        HuiField(
          label: huiText('Click trigger'),
          help: huiText(
            'Any matches left, right, and both sneak-modified clicks.',
          ),
          control: dom.div(<Widget>[
            ArcaneSelect(
              value: action.trigger,
              fullWidth: true,
              size: ComponentSize.sm,
              onChange: (String value) {
                final HuiAction next = action.copy()..trigger = value;
                _replace(index, 'action click trigger', next);
              },
              options: <ArcaneSelectOption>[
                for (final String trigger in huiActionTriggers)
                  ArcaneSelectOption(
                    label: _triggerLabel(trigger),
                    value: trigger,
                  ),
                if (!huiActionTriggers.contains(action.trigger))
                  ArcaneSelectOption(
                    label: huiText("{trigger} (unknown)", <String, Object?>{
                      'trigger': action.trigger,
                    }),
                    value: action.trigger,
                  ),
              ],
            ),
            HuiInlineIssues(
              _issuesFor(index)
                  .where((HuiIssue issue) => issue.path.endsWith('.trigger'))
                  .toList(),
            ),
          ]),
        ),
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
          final HuiMessageAction message => _MessageActionFields(
            action: message,
            issues: _issuesFor(index),
            onChanged: (String label, HuiAction next) =>
                _replace(index, label, next),
          ),
          final HuiTeleportAction teleport => _TeleportActionFields(
            action: teleport,
            issues: _issuesFor(index),
            onChanged: (String label, HuiAction next) =>
                _replace(index, label, next),
          ),
          final HuiConnectAction connect => _ConnectActionFields(
            action: connect,
            issues: _issuesFor(index),
            onChanged: (String label, HuiAction next) =>
                _replace(index, label, next),
          ),
          final HuiNavigateAction navigation => _NavigateActionFields(
            action: navigation,
            store: store,
            issues: _issuesFor(index),
            onChanged: (String label, HuiAction next) =>
                _replace(index, label, next),
          ),
        },
        ExtrasEditor(
          title: huiText('Action'),
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

  static String _triggerLabel(String trigger) => switch (trigger) {
    'any' => huiText('Any click'),
    'left_click' => huiText('Left click'),
    'right_click' => huiText('Right click'),
    'shift_left_click' => huiText('Sneak + left click'),
    'shift_right_click' => huiText('Sneak + right click'),
    _ => trigger,
  };
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

  HuiCommandAction _with({String? command, String? source}) => HuiCommandAction(
    command ?? action.command,
    source ?? action.source,
    action.trigger,
  )..extras = huiDeepCopyMap(action.extras);

  List<HuiIssue> _issuesEndingWith(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-action-fields', <Widget>[
    HuiField(
      label: huiText('Command'),
      required: true,
      trailing: const HuiFieldHelp('action.command.command'),
      help: huiText(
        "%player% and %player_name% become the clicking player's name; all other command tokens stay literal.",
      ),
      control: dom.div(<Widget>[
        TextInput(
          value: action.command,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: huiText('warp shop'),
          onInput: (String value) =>
              onChanged('command', _with(command: value)),
          attributes: const <String, String>{
            'autocomplete': 'off',
            'spellcheck': 'false',
            'dir': 'ltr',
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
      label: huiText('Run as'),
      trailing: const HuiFieldHelp('action.command.source'),
      help: action.source == 'server'
          ? huiText('Runs from console with full privileges.')
          : huiCommandSources.contains(action.source)
          ? huiText('Runs with the player\'s own permissions.')
          : huiText('Unrecognized source; Gloss uses the player default.'),
      control: dom.div(<Widget>[
        HuiSegmented(
          value: action.source,
          onChanged: (String value) =>
              onChanged('command source', _with(source: value)),
          segments: <HuiSegment>[
            HuiSegment(
              value: 'player',
              label: huiText('Player'),
              hint: huiText(
                'player.performCommand - the player runs it with their own '
                'permissions.',
              ),
            ),
            HuiSegment(
              value: 'server',
              label: huiText('Server console'),
              hint: huiText(
                'Bukkit.dispatchCommand from console - full '
                'privileges, no permission check against the player.',
              ),
            ),
            if (!huiCommandSources.contains(action.source))
              HuiSegment(
                value: action.source,
                label: huiText('Unknown'),
                hint: huiText(
                  "Unrecognized source \"{source}\"; Gloss uses the player default.",
                  <String, Object?>{'source': action.source},
                ),
              ),
          ],
        ),
        HuiInlineIssues(_issuesEndingWith('.source')),
      ]),
    ),
  ]);
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
    action.trigger,
  )..extras = huiDeepCopyMap(action.extras);

  List<HuiIssue> _issuesEndingWith(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-action-fields',
    <Widget>[
      HuiField(
        label: huiText('Sound'),
        required: true,
        trailing: const HuiFieldHelp('action.sound.sound'),
        control: dom.div(<Widget>[
          // The browse button only exists once sounds.json lands; without
          // a placeholder it appears under whatever the user is reading.
          if (catalogsLoading) const HuiSkeletonRows(rows: 1),
          RegistryPicker(
            value: action.sound,
            placeholder: huiText('ui.button.click'),
            browseLabel: huiText('Browse sounds'),
            searchPlaceholder: huiText('Search sounds'),
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
        label: huiText('Category'),
        required: true,
        trailing: const HuiFieldHelp('action.sound.source'),
        help: huiText('Decides which client volume slider applies.'),
        control: dom.div(<Widget>[
          ArcaneSelect(
            value: action.source,
            fullWidth: true,
            size: ComponentSize.sm,
            onChange: (String value) =>
                onChanged('sound category', _with(source: value)),
            options: <ArcaneSelectOption>[
              for (final String source in huiSoundSources)
                ArcaneSelectOption(
                  label: _soundSourceLabel(source),
                  value: source,
                ),
              // Keeps an imported but unrecognised category visible instead
              // of silently showing the first entry.
              if (!huiSoundSources.contains(action.source))
                ArcaneSelectOption(
                  label: huiText(
                    "{source} (not a known category)",
                    <String, Object?>{'source': action.source},
                  ),
                  value: action.source,
                ),
            ],
          ),
          HuiInlineIssues(_issuesEndingWith('.source')),
        ]),
      ),
      HuiField(
        label: huiText('Volume'),
        trailing: const HuiFieldHelp('action.sound.volume'),
        help: huiText('Above 1 extends the carry distance, not the loudness.'),
        control: dom.div(<Widget>[
          HuiSliderField(
            label: huiText('Volume'),
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
        label: huiTextKey('field.pitch.sound', 'Pitch'),
        trailing: const HuiFieldHelp('action.sound.pitch'),
        help: huiText('Clamped by Minecraft to 0.5 - 2.0; 1 is as recorded.'),
        control: dom.div(<Widget>[
          HuiSliderField(
            label: huiTextKey('field.pitch.sound', 'Pitch'),
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
    ],
  );
}

class _MessageActionFields extends StatelessWidget {
  const _MessageActionFields({
    required this.action,
    required this.onChanged,
    required this.issues,
  });

  final HuiMessageAction action;
  final void Function(String label, HuiAction action) onChanged;
  final List<HuiIssue> issues;

  HuiMessageAction _with(String message) =>
      HuiMessageAction(message, action.trigger)
        ..extras = huiDeepCopyMap(action.extras);

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-action-fields', <Widget>[
        HuiField(
          label: huiText('Message'),
          required: true,
          trailing: const HuiFieldHelp('action.message.message'),
          help: huiText('MiniMessage sent only to the clicking player.'),
          control: dom.div(<Widget>[
            TextArea(
              value: action.message,
              rows: 3,
              fullWidth: true,
              resize: TextAreaResize.vertical,
              placeholder: huiText('<gold>Hello %player%</gold>'),
              onInput: (String value) => onChanged('message', _with(value)),
            ),
            HuiInlineIssues(
              issues
                  .where((HuiIssue issue) => issue.path.endsWith('.message'))
                  .toList(),
            ),
          ]),
        ),
      ]);
}

class _TeleportActionFields extends StatelessWidget {
  const _TeleportActionFields({
    required this.action,
    required this.onChanged,
    required this.issues,
  });

  final HuiTeleportAction action;
  final void Function(String label, HuiAction action) onChanged;
  final List<HuiIssue> issues;

  HuiTeleportAction _with({
    String? world,
    double? x,
    double? y,
    double? z,
    double? yaw,
    double? pitch,
  }) => HuiTeleportAction(
    world ?? action.world,
    x ?? action.x,
    y ?? action.y,
    z ?? action.z,
    yaw ?? action.yaw,
    pitch ?? action.pitch,
    action.trigger,
  )..extras = huiDeepCopyMap(action.extras);

  List<HuiIssue> _issuesEndingWith(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-action-fields', <Widget>[
    HuiField(
      label: huiText('World key'),
      required: true,
      trailing: const HuiFieldHelp('action.teleport.world'),
      help: huiText(
        'Exact lowercase namespace:key of an already-loaded world.',
      ),
      control: dom.div(<Widget>[
        TextInput(
          value: action.world,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: huiText('minecraft:overworld'),
          onInput: (String value) =>
              onChanged('teleport world', _with(world: value)),
          attributes: const <String, String>{
            'autocomplete': 'off',
            'spellcheck': 'false',
            'dir': 'ltr',
          },
        ),
        HuiInlineIssues(_issuesEndingWith('.world')),
      ]),
    ),
    _numberField(
      label: huiText('X'),
      value: action.x,
      issueSuffix: '.x',
      onValue: (double value) => _with(x: value),
    ),
    _numberField(
      label: huiText('Y'),
      value: action.y,
      issueSuffix: '.y',
      onValue: (double value) => _with(y: value),
    ),
    _numberField(
      label: huiText('Z'),
      value: action.z,
      issueSuffix: '.z',
      onValue: (double value) => _with(z: value),
    ),
    _numberField(
      label: huiText('Yaw'),
      value: action.yaw,
      issueSuffix: '.yaw',
      suffix: '°',
      onValue: (double value) => _with(yaw: value),
    ),
    _numberField(
      label: huiTextKey('field.pitch.orientation', 'Pitch'),
      value: action.pitch,
      issueSuffix: '.pitch',
      suffix: '°',
      onValue: (double value) => _with(pitch: value),
    ),
    HuiNote(
      huiText(
        'The runtime uses the player entity scheduler and asynchronous teleport; '
        'it never loads a missing world or chunk from an action.',
      ),
    ),
  ]);

  Widget _numberField({
    required String label,
    required double value,
    required String issueSuffix,
    required HuiTeleportAction Function(double value) onValue,
    String? suffix,
  }) => HuiField(
    label: label,
    required: true,
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value,
        step: 1,
        decimals: 3,
        suffix: suffix,
        onChanged: (double next) =>
            onChanged('teleport ${label.toLowerCase()}', onValue(next)),
      ),
      HuiInlineIssues(_issuesEndingWith(issueSuffix)),
    ]),
  );
}

class _ConnectActionFields extends StatelessWidget {
  const _ConnectActionFields({
    required this.action,
    required this.onChanged,
    required this.issues,
  });

  final HuiConnectAction action;
  final void Function(String label, HuiAction action) onChanged;
  final List<HuiIssue> issues;

  HuiConnectAction _with(String server) =>
      HuiConnectAction(server, action.trigger)
        ..extras = huiDeepCopyMap(action.extras);

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-action-fields', <Widget>[
    HuiField(
      label: huiText('Proxy server'),
      required: true,
      trailing: const HuiFieldHelp('action.connect.server'),
      help: huiText('Exact BungeeCord or Velocity configured server name.'),
      control: dom.div(<Widget>[
        TextInput(
          value: action.server,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: huiText('lobby'),
          onInput: (String value) => onChanged('proxy server', _with(value)),
          attributes: const <String, String>{
            'autocomplete': 'off',
            'spellcheck': 'false',
            'dir': 'ltr',
          },
        ),
        HuiInlineIssues(
          issues
              .where((HuiIssue issue) => issue.path.endsWith('.server'))
              .toList(),
        ),
      ]),
    ),
    HuiNote(
      huiText(
        'This sends only the fixed BungeeCord Connect message. It cannot open '
        'a URL or choose an arbitrary plugin-message subchannel.',
      ),
    ),
  ]);
}

class _NavigateActionFields extends StatelessWidget {
  const _NavigateActionFields({
    required this.action,
    required this.store,
    required this.onChanged,
    required this.issues,
  });

  final HuiNavigateAction action;
  final EditorStore store;
  final void Function(String label, HuiAction action) onChanged;
  final List<HuiIssue> issues;

  HuiNavigateAction _with({String? target, String? mode}) => HuiNavigateAction(
    target ?? action.target,
    mode ?? action.mode,
    action.trigger,
  )..extras = huiDeepCopyMap(action.extras);

  List<HuiIssue> _issuesEndingWith(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  List<RegistryOption> _searchMenus(String query, int limit) {
    final String normalized = query.trim().toLowerCase();
    final List<RegistryOption> results = <RegistryOption>[];
    for (final WorkspaceDoc doc in store.workspace.docs) {
      final String? runtimeId = doc.runtimeId;
      if (doc.kind != DocumentTypes.menu.kind || runtimeId == null) continue;
      if (normalized.isNotEmpty &&
          !runtimeId.toLowerCase().contains(normalized) &&
          !doc.title.toLowerCase().contains(normalized)) {
        continue;
      }
      results.add(RegistryOption(runtimeId, null, doc.title));
      if (results.length >= limit) break;
    }
    return results;
  }

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-action-fields', <Widget>[
        HuiField(
          label: huiText('Mode'),
          required: true,
          trailing: const HuiFieldHelp('action.navigation.mode'),
          help: huiText(
            'Push keeps a Back entry; replace swaps without adding one.',
          ),
          defaultValue: huiText('Push'),
          onReset: action.mode == 'push'
              ? null
              : () => onChanged('navigation mode', _with(mode: 'push')),
          control: dom.div(<Widget>[
            ArcaneSelect(
              value: action.mode,
              fullWidth: true,
              size: ComponentSize.sm,
              onChange: (String value) =>
                  onChanged('navigation mode', _with(mode: value)),
              options: <ArcaneSelectOption>[
                for (final String mode in huiNavigationModes)
                  ArcaneSelectOption(
                    label: _navigationModeLabel(mode),
                    value: mode,
                  ),
                if (!huiNavigationModes.contains(action.mode))
                  ArcaneSelectOption(
                    label: huiText("{mode} (unknown)", <String, Object?>{
                      'mode': action.mode,
                    }),
                    value: action.mode,
                  ),
              ],
            ),
            HuiInlineIssues(_issuesEndingWith('.mode')),
          ]),
        ),
        if (action.requiresTarget)
          HuiField(
            label: huiText('Target menu'),
            required: true,
            trailing: const HuiFieldHelp('action.navigation.target'),
            help: huiText(
              'Exact runtime menu id. Folder paths use forward slashes.',
            ),
            control: dom.div(<Widget>[
              RegistryPicker(
                value: action.target,
                placeholder: huiText('shops/confirm'),
                browseLabel: huiText('Choose menu'),
                searchPlaceholder: huiText('Search workspace menus'),
                emptyMessage: huiText('No matching menu in this workspace.'),
                showThumbnail: false,
                lowercase: false,
                catalogAvailable: store.workspace.docs.any(
                  (WorkspaceDoc doc) => doc.kind == DocumentTypes.menu.kind,
                ),
                search: _searchMenus,
                onChanged: (String value) =>
                    onChanged('navigation target', _with(target: value)),
              ),
              HuiInlineIssues(_issuesEndingWith('.target')),
            ]),
          ),
        HuiNote(
          huiText(
            'Navigation is terminal: actions below it in this list do not run.',
          ),
          tone: HuiNoteTone.warning,
        ),
        HuiHelpCluster(<String>[
          'action.navigation',
        ], label: huiText('How the page stack works')),
      ]);
}
