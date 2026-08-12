library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../../model/model.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'registry_picker.dart';

class EntityIconEditor extends StatelessWidget {
  const EntityIconEditor({
    required this.icon,
    required this.onChanged,
    this.issues = const <HuiIssue>[],
    super.key,
  });

  final HuiEntityIcon icon;
  final void Function(String label, HuiEntityIcon icon) onChanged;
  final List<HuiIssue> issues;

  List<HuiIssue> _issuesFor(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  HuiEntityIcon _with({String? entity, double? width, double? height}) =>
      HuiEntityIcon(
        entity ?? icon.entity,
        width ?? icon.width,
        height ?? icon.height,
      )..extras = huiDeepCopyMap(icon.extras);

  List<RegistryOption> _search(String query, int limit) {
    final String normalized = query.trim().toLowerCase();
    final List<RegistryOption> results = <RegistryOption>[];
    for (final String entityType in huiSpawnableLivingEntityTypes) {
      if (normalized.isNotEmpty && !entityType.contains(normalized)) continue;
      results.add(RegistryOption(entityType, null, _label(entityType)));
      if (results.length >= limit) break;
    }
    return results;
  }

  String _label(String key) {
    final String path = key.substring(key.indexOf(':') + 1);
    return path
        .split('_')
        .map(
          (String word) => word.isEmpty
              ? word
              : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-icon-entity', <Widget>[
    HuiField(
      label: 'Entity type',
      required: true,
      trailing: const HuiFieldHelp('icon.entity.entity'),
      help: 'Spawnable living registry id. No server entity is created.',
      control: dom.div(<Widget>[
        RegistryPicker(
          value: icon.entity,
          placeholder: 'minecraft:parrot',
          browseLabel: 'Browse entities',
          searchPlaceholder: 'Search living entities',
          showThumbnail: false,
          search: _search,
          onChanged: (String value) =>
              onChanged('entity type', _with(entity: value)),
        ),
        HuiInlineIssues(_issuesFor('.entity')),
      ]),
    ),
    dom.div(
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'grid',
          'grid-template-columns': 'repeat(2, minmax(0, 1fr))',
          'gap': '10px',
        },
      ),
      <Widget>[
        HuiField(
          label: 'Click width',
          trailing: const HuiFieldHelp('icon.entity.width'),
          control: dom.div(<Widget>[
            HuiNumberField(
              value: icon.width,
              min: 0.01,
              max: 64,
              step: 0.05,
              suffix: 'blocks',
              onChanged: (double value) =>
                  onChanged('entity width', _with(width: value)),
            ),
            HuiInlineIssues(_issuesFor('.width')),
          ]),
        ),
        HuiField(
          label: 'Click height',
          trailing: const HuiFieldHelp('icon.entity.height'),
          control: dom.div(<Widget>[
            HuiNumberField(
              value: icon.height,
              min: 0.01,
              max: 64,
              step: 0.05,
              suffix: 'blocks',
              onChanged: (double value) =>
                  onChanged('entity height', _with(height: value)),
            ),
            HuiInlineIssues(_issuesFor('.height')),
          ]),
        ),
      ],
    ),
    const HuiNote(
      'The component anchor is the entity\'s feet. Width and height define '
      'its editor silhouette and automatic click plane, not the client model.',
    ),
  ]);
}
