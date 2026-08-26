/// The bubble surface: an animated chat-bubble stack above a player
/// silhouette, replaying a canned formatted conversation through the plugin
/// wrapping, stacking and expression motion contract.
///
/// Each chat message is one multiline block. Legacy formatting survives the
/// visible-character wrap, and motion expressions drive translation, scale,
/// rotation and opacity from the same lifetime and stack inputs as runtime.
///
/// With `gameContext` the stack mounts into the shared game-screen frame over
/// the player silhouette the frame draws; without it the surface keeps its
/// editor stage and readout.
///
/// Pause freezes the clock offset; resume rejoins where it left off. Owns one
/// repaint driver only while playing and mounted: an animation-frame loop when
/// the style has a shine band, the 50 ms motion timer otherwise.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:web/web.dart' as web;

import '../../logic/bubble_preview.dart';
import '../../logic/gloss_particle_text.dart';
import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';
import '../scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Repaint period for motion alone. The stack eases every poll in game; 50 ms
/// (one tick) keeps mathematical motion smooth without burning frames.
///
/// It is far too coarse for a bounded shine sweep across a long multiline
/// message, so a style with a band drives repaints from
/// `requestAnimationFrame` instead and this timer stays cancelled.
const Duration _tickPeriod = Duration(milliseconds: 50);

/// Pixels per block on the mock stage — presentation scale only.
const double _pixelsPerBlock = 46;

class BubbleView extends StatefulWidget {
  const BubbleView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;

  /// Mounts the bubble stack inside the shared Minecraft game-screen frame
  /// instead of the editor stage. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<BubbleView> createState() => _BubbleViewState();
}

class _BubbleViewState extends State<BubbleView> {
  Timer? _ticker;

  /// True between asking for an animation frame and being called back, so a
  /// rebuild from any other cause never stacks a second request.
  bool _framePending = false;
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

  /// Picks the repaint driver for this frame and keeps exactly one running.
  ///
  /// A configured shine band steps its head faster than one Minecraft tick, so
  /// it takes the animation-frame loop; everything else stays on the 50 ms
  /// timer. Both stop dead when the surface is paused, the workspace toggle is
  /// off, or the component is gone — neither leaves work scheduled.
  void _syncTicker(GlossBubbleStyleDoc doc) {
    final bool wanted = _playing && _store.animationsPlaying;
    if (wanted && (doc.shimmer.spawn || doc.shimmer.flyAway)) {
      _ticker?.cancel();
      _ticker = null;
      _requestFrame();
      return;
    }
    if (wanted && _ticker == null) {
      _ticker = Timer.periodic(_tickPeriod, (Timer _) {
        if (mounted) setState(() {});
      });
    } else if (!wanted && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// One frame at a time: the callback repaints, the repaint runs
  /// [_syncTicker] again, and that asks for the next one only while the
  /// preview is still playing. Nothing re-arms after a pause or a dispose.
  void _requestFrame() {
    if (_framePending) return;
    _framePending = true;
    web.window.requestAnimationFrame(_onAnimationFrame.toJS);
  }

  void _onAnimationFrame(double _) {
    _framePending = false;
    if (mounted) setState(() {});
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
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.overPlayer,
          label: huiText('Chat bubbles in game'),
        );
      }
      return const dom.div(classes: 'hui-bubble-stage is-empty', <Widget>[]);
    }
    _syncTicker(doc);
    final GlossBubblePreviewTimeline timeline = _timelineFor(doc);
    final int nowMs = _nowMs();
    final List<GlossBubblePreviewBubble> bubbles = timeline.bubblesAt(nowMs);
    final List<double> offset = doc.offset;
    final GlossBubbleSelect? select = doc.select;
    final ({bool matches, String? error})? selection = select == null
        ? null
        : glossConditionMatches(
            select.when,
            GlossConditionContext(
              variables: const <String, Object?>{
                'viewer.world': 'world',
                'viewer.health': 20.0,
                'viewer.maxHealth': 20.0,
                'viewer.healthPercent': 100.0,
                'viewer.gameMode': 'SURVIVAL',
              },
              groups: const <String>{'player'},
            ),
          );

    final Widget scene = dom.div(classes: 'hui-bubble-scene', <Widget>[
      for (final GlossBubblePreviewBubble bubble in bubbles)
        _bubble(doc, bubble, offset, nowMs),
      if (!component.gameContext)
        const dom.div(classes: 'hui-bubble-player', <Widget>[
          dom.div(classes: 'hui-bubble-player-head', <Widget>[]),
          dom.div(classes: 'hui-bubble-player-body', <Widget>[]),
          dom.div(classes: 'hui-bubble-player-arms', <Widget>[]),
        ]),
    ]);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.overPlayer,
        label: huiText('Chat bubbles in game'),
        controls: <Widget>[_playPause()],
        child: scene,
      );
    }

    return dom.div(classes: 'hui-bubble-stage', <Widget>[
      dom.div(classes: 'hui-bubble-sky', <Widget>[
        GlossPreviewZoom(
          label: huiText('Chat bubble preview'),
          alignment: GlossPreviewAlignment.bottom,
          child: scene,
        ),
      ]),
      dom.div(classes: 'hui-bubble-controls', <Widget>[
        _playPause(),
        dom.span(classes: 'hui-bubble-readout-inline', <Widget>[
          Text(_readout(doc, selection)),
        ]),
      ]),
    ]);
  }

  Widget _bubble(
    GlossBubbleStyleDoc doc,
    GlossBubblePreviewBubble bubble,
    List<double> offset,
    int nowMs,
  ) {
    final GlossLineRender render = renderGlossBubblePreviewText(
      doc,
      bubble,
      animations: _store.workspaceAnimations,
      emoji: _store.workspaceEmoji,
      nowMs: nowMs,
    );
    return dom.div(
      classes: 'hui-bubble-block',
      styles: dom.Styles(
        raw: <String, String>{
          'bottom':
              '${((bubble.stackY + offset[1] + bubble.motion.translationY) * _pixelsPerBlock).toStringAsFixed(1)}px',
          'left':
              'calc(50% + ${((offset[0] + bubble.motion.translationX) * _pixelsPerBlock).toStringAsFixed(1)}px)',
          'opacity': bubble.motion.opacity.toStringAsFixed(3),
          'transform':
              'translateX(-50%) '
              'translateZ(${((offset[2] + bubble.motion.translationZ) * _pixelsPerBlock).toStringAsFixed(1)}px) '
              'rotateX(${bubble.motion.rotationX.toStringAsFixed(2)}deg) '
              'rotateY(${bubble.motion.rotationY.toStringAsFixed(2)}deg) '
              'rotateZ(${bubble.motion.rotationZ.toStringAsFixed(2)}deg) '
              'scale3d(${bubble.motion.scaleX.toStringAsFixed(3)}, '
              '${bubble.motion.scaleY.toStringAsFixed(3)}, '
              '${bubble.motion.scaleZ.toStringAsFixed(3)})',
        },
      ),
      <Widget>[
        GlossParticleOverlay(
          layers: doc.particleLayers,
          pixelsPerBlock: _pixelsPerBlock,
          tick: nowMs ~/ 50,
          renderedText: GlossParticleTextRendered(
            text: render.renderedText,
            spans: render.particleSpans,
          ),
        ),
        GlossTextLine(render: render),
      ],
    );
  }

  /// Freezes the preview clock. Local, not the store toggle: this surface
  /// replays a canned conversation on its own timeline, so pausing it must
  /// hold that instant rather than only stopping animation frames.
  Widget _playPause() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _togglePlaying,
    attributes: <String, String>{
      'aria-label': _playing ? huiText('Pause') : huiText('Play'),
      'title': _playing ? huiText('Pause') : huiText('Play'),
    },
    child: _playing
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  String _readout(
    GlossBubbleStyleDoc doc,
    ({bool matches, String? error})? selection,
  ) {
    final List<String> parts = <String>[
      huiPlural(
        'bubble.readout.wrap',
        doc.effectiveWordWrapChars,
        oneEnglish: 'wrap {count} character',
        otherEnglish: 'wrap {count} characters',
      ),
      huiText('offset {offset}', <String, Object?>{
        'offset': doc.offset
            .map((double value) => value.toStringAsFixed(1))
            .join(', '),
      }),
      huiText('alive {duration} ms', <String, Object?>{
        'duration': doc.effectiveMaxAliveMs,
      }),
      huiText('expression motion'),
      if (doc.shimmer.spawn || doc.shimmer.flyAway)
        huiText('shine {duration} ms sweep', <String, Object?>{
          'duration': doc.shimmer.effectiveDurationMs,
        }),
      doc.followPlayer
          ? huiText('follows the player')
          : huiText('anchored where sent'),
      if (doc.hideOwn) huiText('hidden from the sender'),
      if (selection == null)
        huiText('manual or default selection')
      else if (selection.error != null)
        huiText('selection condition error')
      else if (selection.matches)
        huiText('matches preview player')
      else
        huiText('does not match preview player'),
    ];
    return parts.join(' · ');
  }
}
