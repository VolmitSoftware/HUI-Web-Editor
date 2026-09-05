library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../logic/validation.dart';
import '../../model/gloss_entity_overlays.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class EntityOverlayInspector extends StatelessWidget {
  const EntityOverlayInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossEntityOverlaysDoc? doc = store.entityOverlaysDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-entity-overlays', <Widget>[
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        HuiEyebrow(huiText('Entity overlays')),
        dom.h2(classes: 'hui-inspector-title', <Widget>[Text(store.menuId)]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText(
              'Nearby living entities share one Gloss display for health, names, combat feedback and plugin details.',
            ),
          ),
        ]),
        HuiRevisionRow(revision: doc.revision),
      ]),
      InspectorSection(
        title: huiText('Visibility'),
        children: <Widget>[
          _toggle(
            'Enabled',
            doc.enabled,
            (GlossEntityOverlaysDoc edited, bool value) =>
                edited.enabled = value,
          ),
          _toggle(
            'Include players',
            doc.includePlayers,
            (GlossEntityOverlaysDoc edited, bool value) =>
                edited.includePlayers = value,
          ),
          _number(
            'Display range',
            'range',
            doc.range,
            'Nearby range in blocks. 1..64.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.range = value,
          ),
          _number(
            'Update interval',
            'updateIntervalTicks',
            doc.updateIntervalTicks,
            'Ticks between entity updates. 1..40.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.updateIntervalTicks = value.round(),
            integer: true,
          ),
          _number(
            'Maximum entities per viewer',
            'maxEntitiesPerViewer',
            doc.maxEntitiesPerViewer,
            'Maximum simultaneous overlays for each viewer. 1..256.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.maxEntitiesPerViewer = value.round(),
            integer: true,
          ),
          _text(
            'Excluded worlds',
            doc.blacklistWorlds.join(', '),
            'World names, separated by commas.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.blacklistWorlds = _list(value),
          ),
          _text(
            'Excluded entity types',
            doc.excludedEntityTypes.join(', '),
            'Bukkit entity types, separated by commas.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.excludedEntityTypes = _list(
                  value,
                ).map((String type) => type.toUpperCase()).toList(),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Display'),
        children: <Widget>[
          _number(
            'Vertical offset',
            'verticalOffset',
            doc.verticalOffset,
            'Blocks above the entity bounds. -2..8.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.verticalOffset = value,
          ),
          _number(
            'Scale',
            'scale',
            doc.scale,
            'Text display scale. 0.1..4.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.scale = value,
          ),
          _number(
            'Health segments',
            'healthSegments',
            doc.healthSegments,
            'Number of segments in the health bar. 1..40.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.healthSegments = value.round(),
            integer: true,
          ),
          _toggle(
            'Show health numbers',
            doc.showHealthNumbers,
            (GlossEntityOverlaysDoc edited, bool value) =>
                edited.showHealthNumbers = value,
          ),
          _toggle(
            'Show custom names',
            doc.showNames,
            (GlossEntityOverlaysDoc edited, bool value) =>
                edited.showNames = value,
          ),
          _toggle(
            'Show attack and armor',
            doc.showCombatStats,
            (GlossEntityOverlaysDoc edited, bool value) =>
                edited.showCombatStats = value,
          ),
          _number(
            'Hit highlight duration',
            'hitHighlightMs',
            doc.hitHighlightMs,
            'Milliseconds to show lost health segments and damage. 0..10000.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.hitHighlightMs = value.round(),
            integer: true,
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Text formats'),
        children: <Widget>[
          _text(
            'Name format',
            doc.nameFormat,
            '{name} is the custom name. React appends its stack count.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.nameFormat = value,
          ),
          _text(
            'Health format',
            doc.healthFormat,
            'Tokens: {bar}, {health}, {max_health}. Without health numbers, only the bar is shown.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.healthFormat = value,
          ),
          _text(
            'Stack format',
            doc.stackFormat,
            '{count} comes from React. Appears only for stacks larger than one.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.stackFormat = value,
          ),
          _text(
            'Combat stats format',
            doc.statsFormat,
            'Tokens: {attack}, {armor}. This is the final line.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.statsFormat = value,
          ),
          _text(
            'Damage format',
            doc.damageFormat,
            '{damage} is the latest health loss during the hit highlight.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.damageFormat = value,
          ),
        ],
      ),
      InspectorSection(
        title: huiText('React and Adapt'),
        children: <Widget>[
          dom.p(classes: 'hui-inspector-lede', <Widget>[
            Text(
              huiText(
                'React supplies mob stack counts automatically. Adapt Discovery Insight adds details to its selected entity. Adapt can restrict the global overlays to active Insight targets through its own adaptation config.',
              ),
            ),
          ]),
          dom.p(classes: 'hui-inspector-lede', <Widget>[
            Text(
              huiText(
                'Use the sample controls to compare these states. Sample controls do not change server settings.',
              ),
            ),
          ]),
        ],
      ),
    ]);
  }

  Widget _toggle(
    String label,
    bool value,
    void Function(GlossEntityOverlaysDoc, bool) edit,
  ) => ArcaneToggleSwitch(
    label: huiText(label),
    labelLeft: true,
    size: ComponentSize.sm,
    value: value,
    onChanged: (bool next) => store.mutateEntityOverlays(
      label,
      (GlossEntityOverlaysDoc doc) => edit(doc, next),
    ),
  );

  Widget _number(
    String label,
    String path,
    num value,
    String help,
    void Function(GlossEntityOverlaysDoc, double) edit, {
    bool integer = false,
  }) => HuiField(
    label: huiText(label),
    help: huiText(help),
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value.toDouble(),
        ariaLabel: huiText(label),
        integer: integer,
        decimals: integer ? 0 : 2,
        step: integer ? 1 : 0.05,
        onChanged: (double next) => store.mutateEntityOverlays(
          label,
          (GlossEntityOverlaysDoc doc) => edit(doc, next),
        ),
      ),
      HuiInlineIssues(
        store.issues
            .where((HuiIssue issue) => issue.path == '\$.$path')
            .toList(),
      ),
    ]),
  );

  Widget _text(
    String label,
    String value,
    String help,
    void Function(GlossEntityOverlaysDoc, String) edit,
  ) => HuiField(
    label: huiText(label),
    help: huiText(help),
    control: TextInput(
      value: value,
      fullWidth: true,
      size: ComponentSize.sm,
      attributes: <String, String>{
        'aria-label': huiText(label),
        'spellcheck': 'false',
      },
      onInput: (String next) => store.mutateEntityOverlays(
        label,
        (GlossEntityOverlaysDoc doc) => edit(doc, next),
      ),
    ),
  );

  List<String> _list(String value) => value
      .split(',')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}
