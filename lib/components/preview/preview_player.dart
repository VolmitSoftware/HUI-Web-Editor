/// The simulated player: their input, their camera, and the runtime rules
/// drawn around them.
///
/// Split out of `preview_stage.dart`, which owns sprites, quads and the frame
/// loop. The three things in this file share one subject rather than one
/// mechanism — every one of them is about the *player*:
///
///  * [PreviewInput] is what a person does with a mouse and a keyboard,
///    including the whole of Player mode: the walk, the mouselook, the pointer
///    lock.
///  * [PreviewOverlayLayer] draws the rules that only exist because a player is
///    standing somewhere — the collision plane that re-aims at their eye, the
///    normal a hovered icon jumps along toward them, the anchor a bitmap hangs
///    off, and the sphere the session closes at when they walk out of it.
///
/// Movement is proposed ([PreviewInput.attemptedFeet]) and committed separately
/// ([PreviewInput.commitFeet]). The stage rejects a locked move before the
/// simulation's range and follow handling, matching
/// `MenuSessionManager.handleMovement`.
///
/// Nothing here schedules a frame of its own. Every handler ends in
/// [PreviewInputHost.onInputChanged], and a held movement key keeps the stage's
/// 50 ms clock awake through [PreviewInput.attemptedFeet] returning non-null —
/// so a parked pointer over a static menu still schedules nothing.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../model/hui_menu.dart' show huiMaxDistanceCeiling;
import '../../preview/preview_scene.dart';
import '../../preview/preview_types.dart';
import '../../preview/projection.dart';
import '../../preview/simulation.dart';
import 'preview_pose.dart';

/// Degrees of orbit per pixel of drag.
const double huiPreviewOrbitSensitivity = 0.32;

/// Wheel dolly response, matching the canvas's `exp(-deltaY * k)` feel.
const double huiPreviewDollyFactor = 0.0016;

/// Pointer travel below which a press-release is a click, not a drag.
const double huiPreviewClickSlopPx = 4;

/// Degrees of look per pixel of locked mouse travel. Deliberately below a
/// shooter's default: the stage is a small viewport and overshooting a 0.2
/// block hitbox is the whole failure mode of first-person inspection.
const double huiPreviewLookDegreesPerPixel = 0.13;

/// Vanilla walking speed. A player covers 4.317 blocks a second, which on the
/// 50 ms tick everything else in the preview runs on is 0.216 blocks a tick.
const double huiPreviewWalkBlocksPerSecond = 4.317;

/// The keys a walk reads, lower-cased.
const Set<String> huiPreviewWalkKeys = <String>{'w', 'a', 's', 'd'};

/// Stage keys that flip a preview setting. Digits for the six overlays, because
/// every letter that would read as a mnemonic there is already a global view
/// shortcut (`keyboard_shortcuts.dart:142-152` binds c, p, s and v); `f` for
/// facing and `k` for pause are the two left over.
const Set<String> huiPreviewToggleKeys = <String>{
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  'f',
  'k',
};

/// Half-width of the ground grid, in blocks. 16 keeps the element at 3072 px a
/// side: a composited layer over 4096 px silently fails to rasterize on the
/// software renderer, and the grid disappears entirely.
const int huiPreviewGroundBlocks = 16;

/// Largest radius the `maxDistance` rings are drawn at, in blocks.
///
/// A ring element is `2 x radius x 96` px a side, so 16 blocks lands on exactly
/// the 3072 px the ground grid already proves rasterizes. Past that the rings
/// are drawn AT the cap and restyled dotted rather than dropped: a toggle that
/// silently does nothing is worse than a stated approximation, and the default
/// `maxDistance` is 6e7, so the uncapped case is the common one.
const double huiPreviewMaxRangeBlocks = 16;

/// How far an overlay is pushed along its plane normal, in blocks. The overlay
/// is otherwise exactly coplanar with the icon quad it describes, and a
/// coplanar pair z-fights into a flicker at every camera angle.
const double huiPreviewOverlayEpsilon = 0.004;

/// Length of a plane-normal marker, in blocks.
const double huiPreviewNormalBlocks = 1;

/// Overlay palette. Blue is already the player and amber already the menu
/// centre, so hitboxes take mint and the range boundary takes red: the colour
/// alone says which runtime rule an overlay is about.
const String _huiPlaneColor = '#6ee7a8';
const String _huiAnchorColor = '#ffd479';
const String _huiRangeColor = '#ff7a7a';

/// What a held pointer is doing.
///
/// [press] moves nothing: it is Player mode without pointer lock, where the
/// cursor is the aim and a press only has to be watched for the slop that
/// separates a click from a stray drag.
enum PreviewDragMode { none, orbit, pan, press }

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------

/// What [PreviewInput] needs from the stage.
abstract interface class PreviewInputHost {
  /// The session pose. Camera writes on it are silent by contract, which is
  /// why a 60 fps drag never rebuilds a Jaspr subtree.
  PreviewPose get inputPose;

  /// `store.previewCameraMode == PreviewCameraMode.player`.
  bool get inputPlayerMode;

  double get inputWidthPx;

  double get inputHeightPx;

  /// Something moved: re-run the simulation and schedule a frame.
  void onInputChanged();

  /// `0` — frame the menu from where the player opened it.
  void onInputReset();

  /// A left click, which is the only thing the runtime dispatches on
  /// (`MenuSessionManager.java:170-203`).
  void onInputClick();

  /// One of [huiPreviewToggleKeys], already lower-cased.
  void onInputToggle(String key);

  /// The user is driving the stage rather than reading it: an orbit or pan
  /// drag, a dolly, or a click. Fires on every one of those, so the host has
  /// to be idempotent — it exists to retire one-time chrome, not to animate.
  void onInputEngaged();
}

/// Every pointer, wheel and key the stage listens to, plus Player mode.
class PreviewInput {
  PreviewInput(this._host);

  final PreviewInputHost _host;

  final Map<String, JSFunction> _stageListeners = <String, JSFunction>{};
  final Map<String, JSFunction> _documentListeners = <String, JSFunction>{};
  web.HTMLElement? _stage;

  double _pointerX = 0;
  double _pointerY = 0;
  bool _pointerInside = false;
  int? _activePointerId;
  PreviewDragMode _drag = PreviewDragMode.none;
  double _dragTotalPx = 0;
  bool _spaceHeld = false;
  bool _pointerLocked = false;
  bool _lockRefused = false;
  bool _suppressNextClick = false;
  final Set<String> _held = <String>{};

  /// True while the browser has handed us the raw mouse. Escape releases it;
  /// the browser does that itself and tells us through `pointerlockchange`.
  bool get pointerLocked => _pointerLocked;

  /// False once a lock request has been refused — a headless browser, an
  /// embedded frame without `allow="pointer-lock"`, or a user who said no.
  /// Player mode then aims with the ordinary cursor instead, and asks no more.
  bool get pointerLockAvailable => !_lockRefused;

  // --- attach ----------------------------------------------------------------

  void attach(web.HTMLElement stage) {
    if (identical(_stage, stage)) return;
    detach();
    _stage = stage;

    void bindStage(
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

    bindStage('pointerdown', _onPointerDown, passive: false);
    bindStage('pointermove', _onPointerMove, passive: false);
    bindStage('pointerup', _onPointerUp);
    bindStage('pointercancel', _onPointerCancel);
    bindStage('pointerenter', _onPointerEnter);
    bindStage('pointerleave', _onPointerLeave);
    bindStage('wheel', _onWheel, passive: false);
    bindStage('contextmenu', _onContextMenu, passive: false);
    bindStage('keydown', _onKeyDown, passive: false);
    bindStage('keyup', _onKeyUp);
    bindStage('blur', _onBlur);

    // Pointer lock is a document-level fact: the browser can drop it without
    // touching the element (Escape, a tab switch), so the state has to be read
    // back rather than assumed.
    void bindDocument(String type, void Function(web.Event event) handler) {
      final JSFunction listener = handler.toJS;
      _documentListeners[type] = listener;
      web.document.addEventListener(type, listener);
    }

    bindDocument('pointerlockchange', _onPointerLockChange);
    bindDocument('pointerlockerror', _onPointerLockError);
    _syncStageState();
  }

  void detach() {
    final web.HTMLElement? stage = _stage;
    if (stage != null) {
      for (final MapEntry<String, JSFunction> entry
          in _stageListeners.entries) {
        stage.removeEventListener(entry.key, entry.value);
      }
    }
    for (final MapEntry<String, JSFunction> entry
        in _documentListeners.entries) {
      web.document.removeEventListener(entry.key, entry.value);
    }
    _stageListeners.clear();
    _documentListeners.clear();
    _stage = null;
    _held.clear();
    _spaceHeld = false;
    _drag = PreviewDragMode.none;
    _activePointerId = null;
  }

  // --- what the stage reads --------------------------------------------------

  /// Viewport pixel to cast the look ray through, or null when nothing is
  /// aimed at the scene.
  ///
  /// Under pointer lock there is no cursor, so the ray is the crosshair at the
  /// centre — which is also literally what the runtime tests, the player's own
  /// eye ray (`ClickableComponent.java:59-70`).
  (double, double)? rayPoint() {
    if (_pointerLocked) {
      return (_host.inputWidthPx / 2, _host.inputHeightPx / 2);
    }
    if (!_pointerInside) return null;
    return (_pointerX, _pointerY);
  }

  /// Where the held movement keys are asking the player to be after [step],
  /// or null when nothing is held.
  ///
  /// Deliberately not applied: see the library comment. Held keys are dropped
  /// outside Player mode so leaving the mode mid-stride cannot resume it.
  PVec3? attemptedFeet(Duration step) {
    if (!_host.inputPlayerMode) {
      _held.clear();
      return null;
    }
    double forward = 0;
    double strafe = 0;
    if (_held.contains('w')) forward += 1;
    if (_held.contains('s')) forward -= 1;
    if (_held.contains('d')) strafe += 1;
    if (_held.contains('a')) strafe -= 1;
    if (forward == 0 && strafe == 0) return null;

    final PlayerPose pose = _host.inputPose.player;
    // Yaw-relative and pitch-free: looking up does not make a player fly.
    // `huiLookDirection` at pitch 0 is the horizontal heading, and the same
    // function 90 degrees round is the player's right.
    final PVec3 ahead = huiLookDirection(yawDegrees: pose.yawDegrees);
    final PVec3 rightward = huiLookDirection(yawDegrees: pose.yawDegrees + 90);
    final PVec3 direction = (ahead * forward + rightward * strafe).normalized;
    final double distance =
        huiPreviewWalkBlocksPerSecond * step.inMicroseconds / 1e6;
    return pose.feet + direction * distance;
  }

  /// Accepts a step the runtime would have allowed.
  void commitFeet(PVec3 feet) {
    final PreviewPose pose = _host.inputPose;
    pose.player = pose.player.copyWith(feet: feet);
  }

  // --- pointer ---------------------------------------------------------------

  void _onPointerEnter(web.Event event) {
    _pointerInside = true;
    _updatePointer(event);
    _host.onInputChanged();
  }

  void _onPointerLeave(web.Event event) {
    _pointerInside = false;
    _host.onInputChanged();
  }

  void _onPointerDown(web.Event event) {
    final web.PointerEvent pointer = event as web.PointerEvent;
    final int button = pointer.button;
    if (button != 0 && button != 1) return;
    event.preventDefault();
    _stage?.focus();
    _pointerInside = true;
    if (!_pointerLocked) _updatePointer(event);

    if (_host.inputPlayerMode) {
      // First press takes the pointer; only after that does a press mean a
      // click at the crosshair. Without the suppression the grab gesture
      // itself would fire whatever the crosshair happened to land on.
      if (!_pointerLocked && !_lockRefused) {
        _suppressNextClick = true;
        _requestPointerLock();
        _host.onInputChanged();
        return;
      }
      if (_pointerLocked) {
        _host.onInputChanged();
        return;
      }
      // Lock refused: the cursor is the aim, so a press still has to be
      // tracked or a click could never reach the menu at all.
    }

    _activePointerId = pointer.pointerId;
    _dragTotalPx = 0;
    _drag = _host.inputPlayerMode
        ? PreviewDragMode.press
        : (button == 1 || _spaceHeld
              ? PreviewDragMode.pan
              : PreviewDragMode.orbit);
    _syncStageState();
    try {
      _stage?.setPointerCapture(pointer.pointerId);
    } catch (_) {
      // Capture is an enhancement; the stage still tracks while inside.
    }
    _host.onInputChanged();
  }

  void _onPointerMove(web.Event event) {
    if (_pointerLocked) {
      _look(event);
      return;
    }
    final double previousX = _pointerX;
    final double previousY = _pointerY;
    _pointerInside = true;
    _updatePointer(event);
    if (_activePointerId == null || _drag == PreviewDragMode.none) {
      _host.onInputChanged();
      return;
    }
    event.preventDefault();
    final double dx = _pointerX - previousX;
    final double dy = _pointerY - previousY;
    _dragTotalPx += dx.abs() + dy.abs();
    switch (_drag) {
      case PreviewDragMode.orbit:
        _orbitBy(dx, dy);
        _host.onInputEngaged();
      case PreviewDragMode.pan:
        _panBy(dx, dy);
        _host.onInputEngaged();
      case PreviewDragMode.press:
      case PreviewDragMode.none:
        // Aiming only; the ray already moved with the cursor.
        break;
    }
    _host.onInputChanged();
  }

  void _onPointerUp(web.Event event) {
    final web.PointerEvent pointer = event as web.PointerEvent;
    if (_pointerLocked) {
      if (pointer.button != 0) return;
      if (_suppressNextClick) {
        _suppressNextClick = false;
        return;
      }
      _host.onInputClick();
      return;
    }
    if (_activePointerId != pointer.pointerId) return;
    final bool wasClick =
        (_drag == PreviewDragMode.orbit || _drag == PreviewDragMode.press) &&
        _dragTotalPx <= huiPreviewClickSlopPx;
    _endDrag(pointer.pointerId);
    // LEFT_CLICK_AIR only (`MenuSessionManager.java:170-203`); a drag that
    // happens to end over a component is a camera move, not a click.
    if (wasClick && pointer.button == 0) _host.onInputClick();
  }

  void _onPointerCancel(web.Event event) =>
      _endDrag((event as web.PointerEvent).pointerId);

  void _endDrag(int pointerId) {
    if (_activePointerId != pointerId) return;
    _activePointerId = null;
    _drag = PreviewDragMode.none;
    _dragTotalPx = 0;
    _syncStageState();
    try {
      _stage?.releasePointerCapture(pointerId);
    } catch (_) {
      // Already released.
    }
    _host.onInputChanged();
  }

  void _onWheel(web.Event event) {
    event.preventDefault();
    // A player has no dolly. Player mode swallows the wheel rather than
    // scrolling the shell behind the stage.
    if (_host.inputPlayerMode) return;
    final double delta = _normalizedWheelDelta(event);
    if (delta == 0) return;
    _host.onInputEngaged();
    final PreviewPose pose = _host.inputPose;
    pose.orbit = pose.orbit
        .copyWith(
          distance:
              pose.orbit.distance * math.exp(delta * huiPreviewDollyFactor),
        )
        .clamped();
    _host.onInputChanged();
  }

  void _onContextMenu(web.Event event) => event.preventDefault();

  void _updatePointer(web.Event event) {
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    final web.DOMRect rect = stage.getBoundingClientRect();
    _pointerX = _eventDouble(event, 'clientX') - rect.left;
    _pointerY = _eventDouble(event, 'clientY') - rect.top;
  }

  // --- camera ----------------------------------------------------------------

  void _orbitBy(double dx, double dy) {
    // Drag right turns the scene right, which means the camera swings left.
    final PreviewPose pose = _host.inputPose;
    pose.orbit = pose.orbit
        .copyWith(
          yawDegrees: pose.orbit.yawDegrees - dx * huiPreviewOrbitSensitivity,
          pitchDegrees:
              pose.orbit.pitchDegrees + dy * huiPreviewOrbitSensitivity,
        )
        .clamped();
  }

  void _panBy(double dx, double dy) {
    final PreviewPose pose = _host.inputPose;
    final CameraBasis basis = CameraBasis.orbit(pose.orbit);
    // A pixel of drag should move the target by a pixel at the target's depth.
    final double blocksPerPixel = pose.orbit.distance / huiPreviewPerspectivePx;
    pose.orbit = pose.orbit.copyWith(
      target:
          pose.orbit.target -
          basis.right * (dx * blocksPerPixel) +
          basis.up * (dy * blocksPerPixel),
    );
  }

  /// Mouselook. Yaw grows to the player's right and pitch grows downward, which
  /// is Minecraft's own convention (`preview_types.dart` states the frame), so
  /// both deltas add straight on.
  void _look(web.Event event) {
    final double dx = _eventDouble(event, 'movementX');
    final double dy = _eventDouble(event, 'movementY');
    if (dx == 0 && dy == 0) return;
    final PreviewPose pose = _host.inputPose;
    final PlayerPose player = pose.player;
    pose.player = player
        .copyWith(
          yawDegrees: player.yawDegrees + dx * huiPreviewLookDegreesPerPixel,
          pitchDegrees:
              player.pitchDegrees + dy * huiPreviewLookDegreesPerPixel,
        )
        .clamped();
    _host.onInputChanged();
  }

  // --- pointer lock ----------------------------------------------------------

  void _requestPointerLock() {
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    try {
      final JSAny? result = (stage as JSObject).callMethod<JSAny?>(
        'requestPointerLock'.toJS,
      );
      // Modern browsers return a promise that rejects when the document is not
      // focused or the user just escaped out of a lock. Swallow it: the state
      // is read back from `pointerlockchange` either way, and an unhandled
      // rejection would be the only thing it produced.
      if (result != null && result.isA<JSPromise<JSAny?>>()) {
        unawaited(
          (result as JSPromise<JSAny?>).toDart.then<void>(
            (JSAny? _) {},
            onError: (Object _) {},
          ),
        );
      }
    } catch (_) {
      _refuseLock();
    }
  }

  void _onPointerLockChange(web.Event event) {
    final bool locked = identical(web.document.pointerLockElement, _stage);
    if (locked == _pointerLocked) return;
    _pointerLocked = locked;
    if (locked) {
      _lockRefused = false;
    } else {
      // Escaping out of the lock must not leave a key stuck down.
      _held.clear();
      _suppressNextClick = false;
    }
    _syncStageState();
    _host.onInputChanged();
  }

  /// The browser said no.
  ///
  /// Headless Chromium refuses outright, an iframe without
  /// `allow="pointer-lock"` refuses, and a user can refuse. Player mode must
  /// not be left in a state where the cursor aims but a click can never fire,
  /// so the refusal is remembered and presses fall back to the cursor.
  void _onPointerLockError(web.Event event) => _refuseLock();

  void _refuseLock() {
    _suppressNextClick = false;
    if (_lockRefused) return;
    _lockRefused = true;
    _host.onInputChanged();
  }

  // --- keyboard --------------------------------------------------------------

  void _onKeyDown(web.Event event) {
    final String key = _eventString(event, 'key');
    if (key == ' ' || key == 'Spacebar') {
      _spaceHeld = true;
      _syncStageState();
      _consume(event);
      return;
    }
    if (key == '0') {
      _host.onInputReset();
      _consume(event);
      return;
    }
    final String lower = key.toLowerCase();
    if (huiPreviewToggleKeys.contains(lower)) {
      _host.onInputToggle(lower);
      _consume(event);
      return;
    }
    if (_host.inputPlayerMode && huiPreviewWalkKeys.contains(lower)) {
      // Plain `s` is the global Split-view shortcut and the document listener
      // is one bubble away (`key_listener_web.dart`), so a walk key has to be
      // stopped here or walking backwards changes the view.
      _consume(event);
      if (_held.add(lower)) _host.onInputChanged();
    }
  }

  void _onKeyUp(web.Event event) {
    final String key = _eventString(event, 'key');
    if (key == ' ' || key == 'Spacebar') {
      _spaceHeld = false;
      _syncStageState();
      return;
    }
    if (_held.remove(key.toLowerCase())) _host.onInputChanged();
  }

  void _onBlur(web.Event event) {
    _spaceHeld = false;
    // A key released while the stage was not focused never arrives, so losing
    // focus mid-stride would walk forever.
    final bool wasWalking = _held.isNotEmpty;
    _held.clear();
    _syncStageState();
    if (wasWalking) _host.onInputChanged();
  }

  static void _consume(web.Event event) {
    event.preventDefault();
    event.stopPropagation();
  }

  void _syncStageState() {
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    stage.classList.toggle('is-panning', _drag == PreviewDragMode.pan);
    stage.classList.toggle('is-orbiting', _drag == PreviewDragMode.orbit);
    stage.classList.toggle('is-pan-ready', _spaceHeld && !_pointerLocked);
  }
}

// ---------------------------------------------------------------------------
// Range
// ---------------------------------------------------------------------------

/// The `maxDistance` the runtime would apply: an absent key reads as the 6e7
/// ceiling, and the value is clamped into `[0, ceiling]`
/// (`MenuSession.java:147-151`).
double huiPreviewBareRange(PreviewSimulation sim) {
  final double raw = sim.maxDistance ?? huiMaxDistanceCeiling;
  if (raw.isNaN) return huiMaxDistanceCeiling;
  return raw < 0
      ? 0
      : (raw > huiMaxDistanceCeiling ? huiMaxDistanceCeiling : raw);
}

/// The radius the session actually closes at.
///
/// The test is `centerDistance² <= maxDistance² + offset.lengthSquared()`
/// (`MenuSession.java:147-151`), so the real boundary is a sphere of radius
/// `sqrt(maxDistance² + |offset|²)` — a menu held further out is allowed to
/// travel proportionally further before it closes. Drawing that rather than
/// `maxDistance` is the point of the overlay.
double huiPreviewEffectiveRange(PreviewSimulation sim) {
  final double bare = huiPreviewBareRange(sim);
  return math.sqrt(bare * bare + sim.menuOffset.lengthSquared);
}

/// What the range check will compare against, spelled out for the HUD.
String huiPreviewRangeSummary(PreviewSimulation sim) {
  final double bare = huiPreviewBareRange(sim);
  if (bare >= huiMaxDistanceCeiling) {
    return 'unbounded - maxDistance absent (ring clamped to '
        '${huiPreviewMaxRangeBlocks.toStringAsFixed(0)})';
  }
  final double effective = huiPreviewEffectiveRange(sim);
  final String text = effective > bare + 5e-3
      ? '${bare.toStringAsFixed(2)} -> ${effective.toStringAsFixed(2)} '
            'effective (+ menu offset)'
      : '${bare.toStringAsFixed(2)} blocks';
  return effective > huiPreviewMaxRangeBlocks ? '$text - ring clamped' : text;
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

/// The six overlay switches, straight off the store.
class PreviewOverlayFlags {
  const PreviewOverlayFlags({
    required this.groundGrid,
    required this.center,
    required this.planes,
    required this.normals,
    required this.anchors,
    required this.range,
    this.selectedButtonId,
  });

  final bool groundGrid;
  final bool center;
  final bool planes;
  final bool normals;
  final bool anchors;
  final bool range;
  final String? selectedButtonId;

  bool get anyPerComponent =>
      planes || normals || anchors || selectedButtonId != null;
}

/// Every world overlay: the ground, the avatar, the menu centre, the
/// `maxDistance` boundary and the per-component collision geometry.
///
/// Owns its DOM outright. Marker and ring nodes are built once with the stage's
/// camera and only ever hidden; per-component nodes are created and destroyed
/// with the flags that reveal them, so a preview with every overlay off carries
/// no per-component overlay DOM at all.
class PreviewOverlayLayer {
  final List<_MarkerNode> _markers = <_MarkerNode>[];
  final List<_MarkerNode> _rings = <_MarkerNode>[];
  final List<_OverlayNode> _overlays = <_OverlayNode>[];
  web.HTMLElement? _camera;

  /// Builds the fixed part into [camera]. Called once per world build; the
  /// caller has already emptied the camera, so the lists reset with it.
  void build(web.HTMLElement camera) {
    _camera = camera;
    _markers.clear();
    _rings.clear();
    _overlays.clear();

    void marker(String key, String classes) {
      final web.HTMLElement node = huiPreviewElement(classes);
      _markers.add(_MarkerNode(key, node));
      camera.append(node);
    }

    marker('ground', 'hui-preview-ground');
    marker('avatar-disc', 'hui-preview-avatar-disc');
    marker('avatar-postA', 'hui-preview-avatar-post');
    marker('avatar-postB', 'hui-preview-avatar-post');
    marker('avatar-eye', 'hui-preview-avatar-eye');
    marker('center-disc', 'hui-preview-center-disc');
    marker('center-postA', 'hui-preview-center-post');
    marker('center-postB', 'hui-preview-center-post');

    // Three axis-aligned great circles per radius: a sphere drawn as rings
    // needs no billboarding and no per-frame work, and the horizontal one is
    // the only one a walking player ever actually crosses.
    for (final String plane in const <String>['xy', 'xz', 'yz']) {
      _ring('range-$plane', solid: true, camera: camera);
      _ring('bare-$plane', solid: false, camera: camera);
    }
  }

  void _ring(
    String key, {
    required bool solid,
    required web.HTMLElement camera,
  }) {
    final web.HTMLElement node = huiPreviewElement(
      'hui-preview-ring ${solid ? 'is-effective' : 'is-bare'}',
    );
    huiPreviewCss(node, <String, String>{
      'box-sizing': 'border-box',
      'border-radius': '50%',
      'border': solid
          ? '2px solid ${huiPreviewAlpha(_huiRangeColor, .72)}'
          : '1px dashed ${huiPreviewAlpha(_huiRangeColor, .42)}',
    });
    node.classList.toggle('is-hidden', true);
    _rings.add(_MarkerNode(key, node));
    camera.append(node);
  }

  /// One frame of every overlay.
  void render({
    required PreviewScene preview,
    required PreviewSimulation sim,
    required PVec3 eye,
    required PVec3 playerFeet,
    required bool playerMode,
    required PreviewOverlayFlags flags,
  }) {
    _renderMarkers(preview, playerFeet, playerMode, flags);
    _renderRange(preview, sim, flags.range);
    _renderComponents(preview, sim.isOpen, eye, flags);
  }

  void _renderMarkers(
    PreviewScene preview,
    PVec3 playerFeet,
    bool playerMode,
    PreviewOverlayFlags flags,
  ) {
    final PVec3 feet = preview.openFeet;
    final PVec3 eye = PVec3(feet.x, feet.y + huiPreviewEyeHeight, feet.z);
    final PVec3 center = preview.center;
    final double yaw = preview.openYawDeg;
    // You cannot see your own head. Standing on the open spot in Player mode
    // puts the eye marker exactly at the camera, where the perspective divide
    // blows it up across the whole viewport.
    final bool showAvatar = !playerMode || playerFeet.distanceTo(feet) > 0.75;

    for (final _MarkerNode marker in _markers) {
      final (bool visible, String transform, double width, double height)
      spec = switch (marker.key) {
        // Snapped to whole blocks so the 1-block gradient stays aligned to
        // integer world coordinates however far the player wanders, and hung
        // off the LIVE feet so walking never runs off the edge of it.
        'ground' => (
          flags.groundGrid,
          _flatTransform(
            PVec3(
              playerFeet.x.roundToDouble(),
              0,
              playerFeet.z.roundToDouble(),
            ),
          ),
          huiPreviewGroundBlocks * 2,
          huiPreviewGroundBlocks * 2,
        ),
        'avatar-disc' => (showAvatar, _flatTransform(feet), 0.6, 0.6),
        'avatar-postA' => (
          showAvatar,
          _uprightTransform(_eyeMid(feet), yaw),
          0.03,
          1.62,
        ),
        'avatar-postB' => (
          showAvatar,
          _uprightTransform(_eyeMid(feet), yaw + 90),
          0.03,
          1.62,
        ),
        'avatar-eye' => (showAvatar, _flatTransform(eye), 0.4, 0.4),
        'center-disc' => (flags.center, _flatTransform(center), 0.24, 0.24),
        'center-postA' => (
          flags.center,
          _uprightTransform(center, yaw),
          0.02,
          0.4,
        ),
        'center-postB' => (
          flags.center,
          _uprightTransform(center, yaw + 90),
          0.02,
          0.4,
        ),
        _ => (false, '', 0, 0),
      };
      huiPreviewShow(marker, spec.$1);
      if (!spec.$1) continue;
      huiPreviewPlace(
        marker,
        spec.$2,
        spec.$3 * huiPreviewPxPerBlock,
        spec.$4 * huiPreviewPxPerBlock,
      );
    }
  }

  /// The `maxDistance` boundary, as great circles on the session centre.
  ///
  /// Centred on `sessionCenter` — the UNROTATED `centerPoint` — because that is
  /// the point the range check measures from (`MenuSession.java:147-151`), not
  /// the rotated one the menu draws at.
  void _renderRange(PreviewScene preview, PreviewSimulation sim, bool show) {
    final PVec3 center = preview.sessionCenter;
    final double bare = huiPreviewBareRange(sim);
    final double effective = huiPreviewEffectiveRange(sim);
    final bool clamped = effective > huiPreviewMaxRangeBlocks;
    final double drawn = clamped ? huiPreviewMaxRangeBlocks : effective;
    // The bare `maxDistance` ring only earns its place when the offset actually
    // loosened the threshold, and never once the pair has been clamped to the
    // same radius — two coincident rings would claim they agree.
    final bool showBare =
        show && !clamped && bare > 1e-6 && effective - bare > 5e-3;

    for (final _MarkerNode ring in _rings) {
      final bool isBare = ring.key.startsWith('bare');
      final bool visible = isBare ? showBare : (show && drawn > 1e-6);
      huiPreviewShow(ring, visible);
      if (!visible) continue;
      final double size = (isBare ? bare : drawn) * 2 * huiPreviewPxPerBlock;
      huiPreviewPlace(ring, _ringTransform(ring.key, center), size, size);
      if (!isBare) {
        ring.element.style.setProperty(
          'border-style',
          clamped ? 'dotted' : 'solid',
        );
      }
    }
  }

  void _renderComponents(
    PreviewScene preview,
    bool open,
    PVec3 eye,
    PreviewOverlayFlags flags,
  ) {
    final web.HTMLElement? camera = _camera;
    if (camera == null) return;
    final int wanted = flags.anyPerComponent ? preview.quads.length : 0;

    while (_overlays.length > wanted) {
      _overlays.removeLast().remove();
    }
    while (_overlays.length < wanted) {
      final _OverlayNode node = _OverlayNode.create();
      _overlays.add(node);
      node.appendTo(camera);
    }

    for (int i = 0; i < wanted; i++) {
      _renderComponent(_overlays[i], preview.quads[i], eye, open, flags);
    }
  }

  void _renderComponent(
    _OverlayNode node,
    PreviewQuad quad,
    PVec3 eye,
    bool open,
    PreviewOverlayFlags flags,
  ) {
    // The plane is rebuilt from the eye EVERY frame while the quad it belongs
    // to never moves (`ClickableComponent.java:60-62`). Seeing the rectangle
    // swing around a stationary icon is the entire reason this overlay exists.
    final PlaneAim? aim = open && quad.hasPlane
        ? aimQuadPlane(quad, eye)
        : null;

    final bool showPlane =
        flags.planes || quad.item.id == flags.selectedButtonId;
    huiPreviewShow(node.plane, showPlane && aim != null);
    if (showPlane && aim != null) {
      huiPreviewPlace(
        node.plane,
        _aimTransform(_liftAim(aim, huiPreviewOverlayEpsilon)),
        quad.planeWidth * huiPreviewPxPerBlock,
        quad.planeHeight * huiPreviewPxPerBlock,
      );
    }

    huiPreviewShow(node.normal, flags.normals && aim != null);
    if (flags.normals && aim != null) {
      huiPreviewPlace(
        node.normal,
        _barTransform(
          center:
              aim.center +
              aim.normal *
                  (huiPreviewNormalBlocks / 2 + huiPreviewOverlayEpsilon),
          along: aim.normal,
          eye: eye,
        ),
        0.02 * huiPreviewPxPerBlock,
        huiPreviewNormalBlocks * huiPreviewPxPerBlock,
      );
    }

    huiPreviewShow(node.anchor, flags.anchors && open);
    huiPreviewShow(node.drop, false);
    if (!flags.anchors || !open) return;

    huiPreviewPlace(
      node.anchor,
      _aimTransform(aimPlaneAt(quad.anchor, eye)),
      0.1 * huiPreviewPxPerBlock,
      0.1 * huiPreviewPxPerBlock,
    );

    // The anchor is the plugin's `location`; the bitmap is drawn below it by
    // the true-render bias and, for items, by the display offset
    // (`MenuIcon.java:128-134`, `ItemMenuIcon.java:83-89`). The hairline is
    // that gap, which is otherwise invisible and routinely surprising.
    final PVec3 drop = quad.visualCenter - quad.anchor;
    final double length = drop.length;
    if (length <= 1e-4) return;
    huiPreviewShow(node.drop, true);
    huiPreviewPlace(
      node.drop,
      _barTransform(center: quad.anchor + drop * 0.5, along: drop, eye: eye),
      0.012 * huiPreviewPxPerBlock,
      length * huiPreviewPxPerBlock,
    );
  }
}

PVec3 _eyeMid(PVec3 feet) =>
    PVec3(feet.x, feet.y + huiPreviewEyeHeight / 2, feet.z);

class _MarkerNode extends PreviewWorldNode {
  _MarkerNode(this.key, super.element);

  final String key;
}

/// The three overlays one component can draw, plus the hairline between its
/// anchor and where its bitmap actually lands.
///
/// Created together and shown independently: they share a lifetime with their
/// quad, not with the flags that reveal them, so toggling an overlay never
/// reconciles the DOM — it only unhides what is already there.
class _OverlayNode {
  _OverlayNode._(this.plane, this.normal, this.anchor, this.drop);

  factory _OverlayNode.create() => _OverlayNode._(
    _styled('hui-preview-plane', <String, String>{
      'box-sizing': 'border-box',
      'border': '1px solid ${huiPreviewAlpha(_huiPlaneColor, .85)}',
      'background': huiPreviewAlpha(_huiPlaneColor, .1),
    }),
    // Opaque at the plane, fading outward: the element's local top is the
    // +normal end, which is where hover teleports the icon to.
    _styled('hui-preview-normal', <String, String>{
      'background':
          'linear-gradient(to top, '
          '${huiPreviewAlpha(_huiPlaneColor, .9)}, '
          '${huiPreviewAlpha(_huiPlaneColor, 0)})',
    }),
    _styled('hui-preview-anchor', <String, String>{
      'box-sizing': 'border-box',
      'border-radius': '50%',
      'border': '2px solid ${huiPreviewAlpha(_huiAnchorColor, .9)}',
    }),
    _styled('hui-preview-drop', <String, String>{
      'background': huiPreviewAlpha(_huiAnchorColor, .55),
    }),
  );

  static PreviewWorldNode _styled(
    String classes,
    Map<String, String> declarations,
  ) {
    final web.HTMLElement node = huiPreviewElement(classes);
    huiPreviewCss(node, declarations);
    node.classList.toggle('is-hidden', true);
    return PreviewWorldNode(node);
  }

  final PreviewWorldNode plane;
  final PreviewWorldNode normal;
  final PreviewWorldNode anchor;
  final PreviewWorldNode drop;

  Iterable<PreviewWorldNode> get all => <PreviewWorldNode>[
    plane,
    normal,
    anchor,
    drop,
  ];

  /// Appended straight to the camera rather than to a group of their own, so
  /// `.hui-preview-camera > *` in `07-preview.css` supplies the absolute
  /// positioning, the transform origin and `is-hidden` for free.
  void appendTo(web.HTMLElement camera) {
    for (final PreviewWorldNode node in all) {
      camera.append(node.element);
    }
  }

  void remove() {
    for (final PreviewWorldNode node in all) {
      node.element.remove();
    }
  }
}

// ---------------------------------------------------------------------------
// World transforms
// ---------------------------------------------------------------------------

/// A plane in the world's horizontal plane, centred at [position].
///
/// Columns are the css images of the element's own axes: local x maps to css x,
/// local y (which points DOWN in css) maps to css +z, and the normal ends up
/// along css -y, i.e. world up.
String _flatTransform(PVec3 position) =>
    '${cssMatrix3d(<double>[
      1, 0, 0, 0, //
      0, 0, 1, 0, //
      0, -1, 0, 0, //
      position.x * huiPreviewPxPerBlock,
      -position.y * huiPreviewPxPerBlock,
      -position.z * huiPreviewPxPerBlock,
      1,
    ])} translate(-50%,-50%)';

String _uprightTransform(PVec3 position, double yawDegrees) =>
    '${cssMatrix3d(cssQuadMatrix(position: position, facingYawDegrees: yawDegrees, pxPerBlock: huiPreviewPxPerBlock))} translate(-50%,-50%)';

/// An element lying exactly on [aim].
String _aimTransform(PlaneAim aim) =>
    '${cssMatrix3d(cssPlaneMatrix(aim, pxPerBlock: huiPreviewPxPerBlock))} '
    'translate(-50%,-50%)';

/// [aim] pushed off its own plane, to keep a coplanar overlay out of a z-fight
/// with the quad it describes.
PlaneAim _liftAim(PlaneAim aim, double blocks) => PlaneAim(
  center: aim.center + aim.normal * blocks,
  normal: aim.normal,
  right: aim.right,
  up: aim.up,
);

/// A thin world-space bar of [along]'s length, centred at [center] and turned
/// face-on to [eye] so a 2 cm stick never goes edge-on and vanishes.
///
/// `cssPlaneMatrix` writes css(right), css(-up) and css(normal) as its columns,
/// so a frame whose `up` is the bar's axis is all it needs; the three vectors
/// only have to be mutually orthogonal, and the handedness of the third is
/// invisible on a solid bar.
String _barTransform({
  required PVec3 center,
  required PVec3 along,
  required PVec3 eye,
}) {
  final PVec3 up = along.normalized;
  PVec3 right = up.cross((eye - center).normalized);
  if (right.lengthSquared <= 1e-12) right = up.cross(PVec3.forward);
  if (right.lengthSquared <= 1e-12) right = up.cross(PVec3.right);
  right = right.normalized;
  return _aimTransform(
    PlaneAim(center: center, normal: right.cross(up), right: right, up: up),
  );
}

/// One of the three great circles, on the world plane its key names.
///
/// Any orthonormal frame will do — a circle has no orientation inside its own
/// plane — so the frames below are picked for readability, not handedness.
String _ringTransform(String key, PVec3 center) =>
    _aimTransform(switch (key.substring(key.length - 2)) {
      'xy' => PlaneAim(
        center: center,
        normal: PVec3.forward,
        right: PVec3.right,
        up: PVec3.up,
      ),
      'xz' => PlaneAim(
        center: center,
        normal: PVec3.up,
        right: PVec3.right,
        up: PVec3.forward,
      ),
      _ => PlaneAim(
        center: center,
        normal: PVec3.right,
        right: PVec3.forward,
        up: PVec3.up,
      ),
    });

// ---------------------------------------------------------------------------
// Shared DOM plumbing
// ---------------------------------------------------------------------------

/// Nodes whose pixel size is written from Dart and cached to avoid style
/// thrash.
abstract class PreviewSizedNode {
  String size = '';
}

/// A node placed by a world matrix, with both writes cached.
class PreviewWorldNode extends PreviewSizedNode {
  PreviewWorldNode(this.element);

  final web.HTMLElement element;
  String transform = '';
}

web.HTMLElement huiPreviewElement(String classes) {
  final web.HTMLElement node =
      web.document.createElement('div') as web.HTMLElement;
  node.className = classes;
  return node;
}

/// Inline styling for nodes `07-preview.css` does not describe — that file is
/// owned by the preview chrome, and a stage-only affordance has no business
/// crossing the line for four declarations. `setProperty` rather than the typed
/// setters, because it accepts every shorthand without a per-name binding.
void huiPreviewCss(web.HTMLElement node, Map<String, String> declarations) {
  for (final MapEntry<String, String> entry in declarations.entries) {
    node.style.setProperty(entry.key, entry.value);
  }
}

/// Hex plus alpha, in a form every target the app already ships understands.
String huiPreviewAlpha(String hex, double alpha) =>
    'color-mix(in srgb, $hex ${(alpha * 100).round()}%, transparent)';

/// Visibility is a class, not the `hidden` attribute: package:web types
/// `hidden` as `JSAny?`, so a bool cannot be assigned to it from Dart.
void huiPreviewShow(PreviewWorldNode node, bool visible) =>
    node.element.classList.toggle('is-hidden', !visible);

void huiPreviewPlace(
  PreviewWorldNode node,
  String transform,
  double widthPx,
  double heightPx,
) {
  huiPreviewWriteTransform(
    node.element,
    transform,
    node.transform,
    (String value) => node.transform = value,
  );
  huiPreviewWriteSize(node.element, widthPx, heightPx, node);
}

void huiPreviewWriteTransform(
  web.HTMLElement node,
  String value,
  String previous,
  void Function(String value) remember,
) {
  if (value == previous) return;
  remember(value);
  node.style.transform = value;
}

void huiPreviewWriteSize(
  web.HTMLElement node,
  double widthPx,
  double heightPx,
  PreviewSizedNode sized,
) {
  final String size =
      '${widthPx.toStringAsFixed(2)}x${heightPx.toStringAsFixed(2)}';
  if (size == sized.size) return;
  sized.size = size;
  node.style.width = '${widthPx.toStringAsFixed(2)}px';
  node.style.height = '${heightPx.toStringAsFixed(2)}px';
}

/// Reads a numeric event property without trusting package:web's `int` typing:
/// real pointers report fractional client coordinates and the typed getter is
/// declared `int`, which throws under dart2js. Same reason as
/// `canvas_interactions.dart:22-26`.
double _eventDouble(web.Event event, String property) {
  final JSAny? value = (event as JSObject).getProperty<JSAny?>(property.toJS);
  if (value == null || !value.isA<JSNumber>()) return 0;
  return (value as JSNumber).toDartDouble;
}

String _eventString(web.Event event, String property) {
  final JSAny? value = (event as JSObject).getProperty<JSAny?>(property.toJS);
  if (value == null || !value.isA<JSString>()) return '';
  return (value as JSString).toDart;
}

/// Wheel deltas arrive in pixels, lines or pages; normalise to pixels the way
/// `viewport_math` does for the canvas so a trackpad and a mouse agree.
double _normalizedWheelDelta(web.Event event) {
  final double delta = _eventDouble(event, 'deltaY');
  final double mode = _eventDouble(event, 'deltaMode');
  if (mode == 1) return delta * 16;
  if (mode == 2) return delta * 400;
  return delta;
}
