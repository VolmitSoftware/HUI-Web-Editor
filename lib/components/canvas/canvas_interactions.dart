/// Pointer, wheel and keyboard handling for [CanvasViewport].
///
/// Pointer Events with `setPointerCapture` (report-animal 4.1) so a drag keeps
/// tracking outside the element; `touch-action: none` in the stylesheet stops
/// the browser claiming the gesture first. Every transform change commits
/// straight to the canvas and to the DOM readouts, never through `setState`.
part of 'canvas_viewport.dart';

enum _DragMode { none, pan, component, hitbox, marquee }

/// Buttons the browser reports on `PointerEvent.button`. Secondary is 2 and is
/// deliberately absent: the canvas answers it with `contextmenu` only.
const int _primaryButton = 0;
const int _middleButton = 1;

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
    final ScreenPoint local = _localPoint(
      _eventDouble(wheel, 'clientX'),
      _eventDouble(wheel, 'clientY'),
    );
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
    // Only the two buttons the canvas has a meaning for. Back/forward mice
    // report buttons 3 and 4 and used to fall through into a pan.
    if (pointer.button != _primaryButton && pointer.button != _middleButton) {
      return;
    }
    _stage?.focus();
    _lastClientX = _eventDouble(pointer, 'clientX');
    _lastClientY = _eventDouble(pointer, 'clientY');

    final bool forcePan = pointer.button == _middleButton || _spaceHeld;
    final WorldPoint world = _worldPoint(_lastClientX, _lastClientY);
    final CanvasItem? selectedHitbox = forcePan
        ? null
        : _selectedDetachedHitboxTarget(world);
    final CanvasItem? hit = forcePan
        ? null
        : selectedHitbox ?? _currentScene.hitTest(world.x, world.y);

    if (forcePan) {
      _dragMode = _DragMode.pan;
      _dragComponentId = null;
    } else if (hit == null) {
      _beginMarquee(pointer, world);
    } else if (selectedHitbox != null || _isDetachedHitboxTarget(hit, world)) {
      _beginHitboxDrag(hit, world);
    } else {
      _beginComponentDrag(pointer, hit, world);
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

  /// Left-drag on empty space. Panning moved to Space-drag and the middle
  /// button (both handled above), which is the one muscle-memory break in this
  /// wave and why the hint line leads with it.
  void _beginMarquee(web.PointerEvent pointer, WorldPoint world) {
    _dragMode = _DragMode.marquee;
    _dragComponentId = null;
    _marqueeStartX = world.x;
    _marqueeStartY = world.y;
    _marquee = marqueeRect(world.x, world.y, world.x, world.y);
    // Shift keeps what was already selected and only ever adds: a band swept
    // across a member must not silently drop it.
    _marqueeBase = pointer.shiftKey
        ? Set<String>.of(component.store.selectionIds)
        : const <String>{};
    if (!pointer.shiftKey) component.store.select(null);
    _markDirty();
  }

  void _beginComponentDrag(
    web.PointerEvent pointer,
    CanvasItem hit,
    WorldPoint world,
  ) {
    final EditorStore store = component.store;
    if (pointer.shiftKey) {
      store.toggleInSelection(hit.id);
      // A shift-click that REMOVED the component must not then drag it.
      if (!store.isSelected(hit.id)) {
        _dragMode = _DragMode.none;
        return;
      }
    } else if (store.isSelected(hit.id)) {
      // Grabbing a member of a group keeps the group and re-primaries it, so
      // the inspector follows the pointer without the group collapsing.
      store.addToSelection(hit.id);
    } else {
      store.select(hit.id);
    }

    _dragMode = _DragMode.component;
    _dragComponentId = hit.id;
    // Preserve the grab point so the component does not jump to the cursor.
    _grabOffsetX = world.x - hit.anchor.x;
    _grabOffsetY = world.y - hit.anchor.y;
    // Deferred to the first pointer move: an alt-CLICK must not leave a
    // coincident copy behind, and the copies land exactly on their sources so
    // the grab point stays valid when it does happen.
    _altDuplicatePending = pointer.altKey;
    // Opened before any mutation so the duplicate and every move that follows
    // collapse into the one undo step the gesture deserves.
    store.beginDrag();
    _captureDragStart();
    _showReadout(hit.component.offset);
  }

  CanvasItem? _selectedDetachedHitboxTarget(WorldPoint world) {
    final String? id = component.store.selectedId;
    if (id == null) return null;
    final CanvasItem? item = _currentScene.byId(id);
    return item != null && _isDetachedHitboxTarget(item, world) ? item : null;
  }

  bool _isDetachedHitboxTarget(CanvasItem item, WorldPoint world) {
    final HuiComponentData data = item.component.data;
    if (data is! HuiButtonData || data.hitbox?.anchor != HuiHitboxAnchor.menu) {
      return false;
    }
    final HuiRect box = item.hitbox;
    final double tolerance = _viewport.pixelsToBlocks(7);
    if (!box.inflate(tolerance).contains(world.x, world.y)) return false;
    if (box.contains(world.x, world.y) &&
        !item.visual.contains(world.x, world.y)) {
      return true;
    }
    final double edgeDistance = math.min(
      math.min((world.x - box.left).abs(), (world.x - box.right).abs()),
      math.min((world.y - box.bottom).abs(), (world.y - box.top).abs()),
    );
    return edgeDistance <= tolerance;
  }

  void _beginHitboxDrag(CanvasItem hit, WorldPoint world) {
    final EditorStore store = component.store;
    if (store.isSelected(hit.id)) {
      store.addToSelection(hit.id);
    } else {
      store.select(hit.id);
    }
    final HuiComponentData data = hit.component.data;
    if (data is! HuiButtonData || data.hitbox == null) return;
    _dragMode = _DragMode.hitbox;
    _dragComponentId = hit.id;
    _grabOffsetX = world.x - hit.hitbox.x;
    _grabOffsetY = world.y - hit.hitbox.y;
    _hitboxDragStart = data.hitbox!.offset.copy();
    store.beginDrag();
    _showReadout(_hitboxDragStart!);
  }

  /// Snapshots what the drag moves. Re-run after an alt-duplicate, because by
  /// then the selection is a different set of components.
  void _captureDragStart() {
    _dragStartOffsets = <String, Vec3>{
      for (final HuiComponent selected in component.store.selectedComponents)
        selected.id: selected.offset.copy(),
    };
    _dragStartBounds = outlineBounds(_currentScene, _dragStartOffsets.keys);
  }

  /// Copies the selection in place and hands the drag to the copies, so the
  /// originals never move.
  void _performAltDuplicate() {
    final EditorStore store = component.store;
    final String? grabbed = _dragComponentId;
    if (grabbed == null) return;
    final List<HuiComponent> sources = store.selectedComponents;
    final int index = sources.indexWhere((HuiComponent c) => c.id == grabbed);
    final List<String> copies = store.duplicateSelection();
    // duplicateSelection walks the document and so does selectedComponents, so
    // the two lists are index-aligned.
    if (index < 0 || copies.length != sources.length) return;
    _dragComponentId = copies[index];
    _captureDragStart();
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
      case _DragMode.hitbox:
        _dragHitboxTo(clientX, clientY);
      case _DragMode.marquee:
        _dragMarqueeTo(clientX, clientY);
    }
    _lastClientX = clientX;
    _lastClientY = clientY;
    event.preventDefault();
  }

  /// The band updates the selection live rather than only on release: sweeping
  /// with the rings appearing as you go is the whole point of a marquee.
  /// [EditorStore.selectMany] drops a write that would not change the set, so
  /// the live update costs one notification per membership change, not one per
  /// pointer frame.
  void _dragMarqueeTo(double clientX, double clientY) {
    final WorldPoint world = _worldPoint(clientX, clientY);
    _setCursorReadout(world);
    _marquee = marqueeRect(_marqueeStartX, _marqueeStartY, world.x, world.y);
    final Set<String> next = <String>{
      ..._marqueeBase,
      ...idsInMarquee(_currentScene, _marquee!),
    };
    component.store.selectMany(next);
    _markDirty();
  }

  void _dragComponentTo(double clientX, double clientY) {
    if (_altDuplicatePending) {
      _altDuplicatePending = false;
      _performAltDuplicate();
    }
    final String? id = _dragComponentId;
    final Vec3? start = _dragStartOffsets[id];
    final WorldBounds? bounds = _dragStartBounds;
    if (id == null || start == null || bounds == null) return;
    final EditorStore store = component.store;
    final CanvasScene scene = _currentScene;
    final WorldPoint world = _worldPoint(clientX, clientY);
    _setCursorReadout(world);

    // anchor = menuOffset + offset * uiScale, so invert exactly that. The scale
    // and offset come from the scene rather than the store so the inversion can
    // never disagree with the geometry the guides were measured against.
    final double scale = scene.uiScale > 0 ? scene.uiScale : 1;
    final double rawX = (world.x - _grabOffsetX - scene.menuOffset.x) / scale;
    final double rawY = (world.y - _grabOffsetY - scene.menuOffset.y) / scale;

    final GroupDrag drag = resolveGroupDrag(
      scene: scene,
      startOffsets: _dragStartOffsets,
      startBounds: bounds,
      grabbedId: id,
      // Snap the grabbed component only; the rest follow its snapped delta, so
      // the group can never be torn apart by the grid.
      grabbedTarget: Vec3(
        store.snapValue(rawX),
        store.snapValue(rawY),
        start.z,
      ),
      guideThresholdBlocks: _viewport.pixelsToBlocks(huiGuideCatchPx),
    );
    if (drag.offsets.isEmpty) return;

    if (!_sameGuides(_guides, drag.guides)) {
      _guides = drag.guides;
      _markDirty();
    }
    if (!_offsetsChanged(store, drag.offsets)) return;
    store.setOffsets(
      drag.offsets.length == 1
          ? 'move $id'
          : 'move ${drag.offsets.length} components',
      drag.offsets,
    );
    final Vec3? landed = drag.offsets[id];
    if (landed != null) _showReadout(landed);
  }

  void _dragHitboxTo(double clientX, double clientY) {
    final String? id = _dragComponentId;
    final Vec3? start = _hitboxDragStart;
    if (id == null || start == null) return;
    final EditorStore store = component.store;
    final CanvasScene scene = _currentScene;
    final WorldPoint world = _worldPoint(clientX, clientY);
    _setCursorReadout(world);
    final double scale = scene.uiScale > 0 ? scene.uiScale : 1;
    final Vec3 offset = Vec3(
      store.snapValue((world.x - _grabOffsetX - scene.menuOffset.x) / scale),
      store.snapValue((world.y - _grabOffsetY - scene.menuOffset.y) / scale),
      start.z,
    );
    final HuiComponentData? data = store.menu.componentById(id)?.data;
    if (data is HuiButtonData && data.hitbox?.offset == offset) return;
    store.setHitboxOffset(id, offset);
    _showReadout(offset);
  }

  /// True when at least one member would actually move. A pointer frame that
  /// lands on the same snapped cell must not notify the store, or every
  /// listener in the shell rebuilds sixty times a second for nothing.
  bool _offsetsChanged(EditorStore store, Map<String, Vec3> offsets) {
    for (final MapEntry<String, Vec3> entry in offsets.entries) {
      if (store.menu.componentById(entry.key)?.offset != entry.value) {
        return true;
      }
    }
    return false;
  }

  /// Guides are compared by what gets drawn, not by identity: a fresh list with
  /// the same lines every frame would repaint the canvas for nothing.
  bool _sameGuides(List<AlignmentGuide> a, List<AlignmentGuide> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].axis != b[i].axis ||
          a[i].match != b[i].match ||
          a[i].position != b[i].position ||
          a[i].start != b[i].start ||
          a[i].end != b[i].end) {
        return false;
      }
    }
    return true;
  }

  void _handlePointerUp(web.Event event) {
    if (!event.isA<web.PointerEvent>()) return;
    final web.PointerEvent pointer = event as web.PointerEvent;
    if (_activePointerId != pointer.pointerId) return;
    if (_dragMode == _DragMode.component || _dragMode == _DragMode.hitbox) {
      component.store.endDrag();
    }
    _activePointerId = null;
    _dragMode = _DragMode.none;
    _dragComponentId = null;
    _altDuplicatePending = false;
    _dragStartOffsets = const <String, Vec3>{};
    _hitboxDragStart = null;
    _dragStartBounds = null;
    _marqueeBase = const <String>{};
    _marquee = null;
    _guides = const <AlignmentGuide>[];
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
    final WorldPoint world = _worldPoint(
      _eventDouble(mouse, 'clientX'),
      _eventDouble(mouse, 'clientY'),
    );
    final CanvasItem? hit = _currentScene.hitTest(world.x, world.y);
    if (hit == null) return;
    event.preventDefault();
    // Re-primary rather than replace when it is already a member: double-click
    // means "edit this one", not "throw away the group I just built".
    if (component.store.isSelected(hit.id)) {
      component.store.addToSelection(hit.id);
    } else {
      component.store.select(hit.id);
    }
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
      // Stepped zoom commits immediately: key repeat fires ~30x/s and would
      // restart the ease every frame, so the camera would never arrive.
      case '+':
      case '=':
        _zoomFromCenter(huiZoomStep);
      case '-':
      case '_':
        _zoomFromCenter(1 / huiZoomStep);
      // Reset and fit are single, large, non-repeating moves — the same ones
      // the toolbar buttons ease (canvas_viewport.dart:303-304).
      case '0':
        _easeThrough(_resetView);
      case 'f':
      case 'F':
        _easeThrough(_fitToContent);
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
    // One store path for every count, so the canvas, the rail and the shell
    // agree: removal is by INDEX, and a duplicated id keeps its namesake. The
    // `removeWhere` this replaced took both rows.
    component.store.deleteComponents(
      component.store.selectionIds.toList(growable: false),
    );
  }

  /// Arrows move the whole selection, in one undo step.
  void _nudge(int dx, int dy, bool coarse) {
    final EditorStore store = component.store;
    final List<HuiComponent> selected = store.selectedComponents;
    if (selected.isEmpty) return;
    final double step = coarse ? huiNudgeStepLarge : huiNudgeStep;
    final Map<String, Vec3> moved = shiftOffsets(
      offsets: <String, Vec3>{
        for (final HuiComponent c in selected) c.id: c.offset,
      },
      dx: dx * step,
      dy: dy * step,
    );
    store.setOffsets(
      moved.length == 1
          ? 'nudge ${selected.first.id}'
          : 'nudge ${moved.length} components',
      moved,
    );
  }

  /// Toolbar restack. [zOrderOffsets] does the sign work — larger `z` paints
  /// first, so "forward" subtracts.
  void _applyZOrder(HuiZOrder op) {
    final EditorStore store = component.store;
    final Map<String, Vec3> next = zOrderOffsets(
      items: _currentScene.items,
      ids: store.selectionIds,
      op: op,
      step: huiDepthStep,
    );
    if (next.isEmpty) return;
    store.setOffsets(huiZOrderLabels[op]!, next);
  }

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

  void _setStageState({bool? dragging, bool? overComponent, bool? panReady}) {
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    if (dragging != null) {
      _toggleClass(stage, 'is-dragging', dragging);
      _toggleClass(
        stage,
        'is-moving-component',
        dragging && _dragMode == _DragMode.component,
      );
      _toggleClass(
        stage,
        'is-marqueeing',
        dragging && _dragMode == _DragMode.marquee,
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
    readout.textContent =
        'x ${_fmt(offset.x)}   y ${_fmt(offset.y)}   '
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
