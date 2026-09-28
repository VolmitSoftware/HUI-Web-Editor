/// Inspector body for a Gloss MOTD document: the document icon, the pause-menu
/// server links, and the entry list with per-entry line editing (1..2 lines
/// each), hover sample, counts, version label, add/remove/duplicate, pipeline
/// previews with missing-reference chips, and the animation reference picker.
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
import 'image_picker_grid.dart';
import '../../services/image_library.dart';
import 'inspector_widgets.dart';
import 'gloss_visibility_editor.dart';
import '../../logic/gloss_show.dart';
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

  /// Issues under [path], minus the [except] subtrees — the entry card shows
  /// the favicon, sample and ping-extra issues next to their own fields, so
  /// its catch-all row must not repeat them.
  List<HuiIssue> _issuesFor(
    String path, {
    List<String> except = const <String>[],
  }) => _store.issues
      .where(
        (HuiIssue issue) =>
            issue.path.startsWith(path) &&
            !except.any((String excluded) => issue.path.startsWith(excluded)),
      )
      .toList();

  /// Issues on [path] itself. A link that names neither a type nor a label is
  /// reported on the link rather than on a field, so the row that chooses
  /// between them shows it — without swallowing the type's own issue, which
  /// its own field already shows.
  List<HuiIssue> _issuesAt(String path) =>
      _store.issues.where((HuiIssue issue) => issue.path == path).toList();

  @override
  Widget build(BuildContext context) {
    final GlossMotdDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-motd', <Widget>[
      _header(doc),
      _favicon(doc),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'motd.visibility',
        issues: _store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => _store.mutateMotd(
          'visibility',
          (GlossMotdDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      _links(doc),
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

  /// The document-wide server-list icon. A path under
  /// `plugins/Gloss/images/`, the same library every menu image comes from,
  /// so the field is the plain path editor the icon inspector uses.
  Widget _favicon(GlossMotdDoc doc) => HuiField(
    label: huiText('Server icon'),
    trailing: const HuiFieldHelp('motd.favicon'),
    help: huiText(
      'The 64x64 server-list icon under plugins/Gloss/images/, used by '
      'every entry. Blank keeps the vanilla one.',
    ),
    control: dom.div(<Widget>[
      TextInput(
        value: doc.favicon ?? '',
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText('server.png'),
        onChanged: (String value) => _store.mutateMotd(
          'server icon',
          (GlossMotdDoc edited) =>
              edited.favicon = value.isEmpty ? null : value,
        ),
        attributes: const <String, String>{
          'autocomplete': 'off',
          'spellcheck': 'false',
          'dir': 'ltr',
        },
      ),
      _faviconUpload(
        'motd-favicon-upload',
        (String path) => _store.mutateMotd(
          'server icon',
          (GlossMotdDoc edited) => edited.favicon = path,
        ),
      ),
      HuiInlineIssues(_issuesFor(r'$.favicon')),
    ]),
  );

  /// Server icons never go through the text-image upload path: that one fits
  /// every file into the 16x16 glyph budget, which would leave a favicon the
  /// server list refuses. [ImageLibrary.addFaviconsFromFiles] keeps the 64x64
  /// bytes and reports anything else against the field.
  Widget _faviconUpload(String inputId, void Function(String path) onPicked) {
    final ImageLibrary? images = _store.images;
    if (images == null) return const dom.div(<Widget>[]);
    return ImageUploadButton(
      images: images,
      inputId: inputId,
      multiple: false,
      label: huiText('Upload a 64x64 icon'),
      upload: images.addFaviconsFromFiles,
      onAdded: (List<String> paths) {
        if (paths.isNotEmpty) onPicked(paths.first);
      },
    );
  }

  /// Per-entry override of [_favicon]: the random pick changes the picture
  /// with the text.
  Widget _entryFavicon(GlossMotdEntry entry, int index) => HuiField(
    label: huiText('Icon override'),
    trailing: const HuiFieldHelp('motd.entries.favicon'),
    help: huiText('Replaces the document icon for this entry only.'),
    control: dom.div(<Widget>[
      TextInput(
        value: entry.favicon ?? '',
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText('event.png'),
        onChanged: (String value) =>
            _store.mutateMotd('entry icon', (GlossMotdDoc edited) {
              if (index < edited.entries.length) {
                edited.entries[index].favicon = value.isEmpty ? null : value;
              }
            }),
        attributes: const <String, String>{
          'autocomplete': 'off',
          'spellcheck': 'false',
          'dir': 'ltr',
        },
      ),
      _faviconUpload(
        'motd-entry-favicon-upload-$index',
        (String path) => _store.mutateMotd('entry icon', (GlossMotdDoc edited) {
          if (index < edited.entries.length) {
            edited.entries[index].favicon = path;
          }
        }),
      ),
      HuiInlineIssues(_issuesFor('entries[$index].favicon')),
    ]),
  );

  /// The pause-menu server links. Published once per document revision
  /// (`MotdService.publishLinks`), not per ping, so the order here is the
  /// order the client lists — which is why this list reorders and the entry
  /// list does not.
  Widget _links(GlossMotdDoc doc) => HuiLineListSection(
    title: huiText('Server links'),
    docKey: 'motd.links',
    sectionKey: 'motd.links',
    addLabel: huiText('Add link'),
    itemCount: doc.links.length,
    issues: _issuesFor(r'$.links'),
    description: huiText(
      'Up to {maximum} entries the client lists in its pause menu. Players '
      'who are already connected keep the list the server held when they '
      'joined.',
      <String, Object?>{'maximum': glossMotdMaxLinks},
    ),
    emptyBody: huiText(
      'The pause menu shows no Gloss links, which is what a server without '
      'this key does. Add one to publish it.',
    ),
    onAdd: () => _store.mutateMotd(
      'add link',
      (GlossMotdDoc edited) =>
          edited.links.add(GlossMotdLink(type: 'website', url: '')),
    ),
    onReorder: (int from, int to) =>
        _store.mutateMotd('reorder links', (GlossMotdDoc edited) {
          if (from >= edited.links.length) return;
          edited.links.insert(to, edited.links.removeAt(from));
        }),
    itemBuilder: (int index) => _linkCard(doc, index),
  );

  Widget _linkCard(GlossMotdDoc doc, int index) {
    final GlossMotdLink link = doc.links[index];
    final String path = 'links[$index]';
    return dom.div(classes: 'hui-motd-link-card', <Widget>[
      dom.div(classes: 'hui-motd-entry-head', <Widget>[
        dom.span(classes: 'hui-motd-entry-label', <Widget>[
          Text(huiText("Link {value}", <String, Object?>{'value': index + 1})),
        ]),
        HuiIconButton(
          label: huiText('Delete link'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onPressed: () =>
              _store.mutateMotd('delete link', (GlossMotdDoc edited) {
                if (index < edited.links.length) edited.links.removeAt(index);
              }),
        ),
      ]),
      HuiField(
        label: huiText('Wording'),
        trailing: const HuiFieldHelp('motd.links.type'),
        help: huiText(
          'A type uses the client\'s own wording in the player\'s language; a '
          'label publishes yours. A link needs one or the other.',
        ),
        control: dom.div(<Widget>[
          HuiSegmented(
            value: link.isLabelled ? 'label' : 'type',
            segments: <HuiSegment>[
              HuiSegment(value: 'type', label: huiText('Client label')),
              HuiSegment(value: 'label', label: huiText('My own label')),
            ],
            onChanged: (String value) =>
                _store.mutateMotd('link wording', (GlossMotdDoc edited) {
                  if (index >= edited.links.length) return;
                  final GlossMotdLink edit = edited.links[index];
                  if (value == 'type') {
                    edit.type = 'website';
                    edit.label = null;
                  } else {
                    edit.type = null;
                    edit.label = '';
                  }
                }),
          ),
          HuiInlineIssues(_issuesAt(path)),
        ]),
      ),
      if (link.isLabelled)
        _linkLabel(link, index, path)
      else
        _linkType(link, index, path),
      HuiField(
        label: huiText('Address'),
        trailing: const HuiFieldHelp('motd.links.url'),
        control: dom.div(<Widget>[
          TextInput(
            value: link.url,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: huiText('https://example.net'),
            onChanged: (String value) =>
                _store.mutateMotd('link address', (GlossMotdDoc edited) {
                  if (index < edited.links.length) {
                    edited.links[index].url = value;
                  }
                }),
            styles: huiTechnicalInputStyles,
            attributes: huiTechnicalInputAttributes,
          ),
          HuiInlineIssues(_issuesFor('$path.url')),
        ]),
      ),
    ]);
  }

  Widget _linkType(GlossMotdLink link, int index, String path) => HuiField(
    label: huiText('Type'),
    trailing: const HuiFieldHelp('motd.links.type'),
    control: dom.div(<Widget>[
      ArcaneSelect(
        value: link.type ?? '',
        options: <ArcaneSelectOption>[
          for (final String type in glossMotdLinkTypes)
            ArcaneSelectOption(value: type, label: type),
        ],
        onChanged: (String value) =>
            _store.mutateMotd('link type', (GlossMotdDoc edited) {
              if (index < edited.links.length) {
                edited.links[index].type = value;
              }
            }),
      ),
      HuiInlineIssues(_issuesFor('$path.type')),
    ]),
  );

  Widget _linkLabel(GlossMotdLink link, int index, String path) => HuiField(
    label: huiText('Label'),
    trailing: const HuiFieldHelp('motd.links.label'),
    control: dom.div(<Widget>[
      TextInput(
        value: link.label ?? '',
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText('&bStore'),
        onChanged: (String value) =>
            _store.mutateMotd('link label', (GlossMotdDoc edited) {
              if (index < edited.links.length) {
                edited.links[index].label = value;
              }
            }),
        attributes: const <String, String>{
          'autocomplete': 'off',
          'spellcheck': 'false',
        },
      ),
      GlossTextLine(
        render: renderGlossLine(
          link.label ?? '',
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
        ),
      ),
      HuiInlineIssues(_issuesFor('$path.label')),
    ]),
  );

  /// The hover list under the player count. Same rows as the entry lines,
  /// because it is the same pipeline — only the limit differs.
  Widget _sample(GlossMotdEntry entry, int index) => HuiLineListSection(
    title: huiText('Hover sample'),
    docKey: 'motd.entries.sample',
    sectionKey: 'motd.entries.sample',
    addLabel: huiText('Add sample line'),
    itemCount: entry.sample.length,
    issues: _issuesFor('entries[$index].sample'),
    emptyBody: huiText(
      'The count keeps the vanilla hover list of real player names. Add a '
      'line to replace it.',
    ),
    onAdd: () => _store.mutateMotd('add sample line', (GlossMotdDoc edited) {
      if (index < edited.entries.length) {
        edited.entries[index].sample.add('');
      }
    }),
    onReorder: (int from, int to) =>
        _store.mutateMotd('reorder sample lines', (GlossMotdDoc edited) {
          if (index >= edited.entries.length) return;
          final List<String> sample = edited.entries[index].sample;
          if (from >= sample.length) return;
          sample.insert(to, sample.removeAt(from));
        }),
    itemBuilder: (int line) => _sampleRow(entry, index, line),
  );

  Widget _sampleRow(GlossMotdEntry entry, int index, int line) {
    final String text = entry.sample[line];
    return HuiLineRow(
      value: text,
      placeholder: huiText('&7Now playing'),
      removeLabel: huiText(
        'Delete sample line {line} of entry {entry}',
        <String, Object?>{'line': line + 1, 'entry': index + 1},
      ),
      beyondRender: line >= glossMotdMaxSampleLines,
      onChanged: (String value) =>
          _store.mutateMotd('edit sample line', (GlossMotdDoc edited) {
            if (index < edited.entries.length &&
                line < edited.entries[index].sample.length) {
              edited.entries[index].sample[line] = value;
            }
          }),
      preview: GlossTextLine(
        render: renderGlossLine(
          text,
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
          viewerAware: false,
        ),
      ),
      chips: <Widget>[
        ...huiMissingAnimationChips(
          text,
          _store.workspaceAnimations,
          where: 'in the server list',
        ),
        if (line >= glossMotdMaxSampleLines)
          dom.span(classes: 'hui-gloss-chip is-missing', <Widget>[
            Text(
              huiText(
                'past line {maximum} — Gloss rejects this file',
                <String, Object?>{'maximum': glossMotdMaxSampleLines},
              ),
            ),
          ]),
      ],
      onRemove: () =>
          _store.mutateMotd('delete sample line', (GlossMotdDoc edited) {
            if (index < edited.entries.length &&
                line < edited.entries[index].sample.length) {
              edited.entries[index].sample.removeAt(line);
            }
          }),
    );
  }

  /// The three fields `applyExtras` sends beside the text. `max` is plain
  /// Bukkit; the other two need Paper's ping event, which the help says.
  Widget _pingExtras(GlossMotdEntry entry, int index) =>
      dom.div(classes: 'hui-motd-ping-extras', <Widget>[
        _pingField(
          label: huiText('Online count'),
          docKey: 'motd.entries.online',
          help: huiText(
            'Text that has to render to a number. Blank keeps the real count. '
            'Needs Paper.',
          ),
          placeholder: huiText('{{ server.online }}'),
          value: entry.online,
          path: 'entries[$index].online',
          historyLabel: 'online count',
          apply: (GlossMotdDoc edited, String? value) =>
              edited.entries[index].online = value,
          index: index,
        ),
        _pingField(
          label: huiText('Max players'),
          docKey: 'motd.entries.max',
          help: huiText(
            'Text that has to render to a number. Blank keeps the real slot '
            'count. Works on Spigot too.',
          ),
          placeholder: huiText('{{ server.maxPlayers }}'),
          value: entry.max,
          path: 'entries[$index].max',
          historyLabel: 'max players',
          apply: (GlossMotdDoc edited, String? value) =>
              edited.entries[index].max = value,
          index: index,
        ),
        _pingField(
          label: huiText('Version label'),
          docKey: 'motd.entries.version',
          help: huiText(
            'Shown where the ping bars sit, and only when the player\'s '
            'client is on another protocol. Needs Paper.',
          ),
          placeholder: huiText('&cOutdated'),
          value: entry.version,
          path: 'entries[$index].version',
          historyLabel: 'version label',
          apply: (GlossMotdDoc edited, String? value) =>
              edited.entries[index].version = value,
          index: index,
        ),
      ]);

  Widget _pingField({
    required String label,
    required String docKey,
    required String help,
    required String placeholder,
    required String? value,
    required String path,
    required String historyLabel,
    required void Function(GlossMotdDoc edited, String? value) apply,
    required int index,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(docKey),
    help: help,
    control: dom.div(<Widget>[
      TextInput(
        value: value ?? '',
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: placeholder,
        onChanged: (String next) =>
            _store.mutateMotd(historyLabel, (GlossMotdDoc edited) {
              if (index < edited.entries.length) {
                apply(edited, next.isEmpty ? null : next);
              }
            }),
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      GlossTextLine(
        render: renderGlossLine(
          value ?? '',
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
          viewerAware: false,
        ),
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

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
      _entryFavicon(entry, index),
      _sample(entry, index),
      _pingExtras(entry, index),
      HuiInlineIssues(
        _issuesFor(
          'entries[$index]',
          except: <String>[
            'entries[$index].favicon',
            'entries[$index].sample',
            'entries[$index].online',
            'entries[$index].max',
            'entries[$index].version',
          ],
        ),
      ),
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
