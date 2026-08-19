/// The bubble surface: an animated chat-bubble stack above a player
/// silhouette, replaying a canned conversation through the ported plugin
/// math.
///
/// Fidelity: wrapping is `BubbleLines.split` (colour-stripped, VolmLib
/// soft-wrap at the style's effective `wordWrapChars`), spawn delay is
/// `lineStaggerTicks * 50 ms` per line, lifetime is the effective
/// `maxAliveMs`, and every bubble's height is `BubbleStackMath.offsetY` with
/// the live list ordered like the plugin's `SenderState.live` — all via
/// `logic/bubble_preview.dart` under an injectable clock. The canned
/// conversation and its rhythm are editor fiction; the numbers are not. The
/// prefix colour renders through the pipeline mirror exactly as the
/// temporary hologram renders `prefix + line`.
///
/// Pause freezes the clock offset; resume rejoins where it left off. Owns a
/// repaint timer only while playing and mounted.
library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/bubble_preview.dart';
import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_text_line.dart';

/// Repaint period. The stack eases every poll in game; 50 ms (one tick)
/// keeps the fly-away launch smooth without burning frames.
const Duration _tickPeriod = Duration(milliseconds: 50);

/// Pixels per block on the mock stage — presentation scale only.
const double _pixelsPerBlock = 46;

class BubbleView extends StatefulWidget {
  const BubbleView({required this.store, super.key});

  final EditorStore store;

  @override
  State<BubbleView> createState() => _BubbleViewState();
}

class _BubbleViewState extends State<BubbleView> {
  Timer? _ticker;
  bool _playing = true;

  /// The preview clock: wall time minus this offset. Pausing captures the
  /// current preview instant; resuming re-derives the offset so playback
  /// continues from the held instant.
  int _clockOffsetMs = 0;
  int _heldMs = 0;

  /// Timeline memo, keyed by the store's gloss revision.
  GlossBubblePreviewTimeline? _timeline;
  int _timelineRevision = -1;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _clockOffsetMs = DateTime.now().millisecondsSinceEpoch;
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant BubbleView oldComponent) {
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

  int _nowMs() => _playing
      ? DateTime.now().millisecondsSinceEpoch - _clockOffsetMs
      : _heldMs;

  void _togglePlaying() {
    setState(() {
      if (_playing) {
        _heldMs = _nowMs();
        _playing = false;
      } else {
        _clockOffsetMs = DateTime.now().millisecondsSinceEpoch - _heldMs;
        _playing = true;
      }
    });
  }

  void _syncTicker() {
    final bool wanted = _playing && _store.animationsPlaying;
    if (wanted && _ticker == null) {
      _ticker = Timer.periodic(_tickPeriod, (Timer _) {
        if (mounted) setState(() {});
      });
    } else if (!wanted && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  GlossBubblePreviewTimeline _timelineFor(GlossBubbleStyleDoc doc) {
    if (_timeline == null || _timelineRevision != _store.glossRevision) {
      _timeline = GlossBubblePreviewTimeline(doc);
      _timelineRevision = _store.glossRevision;
    }
    return _timeline!;
  }

  @override
  Widget build(BuildContext context) {
    final GlossBubbleStyleDoc? doc = _store.bubbleStyleDoc;
    if (doc == null) {
      _ticker?.cancel();
      _ticker = null;
      return const dom.div(classes: 'hui-bubble-stage is-empty', <Widget>[]);
    }
    _syncTicker();
    final GlossBubblePreviewTimeline timeline = _timelineFor(doc);
    final List<GlossBubblePreviewBubble> bubbles = timeline.bubblesAt(
      _nowMs(),
    );

    return dom.div(classes: 'hui-bubble-stage', <Widget>[
      dom.div(classes: 'hui-bubble-sky', <Widget>[
        dom.div(classes: 'hui-bubble-scene', <Widget>[
          for (final GlossBubblePreviewBubble bubble in bubbles)
            dom.div(
              classes: 'hui-bubble-line',
              styles: dom.Styles(
                raw: <String, String>{
                  'bottom':
                      '${(bubble.offsetY * _pixelsPerBlock).toStringAsFixed(1)}px',
                  'opacity': bubble.remainingMs < 400
                      ? (bubble.remainingMs / 400).toStringAsFixed(2)
                      : '1',
                },
              ),
              <Widget>[
                GlossTextLine(
                  render: renderGlossLine(
                    doc.effectivePrefix + bubble.text,
                    emoji: _store.workspaceEmoji,
                  ),
                ),
              ],
            ),
          const dom.div(classes: 'hui-bubble-player', <Widget>[
            dom.div(classes: 'hui-bubble-player-head', <Widget>[]),
            dom.div(classes: 'hui-bubble-player-body', <Widget>[]),
            dom.div(classes: 'hui-bubble-player-arms', <Widget>[]),
          ]),
        ]),
      ]),
      dom.div(classes: 'hui-bubble-controls', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.iconSm,
          onPressed: _togglePlaying,
          attributes: <String, String>{
            'aria-label': _playing ? 'Pause' : 'Play',
          },
          child: _playing
              ? ArcaneIcon.pause(size: IconSize.sm)
              : ArcaneIcon.play(size: IconSize.sm),
        ),
        dom.span(classes: 'hui-bubble-readout-inline', <Widget>[
          Text(_readout(doc)),
        ]),
      ]),
    ]);
  }

  String _readout(GlossBubbleStyleDoc doc) {
    final List<String> parts = <String>[
      'wrap ${doc.effectiveWordWrapChars} chars',
      'stagger ${doc.effectiveLineStaggerTicks} ticks '
          '(${doc.effectiveLineStaggerTicks * 50} ms)',
      'alive ${doc.effectiveMaxAliveMs} ms',
      doc.flyAway ? 'fly-away on' : 'fly-away off',
      doc.followPlayer ? 'follows the player' : 'anchored where sent',
      if (doc.hideOwn) 'hidden from the sender',
    ];
    return parts.join(' · ');
  }
}
