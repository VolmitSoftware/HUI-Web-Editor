/// Inspector body for a Gloss hologram document.
///
/// Anchor world and position, then the reorderable line list — each row an
/// input plus a live Gloss-pipeline preview — with a placeholder picker that
/// inserts into the selected line. The revision is server-owned and shown,
/// not edited.
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
      _lines(doc),
    ]);
  }

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
