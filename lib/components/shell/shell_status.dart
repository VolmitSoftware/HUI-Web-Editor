/// Transient readouts the status bar shows but the document does not own.
///
/// Pointer position, zoom and the contextual hint belong to whatever is drawing
/// the centre pane, not to the menu, so they are kept out of [EditorStore] and
/// pushed here instead. Values are deliberately nullable: "no reading" is a
/// real state, rendered as a dash.
library;

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

class ShellStatus extends ChangeNotifier {
  double _zoom = 1;
  double? _pointerX;
  double? _pointerY;
  String? _hint;

  double get zoom => _zoom;

  /// Block-space pointer coordinates, x right-positive and y up-positive.
  double? get pointerX => _pointerX;

  double? get pointerY => _pointerY;

  bool get hasPointer => _pointerX != null && _pointerY != null;

  /// One-line affordance text ("Scroll to zoom, drag to pan").
  String? get hint => _hint;

  void setZoom(double value) {
    if (!value.isFinite || value == _zoom) return;
    _zoom = value;
    notifyListeners();
  }

  void setPointer(double? x, double? y) {
    final double? nextX = x != null && x.isFinite ? x : null;
    final double? nextY = y != null && y.isFinite ? y : null;
    if (nextX == _pointerX && nextY == _pointerY) return;
    _pointerX = nextX;
    _pointerY = nextY;
    notifyListeners();
  }

  void clearPointer() => setPointer(null, null);

  void setHint(String? value) {
    final String? next = value == null || value.isEmpty ? null : value;
    if (next == _hint) return;
    _hint = next;
    notifyListeners();
  }
}
