/// Pointer, wheel and keyboard handling for [CanvasViewport].
///
/// Pointer Events with `setPointerCapture` (report-animal 4.1) so a drag keeps
/// tracking outside the element; `touch-action: none` in the stylesheet stops
/// the browser claiming the gesture first. Every transform change commits
/// straight to the canvas and to the DOM readouts, never through `setState`.
part of 'canvas_viewport.dart';

enum _DragMode { none, pan, component }

/// Buttons the browser reports on `PointerEvent.button`.
const int _primaryButton = 0;
const int _middleButton = 1;
const int _secondaryButton = 2;

/// Reads a numeric event property without trusting package:web's `int` typing.
///
/// Real pointers report fractional `clientX`/`clientY` (trackpads, zoomed
/// displays, interpolated moves), and the typed `MouseEvent.clientX` getter is
/// declared `int` — reading `1094.8` through it throws
/// `type 'double' is not a subtype of type 'int'` under both DDC and dart2js.
double _eventDouble(web.Event event, String property) {
  final JSAny? value = (event as JSObject).getProperty<JSAny?>(property.toJS);
  if (value == null || !value.isA<JSNumber>()) return 0;
  return (value as JSNumber).toDartDouble;
}

extension _CanvasInteractions on _CanvasViewportState {
  // --- transform commits ----------------------------------------------------

  void _commitViewport(HuiViewport next) {
    _viewport = next;
    _syncZoomReadout();
    _statusDirty = true;
    _markDirty();
  }

  void _syncZoomReadout() {
    final web.Element? label = web.document.getElementById(_zoomLabelId);
    if (label != null) {
      label.textContent = _zoomPercentText;
    }
  }

  void _zoomFromCenter(double factor) =>
      _commitViewport(_viewport.zoomByAtCenter(factor));

  void _resetView() {
    _commitViewport(_viewport.withTransform(CanvasTransform.identity));
  }

  /// Frames the components, the menu centre and enough of the player reference
  /// to keep the scene legible.
  void _fitToContent() {
    if (_viewport.widthPx <= 0 || _viewport.heightPx <= 0) return;
    final CanvasScene scene = _buildScene();
    WorldBounds bounds = scene.contentBounds;
    if (scene.isEmpty) {
      bounds = WorldBounds(
        minX: bounds.minX - 1.5,
        minY: math.min(bounds.minY, 0),
        maxX: bounds.maxX + 1.5,
        maxY: math.max(bounds.maxY, huiPlayerEyeHeight),
      );
    }
    if (bounds.width < 0.35) {
      bounds = WorldBounds(
        minX: bounds.centerX - 0.35,
        minY: bounds.minY,
        maxX: bounds.centerX + 0.35,
        maxY: bounds.maxY,
      );
    }
    if (bounds.height < 0.35) {
      bounds = WorldBounds(
        minX: bounds.minX,
        minY: bounds.centerY - 0.35,
        maxX: bounds.maxX,
        maxY: bounds.centerY + 0.35,
      );
    }
    _commitViewport(_viewport.zoomToFit(bounds.expand(0.3), paddingPx: 44));
  }

  // --- coordinate helpers ---------------------------------------------------

  /// Canvas-local CSS pixels for a pointer or wheel event.
  ScreenPoint _localPoint(double clientX, double clientY) {
    final web.HTMLCanvasElement? canvas = _canvas;
    if (canvas == null) return const ScreenPoint(0, 0);
    final web.DOMRect rect = canvas.getBoundingClientRect();
    return ScreenPoint(clientX - rect.x, clientY - rect.y);
  }

  WorldPoint _worldPoint(double clientX, double clientY) {
    final ScreenPoint local = _localPoint(clientX, clientY);
    return _viewport.screenToWorld(local.x, local.y);
  }

  // --- wheel ----------------------------------------------------------------

  void _handleWheel(web.Event event) {
    if (!event.isA<web.WheelEvent>()) return;
    final web.WheelEvent wheel = event as web.WheelEvent;
    wheel.preventDefault();
    final double factor = wheelZoomFactor(
      _eventDouble(wheel, 'deltaY'),
      deltaMode: wheel.deltaMode,
      pagePixels: math.max(1, _viewport.heightPx),
    );
    if (factor == 1) return;
    final ScreenPoint local =
        _localPoint(_eventDouble(wheel, 'clientX'), _eventDouble(wheel, 'clientY'));
    _commitViewport(
      _viewport.zoomByAtScreenPoint(
        factor: factor,
        screenX: local.x,
        screenY: local.y,
      ),
    );
  }

  // --- pointer --------------------------------------------------------------

  void _handlePointerDown(web.Event event) {
    if (!event.isA<web.PointerEvent>()) return;
    final web.PointerEvent pointer = event as web.PointerEvent;
    if (pointer.button == _secondaryButton) return;
    _stage?.focus();
    _lastClientX = _eventDouble(pointer, 'clientX');
    _lastClientY = _eventDouble(pointer, 'clientY');

    final bool forcePan = pointer.button == _middleButton || _spaceHeld;
    final WorldPoint world = _worldPoint(_lastClientX, _lastClientY);
    final CanvasItem? hit =
        forcePan ? null : _currentScene.hitTest(world.x, world.y);

    if (hit == null) {
      _dragMode = _DragMode.pan;
      _dragComponentId = null;
      if (!forcePan && pointer.button == _primaryButton) {
        component.store.select(null);
      }
    } else {
      _dragMode = _DragMode.component;
      _dragComponentId = hit.id;
      // Preserve the grab point so the component does not jump to the cursor.
      _grabOffsetX = world.x - hit.anchor.x;
      _grabOffsetY = world.y - hit.anchor.y;
      component.store.select(hit.id);
      component.store.beginDrag();
      _showReadout(hit.component.offset);
    }

    _statusDirty = true;
    _activePointerId = pointer.pointerId;
    try {
      _stage?.setPointerCapture(pointer.pointerId);
    } catch (_) {
      // Pointer capture is an enhancement, not a requirement.
    }
    _setStageState(dragging: true);
    event.preventDefault();
  }

  void _handlePointerMove(web.Event event) {
    if (!event.isA<web.PointerEvent>()) return;
    final web.PointerEvent pointer = event as web.PointerEvent;
    final double clientX = _eventDouble(pointer, 'clientX');
    final double clientY = _eventDouble(pointer, 'clientY');

    if (_activePointerId != pointer.pointerId) {
      _updateHover(clientX, clientY);
      return;
    }

    switch (_dragMode) {
      case _DragMode.none:
        break;
      case _DragMode.pan:
        _commitViewport(
          _viewport.panByPixels(clientX - _lastClientX, clientY - _lastClientY),
        );
        _setCursorReadout(_worldPoint(clientX, clientY));
      case _DragMode.component:
        _dragComponentTo(clientX, clientY);
    }
    _lastClientX = clientX;
    _lastClientY = clientY;
    event.preventDefault();
  }

  void _dragComponentTo(double clientX, double clientY) {
    final String? id = _dragComponentId;
    if (id == null) return;
    final EditorStore store = component.store;
    final HuiComponent? target = store.menu.componentById(id);
    if (target == null) return;
    final double scale = store.previewUiScale > 0 ? store.previewUiScale : 1;
    final WorldPoint world = _worldPoint(clientX, clientY);
    _setCursorReadout(world);
    // anchor = menuOffset + offset * uiScale, so invert exactly that.
    final double rawX = (world.x - _grabOffsetX - store.menu.offset.x) / scale;
    final double rawY = (world.y - _grabOffsetY - store.menu.offset.y) / scale;
    final double nextX = store.snapValue(rawX);
    final double nextY = store.snapValue(rawY);
    if (nextX == target.offset.x && nextY == target.offset.y) return;
    // editComponent instead of setComponentOffset: z must survive an xy drag
    // untouched, and the store's snapVec would round it too.
    store.editComponent(id, 'move $id', (HuiComponent moved) {
      moved.offset = Vec3(nextX, nextY, moved.offset.z);
    });
    _showReadout(Vec3(nextX, nextY, target.offset.z));
  }

  void _handlePointerUp(web.Event event) {
    if (!event.isA<web.PointerEvent>()) return;
    final web.PointerEvent pointer = event as web.PointerEvent;
    if (_activePointerId != pointer.pointerId) return;
    if (_dragMode == _DragMode.component) {
      component.store.endDrag();
    }
    _activePointerId = null;
    _dragMode = _DragMode.none;
    _dragComponentId = null;
    _statusDirty = true;
    try {
      if (_stage?.hasPointerCapture(pointer.pointerId) ?? false) {
        _stage?.releasePointerCapture(pointer.pointerId);
      }
    } catch (_) {
      // Already released by the browser.
    }
    _setStageState(dragging: false);
    _hideReadout();
    _markDirty();
  }

  void _handlePointerLeave(web.Event event) {
    if (_activePointerId != null) return;
    _clearCursorReadout();
    if (_hoveredId == null) return;
    _hoveredId = null;
    _setStageState(overComponent: false);
    _markDirty();
  }

  void _updateHover(double clientX, double clientY) {
    final WorldPoint world = _worldPoint(clientX, clientY);
    _setCursorReadout(world);
    final CanvasItem? hit = _currentScene.hitTest(world.x, world.y);
    final String? id = hit?.id;
    if (id == _hoveredId) return;
    _hoveredId = id;
    _setStageState(overComponent: id != null);
    _markDirty();
  }

  // --- context menu, double click -------------------------------------------

  void _handleContextMenu(web.Event event) => event.preventDefault();

  void _handleDoubleClick(web.Event event) {
    if (!event.isA<web.MouseEvent>()) return;
    final web.MouseEvent mouse = event as web.MouseEvent;
    final WorldPoint world =
        _worldPoint(_eventDouble(mouse, 'clientX'), _eventDouble(mouse, 'clientY'));
    final CanvasItem? hit = _currentScene.hitTest(world.x, world.y);
    if (hit == null) return;
    event.preventDefault();
    component.store.select(hit.id);
    // Advisory: the inspector may listen for this to pull focus. Nothing
    // depends on anyone handling it.
    _stage?.dispatchEvent(
      web.CustomEvent(
        'hui-inspector-focus',
        web.CustomEventInit(bubbles: true, composed: true),
      ),
    );
  }

  // --- keyboard -------------------------------------------------------------

  void _handleKeyUp(web.Event event) {
    if (!event.isA<web.KeyboardEvent>()) return;
    if ((event as web.KeyboardEvent).key == ' ') {
      _spaceHeld = false;
      _setStageState(panReady: false);
    }
  }

  void _handleBlur(web.Event event) {
    _spaceHeld = false;
    _setStageState(panReady: false);
  }

  void _handleKeyDown(web.Event event) {
    if (!event.isA<web.KeyboardEvent>()) return;
    final web.KeyboardEvent key = event as web.KeyboardEvent;
    if (key.ctrlKey || key.metaKey || key.altKey) return;
    if (_isTextEntryFocused()) return;

    bool handled = true;
    switch (key.key) {
      case ' ':
        _spaceHeld = true;
        _setStageState(panReady: true);
      case 'Escape':
        component.store.select(null);
      case 'Delete':
      case 'Backspace':
        _deleteSelection();
      case 'ArrowLeft':
        _nudge(-1, 0, key.shiftKey);
      case 'ArrowRight':
        _nudge(1, 0, key.shiftKey);
      case 'ArrowUp':
        _nudge(0, 1, key.shiftKey);
      case 'ArrowDown':
        _nudge(0, -1, key.shiftKey);
      case '+':
      case '=':
        _zoomFromCenter(huiZoomStep);
      case '-':
      case '_':
        _zoomFromCenter(1 / huiZoomStep);
      case '0':
        _resetView();
      case 'f':
      case 'F':
        _fitToContent();
      default:
        handled = false;
    }
    if (!handled) return;
    key.preventDefault();
    // The shell binds document keydown; consuming the event here is what keeps
    // canvas shortcuts from firing twice.
    key.stopPropagation();
  }

  /// Deleting from the canvas is immediate rather than confirmed: the gesture
  /// is local, undo is one keystroke away, and a modal over the artboard breaks
  /// the flow. The shell keeps its confirm for the global binding.
  void _deleteSelection() {
    final String? id = component.store.selectedId;
    if (id == null) return;
    component.store.deleteComponent(id);
  }

  void _nudge(int dx, int dy, bool coarse) {
    final EditorStore store = component.store;
    final String? id = store.selectedId;
    if (id == null) return;
    final double step = coarse ? huiNudgeStepCoarse : huiNudgeStep;
    final HuiComponent? target = store.menu.componentById(id);
    if (target == null) return;
    store.editComponent(id, 'nudge $id', (HuiComponent moved) {
      moved.offset = Vec3(
        _round(moved.offset.x + dx * step),
        _round(moved.offset.y + dy * step),
        moved.offset.z,
      );
    });
  }

  double _round(double value) =>
      !value.isFinite ? 0 : (value * 10000).roundToDouble() / 10000;

  /// True when a form control owns the keyboard, so canvas shortcuts stay out
  /// of the way of inline editing anywhere in the shell.
  bool _isTextEntryFocused() {
    final web.Element? active = web.document.activeElement;
    if (active == null) return false;
    final String tag = active.tagName.toLowerCase();
    if (tag == 'input' || tag == 'textarea' || tag == 'select') return true;
    return active.getAttribute('contenteditable') == 'true';
  }

  // --- DOM readouts ---------------------------------------------------------

  void _setStageState({
    bool? dragging,
    bool? overComponent,
    bool? panReady,
  }) {
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    if (dragging != null) {
      _toggleClass(stage, 'is-dragging', dragging);
      _toggleClass(
        stage,
        'is-moving-component',
        dragging && _dragMode == _DragMode.component,
      );
    }
    if (overComponent != null) {
      _toggleClass(stage, 'is-over-component', overComponent);
    }
    if (panReady != null) {
      _toggleClass(stage, 'is-pan-ready', panReady);
    }
  }

  void _toggleClass(web.Element element, String name, bool on) {
    if (on) {
      element.classList.add(name);
    } else {
      element.classList.remove(name);
    }
  }

  void _showReadout(Vec3 offset) {
    final web.Element? readout = web.document.getElementById(_readoutId);
    if (readout == null) return;
    readout.textContent = 'x ${_fmt(offset.x)}   y ${_fmt(offset.y)}   '
        'z ${_fmt(offset.z)}';
    readout.classList.add('is-visible');
  }

  void _hideReadout() {
    web.document.getElementById(_readoutId)?.classList.remove('is-visible');
  }

  /// Queued for the next frame tick rather than pushed straight into
  /// [ShellStatus]: a pointermove fires far more often than the status strip
  /// can usefully be rebuilt. Also mirrored onto the stage as data attributes
  /// so the position is inspectable without reading Dart state.
  void _setCursorReadout(WorldPoint world) {
    _pendingPointerX = world.x;
    _pendingPointerY = world.y;
    _statusDirty = true;
    _scheduleFrame();
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    stage.setAttribute('data-hui-cursor-x', _fmt(world.x));
    stage.setAttribute('data-hui-cursor-y', _fmt(world.y));
  }

  /// The cursor left the artboard: a stale coordinate reads as a live one.
  void _clearCursorReadout() {
    if (_pendingPointerX == null && _pendingPointerY == null) return;
    _pendingPointerX = null;
    _pendingPointerY = null;
    _statusDirty = true;
    _scheduleFrame();
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    stage.removeAttribute('data-hui-cursor-x');
    stage.removeAttribute('data-hui-cursor-y');
  }

  String _fmt(double value) => value.toStringAsFixed(2);
}
