/// The stage every 3D surface mounts: one canvas the renderer draws into, the
/// still behind it for browsers without WebGL2 (every model in the scene then
/// stands in the DOM layer as its catalog sprite, from the controller's
/// `spriteFor`), the CSS-3D layer the owning view places its text in, and the
/// pointer, wheel, key and touch input that drives the shared camera.
///
/// Jaspr renders the wrapper, the DOM layer and the controls; the canvas is
/// created and owned imperatively under an element Jaspr renders empty and
/// never rebuilds (the `preview_stage.dart` bargain). Frames are dirty-gated:
/// one is scheduled by a controller change, a resize, the pack arriving, a
/// restored context or `animating`; a parked stage schedules nothing.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:web/web.dart' as web;

import '../../l10n/hui_localizations.dart';
import '../../mc/rigs/mc_rig.dart';
import '../../mc/rigs/mc_rigs.dart';
import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_scene.dart';
import '../../preview/projection.dart' show huiPreviewPerspectivePx, huiPreviewPxPerBlock;
import 'mc_asset_loader.dart';
import 'mc_dom_layer.dart';
import 'mc_gl.dart';
import 'mc_gl_renderer.dart';
import 'mc_stage_controller.dart';

/// Where a no-WebGL sprite stands (its bottom-centre, world blocks) and how
/// big it is; a null width keeps the sprite's own aspect at that height.
final class _SpriteBox {
  const _SpriteBox(this.base, this.widthBlocks, this.heightBlocks);
  final McVec3 base;
  final double? widthBlocks;
  final double heightBlocks;
}

class McStage extends StatefulWidget {
  const McStage({
    required this.controller,
    this.overlay = const <Widget>[],
    this.controls = const <Widget>[],
    this.label,
    super.key,
  });

  final McStageController controller;

  /// Anchored text: each child is a `dom.div(classes: 'hui-mc-anchor',
  /// styles: transform: mcDomAnchorTransform(...))` the owning view builds.
  final List<Widget> overlay;
  final List<Widget> controls;
  final String? label;

  @override
  State<McStage> createState() => _McStageState();
}

class _McStageState extends State<McStage> {
  static int _instances = 0;
  late final String _id = 'hui-mc-stage-${_instances++}';
  late final String _canvasHostId = '$_id-gl';

  web.HTMLElement? _host;
  McGl? _gl;
  McGlRenderer? _renderer;
  web.ResizeObserver? _resize;
  double _widthPx = 0;
  double _heightPx = 0;
  bool _framePending = false;

  /// Set by every event that changes what a frame would show; the loop draws
  /// only dirty frames, so an animating stage whose scene ticks at 20 Hz
  /// renders 20 frames a second, not 60 identical ones.
  bool _dirty = true;
  McCamera? _lastCamera;
  bool? _lastWebGl;
  bool _postFramePending = false;
  bool _disposed = false;

  bool _dragging = false;
  bool _panning = false;

  /// The pointer that started the drag; every other pointer is ignored by
  /// the pointer handlers, so a second finger cannot yank the orbit.
  int? _pointerId;
  double _lastX = 0;
  double _lastY = 0;
  final Set<String> _held = <String>{};
  Timer? _flyTimer;
  int _flewAtMs = 0;

  /// Two fingers down: the touch handlers dolly by the separation and pan by
  /// the centroid, and the orbit is suspended until one lifts.
  bool _pinching = false;
  double _pinchDistance = 0;
  double _pinchX = 0;
  double _pinchY = 0;
  final Map<String, JSFunction> _listeners = <String, JSFunction>{};

  McStageController get _c => component.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
    McAssetLoader.addListener(_onPack);
    unawaited(McAssetLoader.load().then<void>((McAssetPackData _) {}, onError: (Object _) {}));
    _schedulePostFrame();
  }

  @override
  void didUpdateComponent(McStage oldComponent) {
    super.didUpdateComponent(oldComponent);
    // A parent rebuild changes only the DOM layer; the canvas follows the
    // controller, so a swapped controller is the one rebuild that draws.
    if (!identical(oldComponent.controller, component.controller)) {
      oldComponent.controller.removeListener(_onController);
      component.controller.addListener(_onController);
      _invalidate();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _c.removeListener(_onController);
    McAssetLoader.removeListener(_onPack);
    _flyTimer?.cancel();
    _resize?.disconnect();
    _detachInput();
    _gl?.dispose();
    super.dispose();
  }

  void _onController() {
    if (_disposed) return;
    _invalidate();
    // The DOM layer only depends on the camera and the WebGL flag; the scene
    // goes to the canvas, so a scene tick must not rebuild the overlay twice.
    if (_lastCamera == _c.camera && _lastWebGl == _c.webGlAvailable) return;
    _lastCamera = _c.camera;
    _lastWebGl = _c.webGlAvailable;
    setState(() {});
  }

  void _onPack() {
    if (_disposed) return;
    // The controller notifies on a real change, and [_onController] repaints
    // off that, so none of the three failure paths needs its own `setState`.
    if (McAssetLoader.failed) {
      _c.webGlAvailable = false;
      return;
    }
    _attachGl();
    _invalidate();
  }

  void _schedulePostFrame() {
    if (_postFramePending || _disposed) return;
    _postFramePending = true;
    context.binding.addPostFrameCallback(() {
      _postFramePending = false;
      if (_disposed) return;
      _attachToDom();
    });
  }

  void _attachToDom() {
    final web.Element? host = web.document.getElementById(_canvasHostId);
    if (host == null || identical(_host, host)) return;
    _host = host as web.HTMLElement;
    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()..className = 'hui-mc-gl';
    host.append(canvas);
    McGl? gl;
    try {
      gl = McGl.create(canvas);
    } catch (error) {
      web.console.error('mc stage: $error'.toJS);
      gl = null;
    }
    if (gl == null) {
      _c.webGlAvailable = false;
    } else {
      _gl = gl;
      // The renderer re-uploads the retained scene on restore but nothing
      // schedules the frame that draws it.
      gl.onRestored(_invalidate);
    }
    _attachGl();
    final web.HTMLElement stage = web.document.getElementById(_id) as web.HTMLElement;
    _observe(stage);
    if (_c.freeCamera) _attachInput(stage);
    _requestFrame();
  }

  void _attachGl() {
    final McGl? gl = _gl;
    final McAssetPackData? pack = McAssetLoader.loaded;
    if (gl == null || pack == null || _renderer != null) return;
    try {
      _renderer = McGlRenderer(gl, pack);
    } catch (error) {
      web.console.error('mc renderer: $error'.toJS);
      _c.webGlAvailable = false;
    }
  }

  void _observe(web.HTMLElement stage) {
    _resize?.disconnect();
    _resize = web.ResizeObserver(((JSAny _, JSAny _) => _measure(stage)).toJS)..observe(stage);
    _measure(stage);
  }

  void _measure(web.HTMLElement stage) {
    if (_disposed) return;
    final web.DOMRect rect = stage.getBoundingClientRect();
    if (rect.width == _widthPx && rect.height == _heightPx) return;
    _widthPx = rect.width;
    _heightPx = rect.height;
    _c.widthPx = rect.width;
    _c.heightPx = rect.height;
    _invalidate();
  }

  /// Something a frame would show changed: draw on the next animation frame.
  void _invalidate() {
    _dirty = true;
    _requestFrame();
  }

  void _requestFrame() {
    if (_framePending || _disposed) return;
    _framePending = true;
    web.window.requestAnimationFrame(
      ((JSNumber _) {
        _framePending = false;
        if (_disposed) return;
        if (_dirty) {
          _dirty = false;
          _render();
        }
        if (_c.animating) _requestFrame();
      }).toJS,
    );
  }

  void _render() {
    final McGlRenderer? renderer = _renderer;
    if (renderer == null || _widthPx <= 0 || _heightPx <= 0) return;
    final bool easing = renderer.render(
      _c.scene,
      _c.camera,
      widthPx: _widthPx,
      heightPx: _heightPx,
      dpr: web.window.devicePixelRatio,
      perspectivePx: huiPreviewPerspectivePx,
    );
    _c.frames++;
    // A pose ease is a frame-by-frame affair: keep drawing until it settles.
    if (easing) _invalidate();
    _host?.setAttribute('data-frames', '${_c.frames}');
  }

  // --- input ---------------------------------------------------------------

  void _attachInput(web.HTMLElement stage) {
    _detachInput();
    void on(String type, void Function(web.Event) handler) {
      final JSFunction fn = handler.toJS;
      _listeners[type] = fn;
      stage.addEventListener(type, fn);
    }

    on('pointerdown', (web.Event e) {
      final web.PointerEvent p = e as web.PointerEvent;
      stage.focus();
      if (_pointerId != null) return;
      _pointerId = p.pointerId;
      _lastX = _num(p, 'clientX');
      _lastY = _num(p, 'clientY');
      stage.setPointerCapture(p.pointerId);
      setState(() {
        _dragging = true;
        _panning = p.button == 1 || p.button == 2 || p.shiftKey;
      });
    });
    on('pointermove', (web.Event e) {
      final web.PointerEvent p = e as web.PointerEvent;
      if (!_dragging || p.pointerId != _pointerId) return;
      final double x = _num(p, 'clientX'), y = _num(p, 'clientY');
      final double dx = x - _lastX, dy = y - _lastY;
      _lastX = x;
      _lastY = y;
      if (_pinching) return;
      _c.camera = _panning ? _c.camera.panBy(dx, dy, _heightPx) : _c.camera.orbitBy(dx, dy);
    });
    void release(web.Event e) {
      if (!_dragging || (e as web.PointerEvent).pointerId != _pointerId) return;
      _pointerId = null;
      setState(() {
        _dragging = false;
        _panning = false;
      });
    }

    on('pointerup', release);
    on('pointercancel', release);
    on('contextmenu', (web.Event e) => e.preventDefault());
    on('wheel', (web.Event e) {
      e.preventDefault();
      final web.WheelEvent w = e as web.WheelEvent;
      _c.camera = _c.camera.dollyBy(mcWheelPixels(_num(w, 'deltaY'), w.deltaMode));
    });
    on('keydown', (web.Event e) {
      final String key = _keyName((e as web.KeyboardEvent).key);
      if (key.isEmpty) return;
      e.preventDefault();
      _held.add(key);
      _syncFly();
    });
    on('keyup', (web.Event e) {
      _held.remove(_keyName((e as web.KeyboardEvent).key));
      _syncFly();
    });
    on('blur', (web.Event e) {
      _held.clear();
      _syncFly();
    });
    on('touchstart', (web.Event e) {
      final web.TouchEvent t = e as web.TouchEvent;
      if (t.touches.length != 2) return;
      e.preventDefault();
      _pinching = true;
      _pinchDistance = _touchDistance(t);
      final (double x, double y) = _touchCentroid(t);
      _pinchX = x;
      _pinchY = y;
    });
    on('touchmove', (web.Event e) {
      final web.TouchEvent t = e as web.TouchEvent;
      if (t.touches.length != 2) return;
      e.preventDefault();
      final double d = _touchDistance(t);
      final (double x, double y) = _touchCentroid(t);
      McCamera camera = _c.camera;
      if (_pinchDistance > 0) camera = camera.dollyBy((_pinchDistance - d) * 2);
      camera = camera.panBy(x - _pinchX, y - _pinchY, _heightPx);
      _pinchDistance = d;
      _pinchX = x;
      _pinchY = y;
      _c.camera = camera;
    });
    void endPinch(web.Event e) {
      if ((e as web.TouchEvent).touches.length >= 2) return;
      _pinching = false;
      _pinchDistance = 0;
    }

    on('touchend', endPinch);
    on('touchcancel', endPinch);
  }

  void _detachInput() {
    final web.Element? stage = web.document.getElementById(_id);
    if (stage != null) {
      for (final MapEntry<String, JSFunction> entry in _listeners.entries) {
        stage.removeEventListener(entry.key, entry.value);
      }
    }
    _listeners.clear();
  }

  void _syncFly() {
    if (_held.isEmpty) {
      _flyTimer?.cancel();
      _flyTimer = null;
      return;
    }
    if (_flyTimer != null) return;
    _flewAtMs = DateTime.now().millisecondsSinceEpoch;
    _flyTimer = Timer.periodic(const Duration(milliseconds: 16), (Timer _) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final double seconds = (now - _flewAtMs).clamp(0, 100) / 1000;
      _flewAtMs = now;
      // Shift is the pan modifier while a drag is live (`pointerdown` reads
      // `shiftKey`), so it lowers the camera only between drags; a shift-pan
      // must not sink the pivot it is dragging.
      final double lift = (_held.contains('space') ? 1 : 0) - (!_dragging && _held.contains('shift') ? 1 : 0);
      _c.camera = _c.camera.flyBy(
        seconds: seconds,
        forward: _axis('w', 's'),
        strafe: _axis('d', 'a'),
        lift: lift,
      );
    });
  }

  double _axis(String positive, String negative) =>
      (_held.contains(positive) ? 1 : 0) - (_held.contains(negative) ? 1 : 0);

  static String _keyName(String key) => switch (key.toLowerCase()) {
    'w' || 'arrowup' => 'w',
    's' || 'arrowdown' => 's',
    'a' || 'arrowleft' => 'a',
    'd' || 'arrowright' => 'd',
    ' ' => 'space',
    'shift' => 'shift',
    _ => '',
  };

  /// Numeric event properties are read untyped: `package:web` declares
  /// `clientX` as `int` and browsers hand back fractions.
  static double _num(web.Event event, String property) => _numOf(event as JSObject, property);

  static double _numOf(JSObject object, String property) {
    final JSAny? value = object.getProperty<JSAny?>(property.toJS);
    return value != null && value.isA<JSNumber>() ? (value as JSNumber).toDartDouble : 0;
  }

  static double _touchDistance(web.TouchEvent t) {
    final web.Touch a = t.touches.item(0)!, b = t.touches.item(1)!;
    final double dx = _numOf(a, 'clientX') - _numOf(b, 'clientX');
    final double dy = _numOf(a, 'clientY') - _numOf(b, 'clientY');
    return math.sqrt(dx * dx + dy * dy);
  }

  static (double, double) _touchCentroid(web.TouchEvent t) {
    final web.Touch a = t.touches.item(0)!, b = t.touches.item(1)!;
    return (
      (_numOf(a, 'clientX') + _numOf(b, 'clientX')) / 2,
      (_numOf(a, 'clientY') + _numOf(b, 'clientY')) / 2,
    );
  }

  // --- no-WebGL sprites ----------------------------------------------------

  /// Every model in the scene as its catalog sprite, anchored in the DOM
  /// layer where the model would stand: the camera that places the still's
  /// text places these, so the readout's "models are sprites" holds.
  List<Widget> _sprites() {
    final String? Function(McSceneNode node)? resolve = _c.spriteFor;
    if (resolve == null) return const <Widget>[];
    final List<Widget> sprites = <Widget>[];
    for (final McSceneNode node in _c.scene.nodes) {
      final _SpriteBox? box = _spriteBox(node);
      if (box == null) continue;
      final String? url = resolve(node);
      if (url == null) continue;
      final double? width = box.widthBlocks;
      sprites.add(
        dom.div(
          classes: 'hui-mc-anchor hui-mc-sprite',
          styles: dom.Styles(
            raw: <String, String>{
              'transform': mcDomAnchorTransform(
                camera: _c.camera,
                position: box.base,
                billboard: McBillboardMode.center,
              ),
            },
          ),
          <Widget>[
            dom.img(
              src: url,
              alt: '',
              styles: dom.Styles(
                raw: <String, String>{
                  'height': '${(box.heightBlocks * huiPreviewPxPerBlock).toStringAsFixed(2)}px',
                  if (width != null) 'width': '${(width * huiPreviewPxPerBlock).toStringAsFixed(2)}px',
                },
              ),
            ),
          ],
        ),
      );
    }
    return sprites;
  }

  /// A block or item takes its box from its transform's scale, centred where
  /// the model's unit cube lands; a rig stands at its transform's origin at
  /// its hitbox height; a billboard is placed as declared.
  static _SpriteBox? _spriteBox(McSceneNode node) {
    switch (node) {
      case McBlockModelNode(:final McMat4 transform) || McItemModelNode(:final McMat4 transform):
        final McVec3 centre = transform.transformPoint(const McVec3(0.5, 0.5, 0.5));
        final double width = _columnLength(transform, 0), height = _columnLength(transform, 1);
        return _SpriteBox(McVec3(centre.x, centre.y - height / 2, centre.z), width, height);
      case McRigNode(:final String rigId, :final McMat4 transform):
        final McRig? rig = mcRigById(rigId, slim: McAssetLoader.loaded?.manifest.player.slim ?? false);
        if (rig == null) return null;
        return _SpriteBox(transform.transformPoint(McVec3.zero), null, rig.heightBlocks);
      case McBillboardNode(:final McVec3 position, :final double widthBlocks, :final double heightBlocks):
        return _SpriteBox(position, widthBlocks, heightBlocks);
      case McShadowNode() || McWaterNode() || McParticleNode():
        return null;
    }
  }

  /// The world length of one local axis under [m], column-major.
  static double _columnLength(McMat4 m, int column) {
    final Float64List v = m.m;
    final double x = v[column * 4], y = v[column * 4 + 1], z = v[column * 4 + 2];
    return math.sqrt(x * x + y * y + z * z);
  }

  // --- render --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _schedulePostFrame();
    final bool free = _c.freeCamera;
    final bool webGl = _c.webGlAvailable;
    return dom.div(
      id: _id,
      classes: <String>[
        'hui-mc-stage',
        if (_dragging && !_panning) 'is-orbiting',
        if (_dragging && _panning) 'is-panning',
      ].join(' '),
      attributes: <String, String>{
        if (free) 'tabindex': '0',
        'role': free ? 'application' : 'img',
        'aria-label': component.label ?? huiText('Minecraft stage'),
        'data-webgl': webGl ? 'ready' : 'unavailable',
        'data-animating': _c.animating ? 'true' : 'false',
      },
      <Widget>[
        if (!webGl) const dom.div(classes: 'hui-mc-still', <Widget>[]),
        dom.div(
          id: _canvasHostId,
          classes: 'hui-mc-gl-host',
          attributes: <String, String>{'data-frames': '${_c.frames}'},
          const <Widget>[],
        ),
        dom.div(classes: 'hui-mc-dom', <Widget>[
          dom.div(
            classes: 'hui-mc-dom-camera',
            styles: dom.Styles(raw: <String, String>{'transform': mcDomCameraTransform(_c.camera)}),
            <Widget>[if (!webGl) ..._sprites(), ...component.overlay],
          ),
        ]),
        if (component.controls.isNotEmpty) dom.div(classes: 'hui-mc-controls', component.controls),
      ],
    );
  }
}
