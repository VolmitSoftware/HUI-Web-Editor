import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../model/hui_actions.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'inspector_widgets.dart';

class DialogActionFields extends StatelessWidget {
  const DialogActionFields({
    required this.action,
    required this.onChanged,
    super.key,
  });

  final HuiRuntimeAction action;
  final void Function(HuiRuntimeAction action) onChanged;

  void _set(String key, Object value) {
    final HuiRuntimeAction next = action.copy();
    next.extras[key] = value;
    onChanged(next);
  }

  List<Map<String, Object?>> _entries(String key) => <Map<String, Object?>>[
    if (action.extras[key] case final List<Object?> entries)
      for (final Object? entry in entries)
        if (entry is Map<String, Object?>) Map<String, Object?>.from(entry),
  ];

  Widget _text(String label, String key, String fallback) => HuiField(
    label: huiText(label),
    control: TextInput(
      value: '${action.extras[key] ?? fallback}',
      attributes: <String, String>{'aria-label': label},
      onChanged: (String value) => _set(key, value),
    ),
  );

  Widget _number(String label, String key, int fallback) => HuiField(
    label: huiText(label),
    control: TextInput(
      value: '${action.extras[key] ?? fallback}',
      attributes: <String, String>{'aria-label': label, 'inputmode': 'numeric'},
      onChanged: (String value) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) _set(key, parsed);
      },
    ),
  );

  Widget _list(
    String label,
    String key,
    Map<String, Object?> Function(int index) create,
  ) {
    final List<Map<String, Object?>> entries = _entries(key);
    return InspectorSection(
      title: huiText(label),
      children: <Widget>[
        for (int index = 0; index < entries.length; index++)
          dom.div(classes: 'hui-action-fields', <Widget>[
            ExtrasEditor(
              title: '$label ${index + 1}',
              extensionKeys: false,
              extras: entries[index],
              onChanged: (String _, Map<String, Object?> values) {
                entries[index] = values;
                _set(key, entries);
              },
            ),
            Button(
              label: huiText('Remove {item}', <String, Object?>{
                'item': '$label ${index + 1}',
              }),
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              onPressed: () {
                entries.removeAt(index);
                _set(key, entries);
              },
            ),
          ]),
        Button(
          label: huiText('Add {item}', <String, Object?>{
            'item': label.toLowerCase(),
          }),
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () =>
              _set(key, <Object?>[...entries, create(entries.length)]),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-action-fields', <Widget>[
    HuiNote(
      huiText(
        'Native Minecraft dialog for Java 1.21.6 or newer. The unsupported action list handles older clients. The browser does not simulate the game screen.',
      ),
    ),
    _text('Dialog title', 'title', ''),
    HuiField(
      label: huiText('Dialog kind'),
      control: ArcaneSelect(
        value: '${action.extras['kind'] ?? 'notice'}',
        options: <ArcaneSelectOption>[
          for (final String kind in <String>[
            'notice',
            'confirmation',
            'multi_action',
          ])
            ArcaneSelectOption(value: kind, label: kind),
        ],
        onChanged: (String value) => _set('kind', value),
      ),
    ),
    _number('Dialog timeout ticks', 'timeoutTicks', 1200),
    if (action.extras['kind'] == 'multi_action')
      _number('Dialog columns', 'columns', 2),
    HuiSwitchRow(
      label: huiText('Close dialog with Escape'),
      value: action.extras['escape'] != false,
      onChanged: (bool value) => _set('escape', value),
    ),
    _list(
      'Body',
      'body',
      (int _) => <String, Object?>{'text': '', 'width': 200},
    ),
    _list(
      'Inputs',
      'inputs',
      (int index) => <String, Object?>{
        'key': 'input${index + 1}',
        'type': 'text',
        'label': 'Input',
        'maxLength': 32,
      },
    ),
    _list(
      'Buttons',
      'buttons',
      (int _) => <String, Object?>{'label': 'Continue', 'actions': <Object?>[]},
    ),
  ]);
}
