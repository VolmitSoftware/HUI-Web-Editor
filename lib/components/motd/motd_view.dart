/// The MOTD surface: a server-list mock row, the way the vanilla multiplayer
/// screen draws it.
///
/// Fidelity notes, all from `MotdService.java`: every ping picks ONE random
/// entry (`handlePing`: `ThreadLocalRandom.nextInt(entries.size())`) and
/// renders its joined lines through `renderStatic` — text functions (so
/// `|animation.<id>|`) and colours apply, PlaceholderAPI tokens stay literal
/// because a ping has no viewer. Shuffle preview replays that pick; the
/// entry chips address one entry directly. The ping bars and player count are
/// cosmetic — the client fills those, never the plugin.
///
/// Owns a playback clock while the shown entry plays an animation and the
/// store's animations toggle is on. Mounted only while the MOTD view is
/// active.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';

/// Animation repaint period, matching the hologram stage.
const Duration _tickPeriod = Duration(milliseconds: 100);

class MotdView extends StatefulWidget {
  const MotdView({required this.store, super.key});

  final EditorStore store;

  @override
  State<MotdView> createState() => _MotdViewState();
}

class _MotdViewState extends State<MotdView> {
  Timer? _ticker;
  final math.Random _random = math.Random();

  /// The previewed entry. Clamped on read: the inspector can shorten the
  /// list under it.
  int _entryIndex = 0;

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
    _ticker?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _syncTicker(bool animated) {
    final bool wanted = animated && _store.animationsPlaying;
    if (wanted && _ticker == null) {
      _ticker = Timer.periodic(_tickPeriod, (Timer _) {
        if (mounted) setState(() {});
      });
    } else if (!wanted && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// `MotdService.handlePing`'s pick, replayed on demand.
  void _shufflePreview(GlossMotdDoc doc) {
    if (doc.entries.length <= 1) return;
    final int current = _entryIndex.clamp(0, doc.entries.length - 1);
    final int next =
        (current + 1 + _random.nextInt(doc.entries.length - 1)) %
        doc.entries.length;
    setState(() => _entryIndex = next);
  }

  @override
  Widget build(BuildContext context) {
    final GlossMotdDoc? doc = _store.motdDoc;
    if (doc == null) {
      _syncTicker(false);
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
    bool animated = false;
    for (final String line in lines) {
      if (glossLineAnimationRefs(line, animations).isNotEmpty) {
        animated = true;
        break;
      }
    }
    _syncTicker(animated);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    return dom.div(classes: 'hui-motd-stage', <Widget>[
      GlossPreviewZoom(
        label: 'MOTD preview',
        child: dom.div(classes: 'hui-motd-screen', <Widget>[
          dom.div(classes: 'hui-motd-row', <Widget>[
            const dom.div(classes: 'hui-motd-icon', <Widget>[
              dom.span(classes: 'hui-motd-icon-glyph', <Widget>[Text('▚')]),
            ]),
            dom.div(classes: 'hui-motd-row-body', <Widget>[
              dom.div(classes: 'hui-motd-row-head', <Widget>[
                const dom.span(classes: 'hui-motd-server-name', <Widget>[
                  Text('My Server'),
                ]),
                dom.span(classes: 'hui-motd-row-status', <Widget>[
                  const dom.span(classes: 'hui-motd-players', <Widget>[
                    Text('17/100'),
                  ]),
                  dom.span(classes: 'hui-motd-ping', <Widget>[
                    for (int bar = 0; bar < 5; bar++)
                      dom.span(
                        classes:
                            'hui-motd-ping-bar${bar < 4 ? ' is-filled' : ''}',
                        const <Widget>[],
                      ),
                  ]),
                ]),
              ]),
              if (entry == null)
                const dom.div(classes: 'hui-motd-line is-blank', <Widget>[
                  Text('No entries — Gloss would reject this file.'),
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
          ]),
          dom.div(classes: 'hui-motd-controls', <Widget>[
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.sm,
              icon: ArcaneIcon.dices(size: IconSize.sm),
              onPressed: doc.entries.length > 1
                  ? () => _shufflePreview(doc)
                  : null,
              child: const Text('Shuffle preview'),
            ),
            dom.div(classes: 'hui-motd-entry-chips', <Widget>[
              for (int index = 0; index < doc.entries.length; index++)
                dom.button(
                  classes:
                      'hui-motd-entry-chip${index == shown ? ' is-active' : ''}',
                  attributes: <String, String>{
                    'type': 'button',
                    'aria-label': 'Preview entry ${index + 1}',
                  },
                  events: <String, EventCallback>{
                    'click': (Object? _) => setState(() => _entryIndex = index),
                  },
                  <Widget>[Text('${index + 1}')],
                ),
            ]),
          ]),
        ]),
      ),
      dom.div(classes: 'hui-motd-readout', <Widget>[
        Text(_readout(doc, entry, shown)),
      ]),
    ]);
  }

  String _readout(GlossMotdDoc doc, GlossMotdEntry? entry, int shown) {
    final List<String> parts = <String>[
      doc.entries.isEmpty
          ? 'no entries'
          : 'entry ${shown + 1} of ${doc.entries.length} — every ping picks '
                'one at random',
      if (entry != null && entry.lines.length > glossMotdMaxLinesPerEntry)
        'entry has ${entry.lines.length} lines; Gloss rejects past '
            '$glossMotdMaxLinesPerEntry',
      'placeholders stay literal (a ping has no viewer)',
    ];
    return parts.join(' · ');
  }
}
