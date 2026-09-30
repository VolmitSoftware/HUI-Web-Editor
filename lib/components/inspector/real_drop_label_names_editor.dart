library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/real_drop_labels.dart';
import '../../logic/validation.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// `labels.names`: one row per material, in file order, each holding the
/// `{type}` text that material's stack label renders with.
///
/// A material is fixed once added, so typing never renames one entry into
/// another's key; changing a material is a remove and an add. A new material is
/// trimmed and upper-cased the way the server reads it, and starts on the Title
/// Case name the label already shows.
class RealDropLabelNamesEditor extends StatefulWidget {
  const RealDropLabelNamesEditor({
    required this.names,
    required this.issues,
    required this.onChanged,
    super.key,
  });

  final Map<String, String> names;

  /// Every issue under `labels.names`, already mapped to the selected
  /// presentation.
  final List<HuiIssue> issues;

  final void Function(String label, Map<String, String> next) onChanged;

  @override
  State<RealDropLabelNamesEditor> createState() =>
      _RealDropLabelNamesEditorState();
}

class _RealDropLabelNamesEditorState extends State<RealDropLabelNamesEditor> {
  String _newMaterial = '';
  String Function()? _newMaterialError;

  void _edit(String material, String name) {
    final Map<String, String> next = Map<String, String>.of(component.names);
    next[material] = name;
    component.onChanged('drop label name', next);
  }

  void _remove(String material) {
    final Map<String, String> next = Map<String, String>.of(component.names)
      ..remove(material);
    component.onChanged('remove drop label name', next);
  }

  void _add() {
    final String material = _newMaterial.trim().toUpperCase();
    if (material.isEmpty) {
      setState(() => _newMaterialError = () => huiText('Enter a material.'));
      return;
    }
    if (component.names.keys.any(
      (String key) => key.trim().toUpperCase() == material,
    )) {
      setState(
        () => _newMaterialError = () => huiText(
          '{key} is already here.',
          <String, Object?>{'key': material},
        ),
      );
      return;
    }
    setState(() {
      _newMaterial = '';
      _newMaterialError = null;
    });
    final Map<String, String> next = Map<String, String>.of(component.names);
    next[material] = glossDropMaterialName(material);
    component.onChanged('add drop label name', next);
  }

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-drop-subgroup', <Widget>[
        dom.div(classes: 'hui-drop-subhead', <Widget>[
          Text(huiText('Names')),
          const HuiFieldHelp('realDrops.labels.names'),
        ]),
        HuiInlineIssues(
          component.issues
              .where((HuiIssue issue) => issue.path.endsWith('.names'))
              .toList(),
        ),
        if (component.names.isEmpty)
          dom.p(classes: 'hui-drop-empty', <Widget>[
            Text(
              huiText(
                'No names. Every material shows its own name in Title Case.',
              ),
            ),
          ])
        else
          for (final String material in component.names.keys.toList())
            _row(material),
        _addRow(),
      ]);

  Widget _row(String material) => HuiField(
    label: material,
    trailing: Button(
      variant: ButtonVariant.ghost,
      size: ButtonSize.iconSm,
      onPressed: () => _remove(material),
      attributes: <String, String>{
        'aria-label': huiText('Remove {key}', <String, Object?>{
          'key': material,
        }),
        'title': huiText('Remove {key}', <String, Object?>{'key': material}),
      },
      icon: ArcaneIcon.trash2(size: IconSize.sm),
    ),
    control: dom.div(<Widget>[
      TextInput(
        value: component.names[material] ?? '',
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: '&7Cobble',
        styles: huiTechnicalInputStyles,
        attributes: <String, String>{
          ...huiTechnicalInputAttributes,
          'aria-label': huiText('Name for {key}', <String, Object?>{
            'key': material,
          }),
        },
        onChanged: (String value) => _edit(material, value),
      ),
      HuiInlineIssues(
        component.issues
            .where((HuiIssue issue) => issue.path.endsWith('.names.$material'))
            .toList(),
      ),
    ]),
  );

  Widget _addRow() => HuiField(
    label: huiText('Add material'),
    error: _newMaterialError?.call(),
    control: dom.div(
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'grid',
          'grid-template-columns': 'minmax(0, 1fr) auto',
          'align-items': 'center',
          'gap': '8px',
          'min-width': '0',
        },
      ),
      <Widget>[
        TextInput(
          value: _newMaterial,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: 'COBBLESTONE',
          onChanged: (String value) {
            _newMaterial = value;
            if (_newMaterialError != null) {
              setState(() => _newMaterialError = null);
            }
          },
          styles: huiTechnicalInputStyles,
          attributes: <String, String>{
            ...huiTechnicalInputAttributes,
            'aria-label': huiText('Material'),
          },
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: _add,
          label: huiText('Add'),
        ),
      ],
    ),
  );
}
