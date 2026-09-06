/// The hologram stage: the text Gloss spawns, standing in the rendered world.
///
/// One line stack over the world's ground plane, posed by the document's
/// `billboard` mode. The stack is DOM text in the stage's CSS-3D layer: its
/// anchor element carries the world pose from `mcDomAnchorTransform`, so a
/// `FIXED` hologram foreshortens as you orbit past it and reads mirrored from
/// behind, which is what the client draws. Inside that layer one block is
/// [huiPreviewPxPerBlock] css pixels and the camera matrix does the
/// perspective, so the plate only sizes itself.
///
/// The stage stands every hologram at [_stageAnchor], the block over spawn,
/// so it always meets the ground; the document's own world coordinates are a
/// readout, not a place on this stage. The ground grid is the renderer's, off
/// this view's own grid toggle, off by default.
///
/// The camera, its pointer, wheel, key and touch input, and the canvas belong
/// to `McStage`; this file writes numbers into styles and reads the camera
/// back out of the controller. Scene geometry still comes from
/// `logic/gloss_hologram_scene.dart`, which is DOM-free and tested on the VM.
///
/// The readout names the mode and what one camera cannot show about it: the
/// three tracking modes are solved against this camera, while in game every
/// viewer gets their own solution.
///
/// With `gameContext` the world is the game screen's world and the stack
/// anchors into it, which puts the client's HUD around the in-world view.
///
/// The stage owns a playback clock while any line references an animation
/// document and the store's animations toggle is on. It is only mounted while
/// the hologram view is active (see `editor_shell.dart`), so a hidden stage
/// costs nothing.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;
import 'package:gloss_editor/l10n/hui_localizations.dart';

import '../../logic/gloss_hologram_scene.dart';
import '../../logic/gloss_particle_text.dart';
import '../../logic/gloss_show.dart';
import '../../logic/gloss_text.dart';
import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_projection_bridge.dart';
import '../../mc/scene/mc_scene.dart';
import '../../model/model.dart';
import '../../preview/projection.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_display_text.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../gloss/gloss_text_line.dart';
import '../mc/mc_dom_layer.dart';
import '../mc/mc_stage.dart';
import '../mc/mc_stage_controller.dart';

/// Animation playback repaint period. Fine enough for the 1 ms floor to look
/// continuous without running a menu-preview-grade frame loop.
const Duration _tickPeriod = Duration(milliseconds: 50);

class HologramView extends StatefulWidget {
  const HologramView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;

  /// Mounts the stage inside the shared Minecraft game-screen frame instead
  /// of filling the editor pane. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<HologramView> createState() => _HologramViewState();
}

class _HologramViewState extends State<HologramView> {
  /// Where the stage draws every hologram: the block over spawn, standing on
  /// the world's ground plane at y = 0.
  static const McVec3 _stageAnchor = McVec3(0.5, 0, 0.5);

  /// The editor stage frames the stack's midpoint and orbits; the game frame
  /// stands at the client's eye over the anchor and does not.
  late final McStageController _stage = McStageController(
    kind: component.gameContext ? McStageKind.frame : McStageKind.hologram,
    homePivot: component.gameContext
        ? McVec3(_stageAnchor.x, mcCameraEyeHeight, _stageAnchor.z)
        : _pivotFor(_store.hologramDoc),
    freeCamera: !component.gameContext,
  );

  Timer? _ticker;

  /// The block-grid overlay is this view's own toggle, off by default: a
  /// hologram stands on the world, and the grid is a measuring aid.
  bool _showGrid = false;
  bool? _gridVisible;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _stage.addListener(_onStageChanged);
    _stage.spriteFor = _spriteFor;
    _syncStage();
  }

  /// The no-WebGL sprite for a node, off the catalogs the store holds now.
  String? _spriteFor(McSceneNode node) => mcCatalogSpriteFor(_store.catalogs, node);

  @override
  void didUpdateComponent(covariant HologramView oldComponent) {
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
    if (!mounted) return;
    _syncStage();
    setState(() {});
  }

  /// The anchored text is built here, so a camera the stage moved has to
  /// rebuild this view, not only the canvas.
  void _onStageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// What the stage draws for the open document: the home framing centres the
  /// stack (the game frame keeps the client's eye), and the block grid follows
  /// this view's toggle.
  void _syncStage() {
    if (!component.gameContext) _stage.homePivot = _pivotFor(_store.hologramDoc);
    final bool grid = _showGrid;
    if (grid == _gridVisible) return;
    _gridVisible = grid;
    _stage.scene = McScene(const <McSceneNode>[], gridVisible: grid);
  }

  /// The anchor at half the stack height, in stage blocks: the framing the
  /// home camera centres on.
  static McVec3 _pivotFor(GlossHologramDoc? doc) {
    final int lines = doc?.lines.length ?? 1;
    return McVec3(
      _stageAnchor.x,
      lines * glossHologramLineHeightBlocks / 2,
      _stageAnchor.z,
    );
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

  void _stopPointer(Object? event) {
    (event as JSObject?)?.callMethod<JSAny?>('stopPropagation'.toJS);
  }

  void _zoomBy(double factor) {
    _stage.camera = _stage.camera
        .copyWith(distance: _stage.camera.distance * factor)
        .clamped();
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
  }

  @override
  Widget build(BuildContext context) {
    final GlossHologramDoc? doc = _store.hologramDoc;
    if (doc == null) {
      _syncTicker(false);
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.world,
          label: huiText('Hologram in game'),
        );
      }
      return const dom.div(classes: 'hui-hologram-stage is-empty', <Widget>[]);
    }
    final GlossAnimationResolver animations = _store.workspaceAnimations;
    final bool animated =
        hologramIsAnimated(doc, animations) ||
        doc.particleLayers.isNotEmpty ||
        doc.extras['show'] is String;
    _syncTicker(animated);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    // Viewport size only centres a projection, so the fallback before the
    // stage's first measure changes none of the numbers read below.
    final double viewportWidth = _stage.widthPx > 0 ? _stage.widthPx : 960;
    final double viewportHeight = _stage.heightPx > 0 ? _stage.heightPx : 600;
    final CameraBasis basis = mcCameraBasis(_stage.camera);
    final GlossHologramDoc staged = _stagedDoc(doc);
    final HologramBillboardPlacement? placement = hologramBillboardPlacement(
      basis: basis,
      anchor: staged.anchor,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final List<GlossLineRender> lines = hologramRenderedLines(
      doc,
      animations: animations,
      emoji: _store.workspaceEmoji,
      nowMs: nowMs,
    );
    final HologramPlaneTransform plane = placement == null
        ? HologramPlaneTransform.identity
        : hologramPlaneTransform(
            basis: basis,
            doc: staged,
            placement: placement,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
          );
    final double homeDistance = mcCameraHome(
      _stage.kind,
      _stage.homePivot,
    ).distance;
    final int zoomPercent = (homeDistance / _stage.camera.distance * 100)
        .round();

    final bool shows =
        placement != null && glossShowMatches(doc.extras['show'], nowMs: nowMs);
    final List<Widget> overlay = <Widget>[
      if (shows)
        _anchored(
          billboard: _billboardMode(doc.style.billboard),
          yawDeg: doc.yaw,
          pitchDeg: doc.pitch,
          child: _billboard(lines, doc, nowMs ~/ 50),
        ),
      if (shows)
        _anchored(billboard: McBillboardMode.center, child: _anchorMarker),
    ];

    final List<Widget> controls = <Widget>[
      dom.div(
        // The stage listens for pointerdown on its own root to start an
        // orbit; a control press must not become a drag.
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'gap': '8px',
          },
        ),
        attributes: <String, String>{
          'role': 'group',
          'aria-label': huiText('Hologram preview controls'),
        },
        events: <String, EventCallback>{'pointerdown': _stopPointer},
        <Widget>[
          _cameraAction(
            label: huiText('Zoom out'),
            icon: ArcaneIcon.zoomOut(size: IconSize.sm),
            onPressed: () => _zoomBy(1.25),
          ),
          dom.span(classes: 'hui-hologram-zoom', <Widget>[
            Text(
              huiText("{zoomPercent}%", <String, Object?>{
                'zoomPercent': zoomPercent,
              }),
            ),
          ]),
          _cameraAction(
            label: huiText('Zoom in'),
            icon: ArcaneIcon.zoomIn(size: IconSize.sm),
            onPressed: () => _zoomBy(0.8),
          ),
          _cameraAction(
            label: huiText('Reset view'),
            icon: ArcaneIcon.maximize(size: IconSize.sm),
            onPressed: _stage.resetCamera,
          ),
          _cameraAction(
            label: huiText('Block grid'),
            icon: ArcaneIcon.grid3x3(size: IconSize.sm),
            onPressed: _toggleGrid,
            pressed: _showGrid,
          ),
        ],
      ),
      if (!component.gameContext) _readout(doc, plane),
    ];

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.world,
        label: huiText('Hologram in game'),
        world: _stage,
        worldOverlay: overlay,
        controls: controls,
        child: const dom.div(<Widget>[]),
      );
    }
    return McStage(
      controller: _stage,
      overlay: overlay,
      controls: controls,
      label: huiText('Hologram stage preview'),
    );
  }

  /// [doc] posed where the stage draws it. The scene math reads the anchor
  /// out of the document, so the readout's mirrored and edge-on notes are
  /// solved at [_stageAnchor] too — the place the stack actually stands.
  GlossHologramDoc _stagedDoc(GlossHologramDoc doc) => GlossHologramDoc(
    anchor: GlossHologramAnchor(
      positionRaw: <double>[_stageAnchor.x, _stageAnchor.y, _stageAnchor.z],
    ),
    style: doc.style,
    yaw: doc.yaw,
    pitch: doc.pitch,
  );

  /// An unknown mode is drawn as `CENTER`, which is how the scene math reads
  /// it (`hologramFacing`); `McBillboardMode.parse` falls back to `FIXED`.
  static McBillboardMode _billboardMode(String billboard) =>
      switch (billboard.trim().toLowerCase()) {
        'fixed' => McBillboardMode.fixed,
        'vertical' => McBillboardMode.vertical,
        'horizontal' => McBillboardMode.horizontal,
        _ => McBillboardMode.center,
      };

  /// One element in the stage's CSS-3D layer, posed at [_stageAnchor] with
  /// its bottom-centre on the anchor. FIXED keeps both document angles,
  /// VERTICAL the pitch only; the layer ignores what a mode does not use.
  Widget _anchored({
    required McBillboardMode billboard,
    required Widget child,
    double yawDeg = 0,
    double pitchDeg = 0,
  }) => dom.div(
    classes: 'hui-mc-anchor',
    styles: dom.Styles(
      raw: <String, String>{
        'transform': mcDomAnchorTransform(
          camera: _stage.camera,
          position: _stageAnchor,
          billboard: billboard,
          yawDeg: yawDeg,
          pitchDeg: pitchDeg,
        ),
      },
    ),
    <Widget>[child],
  );

  /// The line stack, bottom-centred on the anchor and growing upward, exactly
  /// like the joined `TextDisplay` string. Font metrics are the scene
  /// constants: a 0.25-block line advance with an 8-px glyph, in the layer's
  /// own block pixels.
  ///
  /// The anchor element carries the pose, so all that is left here is the
  /// document's non-uniform scale — `scaleY` is already in the line height, so
  /// the box only stretches by the ratio of the two — about the bottom-centre
  /// the entity turns around.
  Widget _billboard(
    List<GlossLineRender> lines,
    GlossHologramDoc doc,
    int tick,
  ) {
    final double linePx =
        glossHologramLineHeightBlocks * huiPreviewPxPerBlock * doc.style.scaleY;
    final double fontPx = linePx * 0.8;
    final double plateScaleX = doc.style.scaleY == 0
        ? 1
        : doc.style.scaleX / doc.style.scaleY;
    final GlossParticleTextRendered rendered = _particleText(lines);
    return dom.div(
      classes: 'hui-hologram-billboard',
      styles: dom.Styles(
        raw: <String, String>{
          // The class places the plate for the retired 2D stage; in the 3D
          // layer the anchor takes its size from this box instead.
          'position': 'relative',
          'font-size': '${fontPx.toStringAsFixed(2)}px',
          'line-height': '${linePx.toStringAsFixed(2)}px',
          'transform-origin': '50% 100%',
          'transform': 'scaleX(${plateScaleX.toStringAsFixed(5)})',
        },
      ),
      <Widget>[
        GlossParticleOverlay(
          layers: doc.particleLayers,
          pixelsPerBlock: huiPreviewPxPerBlock,
          tick: tick,
          renderedText: rendered,
          textScale: doc.style.scaleY,
        ),
        GlossDisplayText(
          style: doc.style,
          box: doc.box,
          pixelsPerFontPixel: linePx / 10,
          child: dom.div(<Widget>[
            for (final GlossLineRender line in lines)
              dom.div(classes: 'hui-hologram-line', <Widget>[
                GlossTextLine(render: line),
              ]),
          ]),
        ),
      ],
    );
  }

  GlossParticleTextRendered _particleText(List<GlossLineRender> lines) {
    final StringBuffer text = StringBuffer();
    final List<GlossParticleTextSpan> spans = <GlossParticleTextSpan>[];
    for (int index = 0; index < lines.length; index++) {
      if (index > 0) text.write('\n');
      final GlossLineRender line = lines[index];
      final int offset = text.length;
      text.write(line.renderedText);
      spans.addAll(<GlossParticleTextSpan>[
        for (final GlossParticleTextSpan span in line.particleSpans)
          GlossParticleTextSpan(
            name: span.name,
            start: span.start + offset,
            end: span.end + offset,
          ),
      ]);
    }
    return GlossParticleTextRendered(
      text: text.toString(),
      spans: List<GlossParticleTextSpan>.unmodifiable(spans),
    );
  }

  /// The anchor point itself, camera-facing so it reads at any orbit. The
  /// layer puts an element's bottom-centre on the anchor; half the marker's
  /// height back up centres the diamond on it.
  static const Widget _anchorMarker = dom.div(
    classes: 'hui-hologram-anchor',
    styles: dom.Styles(
      raw: <String, String>{
        'position': 'relative',
        'margin-bottom': '-4px',
        'transform': 'rotate(45deg)',
      },
    ),
    <Widget>[],
  );

  Widget _readout(GlossHologramDoc doc, HologramPlaneTransform plane) {
    final List<double> position = doc.anchor.position;
    return dom.span(classes: 'hui-mc-readout', <Widget>[
      Text(
        huiText(
          '{world} {x}, {y}, {z} · TextDisplay · {billboard}{viewNote} · '
          'drag to orbit, wheel or controls to zoom',
          <String, Object?>{
            'world': doc.anchor.world.isEmpty
                ? huiText('(no world)')
                : doc.anchor.world,
            'x': position[0].toStringAsFixed(2),
            'y': position[1].toStringAsFixed(2),
            'z': position[2].toStringAsFixed(2),
            'billboard': hologramBillboardNote(doc.style.billboard),
            'viewNote': plane.isEdgeOn
                ? huiText(
                    ' · edge-on from here, so it draws as nothing — '
                    'in game too',
                  )
                : plane.isMirrored
                ? huiText(' · reading it from behind now')
                : '',
          },
        ),
      ),
      if (!_stage.webGlAvailable) Text(' · ${_noWebGlNote()}'),
    ]);
  }

  /// Appended to the readout when the stage fell back to the still.
  String _noWebGlNote() => huiText(
    'No WebGL2 in this browser: the world is a still and models are '
    'sprites',
  );

  /// [pressed] makes it a toggle: the state reads out of the button, not out
  /// of the stage.
  Widget _cameraAction({
    required String label,
    required ArcaneGlyph icon,
    required void Function() onPressed,
    bool? pressed,
  }) => Button(
    variant: (pressed ?? false)
        ? ButtonVariant.secondary
        : ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: onPressed,
    attributes: <String, String>{
      'aria-label': label,
      'title': label,
      if (pressed != null) 'aria-pressed': '$pressed',
    },
    icon: icon,
  );
}
