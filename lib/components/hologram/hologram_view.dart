/// The hologram stage: the CSS preview treatment of what Gloss spawns.
///
/// One line stack at the anchor over a block-grid ground plane, posed by the
/// document's `billboard` mode: `CENTER` draws square to the camera exactly
/// as it always has, and the other three modes get a 2D matrix off
/// `hologramPlaneTransform` — so a `FIXED` hologram foreshortens as you orbit
/// past it and reads mirrored from behind, which is what the client draws.
/// All geometry comes from `logic/gloss_hologram_scene.dart`, which is
/// DOM-free and tested on the VM; this file only writes the numbers into
/// styles.
///
/// The readout names the mode and what one camera cannot show about it: the
/// three tracking modes are solved against this camera, while in game every
/// viewer gets their own solution.
///
/// With `gameContext` the whole stage mounts into the shared game-screen
/// frame, which puts the client's HUD around the in-world view; the orbit
/// camera and its controls keep working inside it.
///
/// The stage owns a playback clock while any line references an animation
/// document and the store's animations toggle is on. It is only mounted while
/// the hologram view is active (see `editor_shell.dart`), so a hidden stage
/// costs nothing.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;
import 'package:web/web.dart' as web;

import '../../logic/gloss_hologram_scene.dart';
import '../../logic/gloss_text.dart';
import '../../logic/gloss_particle_text.dart';
import '../../model/model.dart';
import '../../preview/preview_types.dart';
import '../../preview/projection.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../gloss/gloss_text_line.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

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
  static int _instances = 0;
  late final String _stageId = 'hui-hologram-stage-${_instances++}';

  OrbitCamera _camera = const OrbitCamera();
  String? _cameraDocId;
  PVec3? _cameraFocus;
  bool _dragging = false;
  double _lastX = 0;
  double _lastY = 0;
  double _viewportWidth = 960;
  double _viewportHeight = 600;
  Timer? _ticker;
  web.ResizeObserver? _resize;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _syncCameraToDocument();
    Timer.run(_observeSize);
  }

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
    _ticker?.cancel();
    _resize?.disconnect();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(_syncCameraToDocument);
  }

  /// A different document gets its default orbit. Edits to the open document
  /// preserve the author's orbit but carry its target with a moved anchor.
  void _syncCameraToDocument() {
    final String? activeId = _store.workspace.activeId;
    final GlossHologramDoc? doc = _store.hologramDoc;
    if (doc == null) {
      _cameraDocId = activeId;
      _cameraFocus = null;
      return;
    }
    final OrbitCamera defaultCamera = hologramDefaultCamera(doc);
    final PVec3? previousFocus = _cameraFocus;
    if (activeId != _cameraDocId || previousFocus == null) {
      _camera = defaultCamera;
    } else {
      _camera = reframeHologramCamera(_camera, previousFocus, doc);
    }
    _cameraDocId = activeId;
    _cameraFocus = defaultCamera.target;
  }

  void _observeSize() {
    if (!mounted) return;
    final web.Element? stage = web.document.getElementById(_stageId);
    if (stage == null) return;
    _measure(stage);
    final web.ResizeObserver observer = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver _) {
        if (mounted) setState(() => _measure(stage));
      }).toJS,
    );
    observer.observe(stage);
    _resize = observer;
  }

  void _measure(web.Element stage) {
    final web.DOMRect rect = stage.getBoundingClientRect();
    if (rect.width > 0) _viewportWidth = rect.width;
    if (rect.height > 0) _viewportHeight = rect.height;
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

  double _eventDouble(Object? event, String property) {
    final JSObject? object = event as JSObject?;
    final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
    return value.isA<JSNumber>() ? (value! as JSNumber).toDartDouble : 0;
  }

  void _onPointerDown(Object? event) {
    _dragging = true;
    _lastX = _eventDouble(event, 'clientX');
    _lastY = _eventDouble(event, 'clientY');
  }

  void _onPointerMove(Object? event) {
    if (!_dragging) return;
    final double x = _eventDouble(event, 'clientX');
    final double y = _eventDouble(event, 'clientY');
    final double dx = x - _lastX;
    final double dy = y - _lastY;
    _lastX = x;
    _lastY = y;
    setState(() {
      _camera = _camera
          .copyWith(
            yawDegrees: _camera.yawDegrees - dx * 0.4,
            pitchDegrees: _camera.pitchDegrees + dy * 0.4,
          )
          .clamped();
    });
  }

  void _onPointerUp(Object? event) {
    _dragging = false;
  }

  void _onWheel(Object? event) {
    (event as JSObject?)?.callMethod<JSAny?>('preventDefault'.toJS);
    final double delta = _eventDouble(event, 'deltaY');
    setState(() {
      _camera = _camera
          .copyWith(distance: _camera.distance * math.exp(delta * 0.0015))
          .clamped();
    });
  }

  void _stopPointer(Object? event) {
    (event as JSObject?)?.callMethod<JSAny?>('stopPropagation'.toJS);
  }

  void _zoomBy(double factor) {
    setState(() {
      _camera = _camera.copyWith(distance: _camera.distance * factor).clamped();
    });
  }

  void _resetCamera() {
    final GlossHologramDoc? doc = _store.hologramDoc;
    if (doc == null) return;
    setState(() {
      _camera = hologramDefaultCamera(doc);
      _cameraFocus = _camera.target;
    });
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
        hologramIsAnimated(doc, animations) || doc.particleLayers.isNotEmpty;
    _syncTicker(animated);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    final CameraBasis basis = CameraBasis.orbit(_camera);
    final HologramBillboardPlacement? placement = hologramBillboardPlacement(
      basis: basis,
      anchor: doc.anchor,
      viewportWidth: _viewportWidth,
      viewportHeight: _viewportHeight,
    );
    final List<HologramGridSegment> grid = hologramGroundSegments(
      basis: basis,
      anchor: doc.anchor,
      viewportWidth: _viewportWidth,
      viewportHeight: _viewportHeight,
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
            doc: doc,
            placement: placement,
            viewportWidth: _viewportWidth,
            viewportHeight: _viewportHeight,
          );
    final double defaultDistance = hologramDefaultCamera(doc).distance;
    final int zoomPercent = (defaultDistance / _camera.distance * 100).round();

    final List<double> position = doc.anchor.position;
    final Widget stage = dom.div(
      id: _stageId,
      classes: 'hui-hologram-stage',
      attributes: <String, String>{
        'role': 'img',
        'aria-label': huiText('Hologram stage preview'),
      },
      events: <String, EventCallback>{
        'pointerdown': _onPointerDown,
        'pointermove': _onPointerMove,
        'pointerup': _onPointerUp,
        'pointercancel': _onPointerUp,
        'pointerleave': _onPointerUp,
        'wheel': _onWheel,
      },
      <Widget>[
        for (final HologramGridSegment segment in grid) _gridLine(segment),
        if (placement != null)
          _billboard(placement, plane, lines, doc, nowMs ~/ 50),
        if (placement != null) _anchorMarker(placement),
        dom.div(
          classes: 'hui-hologram-controls',
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
              onPressed: _resetCamera,
            ),
          ],
        ),
        if (!component.gameContext)
          dom.div(classes: 'hui-hologram-readout', <Widget>[
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
                  'billboard': hologramBillboardNote(doc.billboard),
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
          ]),
      ],
    );

    if (!component.gameContext) return stage;
    return GlossGameScreen(
      anchor: GlossGameAnchor.world,
      label: huiText('Hologram in game'),
      child: stage,
    );
  }

  Widget _gridLine(HologramGridSegment segment) {
    final double dx = segment.x2 - segment.x1;
    final double dy = segment.y2 - segment.y1;
    final double length = math.sqrt(dx * dx + dy * dy);
    if (!length.isFinite || length < 1) {
      return const dom.span(classes: 'is-hidden', <Widget>[]);
    }
    final double angle = math.atan2(dy, dx) * 180 / math.pi;
    return dom.div(
      classes:
          'hui-hologram-grid-line${segment.throughAnchor ? ' is-axis' : ''}',
      styles: dom.Styles(
        raw: <String, String>{
          'left': '${segment.x1.toStringAsFixed(2)}px',
          'top': '${segment.y1.toStringAsFixed(2)}px',
          'width': '${length.toStringAsFixed(2)}px',
          'transform': 'rotate(${angle.toStringAsFixed(3)}deg)',
        },
      ),
      const <Widget>[],
    );
  }

  /// The line stack, bottom-centred on the projected anchor and growing
  /// upward, exactly like the joined `TextDisplay` string. Font metrics are
  /// the scene constants: a 0.25-block line advance with an 8-px glyph.
  ///
  /// [plane] rotates the stack about that bottom-centre point, which is why
  /// the transform origin moves there: the anchor is the pivot the entity
  /// turns around too. `CENTER` passes the identity and the box is laid out
  /// untouched.
  Widget _billboard(
    HologramBillboardPlacement placement,
    HologramPlaneTransform plane,
    List<GlossLineRender> lines,
    GlossHologramDoc doc,
    int tick,
  ) {
    final double linePx =
        glossHologramLineHeightBlocks * placement.pxPerBlock * doc.scale;
    final double fontPx = linePx * 0.8;
    final GlossParticleTextRendered rendered = _particleText(lines);
    return dom.div(
      classes: 'hui-hologram-billboard',
      styles: dom.Styles(
        raw: <String, String>{
          'left': '${placement.x.toStringAsFixed(2)}px',
          'top': '${placement.y.toStringAsFixed(2)}px',
          'font-size': '${fontPx.toStringAsFixed(2)}px',
          'line-height': '${linePx.toStringAsFixed(2)}px',
          'transform-origin': '50% 100%',
          'transform':
              'translate(-50%, -100%) matrix(${plane.a.toStringAsFixed(5)}, '
              '${plane.b.toStringAsFixed(5)}, ${plane.c.toStringAsFixed(5)}, '
              '${plane.d.toStringAsFixed(5)}, 0, 0)',
        },
      ),
      <Widget>[
        GlossParticleOverlay(
          layers: doc.particleLayers,
          pixelsPerBlock: placement.pxPerBlock,
          tick: tick,
          renderedText: rendered,
          textScale: doc.scale,
        ),
        for (final GlossLineRender line in lines)
          dom.div(classes: 'hui-hologram-line', <Widget>[
            GlossTextLine(render: line),
          ]),
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

  Widget _anchorMarker(HologramBillboardPlacement placement) => dom.div(
    classes: 'hui-hologram-anchor',
    styles: dom.Styles(
      raw: <String, String>{
        'left': '${placement.x.toStringAsFixed(2)}px',
        'top': '${placement.y.toStringAsFixed(2)}px',
      },
    ),
    const <Widget>[],
  );

  Widget _cameraAction({
    required String label,
    required ArcaneGlyph icon,
    required void Function() onPressed,
  }) => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: onPressed,
    attributes: <String, String>{'aria-label': label, 'title': label},
    icon: icon,
  );
}
