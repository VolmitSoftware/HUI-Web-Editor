library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:gloss_editor/l10n/hui_localizations.dart';

import '../../logic/gloss_show.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'gloss_visibility_editor.dart';
import 'inspector_widgets.dart';
import 'line_list_section.dart';

Widget _header({
  required String eyebrow,
  required String title,
  required String lede,
  required int revision,
}) => dom.div(classes: 'hui-inspector-headgroup', <Widget>[
  dom.div(classes: 'hui-inspector-header', <Widget>[
    HuiEyebrow(eyebrow),
    dom.div(classes: 'hui-inspector-title-row', <Widget>[
      dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[Text(title)]),
    ]),
  ]),
  dom.p(classes: 'hui-inspector-lede', <Widget>[Text(lede)]),
  HuiRevisionRow(revision: revision),
]);

List<ArcaneSelectOption> _options(List<String> values) => <ArcaneSelectOption>[
  for (final String value in values)
    ArcaneSelectOption(value: value, label: value),
];

class InventoryInspector extends StatelessWidget {
  const InventoryInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossInventoryDoc? doc = store.inventoryDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-inventory', <Widget>[
      _header(
        eyebrow: huiText('Inventory'),
        title: store.menuId,
        lede: huiText('Chest window'),
        revision: doc.revision,
      ),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'inventory.visibility',
        issues: store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => store.mutateInventory(
          'visibility',
          (GlossInventoryDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      HuiField(
        label: huiText('Title'),
        control: TextInput(
          value: doc.title,
          size: ComponentSize.sm,
          fullWidth: true,
          onChange: (String value) => store.mutateInventory(
            'title',
            (GlossInventoryDoc edited) => edited.title = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Resolution'),
        control: ArcaneSelect(
          value: doc.resolution,
          size: ComponentSize.sm,
          options: _options(glossInventoryResolutions),
          onChange: (String value) => store.mutateInventory(
            'resolution',
            (GlossInventoryDoc edited) => edited.resolution = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Mask'),
        help: huiText('Mask'),
        control: TextArea(
          value: doc.mask.join('\n'),
          onChange: (String value) => store.mutateInventory(
            'mask',
            (GlossInventoryDoc edited) => edited.mask = value.split('\n'),
          ),
        ),
      ),
      HuiSwitchRow(
        label: huiText('Close on teleport'),
        value: doc.closeOnTeleport,
        onChanged: (bool value) => store.mutateInventory(
          'close on teleport',
          (GlossInventoryDoc edited) => edited.closeOnTeleport = value,
        ),
      ),
    ]);
  }
}

class NameplateInspector extends StatelessWidget {
  const NameplateInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossNameplateDoc? doc = store.nameplateDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-nameplate', <Widget>[
      _header(
        eyebrow: huiText('Nameplate'),
        title: store.menuId,
        lede: huiText('Over player'),
        revision: doc.revision,
      ),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'nameplate.visibility',
        issues: store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => store.mutateNameplate(
          'visibility',
          (GlossNameplateDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      HuiLineListSection(
        title: huiText('Lines'),
        addLabel: huiText('Add line'),
        emptyBody: huiText('Nothing here yet'),
        itemCount: doc.presentation.lines.length,
        onAdd: () => store.mutateNameplate('add line', (GlossNameplateDoc edited) {
          edited.presentation.lines.add(
            GlossNameplateLine(text: '&f{{ subject.name }}'),
          );
        }),
        itemBuilder: (int index) => HuiLineRow(
          value: doc.presentation.lines[index].text,
          placeholder: huiText('Nameplate line'),
          removeLabel: huiText('Delete line {number}', <String, Object?>{
            'number': index + 1,
          }),
          onChanged: (String value) => store.mutateNameplate(
            'line',
            (GlossNameplateDoc edited) {
              if (index < edited.presentation.lines.length) {
                edited.presentation.lines[index].text = value;
              }
            },
          ),
          onRemove: () => store.mutateNameplate(
            'remove line',
            (GlossNameplateDoc edited) {
              if (index < edited.presentation.lines.length) {
                edited.presentation.lines.removeAt(index);
              }
            },
          ),
        ),
      ),
      HuiField(
        label: huiText('Offset'),
        help: huiText('Offset'),
        control: HuiNumberField(
          value: doc.presentation.offset,
          min: -2,
          max: 8,
          onChanged: (double value) => store.mutateNameplate(
            'offset',
            (GlossNameplateDoc edited) => edited.presentation.offset = value,
          ),
        ),
      ),
      HuiSwitchRow(
        label: huiText('Hide while sneaking'),
        value: doc.presentation.hideSneaking,
        onChanged: (bool value) => store.mutateNameplate(
          'hide sneaking',
          (GlossNameplateDoc edited) => edited.presentation.hideSneaking = value,
        ),
      ),
    ]);
  }
}

class NametagInspector extends StatelessWidget {
  const NametagInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossNametagDoc? doc = store.nametagDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-nametag', <Widget>[
      _header(
        eyebrow: huiText('Nametag'),
        title: store.menuId,
        lede: huiText('Team tag'),
        revision: doc.revision,
      ),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'nametag.visibility',
        issues: store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => store.mutateNametag(
          'visibility',
          (GlossNametagDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      HuiField(
        label: huiText('Prefix'),
        control: TextInput(
          value: doc.presentation.prefix,
          size: ComponentSize.sm,
          fullWidth: true,
          onChange: (String value) => store.mutateNametag(
            'prefix',
            (GlossNametagDoc edited) => edited.presentation.prefix = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Suffix'),
        control: TextInput(
          value: doc.presentation.suffix,
          size: ComponentSize.sm,
          fullWidth: true,
          onChange: (String value) => store.mutateNametag(
            'suffix',
            (GlossNametagDoc edited) => edited.presentation.suffix = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Team color'),
        control: TextInput(
          value: doc.presentation.color,
          size: ComponentSize.sm,
          fullWidth: true,
          onChange: (String value) => store.mutateNametag(
            'color',
            (GlossNametagDoc edited) => edited.presentation.color = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Name visibility'),
        control: ArcaneSelect(
          value: doc.presentation.nameTagVisibility,
          size: ComponentSize.sm,
          options: _options(glossNametagVisibilities),
          onChange: (String value) => store.mutateNametag(
            'visibility rule',
            (GlossNametagDoc edited) =>
                edited.presentation.nameTagVisibility = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Collision'),
        control: ArcaneSelect(
          value: doc.presentation.collision,
          size: ComponentSize.sm,
          options: _options(glossNametagCollisions),
          onChange: (String value) => store.mutateNametag(
            'collision',
            (GlossNametagDoc edited) => edited.presentation.collision = value,
          ),
        ),
      ),
    ]);
  }
}

class MarkerInspector extends StatelessWidget {
  const MarkerInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossMarkerDoc? doc = store.markerDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-marker', <Widget>[
      _header(
        eyebrow: huiText('Marker'),
        title: store.menuId,
        lede: huiText('World pin'),
        revision: doc.revision,
      ),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'marker.visibility',
        issues: store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => store.mutateMarker(
          'visibility',
          (GlossMarkerDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      HuiField(
        label: huiText('Label'),
        control: TextInput(
          value: doc.label,
          size: ComponentSize.sm,
          fullWidth: true,
          onChange: (String value) => store.mutateMarker(
            'label',
            (GlossMarkerDoc edited) => edited.label = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Color'),
        control: HuiColorField(
          value: doc.color,
          format: HuiColorFormat.rgb,
          onChanged: (String value) => store.mutateMarker(
            'color',
            (GlossMarkerDoc edited) => edited.color = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('World'),
        control: TextInput(
          value: doc.anchor.world ?? '',
          size: ComponentSize.sm,
          onChange: (String value) => store.mutateMarker(
            'world',
            (GlossMarkerDoc edited) =>
                edited.anchor.world = value.trim().isEmpty ? null : value,
          ),
        ),
      ),
      HuiVec3Field(
        value: Vec3(doc.anchor.x ?? 0, doc.anchor.y ?? 64, doc.anchor.z ?? 0),
        onChanged: (Vec3 value) => store.mutateMarker('position', (
          GlossMarkerDoc edited,
        ) {
          edited.anchor.x = value.x;
          edited.anchor.y = value.y;
          edited.anchor.z = value.z;
        }),
      ),
      HuiField(
        label: huiText('Hide within (blocks)'),
        control: HuiNumberField(
          value: doc.hideWithin,
          min: 0,
          onChanged: (double value) => store.mutateMarker(
            'hide within',
            (GlossMarkerDoc edited) => edited.hideWithin = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Max distance'),
        control: HuiNumberField(
          value: doc.maxDistance,
          min: 1,
          onChanged: (double value) => store.mutateMarker(
            'max distance',
            (GlossMarkerDoc edited) => edited.maxDistance = value,
          ),
        ),
      ),
      HuiSwitchRow(
        label: huiText('Beam'),
        value: doc.beam.enabled,
        onChanged: (bool value) => store.mutateMarker(
          'beam',
          (GlossMarkerDoc edited) => edited.beam.enabled = value,
        ),
      ),
    ]);
  }
}
