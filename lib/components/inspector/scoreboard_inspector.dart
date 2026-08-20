/// Inspector body for a Gloss scoreboard document: title, the reorderable
/// line list with pipeline previews and missing-reference chips, the
/// animation reference picker and placeholder picker, and the selection
/// rules (primary, permission, groups).
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
import 'animation_reference_picker.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'line_list_section.dart';
import 'placeholder_picker.dart';

class ScoreboardInspector extends StatefulWidget {
  const ScoreboardInspector({
    required this.store,
    required this.catalogs,
    super.key,
  });

  final EditorStore store;
  final HuiCatalogs catalogs;

  @override
  State<ScoreboardInspector> createState() => _ScoreboardInspectorState();
}

class _ScoreboardInspectorState extends State<ScoreboardInspector> {
  /// The row the pickers insert into: the last focused line input, or -1 for
  /// the title.
  int _focusedLine = 0;

  EditorStore get _store => component.store;

  GlossScoreboardDoc? get _doc => _store.scoreboardDoc;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossScoreboardDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-scoreboard', <Widget>[
      _header(doc),
      _title(doc),
      _lines(doc),
      _selection(doc),
    ]);
  }

  Widget _header(GlossScoreboardDoc doc) => dom.div(
    classes: 'hui-inspector-headgroup',
    <Widget>[
      dom.div(classes: 'hui-inspector-header is-scoreboard', <Widget>[
        const HuiEyebrow('Scoreboard'),
        dom.div(classes: 'hui-inspector-title-row', <Widget>[
          dom.h2(classes: 'hui-inspector-title', <Widget>[Text(_store.menuId)]),
          const HuiFieldHelp('scoreboard.id'),
        ]),
      ]),
      const dom.p(classes: 'hui-inspector-lede', <Widget>[
        Text('The right-hand sidebar. Only the first 15 lines reach a client.'),
      ]),
      HuiRevisionRow(revision: doc.revision),
    ],
  );

  Widget _title(GlossScoreboardDoc doc) => InspectorSection(
    title: 'Title',
    children: <Widget>[
      HuiField(
        label: 'Title',
        required: true,
        trailing: const HuiFieldHelp('scoreboard.title'),
        help:
            'Centered above the lines. The rendered form is safely capped '
            'at 32 UTF-16 units, colour codes included.',
        control: dom.div(<Widget>[
          TextInput(
            value: doc.title,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: '&d&lGloss',
            onInput: (String value) => _store.mutateScoreboard(
              'scoreboard title',
              (GlossScoreboardDoc edited) => edited.title = value,
            ),
            onFocus: () => _focusedLine = -1,
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          dom.div(classes: 'hui-hologram-line-preview', <Widget>[
            GlossTextLine(
              render: renderGlossScoreboardTitle(
                doc.title,
                animations: _store.workspaceAnimations,
                emoji: _store.workspaceEmoji,
              ),
            ),
          ]),
          HuiInlineIssues(_issuesFor(r'$.title')),
        ]),
      ),
    ],
  );

  Widget _lines(GlossScoreboardDoc doc) => HuiLineListSection(
    title: 'Lines',
    docKey: 'scoreboard.lines',
    addLabel: 'Add line',
    itemCount: doc.lines.length,
    issues: _issuesFor('lines['),
    emptyBody:
        'The sidebar shows its title and nothing else. Add a line to put '
        'something under it.',
    onAdd: () {
      final int next = doc.lines.length;
      _store.mutateScoreboard(
        'add line',
        (GlossScoreboardDoc edited) => edited.lines.add(''),
      );
      setState(() => _focusedLine = next);
    },
    tools: <Widget>[
      AnimationReferencePicker(store: _store, onPicked: _insert),
      PlaceholderPicker(catalogs: component.catalogs, onPicked: _insert),
    ],
    onReorder: (int from, int to) =>
        _store.mutateScoreboard('reorder line', (GlossScoreboardDoc edited) {
          final String moved = edited.lines.removeAt(from);
          edited.lines.insert(to, moved);
        }),
    itemBuilder: (int index) => _lineRow(doc, index),
  );

  Widget _lineRow(GlossScoreboardDoc doc, int index) {
    final String line = doc.lines[index];
    final bool beyondRender = index >= glossBoardMaxLines;
    return HuiLineRow(
      value: line,
      placeholder: '&fText, %papi%, |animation.id|, {{ expression }}',
      removeLabel: 'Delete line ${index + 1}',
      beyondRender: beyondRender,
      onChanged: (String value) => _editLine(index, value),
      onFocus: () => _focusedLine = index,
      preview: GlossTextLine(
        render: renderGlossScoreboardLine(
          line,
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
        ),
      ),
      chips: <Widget>[
        ...huiMissingAnimationChips(
          line,
          _store.workspaceAnimations,
          where: 'in game',
        ),
        if (beyondRender)
          const dom.span(classes: 'hui-gloss-chip is-missing', <Widget>[
            Text('past line 15 — not rendered'),
          ]),
      ],
      onRemove: () =>
          _store.mutateScoreboard('delete line', (GlossScoreboardDoc edited) {
            if (index < edited.lines.length) edited.lines.removeAt(index);
          }),
    );
  }

  Widget _selection(GlossScoreboardDoc doc) => InspectorSection(
    title: 'Selection',
    children: <Widget>[
      HuiSwitchRow(
        label: 'Hide score numbers',
        help:
            'Removes the red numeric column for 1.20.3+ clients. Older '
            'server versions need ViaVersion\'s hide-scoreboard-numbers '
            'fallback for newer clients.',
        trailing: const HuiFieldHelp('scoreboard.hideNumbers'),
        value: doc.hideNumbers,
        onChanged: (bool value) => _store.mutateScoreboard(
          'scoreboard number visibility',
          (GlossScoreboardDoc edited) => edited.hideNumbers = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Primary board',
        help:
            'Volunteers this board as the default for players nothing else '
            'steers.',
        trailing: const HuiFieldHelp('scoreboard.primary'),
        value: doc.primary,
        onChanged: (bool value) => _store.mutateScoreboard(
          'scoreboard primary',
          (GlossScoreboardDoc edited) => edited.primary = value,
        ),
      ),
      HuiField(
        label: 'Permission',
        trailing: const HuiFieldHelp('scoreboard.permission'),
        help:
            '"default" means everyone. Anything else gates the board behind '
            'gloss.board.<permission>, which operators pass and players '
            'need granted.',
        control: dom.div(<Widget>[
          TextInput(
            value: doc.permission,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: 'default',
            onInput: (String value) => _store.mutateScoreboard(
              'scoreboard permission',
              (GlossScoreboardDoc edited) => edited.permission = value,
            ),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          if (doc.permissionGated)
            HuiNote(
              'Gated: players need '
              '$glossBoardPermissionNodePrefix${doc.effectivePermission}.',
            ),
          HuiInlineIssues(_issuesFor(r'$.permission')),
        ]),
      ),
      HuiField(
        label: 'Groups',
        trailing: const HuiFieldHelp('scoreboard.groups'),
        help:
            'Vault group names this board attaches to. Lowercased and '
            'deduplicated by the server.',
        control: dom.div(<Widget>[
          for (int index = 0; index < doc.groups.length; index++)
            dom.div(classes: 'hui-scoreboard-group-row', <Widget>[
              TextInput(
                value: doc.groups[index],
                size: ComponentSize.sm,
                fullWidth: true,
                placeholder: 'vip',
                onInput: (String value) => _store.mutateScoreboard(
                  'edit group',
                  (GlossScoreboardDoc edited) {
                    if (index < edited.groups.length) {
                      edited.groups[index] = value;
                    }
                  },
                ),
                attributes: const <String, String>{
                  'autocomplete': 'off',
                  'spellcheck': 'false',
                },
              ),
              HuiIconButton(
                label: 'Remove group',
                icon: ArcaneIcon.trash2(size: IconSize.sm),
                onPressed: () => _store.mutateScoreboard('remove group', (
                  GlossScoreboardDoc edited,
                ) {
                  if (index < edited.groups.length) {
                    edited.groups.removeAt(index);
                  }
                }),
              ),
            ]),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.plus(size: IconSize.sm),
            onPressed: () => _store.mutateScoreboard(
              'add group',
              (GlossScoreboardDoc edited) => edited.groups.add(''),
            ),
            child: const Text('Add group'),
          ),
          HuiInlineIssues(_issuesFor(r'$.groups')),
        ]),
      ),
    ],
  );

  void _editLine(int index, String value) =>
      _store.mutateScoreboard('edit line', (GlossScoreboardDoc edited) {
        if (index < edited.lines.length) edited.lines[index] = value;
      });

  /// Inserts a picked token at the end of the focused field: the title when
  /// it was focused last, otherwise the focused (or last) line.
  void _insert(String token) {
    final GlossScoreboardDoc? doc = _doc;
    if (doc == null) return;
    if (_focusedLine < 0) {
      _store.mutateScoreboard(
        'scoreboard title',
        (GlossScoreboardDoc edited) => edited.title = edited.title + token,
      );
      return;
    }
    if (doc.lines.isEmpty) {
      _store.mutateScoreboard(
        'add line',
        (GlossScoreboardDoc edited) => edited.lines.add(token),
      );
      return;
    }
    final int index = _focusedLine.clamp(0, doc.lines.length - 1);
    _editLine(index, doc.lines[index] + token);
  }
}
