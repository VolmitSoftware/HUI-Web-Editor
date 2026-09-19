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

class DialogInspector extends StatelessWidget {
  const DialogInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossDialogDoc? doc = store.dialogDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-dialog', <Widget>[
      _header(
        eyebrow: huiText('Dialog'),
        title: store.menuId,
        lede: huiText('Dialog screen'),
        revision: doc.revision,
      ),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'dialog.visibility',
        issues: store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => store.mutateDialog(
          'visibility',
          (GlossDialogDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      HuiField(
        label: huiText('Type'),
        control: ArcaneSelect(
          value: doc.type,
          size: ComponentSize.sm,
          options: _options(glossDialogTypes),
          onChange: (String value) => store.mutateDialog(
            'type',
            (GlossDialogDoc edited) => edited.type = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Title'),
        control: TextInput(
          value: doc.title,
          size: ComponentSize.sm,
          fullWidth: true,
          onChange: (String value) => store.mutateDialog(
            'title',
            (GlossDialogDoc edited) => edited.title = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Pause-menu title'),
        help: huiText('Pause-menu title'),
        control: TextInput(
          value: doc.externalTitle ?? '',
          size: ComponentSize.sm,
          fullWidth: true,
          onChange: (String value) => store.mutateDialog(
            'external title',
            (GlossDialogDoc edited) =>
                edited.externalTitle = value.trim().isEmpty ? null : value,
          ),
        ),
      ),
      HuiField(
        label: huiText('After action'),
        control: ArcaneSelect(
          value: doc.afterAction,
          size: ComponentSize.sm,
          options: _options(glossDialogAfterActions),
          onChange: (String value) => store.mutateDialog(
            'after action',
            (GlossDialogDoc edited) => edited.afterAction = value,
          ),
        ),
      ),
      HuiSwitchRow(
        label: huiText('Close with Escape'),
        value: doc.canCloseWithEscape,
        onChanged: (bool value) => store.mutateDialog(
          'close with escape',
          (GlossDialogDoc edited) => edited.canCloseWithEscape = value,
        ),
      ),
      HuiSwitchRow(
        label: huiText('Pause the world'),
        value: doc.pause,
        onChanged: (bool value) => store.mutateDialog(
          'pause',
          (GlossDialogDoc edited) => edited.pause = value,
        ),
      ),
      HuiLineListSection(
        title: huiText('Body'),
        addLabel: huiText('Add body line'),
        emptyBody: huiText('Nothing here yet'),
        itemCount: doc.body.length,
        onAdd: () => store.mutateDialog('add body', (GlossDialogDoc edited) {
          edited.body.add(GlossDialogBody(text: '&7...'));
        }),
        itemBuilder: (int index) => HuiLineRow(
          value: doc.body[index].text,
          placeholder: huiText('Body text'),
          removeLabel: huiText('Delete body {number}', <String, Object?>{
            'number': index + 1,
          }),
          onChanged: (String value) => store.mutateDialog(
            'body text',
            (GlossDialogDoc edited) {
              if (index < edited.body.length) edited.body[index].text = value;
            },
          ),
          onRemove: () => store.mutateDialog(
            'remove body',
            (GlossDialogDoc edited) {
              if (index < edited.body.length) edited.body.removeAt(index);
            },
          ),
        ),
      ),
      InspectorSection(
        title: huiText('Buttons'),
        children: <Widget>[
          for (int index = 0; index < doc.buttons.length; index++)
            HuiField(
              label: huiText('Button {index}', <String, Object?>{'index': index + 1}),
              control: TextInput(
                value: doc.buttons[index].label,
                size: ComponentSize.sm,
                fullWidth: true,
                onChange: (String value) => store.mutateDialog(
                  'button label',
                  (GlossDialogDoc edited) {
                    if (index < edited.buttons.length) {
                      edited.buttons[index].label = value;
                    }
                  },
                ),
              ),
            ),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () => store.mutateDialog(
              'add button',
              (GlossDialogDoc edited) =>
                  edited.buttons.add(GlossDialogButton(label: '&aOK')),
            ),
            label: huiText('Add button'),
          ),
        ],
      ),
    ]);
  }
}

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

class MotionInspector extends StatelessWidget {
  const MotionInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossMotionDoc? doc = store.motionDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-motion', <Widget>[
      _header(
        eyebrow: huiText('Motion'),
        title: store.menuId,
        lede: huiText('Clip tracks'),
        revision: doc.revision,
      ),
      HuiField(
        label: huiText('Duration (ticks)'),
        control: HuiNumberField(
          value: doc.durationTicks ?? 0,
          min: 0,
          integer: true,
          onChanged: (double value) => store.mutateMotion(
            'duration',
            (GlossMotionDoc edited) => edited.durationTicks = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Loop'),
        control: ArcaneSelect(
          value: doc.loop,
          size: ComponentSize.sm,
          options: _options(glossMotionLoops),
          onChange: (String value) => store.mutateMotion(
            'loop',
            (GlossMotionDoc edited) => edited.loop = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Frames per second'),
        control: HuiNumberField(
          value: doc.fps.toDouble(),
          min: 1,
          max: 120,
          integer: true,
          onChanged: (double value) => store.mutateMotion(
            'fps',
            (GlossMotionDoc edited) => edited.fps = value.round(),
          ),
        ),
      ),
      for (int index = 0; index < doc.tracks.length; index++)
        InspectorSection(
          title: huiText('Track {index}', <String, Object?>{'index': index + 1}),
          children: <Widget>[
            HuiField(
              label: huiText('Bone'),
              control: TextInput(
                value: doc.tracks[index].bone,
                size: ComponentSize.sm,
                onChange: (String value) => store.mutateMotion(
                  'bone',
                  (GlossMotionDoc edited) {
                    if (index < edited.tracks.length) {
                      edited.tracks[index].bone = value;
                    }
                  },
                ),
              ),
            ),
            HuiField(
              label: huiText('Channel'),
              control: ArcaneSelect(
                value: glossMotionChannels.contains(doc.tracks[index].channel)
                    ? doc.tracks[index].channel
                    : 'translation.y',
                size: ComponentSize.sm,
                options: _options(glossMotionChannels),
                onChange: (String value) => store.mutateMotion(
                  'channel',
                  (GlossMotionDoc edited) {
                    if (index < edited.tracks.length) {
                      edited.tracks[index].channel = value;
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: () => store.mutateMotion('add track', (GlossMotionDoc edited) {
          edited.tracks.add(
            GlossMotionTrack(
              keyframes: <GlossMotionKeyframe>[
                GlossMotionKeyframe(tick: 0, value: 0),
                GlossMotionKeyframe(tick: 20, value: 1),
              ],
            ),
          );
        }),
        label: huiText('Add track'),
      ),
    ]);
  }
}

class RigInspector extends StatelessWidget {
  const RigInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossRigDoc? doc = store.rigDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-rig', <Widget>[
      _header(
        eyebrow: huiText('Rig'),
        title: store.menuId,
        lede: huiText('Bones and parts'),
        revision: doc.revision,
      ),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'rig.visibility',
        issues: store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => store.mutateRig(
          'visibility',
          (GlossRigDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      InspectorSection(
        title: huiText('Bones'),
        children: <Widget>[
          for (int index = 0; index < doc.bones.length; index++)
            HuiField(
              label: huiText('Bone {index}', <String, Object?>{'index': index + 1}),
              control: TextInput(
                value: doc.bones[index].id,
                size: ComponentSize.sm,
                onChange: (String value) => store.mutateRig(
                  'bone id',
                  (GlossRigDoc edited) {
                    if (index < edited.bones.length) {
                      edited.bones[index].id = value;
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      InspectorSection(
        title: huiText('Parts'),
        children: <Widget>[
          for (int index = 0; index < doc.parts.length; index++) ...<Widget>[
            HuiField(
              label: huiText('Part {index}', <String, Object?>{'index': index + 1}),
              control: TextInput(
                value: doc.parts[index].id,
                size: ComponentSize.sm,
                onChange: (String value) => store.mutateRig(
                  'part id',
                  (GlossRigDoc edited) {
                    if (index < edited.parts.length) {
                      edited.parts[index].id = value;
                    }
                  },
                ),
              ),
            ),
            HuiField(
              label: huiText('Type'),
              control: ArcaneSelect(
                value: glossRigPartTypes.contains(doc.parts[index].type)
                    ? doc.parts[index].type
                    : 'block',
                size: ComponentSize.sm,
                options: _options(glossRigPartTypes),
                onChange: (String value) => store.mutateRig(
                  'part type',
                  (GlossRigDoc edited) {
                    if (index < edited.parts.length) {
                      edited.parts[index].type = value;
                    }
                  },
                ),
              ),
            ),
          ],
        ],
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

class ZoneInspector extends StatelessWidget {
  const ZoneInspector({required this.store, super.key});

  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final GlossZoneDoc? doc = store.zoneDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-zone', <Widget>[
      _header(
        eyebrow: huiText('Zone'),
        title: store.menuId,
        lede: huiText('Volume'),
        revision: doc.revision,
      ),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'zone.visibility',
        issues: store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => store.mutateZone(
          'visibility',
          (GlossZoneDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      HuiField(
        label: huiText('Shape'),
        control: ArcaneSelect(
          value: doc.shape.type,
          size: ComponentSize.sm,
          options: _options(glossZoneShapeTypes),
          onChange: (String value) => store.mutateZone(
            'shape',
            (GlossZoneDoc edited) => edited.shape.type = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('World'),
        control: TextInput(
          value: doc.shape.world,
          size: ComponentSize.sm,
          onChange: (String value) => store.mutateZone(
            'world',
            (GlossZoneDoc edited) => edited.shape.world = value,
          ),
        ),
      ),
      if (doc.shape.type == 'cuboid') ...<Widget>[
        HuiField(
          label: huiText('Min'),
          control: HuiVec3Field(
            value: Vec3(
              doc.shape.min[0],
              doc.shape.min[1],
              doc.shape.min[2],
            ),
            onChanged: (Vec3 value) => store.mutateZone('min', (
              GlossZoneDoc edited,
            ) {
              edited.shape.min = <double>[value.x, value.y, value.z];
            }),
          ),
        ),
        HuiField(
          label: huiText('Max'),
          control: HuiVec3Field(
            value: Vec3(
              doc.shape.max[0],
              doc.shape.max[1],
              doc.shape.max[2],
            ),
            onChanged: (Vec3 value) => store.mutateZone('max', (
              GlossZoneDoc edited,
            ) {
              edited.shape.max = <double>[value.x, value.y, value.z];
            }),
          ),
        ),
      ],
      HuiField(
        label: huiText('Render'),
        control: ArcaneSelect(
          value: doc.render.mode,
          size: ComponentSize.sm,
          options: _options(glossZoneRenderModes),
          onChange: (String value) => store.mutateZone(
            'render',
            (GlossZoneDoc edited) => edited.render.mode = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Color'),
        control: HuiColorField(
          value: doc.render.color,
          format: HuiColorFormat.rgb,
          onChanged: (String value) => store.mutateZone(
            'color',
            (GlossZoneDoc edited) => edited.render.color = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Toggle permission'),
        control: TextInput(
          value: doc.toggle,
          size: ComponentSize.sm,
          onChange: (String value) => store.mutateZone(
            'toggle',
            (GlossZoneDoc edited) => edited.toggle = value,
          ),
        ),
      ),
    ]);
  }
}
