/// `item` icon editor: material key, stack count and custom model value.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';
import 'registry_picker.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ItemIconEditor extends StatelessWidget {
  const ItemIconEditor({
    required this.icon,
    required this.catalogs,
    required this.onChanged,
    this.issues = const <HuiIssue>[],
    super.key,
  });

  final HuiItemIcon icon;
  final HuiCatalogs catalogs;

  /// Called with a mutation label and the edited copy.
  final void Function(String label, HuiItemIcon icon) onChanged;
  final List<HuiIssue> issues;

  List<HuiIssue> _issuesFor(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-icon-item',
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '12px',
        'min-width': '0',
      },
    ),
    <Widget>[
      HuiField(
        label: huiText('Material'),
        required: true,
        help: huiText(
          'Lowercase registry key. An unknown one blocks the open.',
        ),
        control: dom.div(<Widget>[
          RegistryPicker(
            value: icon.item,
            placeholder: huiText('diamond_sword'),
            browseLabel: huiText('Browse items'),
            searchPlaceholder: huiText('Search 1691 materials'),
            catalogAvailable: catalogs.materials.isNotEmpty,
            textureFor: catalogs.textureFor,
            search: (String query, int limit) => catalogs
                .searchMaterials(query, limit: limit)
                .map(
                  (MaterialEntry entry) =>
                      RegistryOption(entry.key, entry.texture),
                )
                .toList(),
            onChanged: (String value) => onChanged(
              'item material',
              HuiItemIcon(
                value,
                icon.count,
                icon.customModelValue,
                icon.style?.copy(),
              )..extras = huiDeepCopyMap(icon.extras),
            ),
          ),
          HuiInlineIssues(_issuesFor('.item')),
        ]),
      ),
      dom.div(
        classes: 'hui-icon-item-numbers',
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'grid',
            'grid-template-columns': 'repeat(2, minmax(0, 1fr))',
            'gap': '10px',
            'min-width': '0',
          },
        ),
        <Widget>[
          HuiField(
            label: huiText('Count'),
            control: HuiNumberField(
              value: icon.count.toDouble(),
              min: 1,
              max: 99,
              step: 1,
              integer: true,
              onChanged: (double value) => onChanged(
                'item count',
                HuiItemIcon(
                  icon.item,
                  value.round(),
                  icon.customModelValue,
                  icon.style?.copy(),
                )..extras = huiDeepCopyMap(icon.extras),
              ),
            ),
          ),
          HuiField(
            label: huiText('Model value'),
            control: HuiNumberField(
              value: icon.customModelValue.toDouble(),
              min: 0,
              step: 1,
              integer: true,
              onChanged: (double value) => onChanged(
                'item custom model value',
                HuiItemIcon(
                  icon.item,
                  icon.count,
                  value.round(),
                  icon.style?.copy(),
                )..extras = huiDeepCopyMap(icon.extras),
              ),
            ),
          ),
        ],
      ),
      HuiMore(
        summary: huiText('Count, model value and item size'),
        children: <Widget>[
          HuiNote(
            huiText(
              'A count above 1 adds a bold white number under the item and '
              'lifts the item slightly.',
            ),
          ),
          HuiNote(
            huiText(
              'The model value is exported as customModelValue. The old '
              'editor wrote customModelData, which the plugin ignores; '
              'importing such a file moves the value over.',
            ),
          ),
          HuiNote(
            huiText(
              'Items render at roughly 0.75 blocks square and are the only '
              'icon type with a fixed size: uiScale is the only thing that '
              'changes it.',
            ),
          ),
        ],
      ),
    ],
  );
}
