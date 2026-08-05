/// The 3D stage: a CSS-3D scene driven imperatively from one rAF loop and one
/// 50 ms simulation tick.
///
/// Jaspr renders the static shell and nothing else. Everything below
/// `.hui-preview-perspective` is built with `document.createElement` and
/// reconciled by hand, because `DomRenderObject.updateElement` rewrites `class`
/// and removes attributes it did not declare — which here would mean wiping
/// every `matrix3d` and every canvas backing store on any parent rebuild. Same
/// reason, same pattern as `canvas_viewport.dart:181-202`.
///
/// The player lives next door in `preview_player.dart`: pointer, wheel and
/// keyboard input, the orbit camera, the whole of Player mode, and every world
/// overlay that exists because somebody is standing somewhere. This file owns
/// the frame loop, the scene resolution, the icon quads and the readouts.
///
/// Two clocks, and the difference between them is the whole preview:
///
///  * The **quads are frozen.** Their world position and their facing were
///    fixed at open (`MenuSession.java:119-122`, `MenuComponent.java:142-144`);
///    billboarding is always FIXED (`MenuIcon.java:112-114`). Orbiting cannot
///    move them, which is why the camera matrix is written to exactly one
///    element and never touches a quad.
///  * The **collision planes re-aim every tick** at the eye
///    (`ClickableComponent.java:60-62`). That is what `hoveredClickableIds`
///    recomputes per tick, and why hovering changes as you orbit even though
///    nothing moved. Turning the plane overlay on is how that becomes visible:
///    the rectangles swing, the icons do not.
///
/// Idle costs nothing. Both clocks are dirty-gated: with no animated icon, no
/// obfuscated span, no held movement key and no input, the timer cancels itself
/// and no frame is scheduled — the same guarantee the 2D canvas gives.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;
import 'package:web/web.dart' as web;

import '../../logic/canvas_scene.dart';
import '../../logic/hui_geometry.dart';
import '../../logic/icon_content.dart';
import '../../logic/mc_text.dart';
import '../../logic/viewport_math.dart';
import '../../model/model.dart';
import '../../preview/action_log.dart';
import '../../preview/preview_scene.dart';
import '../../preview/preview_types.dart';
import '../../preview/projection.dart';
import '../../preview/simulation.dart';
import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../render/icon_sprites.dart';
import 'preview_player.dart';
import 'preview_pose.dart';

/// Sprites rasterize at twice the scene scale and NEVER at a camera-derived
/// one: `spriteCacheKey` carries the px-per-block, so a scale that tracked the
/// dolly would re-rasterize every icon on every wheel notch. Fixed here,
/// upscaled by the compositor, kept crisp by `image-rendering: pixelated` —
/// which is honest, because the source glyphs are pixel art.
const double huiPreviewSpritePxPerBlock = huiPreviewPxPerBlock * 2;

/// Slack left around the framed content when the camera resets, in blocks.
const double huiPreviewFrameMargin = 0.5;

/// Placeholders resolve once, at open, on the server (`TextUtils.parse` via
/// PlaceholderAPI) — the editor cannot expand them and must not pretend to.
final RegExp huiPlaceholderPattern = RegExp(r'%[^%\s]+%');

class PreviewStage extends StatefulWidget {
  const PreviewStage({
    required this.store,
    required this.images,
    required this.pose,
    this.catalogs,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;

  /// Survives this widget being unmounted; see `preview_pose.dart`.
  final PreviewPose pose;

  /// Null until the boot fetch lands; item icons degrade to placeholders.
  final HuiCatalogs? catalogs;

  @override
  State<PreviewStage> createState() => _PreviewStageState();
}

class _PreviewStageState extends State<PreviewStage>
    implements PreviewStageController, PreviewInputHost {
  static int _instances = 0;

  late final String _uid = 'hui-preview-${_instances++}';
  String get _stageId => '$_uid-stage';
  String get _sceneId => '$_uid-scene';
  String get _bannerId => '$_uid-banner';
  String get _hintId => '$_uid-hint';
  String get _crosshairId => '$_uid-crosshair';

  late final IconSpriteRasterizer _rasterizer = IconSpriteRasterizer(
    onReady: _onSpritesStale,
    trueRender: true,
  );
  final McTextCache _textCache = McTextCache();
  final ImageCharCache _charCache = ImageCharCache();
  late final PreviewInput _input = PreviewInput(this);
  final PreviewOverlayLayer _overlays = PreviewOverlayLayer();

  // --- resolved frame ---
  CanvasScene? _canvas;
  PreviewScene? _preview;
  late PreviewSimulation _sim = _newSimulation();
  String _simSignature = '';

  // --- owned DOM ---
  web.HTMLElement? _stage;
  web.HTMLElement? _perspective;
  web.HTMLElement? _camera;
  web.HTMLElement? _menuGroup;
  web.HTMLElement? _banner;
  web.HTMLElement? _hint;
  web.HTMLElement? _crosshair;
  final List<_QuadNode> _quads = <_QuadNode>[];
  web.ResizeObserver? _resizeObserver;

  // --- loop state ---
  Timer? _tickTimer;
  bool _disposed = false;
  bool _dirty = true;
  bool _framePending = false;
  bool _postFramePending = false;

  /// The 2D pass is stale: the document, an animation frame, the obfuscation
  /// scramble or a bitmap changed.
  bool _canvasDirty = true;

  /// Only the 3D lift is stale: the menu centre walked, or the open pose did.
  /// Split from [_canvasDirty] because `followPlayer` moves the centre every
  /// tick a player walks, and re-measuring every glyph for a translation would
  /// make walking the most expensive thing the preview does.
  bool _liftDirty = true;

  bool _inputSinceTick = true;
  bool _needsInitialFrame = true;
  bool _crosshairVisible = false;
  String _liveSignature = '';
  String _cameraTransform = '';
  PreviewFacingMode _renderedFacing = PreviewFacingMode.inGame;
  bool _renderedPaused = false;
  int _renderedSession = -1;

  int _tickCount = 0;
  int _animationTicks = 0;
  int _obfuscationTick = 0;
  bool _sceneHasAnimation = false;
  bool _sceneHasObfuscation = false;
  int _sceneMinAnimationSpeed = 1;

  // --- viewport ---
  double _widthPx = 0;
  double _heightPx = 0;

  EditorStore get _store => component.store;

  PreviewPose get _pose => component.pose;

  bool get _playerMode => _store.previewCameraMode == PreviewCameraMode.player;

  /// Two switches, deliberately. `animationsPlaying` is the canvas toolbar's
  /// global playback and the 2D view shares it; `pose.paused` is the preview's
  /// own, so a builder can freeze the 3D scene without stopping the canvas.
  bool get _animating => _store.animationsPlaying && !_pose.paused;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _pose.addListener(_onPoseChanged);
    component.images.addListener(_onImagesChanged);
    _pose.controller = this;
    _renderedFacing = _pose.facing;
    _renderedPaused = _pose.paused;
    _renderedSession = _pose.sessionId;
    _schedulePostFrame();
  }

  @override
  void didUpdateComponent(PreviewStage oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
    if (!identical(oldComponent.pose, component.pose)) {
      oldComponent.pose.removeListener(_onPoseChanged);
      oldComponent.pose.controller = null;
      component.pose.addListener(_onPoseChanged);
      component.pose.controller = this;
    }
    if (!identical(oldComponent.images, component.images)) {
      oldComponent.images.removeListener(_onImagesChanged);
      component.images.addListener(_onImagesChanged);
    }
    _canvasDirty = true;
    _wake();
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_onStoreChanged);
    _pose.removeListener(_onPoseChanged);
    component.images.removeListener(_onImagesChanged);
    if (identical(_pose.controller, this)) _pose.controller = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    _input.detach();
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    _rasterizer.dispose();
    super.dispose();
  }

  /// Built once and returned by reference forever. See the library comment.
  ///
  /// Every element Dart writes into is declared empty here and filled
  /// imperatively, which is the same bargain the scene itself strikes: Jaspr
  /// owns the node, nothing owns its contents but this state.
  late final Widget _stageTree = dom.div(
    id: _stageId,
    classes: 'hui-preview-stage',
    attributes: const <String, String>{
      'tabindex': '0',
      'role': 'application',
      'aria-label':
          'HoloUI menu preview. Drag to orbit, scroll to dolly, '
          'space or middle-drag to pan, 0 resets to the open position, '
          'left click fires every hovered component, 1 to 6 toggle overlays, '
          'F switches icon facing. In Player mode WASD walks and clicking '
          'takes the pointer for mouselook.',
    },
    <Widget>[
      dom.div(id: _sceneId, classes: 'hui-preview-scene', const <Widget>[]),
      dom.div(
        id: _crosshairId,
        classes: 'hui-preview-crosshair',
        const <Widget>[],
      ),
      dom.div(id: _bannerId, classes: 'hui-preview-banner', const <Widget>[]),
      dom.div(classes: 'hui-preview-hint', <Widget>[
        dom.span(
          id: _hintId,
          classes: 'hui-preview-hint-item',
          const <Widget>[],
        ),
        const dom.span(classes: 'hui-preview-hint-item', <Widget>[
          Component.text(
            'Left click fires every hovered hitbox, in '
            'declaration order',
          ),
        ]),
        const dom.span(
          classes: 'hui-preview-hint-item hui-preview-hint-note',
          <Widget>[
            Component.text(
              '+X is the player\'s RIGHT: HoloUi negates the JSON x '
              'at load (MenuSession.java:70), so the menu is mirrored relative '
              'to the numbers in the file.',
            ),
          ],
        ),
      ]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    _schedulePostFrame();
    return _stageTree;
  }

  // --- PreviewStageController ------------------------------------------------

  /// Frames the menu the way the player who opened it saw it: looking from
  /// their eye, along their yaw, pulled back only as far as it takes to fit the
  /// whole menu and the avatar in shot. In Player mode it also walks them back
  /// to the spot the session opened from.
  @override
  void resetCamera() {
    final PreviewScene? preview = _preview;
    final PVec3 eye = PVec3(
      _pose.openFeet.x,
      _pose.openFeet.y + huiPreviewEyeHeight,
      _pose.openFeet.z,
    );
    if (preview == null) {
      _pose.orbit = _lookFrom(
        eye,
        _pose.openFeet + const PVec3(0, huiPreviewEyeHeight, 2),
      );
    } else {
      final (double x, double y, double distance) frame = _framing(preview);
      // `contentBounds` is the 2D menu plane; its depth is the menu offset's,
      // which is the plane every component sits on before its own z.
      _pose.orbit = _lookFrom(
        eye,
        preview.lift(frame.$1, frame.$2, preview.menuOffset.z),
        distance: frame.$3,
      );
    }
    _pose.player = PlayerPose(
      feet: _pose.openFeet,
      yawDegrees: _pose.openYawDeg,
    );
    _liftDirty = true;
    _wake();
    _markDirty();
  }

  /// Menu-local centre and the camera distance that fits the content.
  ///
  /// A point `b` blocks off-axis at `d` blocks projects to `b × perspective / d`
  /// pixels, so fitting a half-extent inside half the viewport is a division.
  /// The avatar is folded into the bounds because "where the player stands"
  /// is half of what the preview is for.
  (double, double, double) _framing(PreviewScene preview) {
    final WorldBounds bounds = preview.canvas.contentBounds
        .union(
          const WorldBounds(
            minX: 0,
            minY: 0,
            maxX: 0,
            maxY: huiPreviewEyeHeight,
          ),
        )
        .expand(huiPreviewFrameMargin);
    final double halfWidth = math.max(0.5, bounds.width / 2);
    final double halfHeight = math.max(0.5, bounds.height / 2);
    final double byWidth = _widthPx <= 0
        ? 0
        : halfWidth * huiPreviewPerspectivePx / (_widthPx / 2);
    final double byHeight = _heightPx <= 0
        ? 0
        : halfHeight * huiPreviewPerspectivePx / (_heightPx / 2);
    return (
      bounds.centerX,
      bounds.centerY,
      _clampDouble(math.max(byWidth, byHeight), 1.5, OrbitCamera.maxDistance),
    );
  }

  /// A fresh `MenuSession`: new feet, new yaw, new simulation, empty log.
  @override
  void reopenHere() {
    final CameraBasis basis = _basis();
    final PVec3 feet = PVec3(basis.position.x, 0, basis.position.z);
    final double yaw = _viewYawDegrees;
    _pose.captureOpen(feet: feet, yawDeg: yaw);
    // The simulated player IS wherever the menu was just opened from, so
    // switching into Player mode afterwards starts on the right spot rather
    // than back where the previous session began.
    _pose.player = _pose.player.copyWith(feet: feet, yawDegrees: yaw);
    _pose.log.clear();
    _reseedSimulation();
    _canvasDirty = true;
    _liftDirty = true;
    _rebuildScene();
    final PreviewScene? preview = _preview;
    if (preview != null) {
      // Stay exactly where the camera already is; only re-aim at the new
      // centre, so "reopen HERE" does not teleport the view.
      _pose.orbit = _lookFrom(basis.position, preview.center);
    }
    _markDirty();
  }

  /// An orbit pose that looks at [target] from the direction of [from].
  ///
  /// [distance] overrides how far back the camera sits while keeping the aim,
  /// which is what lets the reset frame the whole menu without changing where
  /// the player was looking.
  OrbitCamera _lookFrom(PVec3 from, PVec3 target, {double? distance}) {
    final PVec3 toTarget = target - from;
    final double span = toTarget.length;
    final PVec3 direction = span <= 1e-6
        ? huiLookDirection(yawDegrees: _pose.openYawDeg)
        : toTarget.normalized;
    return OrbitCamera(
      target: target,
      yawDegrees: math.atan2(direction.x, direction.z) * 180 / math.pi,
      pitchDegrees:
          -math.asin(_clampDouble(direction.y, -1, 1)) * 180 / math.pi,
      distance: distance ?? span,
    ).clamped();
  }

  // --- PreviewInputHost ------------------------------------------------------

  @override
  PreviewPose get inputPose => _pose;

  @override
  bool get inputPlayerMode => _playerMode;

  @override
  double get inputWidthPx => _widthPx;

  @override
  double get inputHeightPx => _heightPx;

  @override
  void onInputChanged() {
    _wake();
    _markDirty();
  }

  @override
  void onInputReset() => resetCamera();

  @override
  void onInputClick() {
    onInputEngaged();
    _fireClick();
  }

  /// The facing note retires itself the moment the preview is being USED. The
  /// setter is a no-op once set, so a 60 fps drag costs one comparison.
  @override
  void onInputEngaged() => _store.previewBannerDismissed = true;

  /// The stage's own overlay controls.
  ///
  /// They write the same store flags the toolbar does, so the two surfaces can
  /// never disagree, and they exist because a 3D viewport that needs the mouse
  /// for the camera also needs a way to change what it draws without leaving
  /// it.
  @override
  void onInputToggle(String key) {
    final EditorStore store = _store;
    switch (key) {
      case '1':
        store.previewShowPlanes = !store.previewShowPlanes;
      case '2':
        store.previewShowNormals = !store.previewShowNormals;
      case '3':
        store.previewShowAnchors = !store.previewShowAnchors;
      case '4':
        store.previewShowCenter = !store.previewShowCenter;
      case '5':
        store.previewShowDistanceSphere = !store.previewShowDistanceSphere;
      case '6':
        store.previewShowGroundGrid = !store.previewShowGroundGrid;
      case 'f':
        _pose.facing = _pose.facing == PreviewFacingMode.inGame
            ? PreviewFacingMode.intent
            : PreviewFacingMode.inGame;
      case 'k':
        _pose.paused = !_pose.paused;
    }
  }

  // --- listeners -------------------------------------------------------------

  void _onStoreChanged() {
    _canvasDirty = true;
    _wake();
    _markDirty();
  }

  void _onPoseChanged() {
    // Only a facing flip, a pause or a reopen needs work here; the per-tick
    // readouts live on `pose.live`, which this state does not listen to.
    final bool facingChanged = _renderedFacing != _pose.facing;
    final bool sessionChanged = _renderedSession != _pose.sessionId;
    final bool pauseChanged = _renderedPaused != _pose.paused;
    if (!facingChanged && !sessionChanged && !pauseChanged) return;
    _renderedFacing = _pose.facing;
    _renderedSession = _pose.sessionId;
    _renderedPaused = _pose.paused;
    if (sessionChanged) _canvasDirty = true;
    if (facingChanged || sessionChanged) _liftDirty = true;
    // Unpausing has to restart a timer that cancelled itself while paused.
    _wake();
    _markDirty();
  }

  void _onImagesChanged() {
    _charCache.clear();
    _rasterizer.clear();
    _canvasDirty = true;
    _wake();
    _markDirty();
  }

  /// A bitmap finished decoding, so every sprite that drew the placeholder in
  /// its place is stale. The rasterizer has already cleared its cache.
  void _onSpritesStale() {
    for (final _QuadNode node in _quads) {
      node.spriteKey = '';
    }
    _markDirty();
  }

  // --- frame loop ------------------------------------------------------------

  void _markDirty() {
    if (_disposed) return;
    _dirty = true;
    if (_framePending) return;
    _framePending = true;
    web.window.requestAnimationFrame(_onAnimationFrame.toJS);
  }

  void _onAnimationFrame(double _) {
    _framePending = false;
    if (_disposed || !_dirty) return;
    _dirty = false;
    _render();
  }

  /// Any input, any document change: run the simulation again until it settles.
  void _wake() {
    if (_disposed) return;
    _inputSinceTick = true;
    _tickTimer ??= Timer.periodic(huiAnimationTick, (Timer _) => _tick());
  }

  /// One Minecraft tick.
  ///
  /// Everything time-varying in the runtime hangs off the same 50 ms clock
  /// (`MenuSessionManager.java:82-103`), so one timer drives animation frames,
  /// the obfuscation scramble, the walk step and the hover state machine.
  void _tick() {
    if (_disposed) return;
    final bool hadInput = _inputSinceTick;
    _inputSinceTick = false;
    _tickCount++;

    // Frame advance is `passedTicks >= speed` per icon
    // (`AnimatedTextImageMenuIcon.java:52-60`); waking on the fastest icon's
    // period is what the 2D canvas does and keeps the two in step.
    if (_sceneHasAnimation && _animating) {
      _animationTicks++;
      if (_animationTicks % _sceneMinAnimationSpeed == 0) _canvasDirty = true;
    }
    // Vanilla scrambles obfuscated glyphs about ten times a second. Counted off
    // the tick clock, not the animation clock, which stops when playback does.
    if (_sceneHasObfuscation && !_pose.paused && _tickCount.isEven) {
      _obfuscationTick++;
      _canvasDirty = true;
    }

    final bool rebuilt = _canvasDirty || _liftDirty;
    if (rebuilt) _rebuildScene();
    _simulate();

    final String signature = _computeLiveSignature();
    final bool changed = signature != _liveSignature;
    if (changed) _liveSignature = signature;
    // `_simulate` can dirty the scene again — a closed session, a followPlayer
    // recentre, a committed step — so the flags are read once more after it ran.
    if (changed || rebuilt || _canvasDirty || _liftDirty) _markDirty();

    // Sleep as soon as nothing can change: no animation, no scramble, no input
    // since the last tick, and a hover state that has stopped moving. Hover
    // ticks are compared clamped at 2, so the tick-2 snap is always observed
    // before the timer stops. A held movement key keeps `_inputSinceTick` set
    // through `_simulate`, so walking never sleeps mid-stride.
    // Pausing has to reach this, not just the frame counter: a paused preview
    // that kept the timer alive would never hit zero scheduled frames.
    final bool continuous =
        (_sceneHasAnimation && _animating) ||
        (_sceneHasObfuscation && !_pose.paused);
    if (!continuous && !hadInput && !changed) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  void _simulate() {
    final PreviewScene? preview = _preview;
    if (preview == null) return;
    final CameraBasis basis = _basis();
    final PVec3 eye = basis.position;

    Set<String> hovered = const <String>{};
    final (double, double)? aim = _input.rayPoint();
    if (aim != null && _widthPx > 0 && _heightPx > 0 && _sim.isOpen) {
      final LookRay ray = rayThrough(
        basis: basis,
        viewportWidth: _widthPx,
        viewportHeight: _heightPx,
        pointerX: aim.$1,
        pointerY: aim.$2,
        perspectivePx: huiPreviewPerspectivePx,
      );
      hovered = hoveredClickableIds(scene: preview, ray: ray, eye: eye).toSet();
    }

    final PVec3 standing = _playerFeet;
    final PVec3? attempted = _input.attemptedFeet(huiAnimationTick);
    final PVec3 previousCenter = _sim.center;

    final PreviewTickResult result = _sim.tick(
      hoveredClickableIds: hovered,
      playerFeet: _tickFeet(standing, attempted),
    );

    // The freeze rewrites the destination back to the origin
    // (`MenuSessionManager.java:115-127`); a closed session stops freezing, so
    // walking out of a locked menu is how you get moving again.
    if (attempted != null && !result.movementLocked) {
      _input.commitFeet(attempted);
      _liftDirty = true;
      _wake();
    }
    if (result.center != previousCenter) _liftDirty = true;
    if (result.closedThisTick != null) _canvasDirty = true;

    final String? primary = result.hoveredIds.isEmpty
        ? null
        : result.hoveredIds.first;
    final int ticks = primary == null ? 0 : _sim.hoverTicksFor(primary);
    final double modifier = primary == null
        ? 0
        : (_sim.highlightModifierFor(primary) ?? 0);
    _pose.live.update(
      hoveredId: primary,
      hoveredIds: result.hoveredIds.length,
      hoverTicks: ticks,
      hoverPushBlocks: ticks <= 0 ? 0 : modifier,
      highlightModifier: modifier,
      distanceToCenter: result.distanceToCenter,
      isOpen: result.isOpen,
      closeReason: _sim.closeReason,
      movementLocked: result.movementLocked,
    );
  }

  /// The feet to hand the simulation this tick.
  ///
  /// `MenuSessionManager.java:104-131` range-tests the ATTEMPTED destination
  /// and does it *before* the `lockPosition` branch — but that branch then
  /// `return`s, so `followPlayer` never runs on a frozen move. A frozen session
  /// is therefore tested against a step it never takes and re-centres on
  /// nothing. `PreviewSimulation.tick` folds both stages into one call, so the
  /// destination is handed over only when it is the one deciding the outcome.
  PVec3 _tickFeet(PVec3 standing, PVec3? attempted) {
    if (attempted == null) return standing;
    if (!_sim.lockPosition || !_sim.isOpen) return attempted;
    return huiWithinMaxDistance(
          playerFeet: attempted,
          center: _sim.center,
          maxDistance: _sim.maxDistance,
          menuOffset: _sim.menuOffset,
        )
        ? standing
        : attempted;
  }

  /// Everything a frame can observe, in one string. A stable signature is what
  /// lets the tick timer stop.
  String _computeLiveSignature() {
    final StringBuffer buffer = StringBuffer();
    for (final String id in _sim.hoveredIds) {
      buffer
        ..write(id)
        ..write(':')
        ..write(math.min(2, _sim.hoverTicksFor(id)))
        ..write(';');
    }
    return (buffer
          ..write(_sim.isOpen)
          ..write('|')
          ..write(_sim.center)
          ..write('|')
          ..write(_playerFeet)
          ..write('|')
          ..write(_input.pointerLocked))
        .toString();
  }

  // --- scene -----------------------------------------------------------------

  PreviewSimulation _newSimulation() => PreviewSimulation(
    menu: component.store.menu,
    openFeet: component.pose.openFeet,
    initialToggleState: component.store.togglePreviewFor,
  );

  void _reseedSimulation() {
    _sim = _newSimulation();
    _simSignature = _simulationSignature(_store.menu);
    _liveSignature = '';
    _pose.live.reset();
  }

  void _rebuildScene() {
    final EditorStore store = _store;
    if (_canvasDirty) {
      _canvasDirty = false;
      _liftDirty = true;

      // Reseed BEFORE laying out: everything the simulation caches at
      // construction — offsets, ranges, modifiers, action lists — has to be
      // current, or the log would quote the document as it was when the view
      // mounted, and `_toggleFace` would resolve against a stale machine.
      final String signature = _simulationSignature(store.menu);
      if (signature != _simSignature) _reseedSimulation();

      final CanvasScene canvas = buildCanvasScene(
        menu: store.menu,
        uiScale: store.previewUiScale,
        // The preview is the view that shows where icons REALLY land, so the
        // in-game vertical bias is always on here regardless of the canvas
        // toolbar's own switch.
        trueRender: true,
        togglePreview: _toggleFace,
        textCache: _textCache,
        images: component.images,
        catalogs: huiFreshestCatalogs(store.catalogs, component.catalogs),
        charCache: _charCache,
        animationTicks: _animationTicks,
      );
      _measureSceneClocks(canvas);
      _canvas = canvas;
    }

    final CanvasScene? canvas = _canvas;
    if (canvas == null || !_liftDirty) return;
    _liftDirty = false;
    _preview = buildPreviewScene(
      menu: store.menu,
      // Off the canvas, not the store: `buildPreviewScene` asserts the two
      // agree, and the canvas is the one every measurement was taken at.
      uiScale: canvas.uiScale,
      openFeet: _pose.openFeet,
      openYawDeg: _pose.openYawDeg,
      // The UNROTATED centre: `MenuSession`'s own `centerPoint`, which is what
      // followPlayer walks and what the range check reads. Feeding it
      // `scene.center` would rotate the layout twice.
      currentCenter: _sim.center,
      canvas: canvas,
    );
  }

  /// A toggle previews the icon the editor is showing, which is also the state
  /// the simulation opened with — until a click flips it, and then the preview
  /// follows the simulation rather than the canvas.
  bool _toggleFace(String id) =>
      _sim.toggleStateFor(id) ?? _store.togglePreviewFor(id);

  void _measureSceneClocks(CanvasScene scene) {
    bool obfuscated = false;
    bool animated = false;
    int minSpeed = 1 << 30;
    for (final CanvasItem item in scene.items) {
      final McTextResult? parsed = item.text;
      if (!obfuscated && parsed != null) {
        for (final List<McSpan> line in parsed.lines) {
          for (final McSpan span in line) {
            if (span.obfuscated) obfuscated = true;
          }
        }
      }
      final HuiIcon? icon = item.icon;
      if (icon is HuiAnimatedImageIcon && icon.source.length > 1) {
        animated = true;
        minSpeed = math.min(minSpeed, math.max(1, icon.speed));
      }
    }
    _sceneHasObfuscation = obfuscated;
    _sceneHasAnimation = animated;
    _sceneMinAnimationSpeed = animated ? minSpeed : 1;
  }

  /// Everything `PreviewSimulation` reads once, at construction.
  String _simulationSignature(HuiMenu menu) {
    final StringBuffer buffer = StringBuffer()
      ..write(menu.offset.x)
      ..write(',')
      ..write(menu.offset.y)
      ..write(',')
      ..write(menu.offset.z)
      ..write('|')
      ..write(menu.maxDistance)
      ..write('|')
      ..write(menu.followPlayer)
      ..write('|')
      ..write(menu.lockPosition);
    for (final HuiComponent item in menu.components) {
      buffer
        ..write('|')
        ..write(item.id)
        ..write(':');
      switch (item.data) {
        case HuiButtonData(
          :final double highlightModifier,
          :final List<HuiAction> actions,
        ):
          buffer.write('b$highlightModifier');
          _writeActions(buffer, actions);
        case HuiToggleData(
          :final double highlightModifier,
          :final List<HuiAction> trueActions,
          :final List<HuiAction> falseActions,
        ):
          buffer.write('t$highlightModifier');
          _writeActions(buffer, trueActions);
          _writeActions(buffer, falseActions);
        case HuiDecorationData():
          buffer.write('d');
      }
    }
    return buffer.toString();
  }

  static void _writeActions(StringBuffer buffer, List<HuiAction> actions) {
    for (final HuiAction action in actions) {
      buffer.write('~');
      switch (action) {
        case HuiCommandAction():
          buffer
            ..write('c')
            ..write(action.command)
            ..write('/')
            ..write(action.source)
            ..write('/')
            ..write(action.absentKeys.contains('source'));
        case HuiSoundAction():
          buffer
            ..write('s')
            ..write(action.sound)
            ..write('/')
            ..write(action.source)
            ..write('/')
            ..write(action.volume)
            ..write('/')
            ..write(action.pitch);
      }
    }
  }

  // --- camera ----------------------------------------------------------------

  CameraBasis _basis() => _playerMode
      ? CameraBasis.player(_pose.player)
      : CameraBasis.orbit(_pose.orbit);

  double get _viewYawDegrees =>
      _playerMode ? _pose.player.yawDegrees : _pose.orbit.yawDegrees;

  /// Where the simulated player is standing.
  ///
  /// Orbiting is a camera move, not a walk: the player stays where they opened
  /// the menu, so a dolly can never fool the range check. Player mode is the
  /// only thing that moves the feet.
  PVec3 get _playerFeet => _playerMode ? _pose.player.feet : _pose.openFeet;

  // --- DOM wiring ------------------------------------------------------------

  void _schedulePostFrame() {
    if (_postFramePending || _disposed) return;
    _postFramePending = true;
    context.binding.addPostFrameCallback(() {
      _postFramePending = false;
      if (_disposed) return;
      _attachToDom();
      _syncStageSize();
      _canvasDirty = true;
      _wake();
      _markDirty();
    });
  }

  void _attachToDom() {
    final web.Element? stageElement = web.document.getElementById(_stageId);
    final web.Element? sceneElement = web.document.getElementById(_sceneId);
    if (stageElement == null || sceneElement == null) return;
    final web.HTMLElement stage = stageElement as web.HTMLElement;
    if (identical(_stage, stage) && _camera != null) return;

    _stage = stage;
    _perspective = sceneElement as web.HTMLElement;
    _banner = web.document.getElementById(_bannerId) as web.HTMLElement?;
    _hint = web.document.getElementById(_hintId) as web.HTMLElement?;
    _crosshair = web.document.getElementById(_crosshairId) as web.HTMLElement?;
    final web.HTMLElement? crosshair = _crosshair;
    if (crosshair != null) _styleCrosshair(crosshair);
    _buildWorld();
    _input.attach(stage);
    _observeResize(stage);
  }

  /// The fixed part of the scene graph. Quads are appended to [_menuGroup] as
  /// the document produces them; nothing here is ever rebuilt.
  void _buildWorld() {
    final web.HTMLElement? perspective = _perspective;
    if (perspective == null) return;
    _clear(perspective);
    _quads.clear();

    final web.HTMLElement camera = huiPreviewElement('hui-preview-camera');
    _camera = camera;
    perspective.append(camera);
    _overlays.build(camera);

    // No transform of its own: `cssQuadMatrix` already carries the player
    // anchor and the frozen open-yaw rotation, baked in by `preview_scene`, so
    // a group transform here would apply the rotation twice. It exists to keep
    // quad reconciliation to one parent.
    final web.HTMLElement group = huiPreviewElement('hui-preview-menu');
    _menuGroup = group;
    camera.append(group);
  }

  /// The pointer-lock crosshair. Inline-styled for the reason `huiPreviewCss`
  /// documents: `07-preview.css` belongs to the preview chrome.
  void _styleCrosshair(web.HTMLElement node) =>
      huiPreviewCss(node, <String, String>{
        'position': 'absolute',
        'left': '50%',
        'top': '50%',
        'width': '15px',
        'height': '15px',
        'margin': '-8px 0 0 -8px',
        'z-index': '3',
        'display': 'none',
        'pointer-events': 'none',
        'opacity': '.85',
        'background':
            'linear-gradient(#f7f4ec,#f7f4ec) center/15px 1px '
            'no-repeat, linear-gradient(#f7f4ec,#f7f4ec) center/1px 15px '
            'no-repeat',
      });

  void _observeResize(web.HTMLElement stage) {
    _resizeObserver?.disconnect();
    try {
      final web.ResizeObserver observer = web.ResizeObserver(
        ((JSAny _, JSAny _) => _syncStageSize()).toJS,
      );
      observer.observe(stage);
      _resizeObserver = observer;
    } catch (_) {
      _resizeObserver = null;
    }
  }

  void _syncStageSize() {
    final web.HTMLElement? stage = _stage;
    if (stage == null || _disposed) return;
    final web.DOMRect rect = stage.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    if (rect.width == _widthPx && rect.height == _heightPx) return;
    _widthPx = rect.width;
    _heightPx = rect.height;
    _wake();
    _markDirty();
  }

  void _fireClick() {
    final List<ActionLogEntry> fired = _sim.click();
    if (fired.isEmpty) return;
    _pose.log.addAll(huiMarkOmittedCommandSources(fired, _store.menu));
    // A toggle just swapped its icon; the scene resolves toggle faces through
    // the simulation, so it has to be re-laid out.
    _canvasDirty = true;
    _wake();
    _markDirty();
  }

  // --- rendering -------------------------------------------------------------

  void _render() {
    if (_disposed) return;
    if (_canvasDirty || _liftDirty) _rebuildScene();
    final PreviewScene? preview = _preview;
    final web.HTMLElement? camera = _camera;
    if (preview == null || camera == null) return;

    // The preview opens framed. Deferred to the first render because the fit
    // needs both a laid-out scene and a measured viewport.
    if (_needsInitialFrame && _widthPx > 0) {
      _needsInitialFrame = false;
      resetCamera();
    }

    final CameraBasis basis = _basis();
    huiPreviewWriteTransform(
      camera,
      cssMatrix3d(
        cssCameraMatrix(
          basis: basis,
          perspectivePx: huiPreviewPerspectivePx,
          pxPerBlock: huiPreviewPxPerBlock,
        ),
      ),
      _cameraTransform,
      (String value) => _cameraTransform = value,
    );

    _overlays.render(
      preview: preview,
      sim: _sim,
      eye: basis.position,
      playerFeet: _playerFeet,
      playerMode: _playerMode,
      flags: _overlayFlags(),
    );
    _renderQuads(preview, basis.position);
    _renderCrosshair();
    _renderHint();
    _renderBanner();
  }

  PreviewOverlayFlags _overlayFlags() {
    final EditorStore store = _store;
    return PreviewOverlayFlags(
      groundGrid: store.previewShowGroundGrid,
      center: store.previewShowCenter,
      planes: store.previewShowPlanes,
      normals: store.previewShowNormals,
      anchors: store.previewShowAnchors,
      range: store.previewShowDistanceSphere,
    );
  }

  void _renderQuads(PreviewScene preview, PVec3 eye) {
    final web.HTMLElement? group = _menuGroup;
    if (group == null) return;
    final List<PreviewQuad> quads = preview.quads;
    final bool open = _sim.isOpen;

    while (_quads.length > quads.length) {
      _quads.removeLast().root.remove();
    }
    while (_quads.length < quads.length) {
      final _QuadNode node = _QuadNode.create();
      _quads.add(node);
      group.append(node.root);
    }

    for (int i = 0; i < quads.length; i++) {
      _renderQuad(_quads[i], quads[i], preview, eye, open);
    }
  }

  void _renderQuad(
    _QuadNode node,
    PreviewQuad quad,
    PreviewScene preview,
    PVec3 eye,
    bool open,
  ) {
    final IconSprite? sprite = _rasterizer.sprite(
      quad.item,
      pxPerBlock: huiPreviewSpritePxPerBlock,
      uiScale: preview.uiScale,
      obfuscationTick: _obfuscationTick,
    );
    if (sprite == null || !open) {
      node.root.classList.toggle('is-hidden', true);
      return;
    }
    node.root.classList.toggle('is-hidden', false);

    final String key = spriteCacheKey(
      quad.item,
      pxPerBlock: huiPreviewSpritePxPerBlock,
      uiScale: preview.uiScale,
      obfuscationTick: _obfuscationTick,
    );
    if (key != node.spriteKey) {
      node.spriteKey = key;
      node.blit(sprite);
      node.setPlaceholder(_placeholderTextOf(quad.item));
      node.root.setAttribute('data-id', quad.id);
      // The only observable trace of the animation clock: canvas pixels are not
      // DOM mutations, so without this the frame cadence cannot be checked from
      // outside the app. Written only when the appearance actually changed.
      if (quad.item.isAnimated) {
        node.root.setAttribute('data-frame', '${quad.item.animationFrame}');
      }
    }

    // Size AND centre from the one rectangle the bitmap was rasterized to
    // (`spriteExtentFor`). It is relative to the anchor, so a cached sprite
    // shared by two identical decorations still lands on each item's own
    // position, and there is no second derivation that could drift from the
    // pixels: the drawn icon sits `huiTextTrueRenderBias` below the anchor and
    // its click plane follows the same rendered centre.
    final HuiRect extent = sprite.localRect;

    // Hover push along the plane's CURRENT normal: the plane re-aims at the
    // eye every tick, so the direction an icon leans is a live value even
    // though the icon's own facing is frozen.
    PVec3 position = preview.lift(
      quad.item.anchor.x + extent.x,
      quad.item.anchor.y + extent.y,
      quad.item.depth,
    );
    final int ticks = _sim.hoverTicksFor(quad.id);
    if (ticks > 0 && quad.hasPlane) {
      position =
          position +
          hoverPush(
            aimQuadPlane(quad, eye),
            _sim.highlightModifierFor(quad.id) ?? 0,
            ticks,
          );
    }

    final String transform =
        '${cssMatrix3d(cssQuadMatrix(position: position, facingYawDegrees: _facingYawFor(quad, preview.openYawDeg), pxPerBlock: huiPreviewPxPerBlock))} translate(-50%,-50%)';
    huiPreviewWriteTransform(
      node.root,
      transform,
      node.transform,
      (String value) => node.transform = value,
    );
    huiPreviewWriteSize(
      node.root,
      extent.w * huiPreviewPxPerBlock,
      extent.h * huiPreviewPxPerBlock,
      node,
    );
    node.root.classList.toggle('is-hovered', ticks > 0);
    node.root.classList.toggle('is-decoration', !quad.clickable);
  }

  /// The whole icon-facing bug, in one function.
  ///
  /// `billboardMode()` is FIXED for every icon (`MenuIcon.java:112-114`) and
  /// `MenuSession.rotate` — the only caller path into `MenuIcon.rotate` — has
  /// no caller of its own, so text, image and animated displays spawn at world
  /// yaw 0 (`MenuIcon.java:129-131`) and are never turned. `ItemMenuIcon.spawn`
  /// is the exception: it yaws item displays at the player directly
  /// (`ItemMenuIcon.java:117-120`). Component POSITIONS are rotated either way
  /// (`MenuComponent.java:142-144`), so the layout follows the player while the
  /// glyphs do not.
  double _facingYawFor(PreviewQuad quad, double openYawDeg) =>
      switch (_pose.facing) {
        PreviewFacingMode.intent => openYawDeg,
        PreviewFacingMode.inGame => switch (quad.item.kind) {
          CanvasIconKind.item || CanvasIconKind.customItem => openYawDeg,
          CanvasIconKind.text ||
          CanvasIconKind.image ||
          CanvasIconKind.missing => 0,
        },
      };

  /// Raw authored text, not the parsed spans: a placeholder is a source-file
  /// fact, and `%player_name%` survives MiniMessage parsing unchanged anyway.
  String? _placeholderTextOf(CanvasItem item) {
    final HuiIcon? icon = item.icon;
    if (icon is! HuiTextIcon) return null;
    final Iterable<RegExpMatch> found = huiPlaceholderPattern.allMatches(
      icon.text,
    );
    if (found.isEmpty) return null;
    return found.map((RegExpMatch match) => match.group(0)!).join(' ');
  }

  void _renderCrosshair() {
    final web.HTMLElement? crosshair = _crosshair;
    if (crosshair == null) return;
    final bool visible = _input.pointerLocked;
    if (visible == _crosshairVisible) return;
    _crosshairVisible = visible;
    crosshair.style.setProperty('display', visible ? 'block' : 'none');
  }

  void _renderHint() {
    final web.HTMLElement? hint = _hint;
    if (hint == null) return;
    final String text = _playerMode
        ? 'WASD walks - click takes the pointer, Esc releases - 0 returns to '
              'the open spot - 1-6 overlays - F facing - K pause'
        : 'Drag orbits - scroll dollies - space-drag pans - 0 resets - '
              '1-6 overlays - F facing - K pause';
    if (hint.textContent == text) return;
    hint.textContent = text;
  }

  /// The scene's one teaching label: which facing mode is on, and whatever the
  /// current mode or overlay needs said in words rather than geometry.
  ///
  /// The facing line is one sentence and closes for good — by its own button or
  /// by the first drag, dolly or click, because someone driving the stage has
  /// stopped reading it. The long version lives behind the toolbar's facing
  /// help, next to the mode buttons it describes. The situational notes below
  /// are NOT dismissible: they report state the user turned on, and vanish
  /// when it is turned off.
  ///
  /// The session readout is not here — that is `preview_hud.dart`'s chrome
  /// strip, which lives in the view's grid where a screen reader can reach it.
  void _renderBanner() {
    final web.HTMLElement? banner = _banner;
    if (banner == null) return;
    final PreviewFacingMode facing = _pose.facing;
    final bool locked = _input.pointerLocked;
    final bool sphere = _store.previewShowDistanceSphere;
    final bool paused = _pose.paused;
    final bool dismissed = _store.previewBannerDismissed;
    final String range = sphere ? huiPreviewRangeSummary(_sim) : '';
    // `pointerLockAvailable` belongs in the signature: it flips asynchronously,
    // from a `pointerlockerror` that changes no other value here, and without
    // it the banner keeps telling a browser that already refused to click and
    // take the pointer.
    final String signature =
        '${facing.name}|$_playerMode|$locked|$paused|'
        '$range|${_input.pointerLockAvailable}|$dismissed';
    if (banner.getAttribute('data-signature') == signature) return;
    banner.setAttribute('data-signature', signature);
    banner.setAttribute('data-mode', facing.name);
    _clear(banner);
    if (!dismissed) {
      final web.HTMLElement head = huiPreviewElement('hui-preview-banner-head');
      head.append(_text('hui-preview-banner-mode', facing.label));
      head.append(_bannerCloseButton());
      banner.append(head);
      banner.append(_text('hui-preview-banner-body', facing.headline));
    }
    if (paused) {
      _note(
        banner,
        '#ffd479',
        'Paused (K). Animated frames and obfuscated glyphs are frozen and '
            'the preview schedules no work at all; hover and clicks still run.',
      );
    }
    if (sphere) {
      // The rings show the boundary; only a number can say WHY it is not the
      // maxDistance the file asked for (`MenuSession.java:147-151`).
      _note(banner, '#ff7a7a', 'maxDistance $range');
    }
    if (_playerMode) {
      _note(
        banner,
        '#7fd4ff',
        locked
            ? 'Player mode: the mouse looks, WASD walks at 4.3 blocks a '
                  'second, and the crosshair is the look ray the runtime '
                  'hit-tests. Escape releases the pointer.'
            : _input.pointerLockAvailable
            ? 'Player mode: click the stage to take the pointer, then the '
                  'mouse looks and WASD walks. Escape gives it back.'
            : 'Player mode: this browser refused the pointer lock, so the '
                  'cursor is the aim instead. WASD still walks.',
      );
    }
    // Nothing left to say: the box goes, rather than sitting there empty on
    // top of the menu it is meant to explain.
    banner.classList.toggle('is-hidden', banner.childElementCount == 0);
  }

  /// Closes the facing note for good. The stage swallows pointerdown to start
  /// a drag, so the press is stopped here before it becomes a camera move.
  web.HTMLElement _bannerCloseButton() {
    final web.HTMLButtonElement button =
        web.document.createElement('button') as web.HTMLButtonElement;
    button
      ..className = 'hui-preview-banner-close'
      ..type = 'button'
      ..textContent = '×';
    button.setAttribute('aria-label', 'Dismiss the icon facing note');
    button.setAttribute(
      'title',
      'Dismiss. The full explanation stays in the toolbar, beside In-game / '
          'Intent.',
    );
    button.addEventListener(
      'pointerdown',
      ((web.Event event) => event.stopPropagation()).toJS,
    );
    button.addEventListener(
      'click',
      ((web.Event event) {
        event.stopPropagation();
        _store.previewBannerDismissed = true;
      }).toJS,
    );
    return button;
  }

  static void _note(web.HTMLElement banner, String color, String text) {
    final web.HTMLElement node = _text('hui-preview-banner-body', text);
    node.style.setProperty('color', huiPreviewAlpha(color, .82));
    banner.append(node);
  }

  // --- small DOM helpers -----------------------------------------------------

  static web.HTMLElement _text(String classes, String value) {
    final web.HTMLElement node = huiPreviewElement(classes);
    node.textContent = value;
    return node;
  }

  /// `replaceChildren()` in package:web demands an argument, and assigning an
  /// empty `textContent` is the shortest correct way to empty an element.
  static void _clear(web.HTMLElement node) => node.textContent = '';

  static double _clampDouble(double value, double min, double max) =>
      value.isNaN ? min : (value < min ? min : (value > max ? max : value));
}

/// One icon quad: a wrapper carrying the world transform, a canvas the quad
/// OWNS, and an optional placeholder strip.
///
/// The canvas is owned rather than adopted on purpose. `IconSpriteRasterizer`
/// hands back a cached `HTMLCanvasElement`, and an element can only live at one
/// place in the DOM — inserting the cached one would silently steal it from
/// whichever identical component drew it first, so two identical decorations
/// would fight over a single node. Blitting is the guard.
class _QuadNode extends PreviewSizedNode {
  _QuadNode._(this.root, this.canvas, this.placeholder);

  factory _QuadNode.create() {
    final web.HTMLElement root = huiPreviewElement('hui-preview-quad');
    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
      ..className = 'hui-preview-quad-canvas';
    final web.HTMLElement placeholder = huiPreviewElement(
      'hui-preview-quad-placeholder',
    );
    placeholder.classList.toggle('is-hidden', true);
    root.append(canvas);
    root.append(placeholder);
    return _QuadNode._(root, canvas, placeholder);
  }

  final web.HTMLElement root;
  final web.HTMLCanvasElement canvas;
  final web.HTMLElement placeholder;

  String spriteKey = '';
  String transform = '';

  void blit(IconSprite sprite) {
    final int width = sprite.canvas.width;
    final int height = sprite.canvas.height;
    if (width <= 0 || height <= 0) return;
    if (canvas.width != width) canvas.width = width;
    if (canvas.height != height) canvas.height = height;
    final web.RenderingContext? raw = canvas.getContext('2d');
    if (raw == null) return;
    final web.CanvasRenderingContext2D ctx =
        raw as web.CanvasRenderingContext2D;
    ctx.clearRect(0, 0, width.toDouble(), height.toDouble());
    ctx.drawImage(sprite.canvas, 0, 0, width.toDouble(), height.toDouble());
  }

  void setPlaceholder(String? found) {
    if (found == null) {
      placeholder.classList.toggle('is-hidden', true);
      root.removeAttribute('title');
      return;
    }
    placeholder.classList.toggle('is-hidden', false);
    root.setAttribute(
      'title',
      '$found resolves once, at open, on the server. The editor has no '
          'PlaceholderAPI, so it is drawn verbatim.',
    );
  }
}
