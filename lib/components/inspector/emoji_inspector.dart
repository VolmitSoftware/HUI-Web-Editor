/// Inspector body for a Gloss emoji document: the token identity, the emoji
/// value with its resolved glyph, the optional trigger, and the enabled
/// switch.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';

class EmojiInspector extends StatefulWidget {
  const EmojiInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<EmojiInspector> createState() => _EmojiInspectorState();
}

class _EmojiInspectorState extends State<EmojiInspector> {
  EditorStore get _store => component.store;

  GlossEmojiDoc? get _doc => _store.emojiDoc;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossEmojiDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-emoji', <Widget>[
      _header(doc),
      _value(doc),
      _behavior(doc),
    ]);
  }

  Widget _header(GlossEmojiDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-emoji', <Widget>[
          const HuiEyebrow('Emoji'),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('emoji.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            'Chat token :${_store.menuId}: — the document id names it, so '
            'renaming the document renames the token. Revision '
            '${doc.revision} is server-owned and travels with the file.',
          ),
        ]),
      ]);

  Widget _value(GlossEmojiDoc doc) => InspectorSection(
    title: 'Glyph',
    children: <Widget>[
      HuiField(
        label: 'Emoji',
        required: true,
        trailing: const HuiFieldHelp('emoji.emoji'),
        help:
            'A literal glyph, or U+XXXX; escapes (e.g. U+2764; for a heart). '
            'Escapes resolve once at load.',
        control: dom.div(<Widget>[
          TextInput(
            value: doc.emoji,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: 'U+2764;',
            onInput: (String value) => _store.mutateEmoji(
              'emoji value',
              (GlossEmojiDoc edited) => edited.emoji = value,
            ),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          dom.div(classes: 'hui-emoji-resolved', <Widget>[
            dom.span(classes: 'hui-emoji-resolved-glyph', <Widget>[
              Text(doc.resolvedGlyph.isEmpty ? '·' : doc.resolvedGlyph),
            ]),
            const dom.span(classes: 'hui-emoji-resolved-note', <Widget>[
              Text('resolved (browser font, not the MC font)'),
            ]),
          ]),
          HuiInlineIssues(_issuesFor(r'$.emoji')),
        ]),
      ),
    ],
  );

  Widget _behavior(GlossEmojiDoc doc) => InspectorSection(
    title: 'Chat behavior',
    children: <Widget>[
      HuiField(
        label: 'Trigger',
        trailing: const HuiFieldHelp('emoji.trigger'),
        help:
            'Optional second spelling replaced in chat, e.g. <3. Empty means '
            'only the :token: substitutes.',
        control: dom.div(<Widget>[
          TextInput(
            value: doc.trigger,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: '<3',
            onInput: (String value) => _store.mutateEmoji(
              'emoji trigger',
              (GlossEmojiDoc edited) => edited.trigger = value,
            ),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          HuiInlineIssues(_issuesFor(r'$.trigger')),
        ]),
      ),
      HuiSwitchRow(
        label: 'Enabled',
        help:
            'Disabled emoji stay listed but never substitute — the replacer '
            'skips them.',
        trailing: const HuiFieldHelp('emoji.enabled'),
        value: doc.enabled,
        onChanged: (bool value) => _store.mutateEmoji(
          'emoji enabled',
          (GlossEmojiDoc edited) => edited.enabled = value,
        ),
      ),
      HuiInlineIssues(_issuesFor(r'$.enabled')),
    ],
  );
}
