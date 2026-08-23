/// The container-preview card surface: a DPR-aware HTML5 canvas plus its
/// control strip.
///
/// Structurally the twin of [CanvasViewport](../canvas/canvas_viewport.dart),
/// and for the same reasons: rendering is driven by one dirty flag and an
/// on-demand `requestAnimationFrame`, the Jaspr tree is never rebuilt for a
/// pan, a zoom or a drag, and the `<canvas>` is built once and returned by
/// reference so nothing ever re-patches it.
///
/// What differs is the coordinate space and the clock. The card is authored in
/// whole pixels at an integer zoom, so the camera is [PreviewCardView] rather
/// than the block-space `HuiViewport`; and the frame is a function of a
/// [PreviewSim] that ticks forward, so a document with a live `cookTime` shows
/// the motion the plugin draws instead of one frozen instant.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, ListenableBuilder;
import 'package:web/web.dart' as web;

import '../../logic/preview_card_edit.dart';
import '../../logic/preview_card_scene.dart';
import '../../logic/preview_sim.dart';
import '../../logic/preview_sim_controls.dart';
import '../../logic/viewport_math.dart'
    show canBeginCanvasGesture, shouldPanCanvasGesture;
import '../../model/preview_doc.dart';
import '../../services/catalogs.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../render/canvas_assets.dart';
import '../render/canvas_brush.dart';
import '../render/icon_renderers.dart';
import '../shell/key_listener.dart' show huiMobilePaneOpen;
import '../shell/shell_status.dart';
import 'preview_card_painter.dart';
import 'preview_card_toolbar.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

part 'preview_card_interactions.dart';

/// Arrow-key steps, in card pixels. Shift jumps by a well.
const int huiPreviewNudgeStep = 1;
const int huiPreviewNudgeStepLarge = 8;

/// Shown in the status bar while an element is being dragged.
const String huiPreviewDragHint =
    'Drag to move - whole pixels - one undo step per gesture';

const String huiPreviewResizeHint =
    'Drag to resize - whole pixels - one undo step per gesture';

class PreviewCardViewport extends StatefulWidget {
  const PreviewCardViewport({
    required this.store,
    this.catalogs,
    this.status,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;

  /// Boot snapshot supplying the English message templates `lang()` renders
  /// against; `store.catalogs` wins once it holds anything. The surface works
  /// without either — an unknown message id renders as itself, which is also
  /// what the plugin does.
  final HuiCatalogs? catalogs;

  /// Zoom and hint readouts for the shell status bar, pushed from the frame
  /// tick rather than the pointer handler.
  final ShellStatus? status;

  /// Draw the card the way the player meets it — centred on the darkened GUI
  /// screen of [GlossGameScreen], with none of the editing chrome — instead of
  /// on the editor artboard. This is what the preview mode mounts, and it is
  /// the only thing that makes that mode more than a second copy of the visual
  /// one. The artboard itself is unchanged: same canvas, same camera, same
  /// simulation, so pan, zoom and drag keep working inside the frame and the
  /// inspector's simulation panel still drives it.
  final bool gameContext;

  @override
  State<PreviewCardViewport> createState() => _PreviewCardViewportState();
}

class _PreviewCardViewportState extends State<PreviewCardViewport> {
  static int _instances = 0;

  late final String _uid = 'hui-preview-card-${_instances++}';
  String get _canvasId => '$_uid-surface';
  String get _stageId => '$_uid-stage';
  String get _readoutId => '$_uid-readout';
  String get _issuesId => '$_uid-issues';
  String get _zoomLabelId => '$_uid-zoom';

  final McFontMetrics _metrics = McFontMetrics();
  late final CanvasAssets _assets;
  late final PreviewCardPainter _painter;

  PreviewCardView _view = const PreviewCardView();
  PreviewCardScene _scene = PreviewCardScene.empty;

  /// Label widths in card pixels, measured by the last paint. The format
  /// carries no label extent, so this is the only thing the hit model can
  /// measure a label with.
  List<double> _labelWidths = const <double>[];
  List<String> _buildErrors = const <String>[];

  /// The simulation itself lives on [EditorStore.previewSim] — shared with the
  /// E8 simulation panel, which is a sibling widget with no reference to this
  /// one. [_syncSim] re-derives its category/vars from the document on every
  /// frame (cheap: [PreviewSimController.sync] memoizes on revision), and
  /// [_reconcileTimers] reads its animation gate. See
  /// `lib/logic/preview_sim_controls.dart` for the ownership story.
  PreviewSim get _sim => component.store.previewSim.sim;

  web.HTMLCanvasElement? _canvas;
  web.HTMLElement? _stage;
  String _renderedAriaLocale = '';
  web.ResizeObserver? _resizeObserver;
  final Map<String, JSFunction> _stageListeners = <String, JSFunction>{};
  JSFunction? _windowResizeListener;

  /// False while the cell has no box to draw into.
  ///
  /// The card surface is mounted in every view and only hidden by CSS (see
  /// `_CenterArea`), so this widget stays alive with its clocks running. Every
  /// timer and every status write is gated on it: a hidden surface must cost
  /// nothing, and must not fight the component canvas over the status bar.
  bool _hasArea = false;

  bool _dirty = true;
  bool _framePending = false;
  bool _postFramePending = false;
  bool _disposed = false;
  bool _needsInitialFit = true;
  bool _fontRequested = false;
  bool _statusDirty = true;

  Timer? _simTimer;

  // Interaction state; the extension in preview_card_interactions.dart drives
  // it.
  int? _activePointerId;
  _PreviewDragMode _dragMode = _PreviewDragMode.none;
  int? _dragElement;
  PreviewHandle? _dragHandle;
  PreviewBox? _dragStartBox;
  PreviewPoint _dragStartPoint = const PreviewPoint(0, 0);
  double _grabCardX = 0;
  double _grabCardY = 0;
  double _lastClientX = 0;
  double _lastClientY = 0;
  bool _spaceHeld = false;
  int? _hoveredItem;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _assets = CanvasAssets(onReady: _markDirty);
    _painter = PreviewCardPainter(metrics: _metrics, assets: _assets);
    component.store.addListener(_onStoreChanged);
    _schedulePostFrame();
  }

  @override
  void didUpdateComponent(PreviewCardViewport oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
    _statusDirty = true;
    _markDirty();
  }

  @override
  void dispose() {
    _disposed = true;
    component.store.removeListener(_onStoreChanged);
    // If this surface unmounts mid-drag (a view switch, a document swap) the
    // pointerup/pointercancel that would normally call `endDrag` never fires,
    // and a stuck `_dragActive` would suppress every undo step pushed
    // anywhere in the app from then on, forever - not just on this surface.
    component.store.endDrag();
    _simTimer?.cancel();
    _simTimer = null;
    _detachListeners();
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    _assets.dispose();
    super.dispose();
  }

  /// Built once and returned by reference on every rebuild: Jaspr short-circuits
  /// `updateChild` for an identical component, so a parent rebuild never
  /// re-patches the stage — which would wipe the canvas backing-store size and
  /// every state class written from Dart.
  late final Widget _stageTree = dom.div(
    id: _stageId,
    classes: 'hui-canvas-stage hui-preview-card-stage',
    attributes: <String, String>{'tabindex': '0', 'role': 'application'},
    <Widget>[
      Component.element(
        tag: 'canvas',
        id: _canvasId,
        classes: 'hui-canvas-surface',
      ),
      dom.div(
        id: _issuesId,
        classes: 'hui-preview-card-issues',
        const <Widget>[],
      ),
      dom.div(id: _readoutId, classes: 'hui-canvas-readout', const <Widget>[]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    _schedulePostFrame();
    final EditorStore store = component.store;
    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.screen,
        label: huiText('Container preview in game'),
        child: dom.div(classes: 'hui-preview-card-game', <Widget>[_stageTree]),
      );
    }
    return dom.div(classes: 'hui-canvas hui-preview-card', <Widget>[
      ListenableBuilder(
        listenable: store,
        builder: (BuildContext inner) => PreviewCardToolbar(
          store: store,
          zoomLabelId: _zoomLabelId,
          zoomLabel: _zoomLabelText,
          simCategory: store.previewSim.category,
          onZoomIn: () =>
              _commitView(_view.zoomedAtCenter(previewZoomIn(_view.zoom))),
          onZoomOut: () =>
              _commitView(_view.zoomedAtCenter(previewZoomOut(_view.zoom))),
          onZoomReset: _resetView,
          onFit: _fitToContent,
          onStepSim: _stepSim,
          onResetSim: _resetSim,
        ),
      ),
      _stageTree,
      dom.div(classes: 'hui-canvas-hint hui-canvas-hint-desktop', <Widget>[
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text(
            huiText(
              'Space or middle-drag pans - scroll zooms - 0 resets '
              '- F fits',
            ),
          ),
        ]),
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text(
            huiText(
              'Click selects - drag moves - corner handles resize - '
              'arrows nudge',
            ),
          ),
        ]),
        dom.span(classes: 'hui-canvas-hint-item hui-canvas-hint-note', <Widget>[
          Component.text(
            huiText(
              'Positions are whole pixels from the card centre, y '
              'up. Expression-driven fields are edited in the inspector.',
            ),
          ),
        ]),
      ]),
      dom.div(classes: 'hui-canvas-hint hui-canvas-hint-touch', <Widget>[
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text(huiText('Drag empty canvas to pan')),
        ]),
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text(huiText('Use the zoom controls')),
        ]),
        dom.span(classes: 'hui-canvas-hint-item', <Widget>[
          Component.text(huiText('Drag elements to move')),
        ]),
      ]),
    ]);
  }

  // --- frame loop -----------------------------------------------------------

  void _onStoreChanged() {
    _statusDirty = true;
    _markDirty();
  }

  void _markDirty() {
    if (_disposed) return;
    _dirty = true;
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (_disposed || _framePending) return;
    _framePending = true;
    web.window.requestAnimationFrame(_onAnimationFrame.toJS);
  }

  void _onAnimationFrame(double timestampMs) {
    _framePending = false;
    if (_disposed) return;
    _flushStatus();
    if (!_dirty) return;
    _dirty = false;
    _paint();
  }

  /// One status write per painted frame at most, and none at all while the cell
  /// is hidden — the component canvas owns the same readouts and is the visible
  /// surface then.
  void _flushStatus() {
    final ShellStatus? status = component.status;
    if (status == null || !_statusDirty || !_hasArea) return;
    _statusDirty = false;
    status.setZoom(_view.zoom.toDouble());
    status.setHint(
      _hint == null
          ? switch (_dragMode) {
              _PreviewDragMode.element => huiText(
                'Drag to move - whole pixels - one undo step per gesture',
              ),
              _PreviewDragMode.resize => huiText(
                'Drag to resize - whole pixels - one undo step per gesture',
              ),
              _PreviewDragMode.pan || _PreviewDragMode.none => null,
            }
          : _localizedRefusalHint(_hint!),
    );
  }

  String _localizedRefusalHint(String hint) => switch (hint) {
    previewExpressionMoveHint => huiText(
      'This element is positioned by an expression - edit x/y in the inspector',
    ),
    previewExpressionResizeHint => huiText(
      'This element is sized by an expression - edit it in the inspector',
    ),
    previewNoResizeHint => huiText('A label has no size to drag'),
    _ => hint,
  };

  void _schedulePostFrame() {
    if (_postFramePending || _disposed) return;
    _postFramePending = true;
    context.binding.addPostFrameCallback(() {
      _postFramePending = false;
      if (_disposed) return;
      _attachToDom();
      _syncStageAriaLabel();
      _syncZoomReadout();
      _syncCanvasSize();
      _markDirty();
    });
  }

  // --- DOM wiring -----------------------------------------------------------

  void _attachToDom() {
    final web.Element? canvasElement = web.document.getElementById(_canvasId);
    final web.Element? stageElement = web.document.getElementById(_stageId);
    if (canvasElement == null || stageElement == null) return;
    final web.HTMLCanvasElement canvas = canvasElement as web.HTMLCanvasElement;
    final web.HTMLElement stage = stageElement as web.HTMLElement;
    if (identical(_canvas, canvas) && identical(_stage, stage)) return;
    _detachListeners();
    _canvas = canvas;
    _stage = stage;
    _attachListeners(stage);
    _observeResize(stage);
    _ensureMinecraftFont();
  }

  void _syncStageAriaLabel() {
    final web.HTMLElement? stage = _stage;
    final String locale = huiLocalizations.activeLocale;
    if (stage == null || _renderedAriaLocale == locale) return;
    _renderedAriaLocale = locale;
    stage.setAttribute(
      'aria-label',
      huiText(
        'Container preview card. Drag empty canvas to pan on touch, use the zoom controls or scroll to zoom, and drag an element to move it.',
      ),
    );
  }

  void _attachListeners(web.HTMLElement stage) {
    void bind(
      String type,
      void Function(web.Event event) handler, {
      bool passive = true,
    }) {
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

  /// The stylesheet declares Minecraftia, but the first paint can beat the font
  /// load. Force it, then recalibrate the glyph metric and repaint — labels are
  /// measured from that metric, so a stale one moves every selection ring.
  void _ensureMinecraftFont() {
    if (_fontRequested) return;
    _fontRequested = true;
    try {
      web.document.fonts.load('16px "Minecraftia"').toDart.then<void>((
        JSArray<web.FontFace> _,
      ) {
        if (_disposed) return;
        _metrics.invalidate();
        _markDirty();
      }, onError: (Object _) {});
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

    // A hidden cell reports 0x0 through the same observer, which makes this the
    // one place that learns about it. The stored view is deliberately NOT
    // zeroed: it is the framing to restore when the cell comes back.
    final bool hadArea = _hasArea;
    _hasArea = width > 0 && height > 0;
    if (hadArea != _hasArea) _reconcileTimers();
    if (!_hasArea) return;
    final double ratio = math.max(1, web.window.devicePixelRatio);
    final int backingWidth = (width * ratio).round();
    final int backingHeight = (height * ratio).round();
    if (canvas.width != backingWidth) canvas.width = backingWidth;
    if (canvas.height != backingHeight) canvas.height = backingHeight;
    _view = _view.resized(width, height);
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
    if (canvas == null || !_hasArea) return;
    final web.RenderingContext? raw = canvas.getContext('2d');
    if (raw == null) return;
    final web.CanvasRenderingContext2D ctx =
        raw as web.CanvasRenderingContext2D;
    final EditorStore store = component.store;
    final HuiCatalogs catalogs = huiFreshestCatalogs(
      store.catalogs,
      component.catalogs,
    );
    final PreviewCardScene scene = _buildScene();
    _labelWidths = _painter.paint(
      ctx: ctx,
      view: _view,
      scene: scene,
      palette: CanvasPalette.resolve(HuiBackdropMode.none, _pageIsLight()),
      devicePixelRatio: math.max(1, web.window.devicePixelRatio),
      textureFor: catalogs.textureFor,
      // In game context the frame is what the player sees: no artboard fill
      // behind it, no grid, and none of the selection chrome. The pointer
      // handling stays live — panning and zooming a preview is reasonable —
      // but nothing an author-only affordance would draw is painted.
      options: component.gameContext
          ? PreviewCardFrameOptions(
              showGrid: false,
              fillBackground: false,
              labelWidths: _labelWidths,
            )
          : PreviewCardFrameOptions(
              showGrid: store.showGrid,
              selectedElement: store.previewSelectedIndex,
              hoveredItem: _hoveredItem,
              handles: _handleSpots(scene),
              labelWidths: _labelWidths,
            ),
    );
    _syncIssues();
    _reconcileTimers();
  }

  /// Resolves the active document against the simulation. Never throws: every
  /// failure is collected and shown in the issues strip, which is the contract
  /// [buildCardScene] holds.
  PreviewCardScene _buildScene() {
    final HuiPreviewDoc? doc = component.store.previewDoc;
    if (doc == null) {
      _scene = PreviewCardScene.empty;
      _buildErrors = const <String>[];
      return _scene;
    }
    _syncSim(doc, component.store.previewRevision);
    final List<String> errors = <String>[];
    _scene = buildCardScene(
      doc,
      _sim,
      onError: errors.add,
      emoji: component.store.workspaceEmoji,
    );
    _buildErrors = errors;
    return _scene;
  }

  /// Re-derives everything about the simulation that depends on the DOCUMENT.
  /// [PreviewSimController.sync] does the actual memoizing (on the revision
  /// and the resolved category), so a steady frame costs nothing here beyond
  /// that one cheap comparison; the strip's category chip and the animation
  /// gate both read the controller directly, so neither needs a mirrored
  /// field on this widget.
  void _syncSim(HuiPreviewDoc doc, int revision) {
    component.store.previewSim.sync(doc, revision, _lang());
    // Cheap even when nothing changed (a couple of field reads); the panel's
    // "force ticking" latch can flip with no document or category change at
    // all, so this cannot be gated on the same memo `sync` uses internally.
    _reconcileTimers();
  }

  PreviewLangCatalog _lang() => huiFreshestCatalogs(
    component.store.catalogs,
    component.catalogs,
  ).previewLang;

  /// Scene for hit testing. Rebuilt when the document changed since the last
  /// paint, so a click can never resolve against a stale layout.
  PreviewCardScene get _currentScene {
    if (!_dirty) return _scene;
    return _buildScene();
  }

  /// Grips for the selection, on the FIRST instance of the element only: a
  /// `repeat` writes one template, so four grips per instance would all do the
  /// same thing while claiming to be different.
  List<PreviewHandleSpot> _handleSpots(PreviewCardScene scene) {
    final EditorStore store = component.store;
    final int? selected = store.previewSelectedIndex;
    final HuiPreviewElement? element = store.previewSelectedElement;
    if (selected == null ||
        element == null ||
        previewResizeRefusal(element) != null) {
      return const <PreviewHandleSpot>[];
    }
    final List<int> items = previewItemsForElement(scene, selected);
    if (items.isEmpty) return const <PreviewHandleSpot>[];
    return previewHandleSpots(_itemBox(scene, items.first));
  }

  PreviewBox _itemBox(PreviewCardScene scene, int index) => previewItemBox(
    scene.items[index],
    labelWidth: index < _labelWidths.length && _labelWidths[index] > 0
        ? _labelWidths[index]
        : null,
  );

  // --- simulation clock -----------------------------------------------------

  /// The clock only runs when something can see it, the user has not paused
  /// it, AND (the document actually reads a value the tick moves OR the
  /// panel's "force ticking" latch is on). A card built from `inventory.size`
  /// alone is the same picture every frame, so ticking it is twenty repaints
  /// a second of identical pixels — the same reasoning `canvas_viewport`
  /// applies to its animated-icon clock; see [previewSimClockWanted] for why
  /// pressing play does not, on its own, override that.
  void _reconcileTimers() {
    final EditorStore store = component.store;
    final bool wanted = previewSimClockWanted(
      hasArea: _hasArea,
      isPreviewDoc: store.isPreviewDoc,
      playing: store.animationsPlaying,
      autoAnimated: store.previewSim.autoAnimated,
      forcePlay: store.previewSim.forcePlay,
    );
    if (!wanted) {
      _simTimer?.cancel();
      _simTimer = null;
      return;
    }
    // No explicit `_markDirty()`: `PreviewSimController.tick` notifies, which
    // `EditorStore` forwards, which is exactly the signal `_onStoreChanged`
    // already turns into a dirty frame.
    _simTimer ??= Timer.periodic(
      previewSimTickInterval,
      (Timer _) => component.store.previewSim.tick(1),
    );
  }

  void _stepSim() => component.store.previewSim.step();

  void _resetSim() => component.store.previewSim.reset();

  // --- readouts -------------------------------------------------------------

  void _syncIssues() {
    final web.Element? strip = web.document.getElementById(_issuesId);
    if (strip == null) return;
    if (_buildErrors.isEmpty) {
      strip.classList.remove('is-visible');
      strip.textContent = '';
      return;
    }
    final int extra = _buildErrors.length - 1;
    strip.textContent = extra > 0
        ? huiPlural(
            'preview.errors.additional',
            extra,
            oneEnglish: '{error}  (+{count} more)',
            otherEnglish: '{error}  (+{count} more)',
            arguments: <String, Object?>{'error': _buildErrors.first},
          )
        : _buildErrors.first;
    strip.classList.add('is-visible');
  }

  bool _pageIsLight() {
    final web.Element? root = web.document.documentElement;
    return root != null && root.classList.contains('light');
  }

  String get _zoomLabelText => '${_view.zoom * 100}%';
}
