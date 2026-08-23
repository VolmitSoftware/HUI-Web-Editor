/// The MOTD surface: a server-list mock row, the way the vanilla multiplayer
/// screen draws it.
///
/// Fidelity notes, all from `MotdService.java`: every ping picks ONE random
/// entry (`handlePing`: `ThreadLocalRandom.nextInt(entries.size())`) and
/// renders its joined lines through `renderStatic` — text functions (so
/// `|animation.<id>|`) and colours apply, PlaceholderAPI tokens stay literal
/// because a ping has no viewer. The entry chips address one entry directly.
/// The ping bars and player count are
/// cosmetic — the client fills those, never the plugin.
///
/// With `gameContext` the server row mounts into the shared game-screen frame
/// as the multiplayer GUI screen it already looks like — no HUD behind it,
/// because a GUI screen replaces the world view.
///
/// Holds one sampled frame until Refresh is pressed, matching the client: an
/// already displayed server-list row is not redrawn between status pings.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class MotdView extends StatefulWidget {
  const MotdView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;

  /// Mounts the server row inside the shared Minecraft game-screen frame
  /// instead of the editor stage. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<MotdView> createState() => _MotdViewState();
}

class _MotdViewState extends State<MotdView> {
  /// The previewed entry. Clamped on read: the inspector can shorten the
  /// list under it.
  int _entryIndex = 0;
  int _sampledAtMs = DateTime.now().millisecondsSinceEpoch;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant MotdView oldComponent) {
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

  void _refreshSample() {
    setState(() => _sampledAtMs = DateTime.now().millisecondsSinceEpoch);
  }

  void _selectEntry(int index) {
    setState(() {
      _entryIndex = index;
      _sampledAtMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GlossMotdDoc? doc = _store.motdDoc;
    if (doc == null) {
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.screen,
          label: huiText('Server list entry in game'),
        );
      }
      return const dom.div(classes: 'hui-motd-stage is-empty', <Widget>[]);
    }
    final GlossAnimationResolver animations = _store.workspaceAnimations;
    final int shown = doc.entries.isEmpty
        ? 0
        : _entryIndex.clamp(0, doc.entries.length - 1);
    final GlossMotdEntry? entry = doc.entries.isEmpty
        ? null
        : doc.entries[shown];
    final List<String> lines = entry == null
        ? const <String>[]
        : entry.lines.take(glossMotdMaxLinesPerEntry).toList();
    final int nowMs = _sampledAtMs;

    final Widget row = dom.div(classes: 'hui-motd-row', <Widget>[
      const dom.div(classes: 'hui-motd-icon', <Widget>[
        dom.span(classes: 'hui-motd-icon-glyph', <Widget>[Text('▚')]),
      ]),
      dom.div(classes: 'hui-motd-row-body', <Widget>[
        dom.div(classes: 'hui-motd-row-head', <Widget>[
          dom.span(classes: 'hui-motd-server-name', <Widget>[
            Text(huiText('My Server')),
          ]),
          dom.span(classes: 'hui-motd-row-status', <Widget>[
            const dom.span(classes: 'hui-motd-players', <Widget>[
              Text('17/100'),
            ]),
            dom.span(classes: 'hui-motd-ping', <Widget>[
              for (int bar = 0; bar < 5; bar++)
                dom.span(
                  classes: 'hui-motd-ping-bar${bar < 4 ? ' is-filled' : ''}',
                  const <Widget>[],
                ),
            ]),
          ]),
        ]),
        if (entry == null)
          dom.div(classes: 'hui-motd-line is-blank', <Widget>[
            Text(huiText('No entries — Gloss would reject this file.')),
          ])
        else
          for (final String line in lines)
            dom.div(classes: 'hui-motd-line', <Widget>[
              GlossTextLine(
                render: renderGlossLine(
                  line,
                  animations: animations,
                  emoji: _store.workspaceEmoji,
                  nowMs: nowMs,
                ),
              ),
            ]),
      ]),
    ]);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.screen,
        label: huiText('Server list entry in game'),
        controls: <Widget>[_refresh()],
        child: dom.div(classes: 'hui-motd-screen', <Widget>[row]),
      );
    }

    return dom.div(classes: 'hui-motd-stage', <Widget>[
      GlossPreviewZoom(
        label: huiText('MOTD preview'),
        child: dom.div(classes: 'hui-motd-screen', <Widget>[
          row,
          dom.div(classes: 'hui-motd-controls', <Widget>[
            dom.span(classes: 'hui-motd-entry-label', <Widget>[
              Text(huiText('Preview entry')),
            ]),
            dom.div(classes: 'hui-motd-entry-chips', <Widget>[
              for (int index = 0; index < doc.entries.length; index++)
                dom.button(
                  classes:
                      'hui-motd-entry-chip${index == shown ? ' is-active' : ''}',
                  attributes: <String, String>{
                    'type': 'button',
                    'aria-label': huiText(
                      "Preview entry {value}",
                      <String, Object?>{'value': index + 1},
                    ),
                  },
                  events: <String, EventCallback>{
                    'click': (Object? _) => _selectEntry(index),
                  },
                  <Widget>[
                    Text(
                      huiText("{value}", <String, Object?>{'value': index + 1}),
                    ),
                  ],
                ),
            ]),
            _refresh(),
          ]),
        ]),
      ),
      dom.div(classes: 'hui-motd-readout', <Widget>[
        Text(_readout(doc, entry, shown)),
      ]),
    ]);
  }

  Widget _refresh() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _refreshSample,
    attributes: <String, String>{
      'aria-label': huiText('Refresh'),
      'title': huiText('Refresh'),
    },
    child: ArcaneIcon.refreshCcw(size: IconSize.sm),
  );

  String _readout(GlossMotdDoc doc, GlossMotdEntry? entry, int shown) {
    final List<String> parts = <String>[
      doc.entries.isEmpty
          ? huiText('no entries')
          : huiText(
              'entry {current} of {total} — every ping picks one at random',
              <String, Object?>{
                'current': shown + 1,
                'total': doc.entries.length,
              },
            ),
      if (entry != null && entry.lines.length > glossMotdMaxLinesPerEntry)
        huiPlural(
          'motd.readout.excess-lines',
          entry.lines.length,
          oneEnglish: 'entry has {count} line; Gloss rejects past {maximum}',
          otherEnglish: 'entry has {count} lines; Gloss rejects past {maximum}',
          arguments: <String, Object?>{'maximum': glossMotdMaxLinesPerEntry},
        ),
      huiText('placeholders stay literal (a ping has no viewer)'),
    ];
    return parts.join(' · ');
  }
}
