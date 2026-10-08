import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../l10n/hui_localizations.dart';
import '../../logic/document_presets.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'inspector_widgets.dart';

class PresetsInspector extends StatelessWidget {
  const PresetsInspector({required this.store, super.key});
  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossDoc? doc = store.glossDoc;
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      if (doc is GlossPresetsDoc) HuiRevisionRow(revision: doc.revision),
      Text(
        huiText(
          'Edit collection defaults and named presets in the catalog. Documents select a named preset with their preset field.',
        ),
      ),
    ]);
  }
}

class PresetsEditor extends StatefulWidget {
  const PresetsEditor({required this.store, super.key});
  final EditorStore store;

  @override
  State<PresetsEditor> createState() => _PresetsEditorState();
}

class _PresetsEditorState extends State<PresetsEditor> {
  String _collection = 'boards';
  String? _selected;
  String _newName = '';
  String? _error;

  void _edit(String label, void Function(GlossPresetsDoc) edit) =>
      component.store.mutateGloss(label, (GlossDoc doc) {
        if (doc is GlossPresetsDoc) {
          edit(doc);
        }
      });

  Map<String, Object?> _object(Object? raw) =>
      raw is Map<String, Object?> ? raw : <String, Object?>{};

  void _add(GlossPresetsDoc doc) {
    final String name = _newName.trim();
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains('..')) {
      setState(
        () => _error = huiText(
          'Enter a name without slashes or consecutive dots.',
        ),
      );
      return;
    }
    if (_object(doc.presets[_collection]).containsKey(name)) {
      setState(
        () => _error = huiText(
          'That preset name already exists in this collection.',
        ),
      );
      return;
    }
    _edit('add preset', (GlossPresetsDoc doc) {
      doc.presets[_collection] = <String, Object?>{
        ..._object(doc.presets[_collection]),
        name: <String, Object?>{'values': <String, Object?>{}},
      };
    });
    setState(() {
      _selected = name;
      _newName = '';
      _error = null;
    });
  }

  void _definition(
    String name,
    String label,
    void Function(Map<String, Object?>) edit,
  ) {
    _edit(label, (GlossPresetsDoc doc) {
      final Map<String, Object?> entries = Map<String, Object?>.of(
        _object(doc.presets[_collection]),
      );
      final Map<String, Object?> definition = Map<String, Object?>.of(
        _object(entries[name]),
      );
      edit(definition);
      entries[name] = definition;
      doc.presets[_collection] = entries;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: component.store,
    builder: (BuildContext context) => _content(),
  );

  Widget _content() {
    final GlossDoc? doc = component.store.glossDoc;
    if (doc is! GlossPresetsDoc) {
      return const dom.div(<Widget>[]);
    }
    final Map<String, Object?> entries = _object(doc.presets[_collection]);
    final String? selected = entries.containsKey(_selected)
        ? _selected
        : entries.keys.firstOrNull;
    final List<String> collections = DocumentPresets.kinds.toList()..sort();
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      InspectorSection(
        title: huiText('Preset catalog'),
        children: <Widget>[
          Text(
            huiText(
              'Defaults apply to every document in a collection. Named presets add shared values; each document can override them. Objects merge recursively and arrays replace completely.',
            ),
          ),
          HuiField(
            label: huiText('Collection'),
            control: ArcaneSelect(
              value: _collection,
              options: <ArcaneSelectOption>[
                for (final String value in collections)
                  ArcaneSelectOption(value: value, label: value),
              ],
              onChanged: (String value) => setState(() {
                _collection = value;
                _selected = null;
                _error = null;
              }),
            ),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Collection defaults'),
        children: <Widget>[
          if (doc.defaults[_collection] != null &&
              doc.defaults[_collection] is! Map)
            Text(
              huiText(
                'This collection must be a JSON object. Repair it in Code view.',
              ),
            )
          else
            ExtrasEditor(
              key: ValueKey<String>('defaults:$_collection'),
              title: huiText('Default values'),
              extensionKeys: false,
              extras: _object(doc.defaults[_collection]),
              onChanged: (String label, Map<String, Object?> values) =>
                  _edit(label, (GlossPresetsDoc doc) {
                    if (values.isEmpty) {
                      doc.defaults.remove(_collection);
                    } else {
                      doc.defaults[_collection] = values;
                    }
                  }),
            ),
        ],
      ),
      InspectorSection(
        title: huiText('Named presets'),
        children: <Widget>[
          if (doc.presets[_collection] != null &&
              doc.presets[_collection] is! Map)
            Text(
              huiText(
                'This collection must be a JSON object. Repair it in Code view.',
              ),
            )
          else ...<Widget>[
            if (entries.isEmpty)
              Text(
                huiText(
                  'No named presets in this collection. Enter a name to create one.',
                ),
              ),
            if (selected != null) ...<Widget>[
              HuiField(
                label: huiText('Preset'),
                control: ArcaneSelect(
                  value: selected,
                  options: <ArcaneSelectOption>[
                    for (final String name in entries.keys)
                      ArcaneSelectOption(value: name, label: name),
                  ],
                  onChanged: (String value) =>
                      setState(() => _selected = value),
                ),
              ),
              ..._preset(selected, entries[selected]),
            ],
            HuiField(
              label: huiText('New preset name'),
              error: _error,
              control: TextInput(
                value: _newName,
                attributes: const <String, String>{
                  'aria-label': 'New preset name',
                },
                onChanged: (String value) => _newName = value,
              ),
            ),
            Button(
              label: huiText('Add preset'),
              variant: ButtonVariant.outline,
              onPressed: () => _add(doc),
            ),
          ],
        ],
      ),
    ]);
  }

  List<Widget> _preset(String name, Object? raw) {
    final Map<String, Object?> definition = _object(raw);
    return <Widget>[
      if (raw is! Map)
        Text(
          huiText('This preset must be a JSON object. Repair it in Code view.'),
        )
      else ...<Widget>[
        HuiField(
          label: huiText('Extends'),
          help: huiText('Optional parent preset name in this collection.'),
          control: TextInput(
            value: definition['extends'] is String
                ? definition['extends'] as String
                : '',
            attributes: const <String, String>{'aria-label': 'Parent preset'},
            onChanged: (String value) => _definition(name, 'preset parent', (
              Map<String, Object?> definition,
            ) {
              if (value.trim().isEmpty) {
                definition.remove('extends');
              } else {
                definition['extends'] = value.trim();
              }
            }),
          ),
        ),
        if (definition['values'] != null && definition['values'] is! Map)
          Text(
            huiText(
              'Preset values must be a JSON object. Repair them in Code view.',
            ),
          )
        else
          ExtrasEditor(
            key: ValueKey<String>('preset:$_collection:$name'),
            title: huiText('Preset values'),
            extensionKeys: false,
            extras: _object(definition['values']),
            onChanged: (String label, Map<String, Object?> values) =>
                _definition(
                  name,
                  label,
                  (Map<String, Object?> definition) =>
                      definition['values'] = values,
                ),
          ),
      ],
      Button(
        label: huiText('Remove preset'),
        variant: ButtonVariant.outline,
        onPressed: () => _edit('remove preset', (GlossPresetsDoc doc) {
          final Map<String, Object?> entries = Map<String, Object?>.of(
            _object(doc.presets[_collection]),
          )..remove(name);
          if (entries.isEmpty) {
            doc.presets.remove(_collection);
          } else {
            doc.presets[_collection] = entries;
          }
        }),
      ),
    ];
  }
}
