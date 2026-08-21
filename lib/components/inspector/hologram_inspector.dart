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
import 'line_list_section.dart';
import 'placeholder_picker.dart';

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
      _anchor(doc),
      _presentation(doc),
      _lines(doc),
    ]);
  }

  Widget _presentation(GlossHologramDoc doc) => InspectorSection(
    title: 'Presentation',
    children: <Widget>[
      HuiSwitchRow(
        label: 'See through blocks',
        value: doc.seeThrough,
        trailing: const HuiFieldHelp('hologram.seeThrough'),
        onChanged: (bool value) => _store.mutateHologram(
          'hologram visibility',
          (GlossHologramDoc edited) {
            edited.seeThrough = value;
            edited.absentKeys.remove('seeThrough');
          },
        ),
      ),
      HuiField(
        label: 'Billboard',
        trailing: const HuiFieldHelp('hologram.billboard'),
        help: 'Which axes the entity may turn on to face a viewer.',
        defaultValue: 'CENTER',
        onReset: doc.billboard == glossHologramDefaultBillboard
            ? null
            : () => _setBillboard(glossHologramDefaultBillboard),
        control: dom.div(<Widget>[
          ArcaneSelect(
            value: doc.billboard,
            size: ComponentSize.sm,
            fullWidth: true,
            options: const <ArcaneSelectOption>[
              ArcaneSelectOption(
                label: 'Center — faces the viewer on both axes',
                value: 'CENTER',
              ),
              ArcaneSelectOption(
                label: 'Vertical — yaws to the viewer, keeps its pitch',
                value: 'VERTICAL',
              ),
              ArcaneSelectOption(
                label: 'Horizontal — pitches to the viewer, keeps its yaw',
                value: 'HORIZONTAL',
              ),
              ArcaneSelectOption(
                label: 'Fixed — never turns',
                value: 'FIXED',
              ),
            ],
            onChange: _setBillboard,
          ),
          HuiInlineIssues(_issuesFor(r'$.billboard')),
        ]),
      ),
      _angle(
        label: 'Yaw',
        docKey: 'hologram.yaw',
        path: r'$.yaw',
        value: doc.yaw,
        limit: glossHologramMaxYawDegrees,
        used: doc.billboard == 'FIXED' || doc.billboard == 'HORIZONTAL',
        help: '0 faces south, 90 faces west, 180 north, -90 east.',
        onChanged: (double value) => _store.mutateHologram(
          'hologram yaw',
          (GlossHologramDoc edited) {
            edited.yaw = value;
            edited.absentKeys.remove('yaw');
          },
        ),
      ),
      _angle(
        label: 'Pitch',
        docKey: 'hologram.pitch',
        path: r'$.pitch',
        value: doc.pitch,
        limit: glossHologramMaxPitchDegrees,
        used: doc.billboard == 'FIXED' || doc.billboard == 'VERTICAL',
        help: 'Positive tips the face downward, negative tips it up.',
        onChanged: (double value) => _store.mutateHologram(
          'hologram pitch',
          (GlossHologramDoc edited) {
            edited.pitch = value;
            edited.absentKeys.remove('pitch');
          },
        ),
      ),
    ],
  );

  void _setBillboard(String value) => _store.mutateHologram(
    'hologram billboard',
    (GlossHologramDoc edited) {
      edited.billboard = value;
      edited.absentKeys.remove('billboard');
    },
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
        ? '$help Degrees, -${limit.toInt()} to ${limit.toInt()}.'
        : 'The current billboard mode turns this axis itself, so this value '
              'never reaches the screen.',
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

  Widget _header(GlossHologramDoc doc) => dom.div(
    classes: 'hui-inspector-headgroup',
    <Widget>[
      dom.div(classes: 'hui-inspector-header is-hologram', <Widget>[
        const HuiEyebrow('Hologram'),
        dom.div(classes: 'hui-inspector-title-row', <Widget>[
          dom.h2(classes: 'hui-inspector-title', <Widget>[Text(_store.menuId)]),
          const HuiFieldHelp('hologram.id'),
        ]),
      ]),
      const dom.p(classes: 'hui-inspector-lede', <Widget>[
        Text('Every line joins into one TextDisplay at a world anchor.'),
      ]),
      // The revision used to be a clause in that sentence, where it read as
      // prose about the document rather than as the value it is — and the
      // written help for it had nowhere to mount.
      HuiRevisionRow(revision: doc.revision, docKey: 'hologram.revision'),
    ],
  );

  Widget _anchor(GlossHologramDoc doc) {
    final List<double> position = doc.anchor.position;
    return InspectorSection(
      title: 'Anchor',
      children: <Widget>[
        HuiField(
          label: 'World',
          required: true,
          trailing: const HuiFieldHelp('hologram.anchor.world'),
          help: 'The world the hologram stands in.',
          control: dom.div(<Widget>[
            TextInput(
              value: doc.anchor.world,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: 'world',
              onInput: (String value) => _store.mutateHologram(
                'hologram world',
                (GlossHologramDoc edited) => edited.anchor.world = value,
              ),
              attributes: const <String, String>{
                'autocomplete': 'off',
                'spellcheck': 'false',
              },
            ),
            HuiInlineIssues(_issuesFor(r'$.anchor.world')),
          ]),
        ),
        HuiField(
          label: 'Position',
          required: true,
          trailing: const HuiFieldHelp('hologram.anchor.position'),
          help: 'Block coordinates of the TextDisplay entity.',
          control: dom.div(<Widget>[
            HuiVec3Field(
              value: Vec3(position[0], position[1], position[2]),
              step: 0.5,
              decimals: 2,
              // World coordinates, not a menu-space offset: the shared hints
              // would say "right of the player", which is wrong here.
              axisHints: const <String>[
                'x: world east',
                'y: world height; the stack grows upward from here',
                'z: world south',
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
    title: 'Lines',
    docKey: 'hologram.lines',
    addLabel: 'Add line',
    itemCount: doc.lines.length,
    issues: _issuesFor('lines['),
    emptyBody:
        'Gloss loads the file and draws nothing at the anchor. Add a line '
        'to give the hologram something to say.',
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
      placeholder: '&fText, %papi%, |animation.id|, {{ expression }}',
      removeLabel: 'Delete line ${index + 1}',
      onChanged: (String value) => _editLine(index, value),
      onFocus: () => _focusedLine = index,
      preview: GlossTextLine(
        render: renderGlossLine(
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
