/// Off-web no-op backend for `code_dom.dart`.
library;

({double left, double top, double width, double height})? huiCodeRect(
  String elementId,
) => null;

List<double> huiCodeKeyBoxes(String preId) => const <double>[];

({double x, double y}) huiCodePointerPoint(Object? event) => (x: 0, y: 0);

({bool ctrl, bool meta, bool shift, bool alt}) huiCodeModifiers(
  Object? event,
) => (ctrl: false, meta: false, shift: false, alt: false);
