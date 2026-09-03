/// Inspector body for a Gloss MOTD document: the entry list with per-entry
/// line editing (1..2 lines each), add/remove/duplicate, pipeline previews
/// with missing-reference chips, and the animation reference picker.
///
/// No placeholder picker on purpose: `MotdService` renders through
/// `renderStatic`, which never expands PlaceholderAPI tokens (a ping has no
/// viewer), so offering the picker here would teach a token that stays
/// literal in the server list.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'animation_reference_picker.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'line_list_section.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class MotdInspector extends StatefulWidget {
  const MotdInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<MotdInspector> createState() => _MotdInspectorState();
}

class _MotdInspectorState extends State<MotdInspector> {
  /// Where the reference picker inserts: the last focused (entry, line).
  int _focusedEntry = 0;
  int _focusedLine = 0;

  EditorStore get _store => component.store;

  GlossMotdDoc? get _doc => _store.motdDoc;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossMotdDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-motd', <Widget>[
      _header(doc),
      _entries(doc),
    ]);
  }

  Widget _header(GlossMotdDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-motd', <Widget>[
          HuiEyebrow(huiText('MOTD')),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('motd.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText(
              'The server-list text. Every ping picks one entry at random.',
            ),
          ),
        ]),
        HuiRevisionRow(revision: doc.revision),
      ]);

  Widget _entries(GlossMotdDoc doc) => HuiLineListSection(
    title: huiText('Entries'),
    docKey: 'motd.entries',
    addLabel: huiText('Add entry'),
    itemCount: doc.entries.length,
    issues: _issuesFor(r'$.entries'),
    emptyTone: HuiNoteTone.danger,
    emptyBody: huiText(
      'Gloss rejects a MOTD file with no entries, so the server list '
      'falls back to the vanilla line. Add one to make the document '
      'loadable.',
    ),
    onAdd: () {
      final int next = doc.entries.length;
      _store.mutateMotd(
        'add entry',
        (GlossMotdDoc edited) =>
            edited.entries.add(GlossMotdEntry(lines: <String>[''])),
      );
      setState(() {
        _focusedEntry = next;
        _focusedLine = 0;
      });
    },
    tools: <Widget>[AnimationReferencePicker(store: _store, onPicked: _insert)],
    // Entries are picked at random, so their order carries no meaning and a
    // drag handle would imply one.
    itemBuilder: (int index) => _entryCard(doc, index),
  );

  Widget _entryCard(GlossMotdDoc doc, int index) {
    final GlossMotdEntry entry = doc.entries[index];
    return dom.div(classes: 'hui-motd-entry-card', <Widget>[
      dom.div(classes: 'hui-motd-entry-head', <Widget>[
        dom.span(classes: 'hui-motd-entry-label', <Widget>[
          Text(huiText("Entry {value}", <String, Object?>{'value': index + 1})),
        ]),
        dom.span(classes: 'hui-motd-entry-actions', <Widget>[
          const HuiFieldHelp('motd.lines'),
          HuiIconButton(
            label: huiText('Duplicate entry'),
            icon: ArcaneIcon.copy(size: IconSize.sm),
            onPressed: () => _store.mutateMotd('duplicate entry', (
              GlossMotdDoc edited,
            ) {
              if (index < edited.entries.length) {
                edited.entries.insert(index + 1, edited.entries[index].copy());
              }
            }),
          ),
          HuiIconButton(
            label: huiText('Delete entry'),
            icon: ArcaneIcon.trash2(size: IconSize.sm),
            onPressed: () =>
                _store.mutateMotd('delete entry', (GlossMotdDoc edited) {
                  if (index < edited.entries.length) {
                    edited.entries.removeAt(index);
                  }
                }),
          ),
        ]),
      ]),
      for (int line = 0; line < entry.lines.length; line++)
        _lineRow(entry, index, line),
      if (entry.lines.length < glossMotdMaxLinesPerEntry)
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: () => _store.mutateMotd('add line', (GlossMotdDoc edited) {
            if (index < edited.entries.length) {
              edited.entries[index].lines.add('');
            }
          }),
          label: huiText('Add second line'),
        ),
      HuiInlineIssues(_issuesFor('entries[$index]')),
    ]);
  }

  Widget _lineRow(GlossMotdEntry entry, int entryIndex, int lineIndex) {
    final String line = entry.lines[lineIndex];
    final bool beyondRender = lineIndex >= glossMotdMaxLinesPerEntry;
    return HuiLineRow(
      value: line,
      placeholder: huiText('&dA glossy server'),
      removeLabel: huiText(
        'Delete line {line} of entry {entry}',
        <String, Object?>{'line': lineIndex + 1, 'entry': entryIndex + 1},
      ),
      beyondRender: beyondRender,
      onChanged: (String value) => _editLine(entryIndex, lineIndex, value),
      onFocus: () {
        _focusedEntry = entryIndex;
        _focusedLine = lineIndex;
      },
      preview: GlossTextLine(
        render: renderGlossLine(
          line,
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
        ),
      ),
      chips: <Widget>[
        ...huiMissingAnimationChips(
          line,
          _store.workspaceAnimations,
          where: 'in the server list',
        ),
        if (beyondRender)
          dom.span(classes: 'hui-gloss-chip is-missing', <Widget>[
            Text(huiText('past line 2 — Gloss rejects this entry')),
          ]),
      ],
      onRemove: () => _store.mutateMotd('delete line', (GlossMotdDoc edited) {
        if (entryIndex < edited.entries.length &&
            lineIndex < edited.entries[entryIndex].lines.length) {
          edited.entries[entryIndex].lines.removeAt(lineIndex);
        }
      }),
    );
  }

  void _editLine(int entryIndex, int lineIndex, String value) =>
      _store.mutateMotd('edit line', (GlossMotdDoc edited) {
        if (entryIndex < edited.entries.length &&
            lineIndex < edited.entries[entryIndex].lines.length) {
          edited.entries[entryIndex].lines[lineIndex] = value;
        }
      });

  /// Inserts a picked token at the end of the focused line, or the last line
  /// of the focused entry when the focus has drifted out of range.
  void _insert(String token) {
    final GlossMotdDoc? doc = _doc;
    if (doc == null || doc.entries.isEmpty) return;
    final int entryIndex = _focusedEntry.clamp(0, doc.entries.length - 1);
    final GlossMotdEntry entry = doc.entries[entryIndex];
    if (entry.lines.isEmpty) {
      _store.mutateMotd('add line', (GlossMotdDoc edited) {
        if (entryIndex < edited.entries.length) {
          edited.entries[entryIndex].lines.add(token);
        }
      });
      return;
    }
    final int lineIndex = _focusedLine.clamp(0, entry.lines.length - 1);
    _editLine(entryIndex, lineIndex, entry.lines[lineIndex] + token);
  }
}
