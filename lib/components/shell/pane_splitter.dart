/// The drag handle between a pane and the canvas.
///
/// Renders a `role="separator"` grab strip and owns the resize gesture. A drag
/// writes the pane's CSS custom property directly (see [writePaneVariable]) and
/// only calls [PaneSplitter.onCommit] when the pointer is released, so moving a
/// splitter never rebuilds the editor. Double-click resets the pane; arrow keys
/// resize it in 8px steps (40px with Shift), Home/End jump to the range ends.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import 'pane_dom.dart';
import 'pane_layout.dart';

class PaneSplitter extends StatefulWidget {
  const PaneSplitter({
    required this.side,
    required this.layout,
    required this.onCommit,
    super.key,
  });

  final PaneSide side;

  /// The committed layout. During a drag the live value lives in the DOM.
  final PaneLayout layout;

  /// Called once per settled gesture: drag release, double-click or key press.
  final void Function(PaneLayout layout) onCommit;

  String get handleId => side == PaneSide.rail
      ? 'hui-splitter-rail'
      : 'hui-splitter-inspector';

  String get label => side == PaneSide.rail
      ? 'Resize the components rail'
      : 'Resize the inspector';

  @override
  State<PaneSplitter> createState() => _PaneSplitterState();
}

class _PaneSplitterState extends State<PaneSplitter> {
  void Function()? _uninstall;

  /// Non-null only between pointerdown and pointerup. The committed
  /// [PaneSplitter.layout] is stale for that window, so every gesture step
  /// reads from here instead.
  PaneLayout? _drag;

  bool _installPending = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _uninstall?.call();
    _uninstall = null;
    super.dispose();
  }

  PaneLayout get _current => _drag ?? component.layout;

  /// The handle only exists after the first paint, so the listeners are wired
  /// from a post-frame callback rather than from [initState].
  void _scheduleInstall() {
    if (_installPending || _disposed || _uninstall != null) return;
    _installPending = true;
    context.binding.addPostFrameCallback(() {
      _installPending = false;
      if (_disposed || _uninstall != null) return;
      _uninstall = installPaneSplitter(
        handleId: component.handleId,
        onDragMove: _onDragMove,
        onDragEnd: _onDragEnd,
        onReset: _onReset,
        onKey: _onKey,
      );
    });
  }

  void _onDragMove(double edgeX) {
    final double viewport = paneViewportWidth();
    final double raw = PaneLayout.widthForEdge(
      component.side,
      edgeX,
      viewport,
    );
    final PaneLayout next =
        _current.withWidth(component.side, raw, viewportWidth: viewport);
    _drag = next;
    _paint(next);
  }

  void _onDragEnd() {
    final PaneLayout? dragged = _drag;
    _drag = null;
    if (dragged == null || dragged == component.layout) return;
    component.onCommit(dragged);
  }

  void _onReset() {
    final PaneLayout next = _current.resetSide(component.side);
    _drag = null;
    _paint(next);
    if (next == component.layout) return;
    component.onCommit(next);
  }

  void _onKey(String key, bool shift) {
    final double viewport = paneViewportWidth();
    final PaneSide side = component.side;
    final double step =
        shift ? PaneLayout.keyStepCoarse : PaneLayout.keyStep;
    // The rail grows rightwards, the inspector leftwards: both handles move
    // the way the arrow points.
    final double grow = side == PaneSide.rail ? step : -step;
    final PaneLayout base = _current;
    final PaneLayout next = switch (key) {
      'ArrowRight' => base.nudged(side, grow, viewportWidth: viewport),
      'ArrowLeft' => base.nudged(side, -grow, viewportWidth: viewport),
      'Home' => base.withWidth(
          side,
          PaneLayout.minOf(side),
          viewportWidth: viewport,
        ),
      'End' => base.withWidth(
          side,
          PaneLayout.maxOf(side),
          viewportWidth: viewport,
        ),
      _ => base,
    };
    if (next == base) return;
    _drag = null;
    _paint(next);
    component.onCommit(next);
  }

  /// Commits the width to the DOM without touching widget state.
  void _paint(PaneLayout layout) {
    final double width = layout.widthOf(component.side);
    writePaneVariable(PaneLayout.variableOf(component.side), width);
    writePaneAria(component.handleId, width);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleInstall();
    final PaneSide side = component.side;
    final double width = component.layout.widthOf(side);
    return dom.div(
      id: component.handleId,
      classes: 'hui-splitter',
      attributes: <String, String>{
        'role': 'separator',
        'aria-orientation': 'vertical',
        'aria-label': component.label,
        'aria-valuemin': PaneLayout.minOf(side).round().toString(),
        'aria-valuemax': PaneLayout.maxOf(side).round().toString(),
        'aria-valuenow': width.round().toString(),
        'aria-valuetext': '${width.round()} pixels',
        'tabindex': '0',
      },
      const <Widget>[
        dom.span(
          classes: 'hui-splitter-grip',
          attributes: <String, String>{'aria-hidden': 'true'},
          <Widget>[],
        ),
      ],
    );
  }
}
