/// The drop stage: a dropped stack falling, tumbling, bouncing and settling
/// under the settings the document actually carries.
///
/// What it draws is the plugin's own presentation model — `RealDropModel`,
/// ported in `logic/real_drop_model.dart` and driven by
/// `logic/real_drop_stage.dart`. The number of item displays comes from the
/// stack size, their places from the offset table, their size from the scale
/// family the material belongs to, their pose from the configured tumble
/// rates and the settled landing mode, their lift off the ground from the
/// authored Y offsets, and the label from `drops.name-format` with the
/// shipped `&7{count}x {type}`. Changing any field in the inspector changes
/// the stage the way it changes the server.
///
/// Two things are the stage's own and are named as approximations in the
/// readout:
///
///  * **Ballistics.** Minecraft's `Item` entity falls and bounces; Gloss only
///    reacts to it. The arc here is a simple one, sized to show a tumble and a
///    settle.
///  * **Model faces.** The sprite catalog ships one rendered image per
///    material — the same image the canvas draws — not the six face textures a
///    cube model has. So a model is that sprite extruded to the depth of its
///    family: a sixteenth of a block for a flat item, the full edge for a
///    cube. Silhouette, size, pose and motion are real; the texture on a
///    tumbling cube's side is the GUI render.
///
/// Pose changes are handed to CSS transitions whose duration is the client's
/// own interpolation window — `limits.updateIntervalTicks` in flight,
/// `landing.transitionTicks` on the settle — so a coarse update interval reads
/// as coarse here too.
library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/showcase_flavor.dart';
import '../../logic/gloss_text.dart';
import '../../logic/real_drop_model.dart';
import '../../logic/real_drop_stage.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';

/// Pixels one block spans on the stage. Presentation scale only — every
/// distance the document states is in blocks and is converted here.
const double _pixelsPerBlock = 170;

/// How deep a model is extruded, as a fraction of its edge.
///
/// A flat item model really is one texture pixel thick in game, and the
/// catalog sprite for it really is its texture, so a flat item is exact. A
/// cube's sprite is already a rendered cube seen from the GUI camera, so
/// stacking it deep would draw four cubes in a row: cubes take just enough
/// depth to keep an edge-on pose from vanishing, and no more.
const Map<DropModelKind, double> _extrusionDepth = <DropModelKind, double>{
  DropModelKind.flat: 1 / 16,
  DropModelKind.thin: 1 / 10,
  DropModelKind.block: 1 / 7,
};

/// Slices per screen pixel of depth. Any sparser and the slices read as a comb
/// along the model's silhouette instead of a solid side.
const double _sliceSpacingPx = 0.8;

class RealDropsView extends StatefulWidget {
  const RealDropsView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;

  /// Mounts the stage inside the shared Minecraft game-screen frame instead of
  /// the editor stage. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<RealDropsView> createState() => _RealDropsViewState();
}

class _RealDropsViewState extends State<RealDropsView> {
  Timer? _ticker;

  /// The period [_ticker] is running at, so a document change that moves the
  /// update interval is noticed.
  int _tickerPeriodMs = 0;
  bool _playing = true;

  /// The preview clock: wall time minus this offset. Pausing captures the
  /// instant; resuming re-derives the offset so playback continues from it.
  int _clockOffsetMs = 0;
  int _heldMs = 0;

  /// Which sample stack is on the stage.
  int _sample = 0;

  /// Timeline memo, rebuilt when the document or the sample changes.
  DropStageTimeline? _timeline;
  int _timelineRevision = -1;
  int _timelineSample = -1;

  EditorStore get _store => component.store;

  ShowcaseDrop get _drop => showcaseDrops[_sample % showcaseDrops.length];

  @override
  void initState() {
    super.initState();
    _clockOffsetMs = DateTime.now().millisecondsSinceEpoch;
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant RealDropsView oldComponent) {
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

  void _nextSample() => setState(() => _sample++);

  /// One repaint per server update, so the stage polls exactly as often as the
  /// plugin does and CSS eases between poses the way the client does.
  ///
  /// The period is part of the document, so a changed `updateIntervalTicks`
  /// has to replace the timer rather than keep the old cadence.
  void _syncTicker(GlossRealDropSettingsDoc doc) {
    final int periodMs = (doc.limits.updateIntervalTicks.clamp(1, 20) * 50)
        .toInt();
    if (!_playing) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    if (_ticker != null && _ticker!.isActive && _tickerPeriodMs == periodMs) {
      return;
    }
    _ticker?.cancel();
    _tickerPeriodMs = periodMs;
    _ticker = Timer.periodic(Duration(milliseconds: periodMs), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  DropStageTimeline _timelineFor(GlossRealDropSettingsDoc doc) {
    if (_timeline == null ||
        _timelineRevision != _store.glossRevision ||
        _timelineSample != _sample) {
      _timeline = DropStageTimeline(doc, _drop);
      _timelineRevision = _store.glossRevision;
      _timelineSample = _sample;
    }
    return _timeline!;
  }

  @override
  Widget build(BuildContext context) {
    final GlossRealDropSettingsDoc? doc = _store.realDropSettingsDoc;
    if (doc == null) {
      _ticker?.cancel();
      _ticker = null;
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.world,
          label: 'Real drops in game',
        );
      }
      return const dom.div(
        classes: 'hui-real-drops-stage is-empty',
        <Widget>[],
      );
    }

    _syncTicker(doc);
    final DropStageTimeline timeline = _timelineFor(doc);
    final DropStageFrame frame = timeline.frameAt(_nowMs());
    final Widget scene = _scene(doc, timeline, frame);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.world,
        label: 'Real drops in game',
        controls: <Widget>[_playPause(), _sampleButton()],
        child: scene,
      );
    }

    return dom.div(classes: 'hui-real-drops-stage', <Widget>[
      scene,
      dom.div(classes: 'hui-real-drops-controls', <Widget>[
        _playPause(),
        _sampleButton(),
        dom.span(classes: 'hui-real-drops-readout-inline', <Widget>[
          Text(_readout(doc, timeline, frame)),
        ]),
      ]),
    ]);
  }

  Widget _playPause() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _togglePlaying,
    attributes: <String, String>{
      'aria-label': _playing ? 'Pause' : 'Play',
      'title': _playing ? 'Pause' : 'Play',
    },
    child: _playing
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  Widget _sampleButton() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _nextSample,
    attributes: <String, String>{
      'aria-label': 'Next sample stack',
      'title': 'Drop something else (${_drop.displayName})',
    },
    child: ArcaneIcon.shuffle(size: IconSize.sm),
  );

  Widget _scene(
    GlossRealDropSettingsDoc doc,
    DropStageTimeline timeline,
    DropStageFrame frame,
  ) {
    final GlossRealDropLabels labels = doc.labels;
    final int easeMs = frame.interpolationTicks.clamp(0, 59) * 50;
    final double edgePx = frame.modelScale * _pixelsPerBlock;
    final String? texture = _store.catalogs.textureFor(_drop.material);

    // The clipping element cannot also be the 3D context: `overflow: hidden`
    // forces `transform-style: flat`, which would lay the ground plane and the
    // extruded models back down into the page.
    return dom.div(classes: 'hui-real-drops-scene', <Widget>[
      dom.div(classes: 'hui-real-drops-world', <Widget>[
      const dom.div(classes: 'hui-real-drops-floor', <Widget>[]),
      dom.div(
        classes: 'hui-real-drops-carrier',
        styles: dom.Styles(
          raw: <String, String>{
            'transform':
                'translate3d(0, '
                '${(-frame.carrierY * _pixelsPerBlock).toStringAsFixed(2)}px, 0)',
            'transition': 'transform ${easeMs}ms linear',
          },
        ),
        <Widget>[
          for (final DropStageVisual visual in frame.visuals)
            _model(visual, frame, edgePx, easeMs, texture),
          if (labels.enabled) _label(labels, frame),
        ],
      ),
      dom.div(
        classes: 'hui-real-drops-shadow',
        styles: dom.Styles(
          raw: <String, String>{
            'width': '${(edgePx * 1.35).toStringAsFixed(1)}px',
            'height': '${(edgePx * 0.5).toStringAsFixed(1)}px',
            'opacity': (0.45 / (1 + frame.carrierY * 1.4)).toStringAsFixed(3),
            'transition': 'opacity ${easeMs}ms linear',
          },
        ),
        const <Widget>[],
      ),
      ]),
    ]);
  }

  /// One `ItemDisplay`: the sprite extruded along its own depth, posed by the
  /// rotation the model math produced, offset and lifted the way the plugin's
  /// transformation places it.
  Widget _model(
    DropStageVisual visual,
    DropStageFrame frame,
    double edgePx,
    int easeMs,
    String? texture,
  ) {
    final double depth = edgePx * (_extrusionDepth[frame.modelKind] ?? 1 / 8);
    final int slices = (depth / _sliceSpacingPx).round().clamp(2, 24);
    final double spacing = depth / (slices - 1);
    return dom.div(
      classes: 'hui-real-drops-model',
      styles: dom.Styles(
        raw: <String, String>{
          'width': '${edgePx.toStringAsFixed(1)}px',
          'height': '${edgePx.toStringAsFixed(1)}px',
          // Centred in layout, not in the transform: `transform-origin` is a
          // point in the element's own box, so a `translate(-50%, -50%)` in
          // the list would leave the model rotating about a corner and swing
          // it off the carrier.
          'margin-left': '-${(edgePx / 2).toStringAsFixed(1)}px',
          'margin-top': '-${(edgePx / 2).toStringAsFixed(1)}px',
          'transform':
              'translate3d('
              '${(visual.x * _pixelsPerBlock).toStringAsFixed(2)}px, '
              '${(-visual.y * _pixelsPerBlock).toStringAsFixed(2)}px, '
              '${(visual.z * _pixelsPerBlock).toStringAsFixed(2)}px) '
              '${visual.rotation.cssMatrix3d()}',
          'transition': 'transform ${easeMs}ms linear',
        },
      ),
      <Widget>[
        for (int layer = 0; layer < slices; layer++)
          if (texture == null)
            dom.div(
              classes: 'hui-real-drops-layer is-missing',
              styles: dom.Styles(
                raw: <String, String>{
                  'transform':
                      'translateZ(${(layer * spacing - depth / 2).toStringAsFixed(2)}px)',
                },
              ),
              const <Widget>[],
            )
          else
            dom.img(
              src: texture,
              alt: '',
              classes: 'hui-real-drops-layer',
              styles: dom.Styles(
                raw: <String, String>{
                  'transform':
                      'translateZ(${(layer * spacing - depth / 2).toStringAsFixed(2)}px)',
                  // Interior slices are the model's own sides, which never
                  // catch as much light as the faces.
                  'filter': layer == 0 || layer == slices - 1
                      ? 'none'
                      : 'brightness(0.86)',
                },
              ),
            ),
      ],
    );
  }

  /// The `TextDisplay` the plugin parents to the carrier: the formatted name,
  /// at `labels.yOffset` blocks, at `labels.scale`, with the configured
  /// background colour and alpha, shadow and see-through depth order.
  Widget _label(GlossRealDropLabels labels, DropStageFrame frame) {
    final double alpha = labels.background ? labels.backgroundAlpha / 255 : 0;
    return dom.div(
      classes: labels.seeThrough
          ? 'hui-real-drops-label is-see-through'
          : 'hui-real-drops-label',
      styles: dom.Styles(
        raw: <String, String>{
          'transform':
              'translate(-50%, -100%) translateY('
              '${(-frame.labelY * _pixelsPerBlock).toStringAsFixed(2)}px)',
        },
      ),
      <Widget>[
        // The plate scales separately so `labels.scale` grows the text around
        // the anchor the way a TextDisplay does, instead of dragging it away
        // from the stack.
        dom.div(
          classes: 'hui-real-drops-plate',
          styles: dom.Styles(
            raw: <String, String>{
              'transform':
                  '${_labelBillboard(labels.billboard)}'
                  'scale(${labels.scale.toStringAsFixed(3)})',
              'background':
                  'rgba(${labels.backgroundRed}, ${labels.backgroundGreen}, '
                  '${labels.backgroundBlue}, ${alpha.toStringAsFixed(3)})',
              if (labels.shadow) 'text-shadow': '2px 2px 0 rgba(0, 0, 0, .55)',
            },
          ),
          <Widget>[
            GlossTextLine(
              render: renderGlossLine(
                frame.label,
                animations: _store.workspaceAnimations,
                emoji: _store.workspaceEmoji,
                nowMs: _nowMs(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The stage camera never moves, so a billboard mode can only be shown by
  /// the pose it locks the label into. `CENTER` and `VERTICAL` both face the
  /// camera here; `HORIZONTAL` lies down and `FIXED` keeps the drop's yaw.
  String _labelBillboard(String billboard) => switch (billboard.toUpperCase()) {
    'HORIZONTAL' => 'rotateX(72deg) ',
    'FIXED' => 'rotateY(-28deg) ',
    _ => '',
  };

  String _readout(
    GlossRealDropSettingsDoc doc,
    DropStageTimeline timeline,
    DropStageFrame frame,
  ) {
    final String kind = switch (frame.modelKind) {
      DropModelKind.block => 'cube',
      DropModelKind.flat => 'flat',
      DropModelKind.thin => 'thin',
    };
    return <String>[
      '${_drop.amount}x ${_drop.displayName}',
      '$kind model at ${frame.modelScale.toStringAsFixed(2)}',
      '${timeline.visualCount} of ${doc.limits.maxVisualsPerStack} displays',
      frame.settled
          ? '${doc.landing.mode.toLowerCase()} landing, '
                '${doc.landing.transitionTicks}-tick ease'
          : doc.motion.tumble
          ? 'tumbling ${doc.motion.speedMultiplier.toStringAsFixed(2)}x, '
                'bounce ${frame.bounceRevision}'
          : 'no tumble',
      '${doc.limits.updateIntervalTicks}-tick updates',
      doc.labels.enabled
          ? 'label ${doc.labels.billboard.toLowerCase()}'
          : 'no label',
    ].join(' · ');
  }
}
