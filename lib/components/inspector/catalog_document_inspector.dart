import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../l10n/hui_localizations.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'gloss_visibility_editor.dart';
import 'inspector_widgets.dart';

class StringsInspector extends StatelessWidget {
  const StringsInspector({required this.store, super.key});
  final EditorStore store;

  void _edit(String label, void Function(GlossStringsDoc) edit) =>
      store.mutateGloss(label, (GlossDoc doc) {
        if (doc is GlossStringsDoc) edit(doc);
      });

  @override
  Widget build(BuildContext context) {
    final GlossDoc? doc = store.glossDoc;
    if (doc is! GlossStringsDoc) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      InspectorSection(
        title: huiText('Strings'),
        children: <Widget>[
          HuiRevisionRow(revision: doc.revision),
          HuiField(
            label: huiText('Locale'),
            control: TextInput(
              value: doc.locale,
              size: ComponentSize.sm,
              onChanged: (String value) =>
                  _edit('locale', (GlossStringsDoc doc) => doc.locale = value),
            ),
          ),
          HuiField(
            label: huiText('Fallback'),
            control: TextInput(
              value: doc.fallback,
              size: ComponentSize.sm,
              onChanged: (String value) => _edit(
                'fallback',
                (GlossStringsDoc doc) => doc.fallback = value,
              ),
            ),
          ),
          ExtrasEditor(
            title: huiText('Entries'),
            extensionKeys: false,
            stringsOnly: true,
            extras: Map<String, Object?>.of(doc.entries),
            onChanged: (String label, Map<String, Object?> values) => _edit(
              label,
              (GlossStringsDoc doc) => doc.entries = <String, String>{
                for (final MapEntry<String, Object?> entry in values.entries)
                  entry.key: entry.value as String,
              },
            ),
          ),
        ],
      ),
    ]);
  }
}

class WaypointInspector extends StatelessWidget {
  const WaypointInspector({required this.store, super.key});
  final EditorStore store;

  void _edit(String label, void Function(GlossWaypointDoc) edit) =>
      store.mutateGloss(label, (GlossDoc doc) {
        if (doc is GlossWaypointDoc) edit(doc);
      });

  @override
  Widget build(BuildContext context) {
    final GlossDoc? doc = store.glossDoc;
    if (doc is! GlossWaypointDoc) return const dom.div(<Widget>[]);
    final String target = doc.anchor.entity != null
        ? 'entity'
        : doc.anchor.player != null
        ? 'player'
        : 'position';
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      HuiRevisionRow(revision: doc.revision),
      InspectorSection(
        title: huiText('Anchor'),
        children: <Widget>[
          HuiField(
            label: huiText('Type'),
            control: ArcaneSelect(
              value: target,
              options: <ArcaneSelectOption>[
                ArcaneSelectOption(
                  value: 'position',
                  label: huiText('Position'),
                ),
                ArcaneSelectOption(value: 'entity', label: huiText('Entity')),
                ArcaneSelectOption(value: 'player', label: huiText('Player')),
              ],
              onChanged: (String value) =>
                  _edit('anchor', (GlossWaypointDoc doc) {
                    doc.anchor = switch (value) {
                      'entity' => GlossMarkerAnchor(entity: ''),
                      'player' => GlossMarkerAnchor(player: ''),
                      _ => GlossMarkerAnchor(world: 'world', x: 0, y: 64, z: 0),
                    };
                  }),
            ),
          ),
          if (target == 'position') ...<Widget>[
            HuiField(
              label: huiText('World'),
              control: TextInput(
                value: doc.anchor.world ?? '',
                onChanged: (String value) => _edit(
                  'world',
                  (GlossWaypointDoc doc) => doc.anchor.world = value,
                ),
              ),
            ),
            HuiVec3Field(
              value: Vec3(
                doc.anchor.x ?? 0,
                doc.anchor.y ?? 64,
                doc.anchor.z ?? 0,
              ),
              onChanged: (Vec3 value) =>
                  _edit('position', (GlossWaypointDoc doc) {
                    doc.anchor.x = value.x;
                    doc.anchor.y = value.y;
                    doc.anchor.z = value.z;
                  }),
            ),
          ] else
            HuiField(
              label: huiText(target == 'entity' ? 'Entity' : 'Player'),
              control: TextInput(
                value: target == 'entity'
                    ? doc.anchor.entity ?? ''
                    : doc.anchor.player ?? '',
                onChanged: (String value) =>
                    _edit('anchor', (GlossWaypointDoc doc) {
                      if (target == 'entity') {
                        doc.anchor.entity = value;
                      } else {
                        doc.anchor.player = value;
                      }
                    }),
              ),
            ),
        ],
      ),
      InspectorSection(
        title: huiText('Style'),
        children: <Widget>[
          HuiField(
            label: huiText('Color'),
            control: HuiColorField(
              value: doc.color,
              format: HuiColorFormat.rgb,
              onChanged: (String value) =>
                  _edit('color', (GlossWaypointDoc doc) => doc.color = value),
            ),
          ),
          HuiField(
            label: huiText('Style'),
            control: TextInput(
              value: doc.style,
              onChanged: (String value) =>
                  _edit('style', (GlossWaypointDoc doc) => doc.style = value),
            ),
          ),
          HuiField(
            label: huiText('Fallback style'),
            control: ArcaneSelect(
              value: doc.fallbackStyle,
              options: const <ArcaneSelectOption>[
                ArcaneSelectOption(value: 'default', label: 'default'),
                ArcaneSelectOption(value: 'bowtie', label: 'bowtie'),
              ],
              onChanged: (String value) => _edit(
                'fallback style',
                (GlossWaypointDoc doc) => doc.fallbackStyle = value,
              ),
            ),
          ),
          HuiField(
            label: huiText('Range'),
            control: HuiNumberField(
              value: doc.range,
              min: 0,
              onChanged: (double value) =>
                  _edit('range', (GlossWaypointDoc doc) => doc.range = value),
            ),
          ),
        ],
      ),
      GlossVisibilityEditor(
        raw: doc.show,
        sectionKey: 'waypoint.show',
        onChanged: (Object? value) =>
            _edit('visibility', (GlossWaypointDoc doc) => doc.show = value),
      ),
      InspectorSection(
        title: huiText('Audience'),
        children: <Widget>[
          GlossVisibilityEditor(
            raw: doc.audience,
            sectionKey: 'waypoint.audience',
            onChanged: (Object? value) => _edit(
              'audience',
              (GlossWaypointDoc doc) => doc.audience = value,
            ),
          ),
        ],
      ),
    ]);
  }
}

class CatalogDocumentView extends StatelessWidget {
  const CatalogDocumentView({required this.store, super.key});
  final EditorStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (BuildContext context) => _content(),
  );

  Widget _content() {
    final GlossDoc? doc = store.glossDoc;
    return dom.div(classes: 'hui-inspector-body', <Widget>[
      if (doc is GlossStringsDoc)
        InspectorSection(
          title: doc.locale,
          children: <Widget>[
            for (final MapEntry<String, String> entry in doc.entries.entries)
              HuiField(label: entry.key, control: Text(entry.value)),
          ],
        ),
      if (doc is GlossWaypointDoc)
        InspectorSection(
          title: huiText('Waypoint'),
          children: <Widget>[
            HuiField(
              label: huiText('Anchor'),
              control: Text(
                doc.anchor.player ??
                    doc.anchor.entity ??
                    '${doc.anchor.world}: ${doc.anchor.x}, ${doc.anchor.y}, ${doc.anchor.z}',
              ),
            ),
            HuiField(label: huiText('Color'), control: Text(doc.color)),
            HuiField(label: huiText('Style'), control: Text(doc.style)),
            HuiField(label: huiText('Range'), control: Text('${doc.range}')),
          ],
        ),
    ]);
  }
}
