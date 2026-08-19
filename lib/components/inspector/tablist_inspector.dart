/// Inspector body for a Gloss tablist document: the header/footer pair with
/// pipeline previews, the groupListNames switch, and the nameFormats table
/// with $player/$group token chips plus a live preview of three sample
/// players resolved through the `chooseListName` mirror.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/gloss_text.dart';
import '../../logic/tablist_selection.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'animation_reference_picker.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';

/// The sample players the live preview resolves, mirroring the surface.
const List<({String name, String? group, bool op})> _samples =
    <({String name, String? group, bool op})>[
      (name: 'Steve', group: 'default', op: false),
      (name: 'Herobrine', group: 'admin', op: true),
      (name: 'Alex', group: 'vip', op: false),
    ];

class TablistInspector extends StatefulWidget {
  const TablistInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<TablistInspector> createState() => _TablistInspectorState();
}

/// Which text field the pickers append into.
enum _Focus { header, footer }

class _TablistInspectorState extends State<TablistInspector> {
  _Focus _focused = _Focus.header;

  EditorStore get _store => component.store;

  GlossTablistDoc? get _doc => _store.tablistDoc;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossTablistDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-tablist', <Widget>[
      _header(doc),
      _headerFooter(doc),
      _formats(doc),
    ]);
  }

  Widget _header(GlossTablistDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-tablist', <Widget>[
          const HuiEyebrow('Tablist'),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('tablist.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            'The tab screen: header and footer over the player grid, and '
            'per-group list names. Revision ${doc.revision} is server-owned '
            'and travels with the file.',
          ),
        ]),
      ]);

  Widget _pipelinePreview(String text) =>
      dom.div(classes: 'hui-hologram-line-preview', <Widget>[
        for (final String line in text.split('\n'))
          dom.div(<Widget>[
            GlossTextLine(
              render: renderGlossLine(
                line,
                animations: _store.workspaceAnimations,
                emoji: _store.workspaceEmoji,
              ),
            ),
          ]),
      ]);

  Widget _headerFooter(GlossTablistDoc doc) => InspectorSection(
    title: 'Header and footer',
    children: <Widget>[
      HuiSwitchRow(
        label: 'Use header and footer',
        help:
            'Off leaves the tab screen\'s top and bottom vanilla; the texts '
            'below go unused.',
        trailing: const HuiFieldHelp('tablist.useHeaderFooter'),
        value: doc.useHeaderFooter,
        onChanged: (bool value) => _store.mutateTablist(
          'tablist useHeaderFooter',
          (GlossTablistDoc edited) {
            edited.useHeaderFooter = value;
            edited.absentKeys.remove('useHeaderFooter');
          },
        ),
      ),
      HuiInlineIssues(_issuesFor(r'$.useHeaderFooter')),
      dom.div(classes: 'hui-hologram-lines-tools', <Widget>[
        AnimationReferencePicker(store: _store, onPicked: _insert),
      ]),
      HuiField(
        label: 'Header',
        trailing: const HuiFieldHelp('tablist.header'),
        help:
            'Above the player grid, through the text pipeline per viewer. '
            r'Use \n for extra lines.',
        control: dom.div(<Widget>[
          TextInput(
            value: doc.header,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: '&d&lGloss',
            onInput: (String value) => _store.mutateTablist(
              'tablist header',
              (GlossTablistDoc edited) {
                edited.header = value;
                edited.absentKeys.remove('header');
              },
            ),
            onFocus: () => _focused = _Focus.header,
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          _pipelinePreview(doc.header),
          HuiInlineIssues(_issuesFor(r'$.header')),
        ]),
      ),
      HuiField(
        label: 'Footer',
        trailing: const HuiFieldHelp('tablist.footer'),
        help: 'Below the player grid, same pipeline.',
        control: dom.div(<Widget>[
          TextInput(
            value: doc.footer,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: '&7VolmitSoftware.com',
            onInput: (String value) => _store.mutateTablist(
              'tablist footer',
              (GlossTablistDoc edited) {
                edited.footer = value;
                edited.absentKeys.remove('footer');
              },
            ),
            onFocus: () => _focused = _Focus.footer,
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          _pipelinePreview(doc.footer),
          HuiInlineIssues(_issuesFor(r'$.footer')),
        ]),
      ),
    ],
  );

  Widget _formats(GlossTablistDoc doc) {
    final List<String> keys = doc.nameFormats.keys.toList();
    return InspectorSection(
      title: 'List names',
      children: <Widget>[
        HuiSwitchRow(
          label: 'Group list names',
          help:
              'Off resets every player to their vanilla list name; the '
              'formats below go unused.',
          trailing: const HuiFieldHelp('tablist.groupListNames'),
          value: doc.groupListNames,
          onChanged: (bool value) => _store.mutateTablist(
            'tablist groupListNames',
            (GlossTablistDoc edited) {
              edited.groupListNames = value;
              edited.absentKeys.remove('groupListNames');
            },
          ),
        ),
        HuiInlineIssues(_issuesFor(r'$.groupListNames')),
        dom.div(classes: 'hui-tablist-token-chips', <Widget>[
          _tokenChip(r'$player', 'The player account name.'),
          _tokenChip(r'$group', 'The resolved group key.'),
        ]),
        for (final String key in keys) _formatRow(doc, key),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: () => _store.mutateTablist(
            'add format',
            (GlossTablistDoc edited) {
              String key = 'group';
              int suffix = 2;
              while (edited.nameFormats.containsKey(key)) {
                key = 'group-$suffix';
                suffix++;
              }
              edited.nameFormats[key] = r'&7$player';
              edited.absentKeys.remove('nameFormats');
            },
          ),
          child: const Text('Add format'),
        ),
        HuiInlineIssues(_issuesFor(r'$.nameFormats')),
        const HuiNote(
          'Resolution order: operators take _op first, then the player\'s '
          'primary group, then default; with no default the literal '
          r'$player fallback applies.',
        ),
        _livePreview(doc),
      ],
    );
  }

  Widget _tokenChip(String token, String hint) => dom.button(
    classes: 'hui-gloss-chip hui-tablist-token-chip',
    attributes: <String, String>{
      'type': 'button',
      'title': '$hint Click to append to the focused header/footer field.',
      'aria-label': 'Insert $token',
    },
    events: <String, EventCallback>{
      'click': (Object? _) => _insert(token),
    },
    <Widget>[Text(token)],
  );

  Widget _formatRow(GlossTablistDoc doc, String key) {
    final String value = doc.nameFormats[key] ?? '';
    return dom.div(classes: 'hui-tablist-format-row', <Widget>[
      TextInput(
        value: key,
        size: ComponentSize.sm,
        placeholder: 'vip',
        onInput: (String next) => _store.mutateTablist(
          'rename format',
          (GlossTablistDoc edited) {
            if (!edited.nameFormats.containsKey(key) ||
                edited.nameFormats.containsKey(next)) {
              return;
            }
            // Rebuild in place to keep the entry's position — the file is
            // insertion-ordered like the LinkedHashMap the plugin builds.
            final Map<String, String> rebuilt = <String, String>{
              for (final MapEntry<String, String> entry
                  in edited.nameFormats.entries)
                (entry.key == key ? next : entry.key): entry.value,
            };
            edited.nameFormats
              ..clear()
              ..addAll(rebuilt);
          },
        ),
        attributes: const <String, String>{
          'autocomplete': 'off',
          'spellcheck': 'false',
          'aria-label': 'Group key',
        },
      ),
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: r'&7$player',
        onInput: (String next) => _store.mutateTablist(
          'edit format',
          (GlossTablistDoc edited) {
            if (edited.nameFormats.containsKey(key)) {
              edited.nameFormats[key] = next;
            }
          },
        ),
        attributes: <String, String>{
          'autocomplete': 'off',
          'spellcheck': 'false',
          'aria-label': 'Format for $key',
        },
      ),
      HuiIconButton(
        label: 'Remove format $key',
        icon: ArcaneIcon.trash2(size: IconSize.sm),
        onPressed: () => _store.mutateTablist(
          'remove format',
          (GlossTablistDoc edited) => edited.nameFormats.remove(key),
        ),
      ),
    ]);
  }

  Widget _livePreview(GlossTablistDoc doc) => dom.div(
    classes: 'hui-tablist-live-preview',
    <Widget>[
      const HuiEyebrow('Live preview'),
      for (final ({String name, String? group, bool op}) sample in _samples)
        dom.div(classes: 'hui-tablist-live-row', <Widget>[
          dom.span(classes: 'hui-tablist-live-meta', <Widget>[
            Text(
              '${sample.name} — '
              '${sample.op ? 'op, ' : ''}group ${sample.group ?? 'none'}',
            ),
          ]),
          dom.span(classes: 'hui-tablist-live-name', <Widget>[
            GlossTextLine(render: renderGlossLine(_resolved(doc, sample))),
          ]),
        ]),
    ],
  );

  String _resolved(
    GlossTablistDoc doc,
    ({String name, String? group, bool op}) sample,
  ) {
    if (!doc.groupListNames) return sample.name;
    final GlossTablistChoice choice = glossTablistChooseListName(
      sample.op,
      sample.group,
      doc.effectiveNameFormats,
    );
    if (choice.template.trim().isEmpty) return sample.name;
    return glossTablistSubstituteTokens(
      choice.template,
      sample.name,
      choice.groupName,
    );
  }

  /// Appends a picked token to whichever of header/footer was focused last.
  void _insert(String token) {
    _store.mutateTablist('tablist insert', (GlossTablistDoc edited) {
      if (_focused == _Focus.header) {
        edited.header = edited.header + token;
        edited.absentKeys.remove('header');
      } else {
        edited.footer = edited.footer + token;
        edited.absentKeys.remove('footer');
      }
    });
  }
}
