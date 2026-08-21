/// The DOM reads the code view cannot express through jaspr props.
///
/// Conditionally imported so `package:web` never enters a file jaspr_builder
/// analyses for styles off-web — the same arrangement
/// `inspector/dom_bridge.dart` uses, and this file deliberately does not
/// duplicate that one: `readTextSelection` and `writeTextValue` are imported
/// from there rather than re-declared here.
///
/// Why each one exists:
/// * `huiCodeRect` — the highlight layer's viewport box, which turns the
///   pre-relative hover boxes into the fixed coordinates a tooltip needs, and
///   the measuring probe's box, which gives the caret popup its cell size.
/// * `huiCodeKeyBoxes` — the measured box of every key span, harvested once per
///   document so a mousemove costs one comparison loop and no layout.
/// * `huiCodePointerPoint` / `huiCodeModifiers` — the two event reads jaspr
///   hands over as an untyped `Object?`.
library;

export 'code_dom_stub.dart'
    if (dart.library.js_interop) 'code_dom_web.dart';
