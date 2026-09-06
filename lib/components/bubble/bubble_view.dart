/// The bubble surface: an animated chat-bubble stack over the player, replaying
/// a canned formatted conversation through the plugin wrapping, stacking and
/// expression motion contract.
///
/// Each chat message is one multiline block. Legacy formatting survives the
/// visible-character wrap, and motion expressions drive translation, scale,
/// rotation and opacity from the same lifetime and stack inputs as runtime.
///
/// The player is the client's own rig on an [McStage], and every bubble is a
/// CSS-3D anchor over its head at a world position, so the stack keeps its
/// place under the camera the same way a chat bubble keeps its place in game.
/// With `gameContext` the stage becomes the game frame's world; without it the
/// surface keeps its editor stage and readout.
///
/// Pause freezes the clock offset; resume rejoins where it left off. Owns one
/// repaint driver only while playing and mounted: an animation-frame loop when
/// the style has a shine band, the 50 ms motion timer otherwise.
library;

import '../gloss/gloss_display_text.dart';
import 'dart:async';
import 'dart:js_interop';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:web/web.dart' as web;

import '../../logic/bubble_motion.dart';
import '../../logic/bubble_preview.dart';
import '../../logic/gloss_particle_text.dart';
import '../../logic/gloss_text.dart';
import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_scene.dart';
import '../../model/model.dart';
import '../../preview/projection.dart' show huiPreviewPxPerBlock;
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../gloss/gloss_text_line.dart';
import '../mc/mc_dom_layer.dart';
import '../mc/mc_stage.dart';
import '../mc/mc_stage_controller.dart';
import '../scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Repaint period for motion alone. The stack eases every poll in game; 50 ms
/// (one tick) keeps mathematical motion smooth without burning frames.
///
/// It is far too coarse for a bounded shine sweep across a long multiline
/// message, so a style with a band drives repaints from
/// `requestAnimationFrame` instead and this timer stays cancelled.
const Duration _tickPeriod = Duration(milliseconds: 50);

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
  /// The world the player stands in and the camera over it. The pivot is the
  /// rig's eye line, so the home framing looks the speaker in the face; the
  /// game frame stands at the client's own eye there and does not orbit.
  late final McStageController _stage = McStageController(
    kind: component.gameContext ? McStageKind.frame : McStageKind.bubbles,
    homePivot: const McVec3(0.5, mcCameraEyeHeight, 0.5),
    freeCamera: !component.gameContext,
  );

  /// The rig's crown: 32.5 model pixels at the 0.9375 player scale.
  static const double _headTopBlocks = (32 + 0.5) / 16 * 0.9375;

  /// Where the bottom bubble's baseline sits — a quarter block of air over the
  /// crown, the gap the plugin leaves before the first line.
  static const double _stackBaseBlocks = _headTopBlocks + 0.25;

  /// The last camera and WebGL verdict this view rendered against, so a
  /// notification raised by its own scene write is told apart from one that
  /// actually moves the anchored bubbles.
  late McCamera _lastCamera = _stage.camera;
  late bool _lastWebGl = _stage.webGlAvailable;

  /// The instant the rig is posed at. It follows the preview clock while
  /// frames are being drawn and holds its last value once they stop, so a
  /// parked stage keeps the pose it froze on instead of jumping on resume.
  int _poseTimeMs = 0;

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
    _stage.addListener(_onStageChanged);
    _stage.spriteFor = _spriteFor;
  }

  /// The no-WebGL sprite for a node, off the catalogs the store holds now.
  String? _spriteFor(McSceneNode node) => mcCatalogSpriteFor(_store.catalogs, node);

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
    _stage.removeListener(_onStageChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  /// The camera moved, or the stage gave up on WebGL: the bubbles are
  /// anchored by this view, so they are re-projected here. The scene and the
  /// animating flag are this view's own writes, and the controller stays quiet
  /// on an unchanged scene, so neither reaches this.
  void _onStageChanged() {
    if (!mounted) return;
    if (_lastCamera == _stage.camera && _lastWebGl == _stage.webGlAvailable) {
      return;
    }
    _lastCamera = _stage.camera;
    _lastWebGl = _stage.webGlAvailable;
    setState(() {});
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

  /// The speaker: one rig on the ground block, meshed facing +Z toward the
  /// camera standing south, posed off the preview clock.
  void _syncStage(int nowMs) {
    final bool animating = _playing && _store.animationsPlaying;
    if (animating) _poseTimeMs = nowMs;
    _stage.scene = McScene(<McSceneNode>[
      McRigNode(
        key: 'player',
        rigId: 'player',
        textureId: 'player',
        transform: McMat4.translation(0.5, 0, 0.5),
        poseTimeMs: _poseTimeMs,
        hurt: 0,
        capeTextureId: 'player_cape',
      ),
    ]);
    _stage.animating = animating;
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
    _syncStage(nowMs);

    final List<Widget> anchored = <Widget>[
      for (final GlossBubblePreviewBubble bubble in bubbles)
        _bubble(doc, bubble, offset, nowMs),
    ];

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.overPlayer,
        label: huiText('Chat bubbles in game'),
        controls: <Widget>[_playPause()],
        world: _stage,
        worldOverlay: anchored,
        child: const dom.div(<Widget>[]),
      );
    }

    return dom.div(classes: 'hui-bubble-stage', <Widget>[
      McStage(
        controller: _stage,
        overlay: anchored,
        label: huiText('Chat bubble preview'),
      ),
      dom.div(classes: 'hui-bubble-controls', <Widget>[
        _playPause(),
        _resetView(),
        dom.span(classes: 'hui-bubble-readout-inline', <Widget>[
          Text(_readout(doc, selection)),
        ]),
        dom.span(classes: 'hui-bubble-readout-inline', <Widget>[
          Text(
            huiText(
              'Click the stage: drag orbits, WASD walks, space and shift lift, '
              'wheel dollies',
            ),
          ),
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
    final GlossBubbleMotionFrame motion = bubble.motion;
    final String anchor = mcDomAnchorTransform(
      camera: _stage.camera,
      position: McVec3(
        0.5 + offset[0] + motion.translationX,
        _stackBaseBlocks + bubble.stackY + offset[1] + motion.translationY,
        0.5 + offset[2] + motion.translationZ,
      ),
      billboard: McBillboardMode.parse(doc.style.billboard),
    );
    return dom.div(
      classes: 'hui-mc-anchor hui-bubble-block',
      styles: dom.Styles(
        raw: <String, String>{
          'opacity': motion.opacity.toStringAsFixed(3),
          // The anchor's trailing `translate(-50%, -100%)` puts the block's
          // bottom-centre on the world point; undoing it, turning and scaling,
          // then re-applying it makes motion pivot about that same point —
          // where a text display's own transform pivots.
          'transform':
              '$anchor translate(50%, 100%) '
              'rotateX(${motion.rotationX.toStringAsFixed(2)}deg) '
              'rotateY(${motion.rotationY.toStringAsFixed(2)}deg) '
              'rotateZ(${motion.rotationZ.toStringAsFixed(2)}deg) '
              'scale3d(${(motion.scaleX * doc.style.scaleX).toStringAsFixed(3)}, '
              '${(motion.scaleY * doc.style.scaleY).toStringAsFixed(3)}, '
              '${(motion.scaleZ * doc.style.scaleZ).toStringAsFixed(3)}) '
              'translate(-50%, -100%)',
        },
      ),
      <Widget>[
        GlossParticleOverlay(
          layers: doc.particleLayers,
          pixelsPerBlock: huiPreviewPxPerBlock,
          tick: nowMs ~/ 50,
          renderedText: GlossParticleTextRendered(
            text: render.renderedText,
            spans: render.particleSpans,
          ),
        ),
        GlossDisplayText(
          style: doc.style,
          box: doc.box,
          child: GlossTextLine(render: render),
        ),
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
    icon: _playing
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  /// The camera is the zoom now, so the one framing affordance left is putting
  /// it back where it started.
  Widget _resetView() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _stage.resetCamera,
    disabled: _stage.isHome,
    attributes: <String, String>{
      'aria-label': huiText('Reset view'),
      'title': huiText('Reset view'),
    },
    icon: ArcaneIcon.maximize(size: IconSize.sm),
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
      if (!_stage.webGlAvailable)
        huiText(
          'No WebGL2 in this browser: the world is a still and models are '
          'sprites',
        ),
    ];
    return parts.join(' · ');
  }
}
