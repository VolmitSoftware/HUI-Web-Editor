/// Inspector body for a Gloss hologram document.
///
/// Anchor world and position, then presentation — see-through plus the
/// billboard mode and the yaw/pitch that only some modes read — then the
/// reorderable line list: each row an input plus a live Gloss-pipeline
/// preview, with a placeholder picker that inserts into the selected line.
/// The revision is server-owned and shown, not edited.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'display_style_editor.dart';
import 'hologram_box_editor.dart';
import '../../model/gloss_hologram_box.dart';
import 'gloss_visibility_editor.dart';
import '../../logic/gloss_show.dart';
import 'line_list_section.dart';
import 'particle_layers_editor.dart';
import 'placeholder_picker.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class HologramInspector extends StatefulWidget {
  const HologramInspector({
    required this.store,
    required this.catalogs,
    super.key,
  });

  final EditorStore store;
  final HuiCatalogs catalogs;

  @override
  State<HologramInspector> createState() => _HologramInspectorState();
}

class _HologramInspectorState extends State<HologramInspector> {
  /// The row the placeholder picker inserts into: the last focused input.
  int _focusedLine = 0;

  EditorStore get _store => component.store;

  GlossHologramDoc? get _doc => _store.hologramDoc;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossHologramDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-hologram', <Widget>[
      _header(doc),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'hologram.visibility',
        issues: _store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => _store.mutateHologram(
          'visibility',
          (GlossHologramDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      _anchor(doc),
      DisplayStyleEditor(
        style: doc.style,
        defaults: defaultHologramDisplayStyle(),
        issues: _issuesFor(r'$.style'),
        onChanged: (String label, HuiIconStyle? value) => _store.mutateHologram(
          label,
          (GlossHologramDoc edited) =>
              edited.style = value ?? defaultHologramDisplayStyle(),
        ),
      ),
      HologramBoxEditor(
        box: doc.box,
        sectionKey: 'hologram.box',
        issues: _issuesFor(r'$.box'),
        mutate: (String label, void Function(GlossHologramBox) edit) =>
            _store.mutateHologram(
              label,
              (GlossHologramDoc edited) => edit(edited.box),
            ),
      ),
      _presentation(doc),
      _lines(doc),
      ParticleLayersEditor(
        layers: doc.particleLayers,
        sectionKey: 'hologram.particleLayers',
        mutate: (String label, void Function(List<GlossParticleLayer>) edit) =>
            _store.mutateHologram(
              label,
              (GlossHologramDoc edited) => edit(edited.particleLayers),
            ),
      ),
    ]);
  }

  Widget _presentation(GlossHologramDoc doc) => InspectorSection(
    title: huiText('Presentation'),
    children: <Widget>[
      _angle(
        label: huiText('Yaw'),
        docKey: 'hologram.yaw',
        path: r'$.yaw',
        value: doc.yaw,
        limit: glossHologramMaxYawDegrees,
        used:
            doc.style.billboard == 'fixed' ||
            doc.style.billboard == 'horizontal',
        help: huiText('0 faces south, 90 faces west, 180 north, -90 east.'),
        onChanged: (double value) =>
            _store.mutateHologram('hologram yaw', (GlossHologramDoc edited) {
              edited.yaw = value;
              edited.absentKeys.remove('yaw');
            }),
      ),
      _angle(
        label: huiTextKey('field.pitch.orientation', 'Pitch'),
        docKey: 'hologram.pitch',
        path: r'$.pitch',
        value: doc.pitch,
        limit: glossHologramMaxPitchDegrees,
        used:
            doc.style.billboard == 'fixed' || doc.style.billboard == 'vertical',
        help: huiText('Positive tips the face downward, negative tips it up.'),
        onChanged: (double value) =>
            _store.mutateHologram('hologram pitch', (GlossHologramDoc edited) {
              edited.pitch = value;
              edited.absentKeys.remove('pitch');
            }),
      ),
    ],
  );

  /// One orientation angle. The row stays put and says so when the current
  /// billboard mode turns that axis itself, because a control that vanishes
  /// with the mode hides the value the author is about to need again.
  Widget _angle({
    required String label,
    required String docKey,
    required String path,
    required double value,
    required double limit,
    required bool used,
    required String help,
    required void Function(double value) onChanged,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(docKey),
    help: used
        ? huiText('{help} Degrees, {minimum} to {maximum}.', <String, Object?>{
            'help': help,
            'minimum': -limit.toInt(),
            'maximum': limit.toInt(),
          })
        : huiText(
            'The current billboard mode turns this axis itself, so this value '
            'never reaches the screen.',
          ),
    defaultValue: '0',
    onReset: value == 0 ? null : () => onChanged(0),
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value,
        step: 15,
        decimals: 2,
        suffix: '°',
        onChanged: onChanged,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _header(GlossHologramDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-hologram', <Widget>[
          HuiEyebrow(huiText('Hologram')),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('hologram.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText('Every line joins into one TextDisplay at a world anchor.'),
          ),
        ]),
        // The revision used to be a clause in that sentence, where it read as
        // prose about the document rather than as the value it is — and the
        // written help for it had nowhere to mount.
        HuiRevisionRow(revision: doc.revision, docKey: 'hologram.revision'),
      ]);

  Widget _anchor(GlossHologramDoc doc) {
    final List<double> position = doc.anchor.position;
    return InspectorSection(
      title: huiText('Anchor'),
      children: <Widget>[
        HuiField(
          label: huiText('World'),
          required: true,
          trailing: const HuiFieldHelp('hologram.anchor.world'),
          help: huiText('The world the hologram stands in.'),
          control: dom.div(<Widget>[
            TextInput(
              value: doc.anchor.world,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: huiText('world'),
              onInput: (String value) => _store.mutateHologram(
                'hologram world',
                (GlossHologramDoc edited) => edited.anchor.world = value,
              ),
              attributes: const <String, String>{
                'autocomplete': 'off',
                'spellcheck': 'false',
                'dir': 'ltr',
              },
            ),
            HuiInlineIssues(_issuesFor(r'$.anchor.world')),
          ]),
        ),
        HuiField(
          label: huiText('Position'),
          required: true,
          trailing: const HuiFieldHelp('hologram.anchor.position'),
          help: huiText('Block coordinates of the TextDisplay entity.'),
          control: dom.div(<Widget>[
            HuiVec3Field(
              value: Vec3(position[0], position[1], position[2]),
              step: 0.5,
              decimals: 2,
              // World coordinates, not a menu-space offset: the shared hints
              // would say "right of the player", which is wrong here.
              axisHints: <String>[
                huiText('x: world east'),
                huiText('y: world height; the stack grows upward from here'),
                huiText('z: world south'),
              ],
              onChanged: (Vec3 value) => _store.mutateHologram(
                'hologram position',
                (GlossHologramDoc edited) =>
                    edited.anchor.setPosition(value.x, value.y, value.z),
              ),
            ),
            HuiInlineIssues(_issuesFor(r'$.anchor.position')),
          ]),
        ),
      ],
    );
  }

  Widget _lines(GlossHologramDoc doc) => HuiLineListSection(
    title: huiText('Lines'),
    docKey: 'hologram.lines',
    addLabel: huiText('Add line'),
    itemCount: doc.lines.length,
    issues: _issuesFor('lines['),
    emptyBody: huiText(
      'Gloss loads the file and draws nothing at the anchor. Add a line '
      'to give the hologram something to say.',
    ),
    onAdd: () {
      final int next = doc.lines.length;
      _store.mutateHologram(
        'add line',
        (GlossHologramDoc edited) => edited.lines.add(''),
      );
      setState(() => _focusedLine = next);
    },
    tools: <Widget>[
      PlaceholderPicker(
        catalogs: component.catalogs,
        onPicked: _insertPlaceholder,
      ),
    ],
    onReorder: (int from, int to) =>
        _store.mutateHologram('reorder line', (GlossHologramDoc edited) {
          final String moved = edited.lines.removeAt(from);
          edited.lines.insert(to, moved);
        }),
    itemBuilder: (int index) => _lineRow(doc, index),
  );

  Widget _lineRow(GlossHologramDoc doc, int index) {
    final String line = doc.lines[index];
    return HuiLineRow(
      value: line,
      placeholder: huiText('&fText, %papi%, |animation.id|, {{ expression }}'),
      removeLabel: huiText('Delete line {number}', <String, Object?>{
        'number': index + 1,
      }),
      onChanged: (String value) => _editLine(index, value),
      onFocus: () => _focusedLine = index,
      preview: GlossTextLine(
        render: renderGlossLine(
          richText: true,
          line,
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
        ),
      ),
      onRemove: () =>
          _store.mutateHologram('delete line', (GlossHologramDoc edited) {
            if (index < edited.lines.length) edited.lines.removeAt(index);
          }),
    );
  }

  void _editLine(int index, String value) =>
      _store.mutateHologram('edit line', (GlossHologramDoc edited) {
        if (index < edited.lines.length) edited.lines[index] = value;
      });

  void _insertPlaceholder(String token) {
    final GlossHologramDoc? doc = _doc;
    if (doc == null || doc.lines.isEmpty) return;
    final int index = _focusedLine.clamp(0, doc.lines.length - 1);
    _editLine(index, doc.lines[index] + token);
  }
}
