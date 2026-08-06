/// The canvas viewport: a DPR-aware HTML5 canvas plus its control strip.
///
/// Rendering is driven by a single dirty flag and one on-demand
/// `requestAnimationFrame`; the Jaspr tree is never rebuilt for a pan, a zoom
/// or a drag. Transform changes are committed straight to the canvas and to the
/// two DOM readouts, which is the anim-al shadowbox pattern (report-animal 4.1)
/// and the only way a 60 fps drag stays cheap.
///
/// Keyboard handling is element-scoped: the stage owns `keydown` and calls
/// `stopPropagation` for the keys it consumes, so the shell's document-level
/// binder never double-fires while the canvas has focus.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, ListenableBuilder;
import 'package:web/web.dart' as web;

import '../../config/editing.dart';
import '../../logic/canvas_scene.dart';
import '../../logic/hui_geometry.dart' show HuiRect;
import '../../logic/mc_text.dart';
import '../../logic/multi_select.dart';
import '../../logic/viewport_math.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../render/canvas_assets.dart';
import '../render/canvas_brush.dart';
import '../render/icon_renderers.dart';
import '../shell/shell_status.dart';
import 'backdrop.dart';
import 'canvas_painter.dart';
import 'canvas_toolbar.dart';

part 'canvas_interactions.dart';

/// Obfuscated text re-scrambles at this rate, like the vanilla client.
const Duration huiObfuscationInterval = Duration(milliseconds: 100);

/// Toolbar and keyboard zoom step.
const double huiZoomStep = 1.25;

/// How long an eased camera move takes: the zoom buttons, fit and reset.
///
/// Sits between --hui-dur-2 and --hui-dur-3 deliberately. A camera move is a
/// full-surface change, but a 320 ms one makes a second click feel queued. The
/// wheel is never eased — a wheel notch is already the animation, and easing it
/// would fight the user's own inertia.
const Duration huiViewportEase = Duration(milliseconds: 180);

/// The selection ring advances one dash step per tick.
///
/// Slower than the 50 ms animation clock on purpose: the ring is peripheral and
/// every tick costs a full canvas repaint. 80 ms x [huiSelectionDashStep] over
/// the 10 px [huiSelectionDash] period is one cycle every 400 ms.
const Duration huiSelectionMarchInterval = Duration(milliseconds: 80);

/// One eased camera move in flight.
///
/// Zoom interpolates in LOG space and the camera target in world blocks, so a
/// fit that both zooms and travels holds a constant apparent speed instead of
/// spending most of its time nearly still at the far end.
class _ViewportEase {
  _ViewportEase({
    required this.fromZoom,
    required this.fromX,
    required this.fromY,
    required this.toZoom,
    required this.toX,
    required this.toY,
    required this.target,
  });

  final double fromZoom;
  final double fromX;
  final double fromY;
  final double toZoom;
  final double toX;
  final double toY;

  /// Committed verbatim on the closing frame, so an eased move can never land a
  /// hair off the transform the commit path actually computed.
  final HuiViewport target;

  /// Stamped on the first frame that sees the ease, not when it is created:
  /// otherwise the gap between the click and the next rAF is spent before the
  /// first pixel moves.
  double startMs = -1;
}

/// Catch radius for the smart alignment guides, in SCREEN pixels. Converted to
/// blocks per drag through the live viewport, so the guides feel the same at
/// every zoom instead of becoming unusable when zoomed in.
const double huiGuideCatchPx = 8;

/// Shown in the status bar for the duration of a component drag.
const String huiDragHint = 'Drag to move - one undo step per gesture';

const String huiHitboxDragHint =
    'Drag to move detached hitbox - one undo step per gesture';

/// Shown while the rubber band is live.
const String huiMarqueeHint = 'Marquee - Shift keeps the current selection';

class CanvasViewport extends StatefulWidget {
  const CanvasViewport({
    required this.store,
    required this.images,
    this.catalogs,
    this.status,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;

  /// Boot snapshot supplying item sprites; `store.catalogs` wins once it holds
  /// anything, so an imported custom item catalog reaches the canvas. The
  /// canvas works without either; items fall back to a labelled placeholder.
  final HuiCatalogs? catalogs;

  /// Pointer, zoom and hint readouts for the shell status bar. Pushed from the
  /// frame tick rather than from the pointer handler, so a 60 fps drag rebuilds
  /// the status strip at most once per painted frame.
  final ShellStatus? status;

  @override
  State<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends State<CanvasViewport> {
  static int _instances = 0;

  late final String _uid = 'hui-canvas-${_instances++}';
  String get _canvasId => '$_uid-surface';
  String get _stageId => '$_uid-stage';
  String get _readoutId => '$_uid-readout';
  String get _zoomLabelId => '$_uid-zoom';

  late final CanvasAssets _assets = CanvasAssets(onReady: _markDirty);
  final McFontMetrics _metrics = McFontMetrics();
  final McTextCache _textCache = McTextCache();
  final ImageCharCache _charCache = ImageCharCache();
  late final CanvasPainter _painter =
      CanvasPainter(assets: _assets, metrics: _metrics);

  HuiViewport _viewport = const HuiViewport(widthPx: 0, heightPx: 0);
  CanvasScene? _scene;

  web.HTMLCanvasElement? _canvas;
  web.HTMLElement? _stage;
  web.ResizeObserver? _resizeObserver;
  final Map<String, JSFunction> _stageListeners = <String, JSFunction>{};
  JSFunction? _windowResizeListener;

  /// Queried live rather than read once at boot: the OS switch can flip while
  /// the editor is open, and the marching ring has to stop when it does.
  web.MediaQueryList? _reducedMotionQuery;
  JSFunction? _reducedMotionListener;

  /// False while the canvas cell has no box to draw into.
  ///
  /// The Preview and Code views `display: none` the canvas cell rather than
  /// unmounting it (`07-preview.css:28`, `02-shell.css:154`), so this widget
  /// stays alive with its clocks running. Measured: switching Visual to
  /// Preview and then pausing the preview still left 40 `requestAnimationFrame`
  /// calls over 4 s, all of them the hidden canvas re-scrambling an `<obf>`
  /// span nobody could see. A hidden canvas needs no clock, so every timer is
  /// gated on this.
  bool _hasArea = false;

  bool _dirty = true;
  bool _framePending = false;
  bool _postFramePending = false;
  bool _disposed = false;
  bool _needsInitialFit = true;
  bool _fontRequested = false;

  Timer? _obfuscationTimer;
  Timer? _animationTimer;
  Timer? _selectionTimer;
  Duration _animationPeriod = Duration.zero;
  int _obfuscationTick = 0;
  int _selectionTick = 0;
  int _animationElapsedMs = 0;
  bool _sceneHasObfuscation = false;
  bool _sceneHasAnimation = false;
  int _sceneMinAnimationSpeed = 1;

  // Interaction state; the extension in canvas_interactions.dart drives it.
  int? _activePointerId;
  _DragMode _dragMode = _DragMode.none;
  String? _dragComponentId;
  double _grabOffsetX = 0;
  double _grabOffsetY = 0;
  double _lastClientX = 0;
  double _lastClientY = 0;
  bool _spaceHeld = false;
  String? _hoveredId;

  // Multi-select gesture state.
  //
  // The offsets and bounds are captured once at pointer-down and every frame of
  // the drag is resolved against them, so a group can never drift apart across
  // frames the way an incremental delta would let it.
  Map<String, Vec3> _dragStartOffsets = const <String, Vec3>{};
  Vec3? _hitboxDragStart;
  WorldBounds? _dragStartBounds;
  bool _altDuplicatePending = false;
  List<AlignmentGuide> _guides = const <AlignmentGuide>[];
  double _marqueeStartX = 0;
  double _marqueeStartY = 0;
  HuiRect? _marquee;
  Set<String> _marqueeBase = const <String>{};

  // Status-bar readouts, flushed on the frame tick.
  double? _pendingPointerX;
  double? _pendingPointerY;
  bool _statusDirty = true;

  /// The eased camera move in flight, or null when the viewport is at rest.
  _ViewportEase? _ease;

  @override
  void initState() {
    super.initState();
    component.store.addListener(_onStoreChanged);
    component.images.addListener(_onImagesChanged);
    _schedulePostFrame();
  }

  @override
  void didUpdateComponent(CanvasViewport oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
    if (!identical(oldComponent.images, component.images)) {
      oldComponent.images.removeListener(_onImagesChanged);
      component.images.addListener(_onImagesChanged);
    }
    _markDirty();
  }

  @override
  void dispose() {
    _disposed = true;
    component.store.removeListener(_onStoreChanged);
    component.images.removeListener(_onImagesChanged);
    _obfuscationTimer?.cancel();
    _animationTimer?.cancel();
    _selectionTimer?.cancel();
    _detachListeners();
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    _assets.dispose();
    super.dispose();
  }

  /// Built once and returned by reference on every rebuild.
  ///
  /// Jaspr short-circuits `updateChild` when the child component is the same
  /// instance, so a parent rebuild never re-patches the stage. That matters:
  /// `DomRenderObject.updateElement` rewrites `class` and REMOVES any attribute
  /// it did not declare, which would wipe the canvas backing-store size and
  /// every interaction state class set from Dart.
  late final Widget _stageTree = dom.div(
    id: _stageId,
    classes: 'hui-canvas-stage',
    attributes: const <String, String>{
      'tabindex': '0',
      'role': 'application',
      'aria-label': 'HoloUI menu layout canvas. Scroll to zoom, drag to pan, '
          'drag a component to move it.',
    },
    <Widget>[
      Component.element(
        tag: 'canvas',
        id: _canvasId,
        classes: 'hui-canvas-surface',
      ),
      dom.div(
        id: _readoutId,
        classes: 'hui-canvas-readout',
        const <Widget>[],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    _schedulePostFrame();
    final EditorStore store = component.store;
    return dom.div(classes: 'hui-canvas', <Widget>[
      ListenableBuilder(
        listenable: store,
        builder: (BuildContext inner) => CanvasToolbar(
          store: store,
          zoomLabelId: _zoomLabelId,
          zoomPercent: _zoomPercentText,
          // Eased: a button press has no inertia of its own to respect, so the
          // travel is what tells the user the artboard moved rather than
          // changed. The wheel and the keyboard keep their immediate paths.
          onZoomIn: () => _easeThrough(() => _zoomFromCenter(huiZoomStep)),
          onZoomOut: () => _easeThrough(() => _zoomFromCenter(1 / huiZoomStep)),
          onZoomReset: () => _easeThrough(_resetView),
          onFit: () => _easeThrough(_fitToContent),
          hasAnimatedIcons: _sceneHasAnimation,
          onZOrder: _applyZOrder,
        ),
      ),
      _stageTree,
      // One line, never two: the separators are drawn by CSS between the
      // items, and the trailing note is dropped by CSS before anything is
      // allowed to wrap. See `.hui-canvas-hint` in web/styles/03-canvas.css.
      const dom.div(classes: 'hui-canvas-hint', <Widget>[
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          // Left-drag on empty space is the marquee now; panning is Space-drag
          // or the middle button, which is why the pan verb moved up front.
          Component.text('Space or middle-drag pans - scroll zooms - 0 resets '
              '- F fits'),
        ]),
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text('Drag empty space to marquee - Shift-click adds - '
              'Alt-drag copies - arrows nudge'),
        ]),
        dom.span(classes: 'hui-canvas-hint-item hui-canvas-hint-note', <Widget>[
          Component.text('Icons never turn to face the player (billboard '
              'FIXED); only the click plane re-aims.'),
        ]),
      ]),
    ]);
  }

  // --- frame loop -----------------------------------------------------------

  void _onStoreChanged() => _markDirty();

  void _onImagesChanged() {
    _assets.prunePixelCanvases(component.images.paths);
    // A re-uploaded path keeps its name but changes its pixels, and the
    // character count is keyed by path, so the memo has to go.
    _charCache.clear();
    _markDirty();
  }

  void _markDirty() {
    if (_disposed) return;
    _dirty = true;
    _scheduleFrame();
  }

  /// Asks for a frame without forcing a repaint: a pointer readout that lands
  /// on the same component does not change a single pixel of the canvas.
  void _scheduleFrame() {
    if (_disposed || _framePending) return;
    _framePending = true;
    web.window.requestAnimationFrame(_onAnimationFrame.toJS);
  }

  void _onAnimationFrame(double timestampMs) {
    _framePending = false;
    if (_disposed) return;
    // Before the dirty check: the step commits a viewport, which is what marks
    // the frame dirty and schedules the next one.
    _stepViewportEase(timestampMs);
    _flushStatus();
    if (!_dirty) return;
    _dirty = false;
    _paint();
  }

  // --- eased camera moves ---------------------------------------------------

  bool get _prefersReducedMotion => _reducedMotionQuery?.matches ?? false;

  /// World point under the canvas centre. `originX = width / 2 + panX`, so the
  /// centre pixel maps to `-panX / pixelsPerBlock`.
  static double _centerWorldX(HuiViewport view) =>
      -view.transform.panX / view.pixelsPerBlock;

  static double _centerWorldY(HuiViewport view) =>
      view.transform.panY / view.pixelsPerBlock;

  /// Turns a commit-immediately viewport move into an eased travel.
  ///
  /// [move] is one of the existing commit paths, so the framing maths behind a
  /// fit or a reset stays in exactly one place and the eased and immediate
  /// routes can never disagree about where the camera lands. The jump [move]
  /// commits is never painted: nothing yields to the frame loop between the
  /// call and the rewind at the end.
  void _easeThrough(void Function() move) {
    final HuiViewport shown = _viewport;
    final _ViewportEase? running = _ease;
    // A second click composes on the DESTINATION of the move already in
    // flight, not on the frame it happens to be showing, so two zoom-ins are
    // always exactly one squared step however fast they arrive.
    if (running != null) _viewport = running.target;
    move();
    final HuiViewport target = _viewport;
    if (_prefersReducedMotion || target.transform == shown.transform) {
      _ease = null;
      _commitViewport(target);
      return;
    }
    _ease = _ViewportEase(
      fromZoom: shown.zoom,
      fromX: _centerWorldX(shown),
      fromY: _centerWorldY(shown),
      toZoom: target.zoom,
      toX: _centerWorldX(target),
      toY: _centerWorldY(target),
      target: target,
    );
    _commitViewport(shown);
  }

  void _stepViewportEase(double timestampMs) {
    final _ViewportEase? ease = _ease;
    if (ease == null) return;
    if (ease.startMs < 0) ease.startMs = timestampMs;
    final double span = huiViewportEase.inMilliseconds.toDouble();
    final double t = ((timestampMs - ease.startMs) / span).clamp(0.0, 1.0);
    if (t >= 1) {
      _ease = null;
      _commitViewport(ease.target);
      return;
    }
    final double eased = _easeOut(t);
    final double zoom = clampZoom(
      math.exp(_lerp(math.log(ease.fromZoom), math.log(ease.toZoom), eased)),
    );
    // Zoom first, then centre: `centerOn` reads `pixelsPerBlock` off its own
    // receiver, so it has to see the zoom this frame arrives at.
    _commitViewport(
      _viewport.withTransform(CanvasTransform(zoom: zoom)).centerOn(
            _lerp(ease.fromX, ease.toX, eased),
            _lerp(ease.fromY, ease.toY, eased),
          ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Tracks --hui-ease-out (cubic-bezier(.16, 1, .3, 1)) closely enough over
  /// 180 ms that a real bezier solver would buy three Newton iterations a frame
  /// and no visible difference.
  static double _easeOut(double t) => 1 - math.pow(1 - t, 4).toDouble();

  /// One status-bar notification per frame at most. [ShellStatus] drops
  /// no-op writes itself, so an idle canvas never rebuilds the strip.
  void _flushStatus() {
    final ShellStatus? status = component.status;
    if (status == null || !_statusDirty) return;
    _statusDirty = false;
    status.setZoom(_viewport.zoom);
    status.setPointer(_pendingPointerX, _pendingPointerY);
    status.setHint(switch (_dragMode) {
      _DragMode.component => huiDragHint,
      _DragMode.hitbox => huiHitboxDragHint,
      _DragMode.marquee => huiMarqueeHint,
      _DragMode.pan || _DragMode.none => null,
    });
  }

  void _schedulePostFrame() {
    if (_postFramePending || _disposed) return;
    _postFramePending = true;
    context.binding.addPostFrameCallback(() {
      _postFramePending = false;
      if (_disposed) return;
      _attachToDom();
      _restoreDomState();
      _syncCanvasSize();
      _markDirty();
    });
  }

  // --- DOM wiring -----------------------------------------------------------

  void _attachToDom() {
    final web.Element? canvasElement = web.document.getElementById(_canvasId);
    final web.Element? stageElement = web.document.getElementById(_stageId);
    if (canvasElement == null || stageElement == null) return;
    final web.HTMLCanvasElement canvas =
        canvasElement as web.HTMLCanvasElement;
    final web.HTMLElement stage = stageElement as web.HTMLElement;
    if (identical(_canvas, canvas) && identical(_stage, stage)) {
      return;
    }
    _detachListeners();
    _canvas = canvas;
    _stage = stage;
    _attachListeners(stage);
    _observeResize(stage);
    _ensureMinecraftFont();
  }

  void _attachListeners(web.HTMLElement stage) {
    void bind(String type, void Function(web.Event event) handler,
        {bool passive = true}) {
      final JSFunction listener = handler.toJS;
      _stageListeners[type] = listener;
      stage.addEventListener(
        type,
        listener,
        web.AddEventListenerOptions(passive: passive),
      );
    }

    bind('pointerdown', _handlePointerDown, passive: false);
    bind('pointermove', _handlePointerMove, passive: false);
    bind('pointerup', _handlePointerUp);
    bind('pointercancel', _handlePointerUp);
    bind('pointerleave', _handlePointerLeave);
    bind('wheel', _handleWheel, passive: false);
    bind('contextmenu', _handleContextMenu, passive: false);
    bind('dblclick', _handleDoubleClick, passive: false);
    bind('keydown', _handleKeyDown, passive: false);
    bind('keyup', _handleKeyUp);
    bind('blur', _handleBlur);

    final JSFunction resize = ((web.Event _) => _syncCanvasSize()).toJS;
    _windowResizeListener = resize;
    web.window.addEventListener('resize', resize);

    // A repaint is all the flip needs: `_reconcileTimers` runs off the paint
    // and is what starts or stops the marching ring.
    final web.MediaQueryList motion =
        web.window.matchMedia('(prefers-reduced-motion: reduce)');
    final JSFunction onMotionChange = ((web.Event _) => _markDirty()).toJS;
    motion.addEventListener('change', onMotionChange);
    _reducedMotionQuery = motion;
    _reducedMotionListener = onMotionChange;
  }

  void _detachListeners() {
    final web.HTMLElement? stage = _stage;
    if (stage != null) {
      for (final MapEntry<String, JSFunction> entry
          in _stageListeners.entries) {
        stage.removeEventListener(entry.key, entry.value);
      }
    }
    _stageListeners.clear();
    final JSFunction? resize = _windowResizeListener;
    if (resize != null) {
      web.window.removeEventListener('resize', resize);
      _windowResizeListener = null;
    }
    final web.MediaQueryList? motion = _reducedMotionQuery;
    final JSFunction? onMotionChange = _reducedMotionListener;
    if (motion != null && onMotionChange != null) {
      motion.removeEventListener('change', onMotionChange);
    }
    _reducedMotionQuery = null;
    _reducedMotionListener = null;
  }

  void _observeResize(web.HTMLElement stage) {
    _resizeObserver?.disconnect();
    try {
      final web.ResizeObserver observer = web.ResizeObserver(
        ((JSAny _, JSAny _) => _syncCanvasSize()).toJS,
      );
      observer.observe(stage);
      _resizeObserver = observer;
    } catch (_) {
      // ResizeObserver is an enhancement; the window listener covers the rest.
      _resizeObserver = null;
    }
  }

  /// The stylesheet declares Minecraftia, but the first canvas paint can beat
  /// the font load. Force it, then recalibrate the glyph metric and repaint.
  void _ensureMinecraftFont() {
    if (_fontRequested) return;
    _fontRequested = true;
    try {
      web.document.fonts.load('16px "Minecraftia"').toDart.then<void>(
        (JSArray<web.FontFace> _) {
          if (_disposed) return;
          _metrics.invalidate();
          _markDirty();
        },
        onError: (Object _) {},
      );
    } catch (_) {
      // Font Loading API unavailable: the fallback metric still renders.
    }
  }

  void _syncCanvasSize() {
    final web.HTMLCanvasElement? canvas = _canvas;
    if (canvas == null || _disposed) return;
    final web.DOMRect rect = canvas.getBoundingClientRect();
    final double width = rect.width;
    final double height = rect.height;

    // A hide reports 0x0 through the same ResizeObserver, which makes this the
    // one place that learns about it. The stored size is deliberately NOT
    // zeroed: it is the framing to restore when the cell comes back, and
    // clearing it would reset the camera on every trip through Preview.
    final bool hadArea = _hasArea;
    _hasArea = width > 0 && height > 0;
    if (hadArea != _hasArea) _reconcileTimers();
    if (!_hasArea) return;
    final double ratio = math.max(1, web.window.devicePixelRatio);
    final int backingWidth = (width * ratio).round();
    final int backingHeight = (height * ratio).round();
    if (canvas.width != backingWidth) canvas.width = backingWidth;
    if (canvas.height != backingHeight) canvas.height = backingHeight;
    _viewport = _viewport.resized(
      widthPx: width,
      heightPx: height,
      devicePixelRatio: ratio,
    );
    if (_needsInitialFit) {
      _needsInitialFit = false;
      _fitToContent();
      return;
    }
    _markDirty();
  }

  // --- painting -------------------------------------------------------------

  void _paint() {
    final web.HTMLCanvasElement? canvas = _canvas;
    // Gated on [_hasArea], not on the viewport size. The stored size is
    // deliberately NOT zeroed when the cell hides (it is the framing to restore
    // when it comes back), so `widthPx` reads stale-positive the whole time the
    // canvas is invisible. Without this guard every store notification from
    // whichever surface IS visible — a preview-card drag fires one per pointer
    // move — rebuilt a whole `CanvasScene` off the menu and painted it into a
    // canvas with no box at all.
    if (canvas == null || !_hasArea || _viewport.widthPx <= 0) return;
    final web.RenderingContext? raw = canvas.getContext('2d');
    if (raw == null) return;
    final web.CanvasRenderingContext2D ctx =
        raw as web.CanvasRenderingContext2D;
    final EditorStore store = component.store;
    final CanvasScene scene = _buildScene();
    _painter.paint(
      ctx: ctx,
      viewport: _viewport,
      palette: CanvasPalette.resolve(store.backdrop, _pageIsLight()),
      scene: scene,
      options: CanvasFrameOptions(
        backdrop: store.backdrop,
        showGrid: store.showGrid,
        showHitboxes: store.showHitboxes,
        showAnchors: store.showAnchors,
        trueRender: store.trueRender,
        uiScale: store.previewUiScale,
        selectedId: store.selectedId,
        selectedIds: store.selectionIds,
        hoveredId: _hoveredId,
        draggingId: _dragComponentId,
        marquee: _marquee,
        guides: _guides,
        obfuscationTick: _obfuscationTick,
        selectionDashOffset: _selectionTick * huiSelectionDashStep,
      ),
    );
    _reconcileTimers();
  }

  /// Belt-and-braces re-assert of the DOM state the canvas owns imperatively,
  /// in case something else in the tree ever re-patches these nodes.
  void _restoreDomState() {
    _syncZoomReadout();
    _setStageState(
      dragging: _activePointerId != null,
      overComponent: _hoveredId != null,
      panReady: _spaceHeld,
    );
  }

  CanvasScene _buildScene() {
    final EditorStore store = component.store;
    final CanvasScene scene = buildCanvasScene(
      menu: store.menu,
      uiScale: store.previewUiScale,
      trueRender: store.trueRender,
      togglePreview: store.togglePreviewFor,
      textCache: _textCache,
      images: component.images,
      catalogs: huiFreshestCatalogs(store.catalogs, component.catalogs),
      charCache: _charCache,
      animationTicks: _animationElapsedMs ~/ 50,
    );
    _scene = scene;
    _measureSceneTimers(scene);
    return scene;
  }

  /// Scene for hit testing. Rebuilt when the document changed since the last
  /// paint so a click can never resolve against a stale layout.
  CanvasScene get _currentScene {
    final CanvasScene? cached = _scene;
    if (cached != null && !_dirty) return cached;
    return _buildScene();
  }

  /// Timers only run when the frame actually needs them: no animated icon means
  /// no 50 ms wake-up, no obfuscated span means no 100 ms wake-up.
  void _measureSceneTimers(CanvasScene scene) {
    bool obfuscated = false;
    bool animated = false;
    int minSpeed = 1 << 30;
    for (final CanvasItem item in scene.items) {
      final McTextResult? parsed = item.text;
      if (!obfuscated && parsed != null) {
        for (final List<McSpan> line in parsed.lines) {
          for (final McSpan span in line) {
            if (span.obfuscated) {
              obfuscated = true;
              break;
            }
          }
          if (obfuscated) break;
        }
      }
      final HuiIcon? icon = item.icon;
      if (icon is HuiAnimatedImageIcon && icon.source.length > 1) {
        animated = true;
        minSpeed = math.min(minSpeed, math.max(1, icon.speed));
      }
    }
    _sceneHasObfuscation = obfuscated;
    _sceneMinAnimationSpeed = animated ? minSpeed : 1;
    if (animated == _sceneHasAnimation) return;
    _sceneHasAnimation = animated;
    // The play/pause control only exists while something animates, and that is
    // a document fact rather than a store flag, so the strip needs a rebuild.
    if (!_disposed) {
      setState(() {});
    }
  }

  /// The one clock in this widget that could otherwise run forever, so it is
  /// gated hardest: a march needs something to ring AND a motion budget to
  /// spend. No selection means no timer, which is what keeps an idle canvas at
  /// zero scheduled frames.
  void _reconcileSelectionMarch() {
    final bool wanted = _hasArea &&
        component.store.selectionIds.isNotEmpty &&
        !_prefersReducedMotion;
    if (!wanted) {
      _selectionTimer?.cancel();
      _selectionTimer = null;
      // Phase 0 on the next paint, so a fresh selection never starts mid-dash.
      _selectionTick = 0;
      return;
    }
    _selectionTimer ??= Timer.periodic(huiSelectionMarchInterval, (Timer _) {
      _selectionTick++;
      _markDirty();
    });
  }

  void _reconcileTimers() {
    _reconcileSelectionMarch();
    if (_hasArea && _sceneHasObfuscation) {
      _obfuscationTimer ??= Timer.periodic(huiObfuscationInterval, (Timer _) {
        _obfuscationTick++;
        _markDirty();
      });
    } else {
      _obfuscationTimer?.cancel();
      _obfuscationTimer = null;
    }

    final bool wantAnimation =
        _hasArea && _sceneHasAnimation && component.store.animationsPlaying;
    if (!wantAnimation) {
      _animationTimer?.cancel();
      _animationTimer = null;
      return;
    }
    final Duration period = Duration(
      milliseconds: huiAnimationTick.inMilliseconds * _sceneMinAnimationSpeed,
    );
    if (_animationTimer != null && _animationPeriod == period) return;
    _animationTimer?.cancel();
    _animationPeriod = period;
    _animationTimer = Timer.periodic(period, (Timer _) {
      _animationElapsedMs += period.inMilliseconds;
      _markDirty();
    });
  }

  bool _pageIsLight() {
    final web.Element? root = web.document.documentElement;
    return root != null && root.classList.contains('light');
  }

  String get _zoomPercentText =>
      '${(_viewport.zoom * 100).round().clamp(1, 999999)}%';
}
