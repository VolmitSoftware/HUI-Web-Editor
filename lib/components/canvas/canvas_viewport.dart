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

import '../../logic/mc_text.dart';
import '../../logic/viewport_math.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../shell/shell_status.dart';
import 'backdrop.dart';
import 'canvas_assets.dart';
import 'canvas_brush.dart';
import 'canvas_painter.dart';
import 'canvas_scene.dart';
import 'canvas_toolbar.dart';
import 'icon_renderers.dart';

part 'canvas_interactions.dart';

/// Nudge applied by the arrow keys, and the shift-modified nudge. Matches the
/// shell's global binding so the two never disagree.
const double huiNudgeStep = 0.05;
const double huiNudgeStepCoarse = 0.25;

/// Obfuscated text re-scrambles at this rate, like the vanilla client.
const Duration huiObfuscationInterval = Duration(milliseconds: 100);

/// Toolbar and keyboard zoom step.
const double huiZoomStep = 1.25;

/// Shown in the status bar for the duration of a component drag.
const String huiDragHint = 'Drag to move - one undo step per gesture';

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

  bool _dirty = true;
  bool _framePending = false;
  bool _postFramePending = false;
  bool _disposed = false;
  bool _needsInitialFit = true;
  bool _fontRequested = false;

  Timer? _obfuscationTimer;
  Timer? _animationTimer;
  Duration _animationPeriod = Duration.zero;
  int _obfuscationTick = 0;
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

  // Status-bar readouts, flushed on the frame tick.
  double? _pendingPointerX;
  double? _pendingPointerY;
  bool _statusDirty = true;

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
          onZoomIn: () => _zoomFromCenter(huiZoomStep),
          onZoomOut: () => _zoomFromCenter(1 / huiZoomStep),
          onZoomReset: _resetView,
          onFit: _fitToContent,
          hasAnimatedIcons: _sceneHasAnimation,
        ),
      ),
      _stageTree,
      // One line, never two: the separators are drawn by CSS between the
      // items, and the trailing note is dropped by CSS before anything is
      // allowed to wrap. See `.hui-canvas-hint` in web/styles/03-canvas.css.
      const dom.div(classes: 'hui-canvas-hint', <Widget>[
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text('Scroll to zoom - drag to pan - 0 resets - F fits'),
        ]),
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text('Drag to move - arrows nudge - Delete removes - '
              'Esc deselects'),
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

  void _onAnimationFrame(double _) {
    _framePending = false;
    if (_disposed) return;
    _flushStatus();
    if (!_dirty) return;
    _dirty = false;
    _paint();
  }

  /// One status-bar notification per frame at most. [ShellStatus] drops
  /// no-op writes itself, so an idle canvas never rebuilds the strip.
  void _flushStatus() {
    final ShellStatus? status = component.status;
    if (status == null || !_statusDirty) return;
    _statusDirty = false;
    status.setZoom(_viewport.zoom);
    status.setPointer(_pendingPointerX, _pendingPointerY);
    status.setHint(_dragMode == _DragMode.component ? huiDragHint : null);
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
    if (width <= 0 || height <= 0) return;
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
    if (canvas == null || _viewport.widthPx <= 0) return;
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
        hoveredId: _hoveredId,
        draggingId: _dragComponentId,
        obfuscationTick: _obfuscationTick,
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

  void _reconcileTimers() {
    if (_sceneHasObfuscation) {
      _obfuscationTimer ??= Timer.periodic(huiObfuscationInterval, (Timer _) {
        _obfuscationTick++;
        _markDirty();
      });
    } else {
      _obfuscationTimer?.cancel();
      _obfuscationTimer = null;
    }

    final bool wantAnimation =
        _sceneHasAnimation && component.store.animationsPlaying;
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
