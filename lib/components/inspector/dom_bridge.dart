/// The three DOM reads the inspector cannot express through jaspr props.
///
/// Conditionally imported so `package:web` never enters a file that
/// jaspr_builder analyses for styles off-web.
///
/// Why each one exists:
/// * `readTextSelection` / `writeTextValue` — the tag palette and the colour
///   picker splice text at the caret. jaspr renders a textarea's value as a
///   child text node, which only feeds `defaultValue`: once the user has typed,
///   the browser stops mirroring it, so a programmatic edit has to write the
///   `value` property and restore the caret itself.
/// * `readInputFiles` — the image upload control needs the `File` objects off a
///   file input to hand to `ImageLibrary.addFromFiles`.
library;

export 'dom_bridge_stub.dart'
    if (dart.library.js_interop) 'dom_bridge_web.dart';
