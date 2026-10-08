import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import '../../model/gloss_tab_layout.dart';
import '../../l10n/hui_localizations.dart';
import '../common/common.dart';
import 'gloss_visibility_editor.dart';
import 'inspector_widgets.dart';

class TablistLayoutEditor extends StatelessWidget {
  const TablistLayoutEditor({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final GlossTabLayout? value;
  final void Function(GlossTabLayout) onChanged;
  void _edit(void Function(GlossTabLayout) edit) {
    final GlossTabLayout copy = value?.copy() ?? GlossTabLayout();
    edit(copy);
    onChanged(copy);
  }

  @override
  Widget build(BuildContext context) {
    final GlossTabLayout? layout = value;
    return InspectorSection(
      title: huiText('Layout'),
      children: <Widget>[
        HuiSwitchRow(
          label: huiText('Enable fixed layout'),
          value: layout?.enabled ?? false,
          onChanged: (bool enabled) =>
              _edit((GlossTabLayout copy) => copy.enabled = enabled),
        ),
        if (layout != null) ...<Widget>[
          GlossVisibilityEditor(
            raw: layout.show,
            onChanged: (Object? show) =>
                _edit((GlossTabLayout copy) => copy.show = show),
          ),
          TablistPresentationEditor(
            value: layout,
            prefix: huiText('Base layout'),
            onChanged: (GlossTabPresentation edited) =>
                _edit((GlossTabLayout copy) {
                  copy.entries = edited.entries;
                  copy.slots = edited.slots;
                  copy.sections = edited.sections;
                  copy.skins = edited.skins;
                }),
          ),
          for (int index = 0; index < layout.variants.length; index++)
            InspectorSection(
              title: huiText('Layout variant {index}', <String, Object?>{
                'index': index + 1,
              }),
              sectionKey: 'tab.layout.variant.$index',
              children: <Widget>[
                _text(
                  huiText('Layout variant {index} id', <String, Object?>{
                    'index': index + 1,
                  }),
                  layout.variants[index].id,
                  (String text) => _edit(
                    (GlossTabLayout copy) => copy.variants[index].id = text,
                  ),
                ),
                _integer(
                  huiText('Layout variant {index} priority', <String, Object?>{
                    'index': index + 1,
                  }),
                  layout.variants[index].priority,
                  (int number) => _edit(
                    (GlossTabLayout copy) =>
                        copy.variants[index].priority = number,
                  ),
                ),
                _text(
                  huiText('Layout variant {index} condition', <String, Object?>{
                    'index': index + 1,
                  }),
                  layout.variants[index].when,
                  (String text) => _edit(
                    (GlossTabLayout copy) => copy.variants[index].when = text,
                  ),
                ),
                TablistPresentationEditor(
                  value: layout.variants[index].presentation,
                  prefix: huiText('Layout variant {index}', <String, Object?>{
                    'index': index + 1,
                  }),
                  onChanged: (GlossTabPresentation edited) => _edit(
                    (GlossTabLayout copy) =>
                        copy.variants[index].presentation = edited,
                  ),
                ),
                _button(
                  huiText('Remove layout variant {index}', <String, Object?>{
                    'index': index + 1,
                  }),
                  () => _edit(
                    (GlossTabLayout copy) => copy.variants.removeAt(index),
                  ),
                ),
              ],
            ),
          _button(
            huiText('Add layout variant'),
            () => _edit((GlossTabLayout copy) {
              String id = 'variant';
              int suffix = 1;
              while (copy.variants.any(
                (GlossTabLayoutVariant variant) => variant.id == id,
              )) {
                id = 'variant_${suffix++}';
              }
              copy.variants.add(
                GlossTabLayoutVariant(
                  id: id,
                  presentation: GlossTabPresentation(
                    entries: copy.entries,
                    slots: <GlossTabSlot>[
                      for (final GlossTabSlot slot in copy.slots) slot.copy(),
                    ],
                    sections: <GlossTabSection>[
                      for (final GlossTabSection section in copy.sections)
                        section.copy(),
                    ],
                    skins: <String, GlossTabSkin>{
                      for (final MapEntry<String, GlossTabSkin> skin
                          in copy.skins.entries)
                        skin.key: skin.value.copy(),
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class TablistPresentationEditor extends StatelessWidget {
  const TablistPresentationEditor({
    required this.value,
    required this.prefix,
    required this.onChanged,
    super.key,
  });
  final GlossTabPresentation value;
  final String prefix;
  final void Function(GlossTabPresentation) onChanged;
  void _edit(void Function(GlossTabPresentation) edit) {
    final GlossTabPresentation copy = value.copy();
    edit(copy);
    onChanged(copy);
  }

  void _slot(int index, void Function(GlossTabSlot) edit) =>
      _edit((GlossTabPresentation copy) => edit(copy.slots[index]));
  void _section(int index, void Function(GlossTabSection) edit) =>
      _edit((GlossTabPresentation copy) => edit(copy.sections[index]));
  @override
  Widget build(BuildContext context) => dom.div(<Widget>[
    _integer(
      huiText('{prefix} entries', <String, Object?>{'prefix': prefix}),
      value.entries,
      (int number) =>
          _edit((GlossTabPresentation copy) => copy.entries = number),
    ),
    dom.p(classes: 'hui-field-help-text', <Widget>[
      Text(
        huiText(
          '{columns} columns × {rows} rows; Java 1.21.2 or later.',
          <String, Object?>{'columns': value.columns, 'rows': value.rows},
        ),
      ),
    ]),
    for (int index = 0; index < value.slots.length; index++)
      InspectorSection(
        title: huiText('Fixed cell {index}', <String, Object?>{
          'index': index + 1,
        }),
        sectionKey: '$prefix.slot.$index',
        children: <Widget>[
          _integer(
            huiText('{prefix} cell {index} column', <String, Object?>{
              'prefix': prefix,
              'index': index + 1,
            }),
            value.slots[index].column,
            (int n) => _slot(index, (GlossTabSlot slot) => slot.column = n),
          ),
          _integer(
            huiText('{prefix} cell {index} row', <String, Object?>{
              'prefix': prefix,
              'index': index + 1,
            }),
            value.slots[index].row,
            (int n) => _slot(index, (GlossTabSlot slot) => slot.row = n),
          ),
          _text(
            huiText('{prefix} cell {index} text', <String, Object?>{
              'prefix': prefix,
              'index': index + 1,
            }),
            value.slots[index].text,
            (String text) =>
                _slot(index, (GlossTabSlot slot) => slot.text = text),
          ),
          _text(
            huiText('{prefix} cell {index} skin', <String, Object?>{
              'prefix': prefix,
              'index': index + 1,
            }),
            value.slots[index].skin ?? '',
            (String text) => _slot(
              index,
              (GlossTabSlot slot) => slot.skin = text.isEmpty ? null : text,
            ),
          ),
          _text(
            huiText('{prefix} cell {index} ping', <String, Object?>{
              'prefix': prefix,
              'index': index + 1,
            }),
            value.slots[index].ping?.toString() ?? '',
            (String text) {
              if (text.isEmpty || int.tryParse(text) != null) {
                _slot(
                  index,
                  (GlossTabSlot slot) => slot.ping = int.tryParse(text),
                );
              }
            },
          ),
          HuiSwitchRow(
            label: huiText('{prefix} cell {index} hat', <String, Object?>{
              'prefix': prefix,
              'index': index + 1,
            }),
            value: value.slots[index].hat,
            onChanged: (bool b) =>
                _slot(index, (GlossTabSlot slot) => slot.hat = b),
          ),
          _button(
            huiText('Remove {prefix} cell {index}', <String, Object?>{
              'prefix': prefix,
              'index': index + 1,
            }),
            () => _edit(
              (GlossTabPresentation copy) => copy.slots.removeAt(index),
            ),
          ),
        ],
      ),
    _button(
      huiText('Add {prefix} fixed cell', <String, Object?>{'prefix': prefix}),
      () =>
          _edit((GlossTabPresentation copy) => copy.slots.add(GlossTabSlot())),
    ),
    for (int index = 0; index < value.sections.length; index++) _roster(index),
    _button(
      huiText('Add {prefix} roster section', <String, Object?>{
        'prefix': prefix,
      }),
      () => _edit((GlossTabPresentation copy) {
        String id = 'players';
        int suffix = 1;
        while (copy.sections.any(
          (GlossTabSection section) => section.id == id,
        )) {
          id = 'players_${suffix++}';
        }
        copy.sections.add(
          GlossTabSection(id: id, rows: copy.rows.clamp(1, 20)),
        );
      }),
    ),
    for (final String name in value.skins.keys)
      InspectorSection(
        title: huiText('Skin {name}', <String, Object?>{'name': name}),
        sectionKey: '$prefix.skin.$name',
        children: <Widget>[
          _text(
            huiText('{prefix} skin {name} name', <String, Object?>{
              'prefix': prefix,
              'name': name,
            }),
            name,
            (String next) {
              if (next.isEmpty ||
                  (next != name && value.skins.containsKey(next))) {
                return;
              }
              _edit((GlossTabPresentation copy) {
                final GlossTabSkin skin = copy.skins.remove(name)!;
                copy.skins[next] = skin;
              });
            },
          ),
          _text(
            huiText('{prefix} skin {name} value', <String, Object?>{
              'prefix': prefix,
              'name': name,
            }),
            value.skins[name]!.value,
            (String text) => _edit(
              (GlossTabPresentation copy) => copy.skins[name]!.value = text,
            ),
          ),
          _text(
            huiText('{prefix} skin {name} signature', <String, Object?>{
              'prefix': prefix,
              'name': name,
            }),
            value.skins[name]!.signature ?? '',
            (String text) => _edit(
              (GlossTabPresentation copy) =>
                  copy.skins[name]!.signature = text.isEmpty ? null : text,
            ),
          ),
          _button(
            huiText('Remove {prefix} skin {name}', <String, Object?>{
              'prefix': prefix,
              'name': name,
            }),
            () => _edit((GlossTabPresentation copy) => copy.skins.remove(name)),
          ),
        ],
      ),
    _button(
      huiText('Add {prefix} skin', <String, Object?>{'prefix': prefix}),
      () => _edit((GlossTabPresentation copy) {
        String name = 'skin';
        int suffix = 1;
        while (copy.skins.containsKey(name)) {
          name = 'skin_${suffix++}';
        }
        copy.skins[name] = GlossTabSkin();
      }),
    ),
  ]);

  Widget _roster(int index) {
    final GlossTabSection section = value.sections[index];
    final String label = huiText('{prefix} roster {index}', <String, Object?>{
      'prefix': prefix,
      'index': index + 1,
    });
    return InspectorSection(
      title: huiText('Roster {index}', <String, Object?>{'index': index + 1}),
      sectionKey: '$prefix.roster.$index',
      children: <Widget>[
        _text(
          huiText('{label} id', <String, Object?>{'label': label}),
          section.id,
          (String text) =>
              _section(index, (GlossTabSection row) => row.id = text),
        ),
        _integer(
          huiText('{label} column', <String, Object?>{'label': label}),
          section.column,
          (int n) => _section(index, (GlossTabSection row) => row.column = n),
        ),
        _integer(
          huiText('{label} row', <String, Object?>{'label': label}),
          section.row,
          (int n) => _section(index, (GlossTabSection row) => row.row = n),
        ),
        _integer(
          huiText('{label} columns', <String, Object?>{'label': label}),
          section.columns,
          (int n) => _section(index, (GlossTabSection row) => row.columns = n),
        ),
        _integer(
          huiText('{label} rows', <String, Object?>{'label': label}),
          section.rows,
          (int n) => _section(index, (GlossTabSection row) => row.rows = n),
        ),
        _text(
          huiText('{label} filter', <String, Object?>{'label': label}),
          section.filter,
          (String text) =>
              _section(index, (GlossTabSection row) => row.filter = text),
        ),
        HuiSwitchRow(
          label: huiText('{label} override name format', <String, Object?>{
            'label': label,
          }),
          value: section.format != null,
          onChanged: (bool b) => _section(
            index,
            (GlossTabSection row) => row.format = b ? r'$player' : null,
          ),
        ),
        if (section.format != null)
          _text(
            huiText('{label} name format', <String, Object?>{'label': label}),
            section.format!,
            (String text) =>
                _section(index, (GlossTabSection row) => row.format = text),
          ),
        _choice(
          huiText('{label} overflow', <String, Object?>{'label': label}),
          section.overflow,
          const <String>['hide', 'count'],
          (String text) =>
              _section(index, (GlossTabSection row) => row.overflow = text),
        ),
        _text(
          huiText('{label} overflow format', <String, Object?>{'label': label}),
          section.overflowFormat,
          (String text) => _section(
            index,
            (GlossTabSection row) => row.overflowFormat = text,
          ),
        ),
        _text(
          huiText('{label} skin', <String, Object?>{'label': label}),
          section.skin ?? '',
          (String text) => _section(
            index,
            (GlossTabSection row) => row.skin = text.isEmpty ? null : text,
          ),
        ),
        HuiSwitchRow(
          label: huiText('{label} hat', <String, Object?>{'label': label}),
          value: section.hat,
          onChanged: (bool b) =>
              _section(index, (GlossTabSection row) => row.hat = b),
        ),
        HuiSwitchRow(
          label: huiText('{label} include NPCs', <String, Object?>{
            'label': label,
          }),
          value: section.includeNpcs,
          onChanged: (bool b) =>
              _section(index, (GlossTabSection row) => row.includeNpcs = b),
        ),
        for (int key = 0; key < section.sort.length; key++)
          InspectorSection(
            title: huiText('Sort key {index}', <String, Object?>{
              'index': key + 1,
            }),
            sectionKey: '$label.sort.$key',
            children: <Widget>[
              _text(
                huiText('{label} sort {key} expression', <String, Object?>{
                  'label': label,
                  'key': key + 1,
                }),
                section.sort[key].expression,
                (String text) => _section(
                  index,
                  (GlossTabSection row) => row.sort[key].expression = text,
                ),
              ),
              _choice(
                huiText('{label} sort {key} type', <String, Object?>{
                  'label': label,
                  'key': key + 1,
                }),
                section.sort[key].type,
                const <String>['text', 'number'],
                (String text) => _section(
                  index,
                  (GlossTabSection row) => row.sort[key].type = text,
                ),
              ),
              _choice(
                huiText('{label} sort {key} direction', <String, Object?>{
                  'label': label,
                  'key': key + 1,
                }),
                section.sort[key].direction,
                const <String>['ascending', 'descending'],
                (String text) => _section(
                  index,
                  (GlossTabSection row) => row.sort[key].direction = text,
                ),
              ),
              if (key > 0)
                _button(
                  huiText('Move {label} sort {key} up', <String, Object?>{
                    'label': label,
                    'key': key + 1,
                  }),
                  () => _section(index, (GlossTabSection row) {
                    final GlossTabSortKey moved = row.sort.removeAt(key);
                    row.sort.insert(key - 1, moved);
                  }),
                ),
              _button(
                huiText('Remove {label} sort {key}', <String, Object?>{
                  'label': label,
                  'key': key + 1,
                }),
                () => _section(
                  index,
                  (GlossTabSection row) => row.sort.removeAt(key),
                ),
              ),
            ],
          ),
        if (section.sort.length < 16)
          _button(
            huiText('Add {label} sort key', <String, Object?>{'label': label}),
            () => _section(
              index,
              (GlossTabSection row) =>
                  row.sort = <GlossTabSortKey>[...row.sort, GlossTabSortKey()],
            ),
          ),
        _button(
          huiText('Remove {label}', <String, Object?>{'label': label}),
          () => _edit(
            (GlossTabPresentation copy) => copy.sections.removeAt(index),
          ),
        ),
      ],
    );
  }
}

Widget _text(String label, String value, void Function(String) changed) =>
    HuiField(
      label: huiText(label),
      control: TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        onChanged: changed,
        attributes: <String, String>{
          'aria-label': huiText(label),
          'spellcheck': 'false',
        },
      ),
    );
Widget _integer(String label, int value, void Function(int) changed) =>
    _text(label, '$value', (String text) {
      final int? parsed = int.tryParse(text);
      if (parsed != null) changed(parsed);
    });
Widget _button(String label, void Function() pressed) => Button(
  variant: ButtonVariant.outline,
  size: ButtonSize.sm,
  label: huiText(label),
  onPressed: pressed,
);
Widget _choice(
  String label,
  String value,
  List<String> choices,
  void Function(String) changed,
) => HuiField(
  label: huiText(label),
  control: dom.div(
    attributes: <String, String>{'role': 'group', 'aria-label': huiText(label)},
    <Widget>[
      HuiSegmented(
        value: value,
        segments: <HuiSegment>[
          for (final String choice in choices)
            HuiSegment(value: choice, label: huiText(choice)),
        ],
        onChanged: changed,
      ),
    ],
  ),
);
