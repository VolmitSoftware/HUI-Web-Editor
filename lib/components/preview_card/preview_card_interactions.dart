/// Pointer, wheel and keyboard handling for [PreviewCardViewport].
///
/// Pointer Events with `setPointerCapture` so a drag keeps tracking outside the
/// element; `touch-action: none` in the stylesheet stops the browser claiming
/// the gesture first. Every transform change commits straight to the canvas and
/// to the DOM readouts, never through `setState`.
///
/// Every write goes through `EditorStore.editPreviewElement`, which is the
/// document's single undoable write path, and every gesture is wrapped in
/// `beginDrag`/`endDrag` so it collapses into one history entry.
part of 'preview_card_viewport.dart';

enum _PreviewDragMode { none, pan, element, resize }

/// Buttons the browser reports on `PointerEvent.button`. Secondary is 2 and is
/// deliberately absent: the surface answers it with `contextmenu` only.
const int _primaryButton = 0;
const int _middleButton = 1;

/// How far outside a grip still counts as grabbing it.
const double _handleGrabSlackPx = 3;

/// Reads a numeric event property without trusting package:web's `int` typing.
///
/// Real pointers report fractional `clientX`/`clientY` and the typed
/// `MouseEvent.clientX` getter is declared `int`, so reading `1094.8` through it
/// throws under both DDC and dart2js.
double _eventDouble(web.Event event, String property) {
  final JSAny? value = (event as JSObject).getProperty<JSAny?>(property.toJS);
  if (value == null || !value.isA<JSNumber>()) return 0;
  return (value as JSNumber).toDartDouble;
}

extension _PreviewCardInteractions on _PreviewCardViewportState {
  // --- transform commits ----------------------------------------------------

  void _commitView(PreviewCardView next) {
    _view = next;
    _syncZoomReadout();
    _statusDirty = true;
    _markDirty();
  }

  void _syncZoomReadout() {
    web.document.getElementById(_zoomLabelId)?.textContent = _zoomLabelText;
  }

  void _resetView() => _commitView(_view.reset());

  void _fitToContent() {
    if (!_view.hasArea) return;
    _commitView(
      _view.fittedTo(
        previewSceneBounds(_currentScene, labelWidths: _labelWidths),
        paddingPx: 32,
      ),
    );
  }

  // --- coordinate helpers ---------------------------------------------------

  /// Canvas-local CSS pixels for a pointer or wheel event.
  ({double x, double y}) _localPoint(double clientX, double clientY) {
    final web.HTMLCanvasElement? canvas = _canvas;
    if (canvas == null) return (x: 0, y: 0);
    final web.DOMRect rect = canvas.getBoundingClientRect();
    return (x: clientX - rect.x, y: clientY - rect.y);
  }

  ({double x, double y}) _cardPoint(double clientX, double clientY) {
    final ({double x, double y}) local = _localPoint(clientX, clientY);
    return (x: _view.toCardX(local.x), y: _view.toCardY(local.y));
  }

  // --- wheel ----------------------------------------------------------------

  /// One notch is one zoom stop. The card is authored in whole pixels, so a
  /// continuous zoom would only ever land between two honest scales.
  void _handleWheel(web.Event event) {
    if (!event.isA<web.WheelEvent>()) return;
    final web.WheelEvent wheel = event as web.WheelEvent;
    wheel.preventDefault();
    final double delta = _eventDouble(wheel, 'deltaY');
    if (delta == 0) return;
    final int next = delta < 0
        ? previewZoomIn(_view.zoom)
        : previewZoomOut(_view.zoom);
    if (next == _view.zoom) return;
    final ({double x, double y}) local = _localPoint(
      _eventDouble(wheel, 'clientX'),
      _eventDouble(wheel, 'clientY'),
    );
    _commitView(_view.zoomedAt(next, screenX: local.x, screenY: local.y));
  }

  // --- pointer --------------------------------------------------------------

  void _handlePointerDown(web.Event event) {
    if (!event.isA<web.PointerEvent>()) return;
    final web.PointerEvent pointer = event as web.PointerEvent;
    // Only the two buttons this surface has a meaning for. Back/forward mice
    // report 3 and 4 and must not fall through into a pan.
    if (pointer.button != _primaryButton && pointer.button != _middleButton) {
      return;
    }
    _stage?.focus();
    _setHint(null);
    _lastClientX = _eventDouble(pointer, 'clientX');
    _lastClientY = _eventDouble(pointer, 'clientY');
    final bool forcePan = pointer.button == _middleButton || _spaceHeld;

    if (forcePan) {
      _dragMode = _PreviewDragMode.pan;
      _dragElement = null;
    } else {
      final ({double x, double y}) local = _localPoint(
        _lastClientX,
        _lastClientY,
      );
      final ({double x, double y}) card = (
        x: _view.toCardX(local.x),
        y: _view.toCardY(local.y),
      );
      final PreviewCardScene scene = _currentScene;
      final PreviewHandle? handle = _handleAt(scene, local.x, local.y);
      if (handle != null) {
        _beginResize(scene, handle);
      } else {
        _beginSelectOrDrag(scene, card.x, card.y);
      }
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

  /// Click selects the topmost element under the pointer and, unless its
  /// position is expression-driven, starts moving it.
  void _beginSelectOrDrag(PreviewCardScene scene, double cardX, double cardY) {
    final EditorStore store = component.store;
    final int? item = previewHitTestItem(
      scene,
      cardX,
      cardY,
      labelWidths: _labelWidths,
    );
    final int element = item == null ? -1 : previewElementIndexOf(scene, item);
    if (element < 0) {
      store.selectPreviewElement(null);
      _dragMode = _PreviewDragMode.none;
      _dragElement = null;
      return;
    }
    store.selectPreviewElement(element);
    // Read back through the document rather than through the selection: a
    // rejected index would otherwise leave the PREVIOUS selection here and
    // hand the drag an element nobody clicked.
    final HuiPreviewElement? template = _elementAt(element);
    if (template == null) return;
    final String? refusal = previewMoveRefusal(template);
    if (refusal != null) {
      // Selected, but not moved: the author still needs the inspector open on
      // the element they just clicked.
      _setHint(refusal);
      _dragMode = _PreviewDragMode.none;
      _dragElement = null;
      return;
    }
    _dragMode = _PreviewDragMode.element;
    _dragElement = element;
    _dragStartPoint = PreviewPoint(
      previewConstantInt(template.x),
      previewConstantInt(template.y),
    );
    _grabCardX = cardX;
    _grabCardY = cardY;
    // Opened before the first write so every frame of the gesture collapses
    // into the one undo step it deserves.
    store.beginDrag();
    _showReadout(_dragStartPoint);
  }

  void _beginResize(PreviewCardScene scene, PreviewHandle handle) {
    final EditorStore store = component.store;
    final int? element = store.previewSelectedIndex;
    if (element == null) return;
    final List<int> items = previewItemsForElement(scene, element);
    if (items.isEmpty) return;
    _dragMode = _PreviewDragMode.resize;
    _dragElement = element;
    _dragHandle = handle;
    // The box as it was at pointer-down: the opposite corner is pinned to it
    // for the whole gesture, so the element cannot walk away from the pointer.
    _dragStartBox = _itemBox(scene, items.first);
    store.beginDrag();
  }

  /// Which grip is under a screen point, or null.
  PreviewHandle? _handleAt(
    PreviewCardScene scene,
    double screenX,
    double screenY,
  ) {
    const double slack = previewHandleRadiusPx + _handleGrabSlackPx;
    for (final PreviewHandleSpot spot in _handleSpots(scene)) {
      if ((_view.toScreenX(spot.x) - screenX).abs() <= slack &&
          (_view.toScreenY(spot.y) - screenY).abs() <= slack) {
        return spot.handle;
      }
    }
    return null;
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
      case _PreviewDragMode.none:
        break;
      case _PreviewDragMode.pan:
        _commitView(
          _view.pannedBy(clientX - _lastClientX, clientY - _lastClientY),
        );
      case _PreviewDragMode.element:
        _dragElementTo(clientX, clientY);
      case _PreviewDragMode.resize:
        _resizeTo(clientX, clientY);
    }
    _lastClientX = clientX;
    _lastClientY = clientY;
    event.preventDefault();
  }

  void _dragElementTo(double clientX, double clientY) {
    final int? index = _dragElement;
    if (index == null) return;
    final EditorStore store = component.store;
    final HuiPreviewElement? element = _elementAt(index);
    if (element == null) return;
    final ({double x, double y}) card = _cardPoint(clientX, clientY);
    final PreviewPoint target = previewMoveFrom(
      _dragStartPoint,
      dxCard: card.x - _grabCardX,
      dyCard: card.y - _grabCardY,
    );
    // A pointer frame that lands on the same whole pixel must not notify the
    // store, or every listener in the shell rebuilds sixty times a second.
    if (previewConstantInt(element.x) == target.x &&
        previewConstantInt(element.y) == target.y) {
      return;
    }
    store.editPreviewElement(index, 'move element', (HuiPreviewElement edited) {
      edited.x = target.x;
      edited.y = target.y;
    });
    _showReadout(target);
  }

  void _resizeTo(double clientX, double clientY) {
    final int? index = _dragElement;
    final PreviewHandle? handle = _dragHandle;
    final PreviewBox? box = _dragStartBox;
    if (index == null || handle == null || box == null) return;
    final HuiPreviewElement? element = _elementAt(index);
    if (element == null) return;
    final ({double x, double y}) card = _cardPoint(clientX, clientY);
    final PreviewResize? next = previewResizeTarget(
      element: element,
      box: box,
      handle: handle,
      cardX: card.x,
      cardY: card.y,
    );
    if (next == null) return;
    if (previewConstantInt(element.x) == next.x &&
        previewConstantInt(element.y) == next.y &&
        previewConstantInt(element.size, fallback: -1) == (next.size ?? -1) &&
        previewConstantInt(element.width, fallback: -1) == (next.width ?? -1) &&
        previewConstantInt(element.height, fallback: -1) ==
            (next.height ?? -1)) {
      return;
    }
    component.store.editPreviewElement(index, 'resize element', (
      HuiPreviewElement edited,
    ) {
      edited.x = next.x;
      edited.y = next.y;
      if (next.width != null) edited.width = next.width;
      if (next.height != null) edited.height = next.height;
      if (next.size != null) edited.size = next.size;
    });
    _showReadout(PreviewPoint(next.x, next.y), size: next);
  }

  HuiPreviewElement? _elementAt(int index) {
    final HuiPreviewDoc? doc = component.store.previewDoc;
    if (doc == null || index < 0 || index >= doc.elements.length) return null;
    return doc.elements[index];
  }

  void _handlePointerUp(web.Event event) {
    if (!event.isA<web.PointerEvent>()) return;
    final web.PointerEvent pointer = event as web.PointerEvent;
    if (_activePointerId != pointer.pointerId) return;
    if (_dragMode == _PreviewDragMode.element ||
        _dragMode == _PreviewDragMode.resize) {
      component.store.endDrag();
    }
    _activePointerId = null;
    _dragMode = _PreviewDragMode.none;
    _dragElement = null;
    _dragHandle = null;
    _dragStartBox = null;
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
    if (_hoveredItem == null) return;
    _hoveredItem = null;
    _setStageState(overElement: false);
    _markDirty();
  }

  void _updateHover(double clientX, double clientY) {
    final ({double x, double y}) card = _cardPoint(clientX, clientY);
    final int? item = previewHitTestItem(
      _currentScene,
      card.x,
      card.y,
      labelWidths: _labelWidths,
    );
    if (item == _hoveredItem) return;
    _hoveredItem = item;
    _setStageState(overElement: item != null);
    _markDirty();
  }

  void _handleContextMenu(web.Event event) => event.preventDefault();

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
        component.store.selectPreviewElement(null);
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
        _commitView(_view.zoomedAtCenter(previewZoomIn(_view.zoom)));
      case '-':
      case '_':
        _commitView(_view.zoomedAtCenter(previewZoomOut(_view.zoom)));
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
    // these shortcuts from firing twice.
    key.stopPropagation();
  }

  /// Arrows move the selected element by whole pixels; shift jumps by a well.
  void _nudge(int dx, int dy, bool coarse) {
    final EditorStore store = component.store;
    final int? index = store.previewSelectedIndex;
    final HuiPreviewElement? element = store.previewSelectedElement;
    if (index == null || element == null) return;
    final String? refusal = previewMoveRefusal(element);
    if (refusal != null) {
      _setHint(refusal);
      return;
    }
    final int step = coarse ? huiPreviewNudgeStepLarge : huiPreviewNudgeStep;
    final PreviewPoint target = previewMoveTarget(
      element,
      dxCard: (dx * step).toDouble(),
      dyCard: (dy * step).toDouble(),
    );
    store.editPreviewElement(index, 'move element', (HuiPreviewElement edited) {
      edited.x = target.x;
      edited.y = target.y;
    });
  }

  /// True when a form control owns the keyboard, so these shortcuts stay out of
  /// the way of inline editing anywhere in the shell.
  bool _isTextEntryFocused() {
    final web.Element? active = web.document.activeElement;
    if (active == null) return false;
    final String tag = active.tagName.toLowerCase();
    if (tag == 'input' || tag == 'textarea' || tag == 'select') return true;
    return active.getAttribute('contenteditable') == 'true';
  }

  // --- DOM readouts ---------------------------------------------------------

  void _setHint(String? value) {
    if (_hint == value) return;
    _hint = value;
    _statusDirty = true;
    _scheduleFrame();
  }

  void _setStageState({bool? dragging, bool? overElement, bool? panReady}) {
    final web.HTMLElement? stage = _stage;
    if (stage == null) return;
    if (dragging != null) {
      _toggleClass(stage, 'is-dragging', dragging);
      _toggleClass(
        stage,
        'is-moving-component',
        dragging && _dragMode == _PreviewDragMode.element,
      );
    }
    if (overElement != null) {
      _toggleClass(stage, 'is-over-component', overElement);
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

  void _showReadout(PreviewPoint point, {PreviewResize? size}) {
    final web.Element? readout = web.document.getElementById(_readoutId);
    if (readout == null) return;
    final StringBuffer text = StringBuffer('x ${point.x}   y ${point.y}');
    if (size?.size != null) {
      text.write('   size ${size!.size}');
    } else if (size?.width != null) {
      text.write('   ${size!.width} x ${size.height}');
    }
    readout.textContent = text.toString();
    readout.classList.add('is-visible');
  }

  void _hideReadout() {
    web.document.getElementById(_readoutId)?.classList.remove('is-visible');
  }
}
