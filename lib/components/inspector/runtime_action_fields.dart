import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../model/behavior_authoring.dart';
import '../../model/hui_actions.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'actions_editor.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';

const List<String> runtimeAuthoringTypes = <String>[
  'sequence',
  'parallel',
  'repeat',
  'if',
  'switch',
  'chance',
  'delay',
  'cooldown',
  'setState',
  'addState',
  'clearState',
  'emit',
  'stop',
];

Set<String> runtimeManagedKeys(String type) => <String>{
  if (runtimeAuthoringTypes.contains(type) || type == 'call') ...<String>[
    'when',
    'cooldownTicks',
  ],
  ...switch (type) {
    'sequence' => <String>{'steps', 'onSkip', 'skippable', 'once'},
    'parallel' => <String>{'branches'},
    'repeat' => <String>{'times', 'everyTicks', 'while', 'steps'},
    'if' => <String>{'then', 'else'},
    'switch' => <String>{'on', 'cases', 'default'},
    'chance' => <String>{'percent', 'then', 'else'},
    'delay' => <String>{'ticks'},
    'cooldown' => <String>{'key', 'ticks', 'then', 'else'},
    'setState' || 'addState' => <String>{'key', 'value', 'target'},
    'clearState' => <String>{'key', 'target'},
    'emit' => <String>{'name'},
    'call' => <String>{'action'},
    _ => <String>{},
  },
};

class RuntimeActionFields extends StatelessWidget {
  const RuntimeActionFields({
    required this.action,
    required this.store,
    required this.session,
    required this.sessionKey,
    required this.onChanged,
    required this.depth,
    required this.clickContext,
    super.key,
  });
  final HuiRuntimeAction action;
  final EditorStore store;
  final InspectorSession session;
  final String sessionKey;
  final void Function(HuiRuntimeAction next) onChanged;
  final int depth;
  final bool clickContext;

  void _change(String key, Object? value) {
    final HuiRuntimeAction next = action.copy();
    if (value == null) {
      next.extras.remove(key);
    } else {
      next.extras[key] = value;
    }
    onChanged(next);
  }

  Widget _text(String key, String label) => HuiField(
    label: label,
    control: TextInput(
      value: '${action.extras[key] ?? ''}',
      fullWidth: true,
      attributes: <String, String>{'aria-label': '$sessionKey/$key'},
      onChanged: (String value) => _change(key, value.isEmpty ? null : value),
    ),
  );

  Widget _number(String key, String label, {bool decimal = false}) => HuiField(
    label: label,
    control: TextInput(
      value: '${action.extras[key] ?? ''}',
      fullWidth: true,
      attributes: <String, String>{
        'aria-label': '$sessionKey/$key',
        'inputmode': decimal ? 'decimal' : 'numeric',
      },
      onChanged: (String value) {
        final num? parsed = decimal
            ? double.tryParse(value)
            : int.tryParse(value);
        if (parsed?.isFinite == true || value.trim().isEmpty) {
          _change(key, parsed);
        }
      },
    ),
  );

  Widget _actions(
    String key,
    Object? raw,
    void Function(List<Map<String, Object?>> next) update, {
    String? label,
  }) {
    final HuiActionSourceList? source = HuiActionSourceList.read(raw);
    if (source == null || depth >= 32) {
      return HuiNote(
        huiText('Repair actions in Code view to use these controls.'),
      );
    }
    return ActionsEditor(
      store: store,
      catalogs: store.catalogs,
      session: session,
      sessionKey: '$sessionKey/$key',
      slot: ActionSlot.actions,
      actions: source.actions,
      clickContext: clickContext,
      title: label ?? key,
      depth: depth + 1,
      timedSteps: action.type == 'sequence' && key == 'steps',
      onEdit: (String label, void Function(List<HuiAction>) edit) {
        final HuiActionSourceList? current = HuiActionSourceList.read(raw);
        if (current != null) update(current.edit(edit));
      },
    );
  }

  Widget _list(String key) => _actions(
    key,
    action.extras[key],
    (List<Map<String, Object?>> next) => _change(key, next),
  );

  Widget _branches() {
    final Object? raw = action.extras['branches'];
    if (raw != null && raw is! List) {
      return HuiNote(
        huiText('Repair actions in Code view to use these controls.'),
      );
    }
    final List<Object?> branches = raw is List
        ? List<Object?>.of(raw)
        : <Object?>[];
    return dom.div(<Widget>[
      for (final (int index, Object? branch) in branches.indexed) ...<Widget>[
        _actions('branches/$index', branch, (List<Map<String, Object?>> next) {
          final List<Object?> changed = List<Object?>.of(branches);
          changed[index] = next;
          _change('branches', changed);
        }, label: 'branches[$index]'),
        Button(
          label: huiText('Remove branch'),
          variant: ButtonVariant.outline,
          onPressed: () {
            final List<Object?> changed = List<Object?>.of(branches)
              ..removeAt(index);
            _change('branches', changed);
          },
        ),
      ],
      Button(
        label: huiText('Add branch'),
        variant: ButtonVariant.outline,
        onPressed: () =>
            _change('branches', <Object?>[...branches, <Object?>[]]),
      ),
    ]);
  }

  Widget _cases() {
    final Object? raw = action.extras['cases'];
    if (raw != null && raw is! Map<String, Object?>) {
      return HuiNote(
        huiText('Repair actions in Code view to use these controls.'),
      );
    }
    final Map<String, Object?> cases = raw is Map<String, Object?>
        ? raw
        : <String, Object?>{};
    return dom.div(<Widget>[
      for (final MapEntry<String, Object?> entry in cases.entries) ...<Widget>[
        HuiField(
          label: huiText('Case key'),
          control: TextInput(
            value: entry.key,
            attributes: <String, String>{
              'aria-label': '$sessionKey/cases/${entry.key}/key',
            },
            onChanged: (String value) {
              if (value == entry.key || cases.containsKey(value)) return;
              _change('cases', <String, Object?>{
                for (final MapEntry<String, Object?> current in cases.entries)
                  current.key == entry.key ? value : current.key: current.value,
              });
            },
          ),
        ),
        _actions(
          'cases/${entry.key}',
          entry.value,
          (List<Map<String, Object?>> next) =>
              _change('cases', <String, Object?>{...cases, entry.key: next}),
          label: entry.key,
        ),
        Button(
          label: huiText('Remove case'),
          variant: ButtonVariant.outline,
          onPressed: () {
            final Map<String, Object?> changed = Map<String, Object?>.of(cases)
              ..remove(entry.key);
            _change('cases', changed);
          },
        ),
      ],
      Button(
        label: huiText('Add case'),
        variant: ButtonVariant.outline,
        onPressed: () {
          int index = 1;
          while (cases.containsKey('case$index')) {
            index++;
          }
          _change('cases', <String, Object?>{
            ...cases,
            'case$index': <Object?>[],
          });
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!runtimeAuthoringTypes.contains(action.type) && action.type != 'call') {
      return const dom.div(<Widget>[]);
    }
    return dom.div(<Widget>[
      _text('when', huiText('Condition')),
      _number('cooldownTicks', huiText('Cooldown ticks')),
      if (action.type == 'call') _text('action', huiText('Named action')),
      if (<String>{
        'setState',
        'addState',
        'clearState',
        'cooldown',
      }.contains(action.type))
        _text('key', huiText('State key')),
      if (<String>{'setState', 'addState'}.contains(action.type))
        _text('value', huiText('Value')),
      if (<String>{'setState', 'addState', 'clearState'}.contains(action.type))
        ArcaneSelect(
          label: huiText('Target'),
          value: '${action.extras['target'] ?? 'viewer'}',
          options: <ArcaneSelectOption>[
            for (final String role in <String>['viewer', 'subject', 'source'])
              ArcaneSelectOption(value: role, label: role),
          ],
          onChanged: (String value) => _change('target', value),
        ),
      if (action.type == 'emit') _text('name', huiText('Name')),
      if (action.type == 'delay' || action.type == 'cooldown')
        _number('ticks', huiText('Ticks')),
      if (action.type == 'repeat') ...<Widget>[
        _number('times', huiText('Count')),
        _number('everyTicks', huiText('Interval')),
        _text('while', huiText('Condition')),
        _list('steps'),
      ],
      if (action.type == 'sequence') ...<Widget>[
        HuiSwitchRow(
          label: huiText('Skippable'),
          value: action.extras['skippable'] == true,
          onChanged: (bool value) => _change('skippable', value),
        ),
        _text('once', huiText('State key')),
        _list('steps'),
        _list('onSkip'),
      ],
      if (action.type == 'parallel') _branches(),
      if (action.type == 'chance')
        _number('percent', huiText('Percent'), decimal: true),
      if (<String>{
        'if',
        'chance',
        'cooldown',
      }.contains(action.type)) ...<Widget>[_list('then'), _list('else')],
      if (action.type == 'switch') ...<Widget>[
        _text('on', huiText('Expression')),
        _cases(),
        _list('default'),
      ],
    ]);
  }
}
