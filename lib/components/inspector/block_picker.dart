library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/canvas_scene.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';
import 'registry_picker.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class BlockIconEditor extends StatelessWidget {
  const BlockIconEditor({
    required this.icon,
    required this.catalogs,
    required this.onChanged,
    this.issues = const <HuiIssue>[],
    super.key,
  });

  final HuiBlockIcon icon;
  final HuiCatalogs catalogs;
  final void Function(String label, HuiBlockIcon icon) onChanged;
  final List<HuiIssue> issues;

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-icon-block', <Widget>[
    HuiField(
      label: huiText('Block'),
      required: true,
      help: huiText('Lowercase namespaced block material. Items are rejected.'),
      control: dom.div(<Widget>[
        RegistryPicker(
          value: icon.block,
          placeholder: huiText('minecraft:stone'),
          browseLabel: huiText('Browse blocks'),
          searchPlaceholder: huiText('Search block materials'),
          catalogAvailable: catalogs.materials.isNotEmpty,
          textureFor: (String key) => catalogs.textureFor(
            key.startsWith('minecraft:')
                ? key.substring('minecraft:'.length)
                : key,
          ),
          search: (String query, int limit) => catalogs
              .searchMaterials(query, limit: catalogs.materials.length)
              .where((MaterialEntry entry) => huiIsBlockLikeMaterial(entry.key))
              .take(limit)
              .map(
                (MaterialEntry entry) => RegistryOption(
                  entry.key.contains(':')
                      ? entry.key
                      : 'minecraft:${entry.key}',
                  entry.texture,
                ),
              )
              .toList(),
          onChanged: (String value) => onChanged(
            'block material',
            HuiBlockIcon(value, icon.style?.copy())
              ..extras = huiDeepCopyMap(icon.extras),
          ),
        ),
        HuiInlineIssues(
          issues
              .where((HuiIssue issue) => issue.path.endsWith('.block'))
              .toList(),
        ),
      ]),
    ),
    HuiNote(
      huiText(
        'The runtime uses the material\'s default block state in a packet-only '
        'block display. Directional state properties are not authored here.',
      ),
    ),
  ]);
}
