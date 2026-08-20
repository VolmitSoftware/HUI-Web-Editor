/// The emoji surface: a searchable glyph grid of everything the workspace's
/// emoji stage can substitute, with the open document highlighted, and a
/// chat-preview line replaying `EmojiReplacer.apply` on a sample message.
///
/// The grid reads [EditorStore.workspaceEmoji] — the shipped catalog with the
/// workspace's emoji documents layered over it by id, sorted the way
/// `EmojiService.rebuild` sorts. Clicking a workspace-backed cell opens that
/// document; catalog-only cells are informational (the plugin extracts them
/// on first run, and creating a same-named document overrides them here).
///
/// With `gameContext` only the chat line survives, mounted into the shared
/// game-screen frame's chat region — that is the one place a player ever sees
/// an emoji document's work. The searchable grid is editor chrome and drops
/// out there.
///
/// Fidelity caveat, stated in the surface itself: glyphs render with the
/// browser's font fallback stack, not the Minecraft client font, so metrics
/// and coverage differ in game.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../gloss/gloss_game_screen.dart';

class EmojiView extends StatefulWidget {
  const EmojiView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;

  /// Mounts the chat line inside the shared Minecraft game-screen frame
  /// instead of the editor grid. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<EmojiView> createState() => _EmojiViewState();
}

class _EmojiViewState extends State<EmojiView> {
  String _query = '';

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant EmojiView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  List<GlossEmojiEntry> _filtered(List<GlossEmojiEntry> entries) {
    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return entries;
    return <GlossEmojiEntry>[
      for (final GlossEmojiEntry entry in entries)
        if (entry.id.toLowerCase().contains(needle) ||
            entry.trigger.toLowerCase().contains(needle) ||
            entry.glyph.contains(needle))
          entry,
    ];
  }

  /// Opens the workspace document behind a grid cell. Runtime ids are unique
  /// per kind, and the emoji view is only mounted while an emoji document is
  /// active, so the active kind is the emoji kind.
  void _open(GlossEmojiEntry entry) {
    for (final WorkspaceDoc doc in _store.workspace.docs) {
      if (doc.kind == _store.docKind && doc.runtimeId == entry.id) {
        _store.openDocument(doc.id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlossEmojiDoc? doc = _store.emojiDoc;
    if (doc == null) {
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.chat,
          label: 'Emoji in chat',
        );
      }
      return const dom.div(classes: 'hui-emoji-stage is-empty', <Widget>[]);
    }
    final String openId = _store.menuId;
    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.chat,
        label: 'Emoji in chat',
        child: _chatPreview(doc, openId),
      );
    }
    final List<GlossEmojiEntry> entries = _filtered(
      _store.workspaceEmoji.entries,
    );

    return dom.div(classes: 'hui-emoji-stage', <Widget>[
      _chatPreview(doc, openId),
      dom.div(classes: 'hui-emoji-tools', <Widget>[
        TextInput(
          value: _query,
          size: ComponentSize.sm,
          placeholder: 'Search name, trigger or glyph',
          onInput: (String value) => setState(() => _query = value),
          attributes: const <String, String>{
            'autocomplete': 'off',
            'spellcheck': 'false',
            'aria-label': 'Search emoji',
          },
        ),
        dom.span(classes: 'hui-emoji-count', <Widget>[
          Text(
            '${entries.length} of ${_store.workspaceEmoji.entries.length} '
            'emoji',
          ),
        ]),
      ]),
      dom.div(classes: 'hui-emoji-grid', <Widget>[
        for (final GlossEmojiEntry entry in entries) _cell(entry, openId),
      ]),
      const dom.div(classes: 'hui-emoji-readout', <Widget>[
        Text(
          'Glyphs render with the browser font stack here — coverage and '
          'metrics differ from the Minecraft client font in game. Workspace '
          'documents override same-named shipped emoji in these previews.',
        ),
      ]),
    ]);
  }

  /// The open document's substitution, replayed on a sample chat line the
  /// way `TextPipeline.chat` would after the emoji filter.
  Widget _chatPreview(GlossEmojiDoc doc, String openId) {
    final String token = ':$openId:';
    final String sample = doc.trigger.isEmpty
        ? 'SwiftSwamp smells >.< $token'
        : 'SwiftSwamp smells >.< $token ${doc.trigger}';
    final String substituted = glossApplyEmoji(sample, _store.workspaceEmoji);
    return dom.div(classes: 'hui-emoji-chat', <Widget>[
      dom.div(classes: 'hui-emoji-chat-line is-raw', <Widget>[
        const dom.span(classes: 'hui-emoji-chat-speaker', <Widget>[
          Text('<Magic_Psycho>'),
        ]),
        Text(' $sample'),
      ]),
      dom.div(classes: 'hui-emoji-chat-line', <Widget>[
        const dom.span(classes: 'hui-emoji-chat-speaker', <Widget>[
          Text('<Magic_Psycho>'),
        ]),
        Text(' $substituted'),
      ]),
      dom.div(classes: 'hui-emoji-chat-meta', <Widget>[
        Text(
          doc.enabled
              ? (doc.trigger.isEmpty
                    ? '$token substitutes; no trigger.'
                    : '$token and "${doc.trigger}" both substitute.')
              : 'Disabled: neither $token nor the trigger substitutes in '
                    'game.',
        ),
      ]),
    ]);
  }

  Widget _cell(GlossEmojiEntry entry, String openId) {
    final bool isOpen = entry.fromWorkspace && entry.id == openId;
    final List<String> classes = <String>[
      'hui-emoji-cell',
      if (isOpen) 'is-open',
      if (!entry.fromWorkspace) 'is-catalog',
      if (!entry.enabled) 'is-disabled',
    ];
    final String title = <String>[
      entry.token,
      if (entry.hasTrigger) 'trigger ${entry.trigger}',
      if (!entry.enabled) 'disabled',
      entry.fromWorkspace
          ? 'workspace document — click to open'
          : 'shipped catalog',
    ].join(' · ');
    return dom.button(
      classes: classes.join(' '),
      attributes: <String, String>{
        'type': 'button',
        'title': title,
        'aria-label': 'Emoji ${entry.id}',
        if (!entry.fromWorkspace) 'disabled': '',
      },
      events: <String, EventCallback>{
        if (entry.fromWorkspace) 'click': (Object? _) => _open(entry),
      },
      <Widget>[
        dom.span(classes: 'hui-emoji-cell-glyph', <Widget>[
          Text(entry.glyph.isEmpty ? '·' : entry.glyph),
        ]),
        dom.span(classes: 'hui-emoji-cell-name', <Widget>[Text(entry.id)]),
        if (entry.hasTrigger)
          dom.span(classes: 'hui-emoji-cell-trigger', <Widget>[
            Text(entry.trigger),
          ]),
      ],
    );
  }
}
