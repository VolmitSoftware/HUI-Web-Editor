/// Generic drag-to-reorder list.
///
/// Pointer Events with `setPointerCapture` on the grab handle, so a drag keeps
/// tracking after the pointer leaves the row (or the panel) — the same
/// discipline as the canvas (`canvas_interactions.dart:158`), including
/// `touch-action: none` so the browser does not claim the gesture as a scroll.
///
/// Row midpoints are measured once, at pointer-down, and the drop slot is
/// recomputed from them on move; `setState` runs only when the slot actually
/// changes, so a drag costs a handful of rebuilds rather than one per frame.
/// The dragged row does not follow the pointer — an insertion line marks where
/// it will land, which needs no per-frame writes to nodes Jaspr manages.
///
/// Pointer only, deliberately: the accessible path is the caller's existing
/// up/down buttons, so the handle is hidden from assistive technology instead
/// of pretending to be a keyboard control it is not.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;
import 'package:web/web.dart' as web;

import '../common/class_names.dart';

/// The browser's primary button on `PointerEvent.button`.
const int _primaryButton = 0;

class HuiReorderList extends StatefulWidget {
  const HuiReorderList({
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    this.handleLabel = 'Drag to reorder',
    this.classes = '',
    super.key,
  });

  final int itemCount;

  /// Builds the row body. The handle is added around it.
  final Widget Function(int index) itemBuilder;

  /// Called once per completed drag that actually moves something. The indices
  /// are the arguments to `list.removeAt(from)` followed by
  /// `list.insert(to, moved)` — one mutation, so one undo step.
  final void Function(int from, int to) onReorder;

  final String handleLabel;
  final String classes;

  @override
  State<HuiReorderList> createState() => _HuiReorderListState();
}

class _HuiReorderListState extends State<HuiReorderList> {
  static int _instances = 0;

  late final String _uid = 'hui-reorder-${_instances++}';

  int? _dragIndex;

  /// Insertion slot, `0 .. itemCount`: the gap the row would drop into.
  int _slot = 0;

  /// Row centres in client pixels, captured at pointer-down. Row heights do not
  /// change during a drag because the dragged row stays where it is.
  List<double> _midpoints = const <double>[];

  int? _pointerId;

  String _handleId(int index) => '$_uid-handle-$index';

  web.Element? _handle(int index) =>
      web.document.getElementById(_handleId(index));

  /// Reads a numeric event property explicitly. Dynamic dispatch on
  /// `package:web` extension types throws under dart2js, and `clientY` is
  /// declared `int` while real pointers report fractions.
  double _eventDouble(Object? event, String property) {
    final JSObject? object = event as JSObject?;
    final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
    if (value == null || !value.isA<JSNumber>()) return 0;
    return (value as JSNumber).toDartDouble;
  }

  int _eventInt(Object? event, String property) =>
      _eventDouble(event, property).round();

  int _slotFor(double clientY) {
    int slot = 0;
    while (slot < _midpoints.length && clientY > _midpoints[slot]) {
      slot++;
    }
    return slot;
  }

  void _measure() {
    final List<double> midpoints = <double>[];
    for (int i = 0; i < component.itemCount; i++) {
      final web.Element? row =
          web.document.getElementById('$_uid-row-$i');
      if (row == null) return;
      final web.DOMRect rect = row.getBoundingClientRect();
      midpoints.add(rect.top + rect.height / 2);
    }
    _midpoints = midpoints;
  }

  void _onDown(int index, Object? event) {
    if (_eventInt(event, 'button') != _primaryButton) return;
    _measure();
    if (_midpoints.length != component.itemCount) return;
    final int pointerId = _eventInt(event, 'pointerId');
    try {
      _handle(index)?.setPointerCapture(pointerId);
    } catch (_) {
      // Capture is an enhancement; the drag still works inside the list.
    }
    _pointerId = pointerId;
    setState(() {
      _dragIndex = index;
      _slot = index;
    });
    (event as JSObject?)?.callMethod<JSAny?>('preventDefault'.toJS);
  }

  void _onMove(Object? event) {
    if (_dragIndex == null) return;
    if (_eventInt(event, 'pointerId') != _pointerId) return;
    final int slot = _slotFor(_eventDouble(event, 'clientY'));
    if (slot == _slot) return;
    setState(() => _slot = slot);
  }

  void _onUp(Object? event) {
    final int? from = _dragIndex;
    if (from == null) return;
    if (_eventInt(event, 'pointerId') != _pointerId) return;
    _release(from);
    // The slot counts gaps, so everything past the source shifts down by one
    // when the row is lifted out.
    final int to = (_slot > from ? _slot - 1 : _slot)
        .clamp(0, component.itemCount - 1);
    setState(() {
      _dragIndex = null;
      _midpoints = const <double>[];
    });
    if (to != from) component.onReorder(from, to);
  }

  void _onCancel(Object? event) {
    final int? from = _dragIndex;
    if (from == null) return;
    _release(from);
    setState(() {
      _dragIndex = null;
      _midpoints = const <double>[];
    });
  }

  void _release(int index) {
    final int? pointerId = _pointerId;
    _pointerId = null;
    if (pointerId == null) return;
    try {
      final web.Element? handle = _handle(index);
      if (handle != null && handle.hasPointerCapture(pointerId)) {
        handle.releasePointerCapture(pointerId);
      }
    } catch (_) {
      // Already released by the browser.
    }
  }

  /// The line only means something when the row would actually move: dropping
  /// into the gap either side of the source is a no-op.
  bool _showLine(int slot) {
    final int? from = _dragIndex;
    if (from == null || _slot != slot) return false;
    return slot != from && slot != from + 1;
  }

  @override
  Widget build(BuildContext context) => dom.div(
        id: _uid,
        classes: classNames(<String?>[
          'hui-reorder',
          _dragIndex != null ? 'is-dragging' : null,
          component.classes,
        ]),
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'flex-direction': 'column',
            'gap': '4px',
            'min-width': '0',
          },
        ),
        <Widget>[
          for (int i = 0; i < component.itemCount; i++) ...<Widget>[
            _line(i),
            _row(i),
          ],
          _line(component.itemCount),
        ],
      );

  Widget _line(int slot) => dom.div(
        classes: classNames(<String?>[
          'hui-reorder-line',
          _showLine(slot) ? 'is-active' : null,
        ]),
        styles: dom.Styles(
          raw: <String, String>{
            'height': '2px',
            'border-radius': '2px',
            'background': _showLine(slot) ? 'var(--primary)' : 'transparent',
          },
        ),
        const <Widget>[],
      );

  Widget _row(int index) {
    final bool dragging = _dragIndex == index;
    return dom.div(
      id: '$_uid-row-$index',
      classes: classNames(<String?>[
        'hui-reorder-row',
        dragging ? 'is-dragging' : null,
      ]),
      attributes: <String, String>{'data-hui-reorder-index': '$index'},
      styles: dom.Styles(
        raw: <String, String>{
          'display': 'grid',
          'grid-template-columns': 'auto minmax(0, 1fr)',
          'align-items': 'center',
          'gap': '6px',
          'min-width': '0',
          if (dragging) 'opacity': '0.55',
        },
      ),
      <Widget>[
        _handleWidget(index),
        dom.div(
          classes: 'hui-reorder-content',
          styles: const dom.Styles(raw: <String, String>{'min-width': '0'}),
          <Widget>[component.itemBuilder(index)],
        ),
      ],
    );
  }

  Widget _handleWidget(int index) => dom.span(
        id: _handleId(index),
        classes: 'hui-reorder-handle',
        attributes: <String, String>{
          'aria-hidden': 'true',
          'title': component.handleLabel,
        },
        styles: dom.Styles(
          raw: <String, String>{
            'display': 'inline-flex',
            'align-items': 'center',
            'justify-content': 'center',
            'flex': '0 0 auto',
            'width': '20px',
            'align-self': 'stretch',
            'color': 'var(--muted-foreground)',
            'cursor': _dragIndex == index ? 'grabbing' : 'grab',
            // Without this the browser treats the drag as a scroll and the
            // pointer stream stops mid-gesture on touch and trackpads.
            'touch-action': 'none',
          },
        ),
        events: <String, EventCallback>{
          'pointerdown': (Object? event) => _onDown(index, event),
          'pointermove': _onMove,
          'pointerup': _onUp,
          'pointercancel': _onCancel,
        },
        <Widget>[ArcaneIcon.gripVertical(size: IconSize.sm)],
      );
}
