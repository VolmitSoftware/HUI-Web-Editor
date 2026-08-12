/// Splitter DOM plumbing: pointer capture, the live CSS custom property write
/// and the viewport measurement the clamps need.
///
/// Conditionally exported so the widget that uses it stays free of
/// `package:web`, which jaspr_builder's off-web style analysis cannot load.
///
/// ```dart
/// final void Function() uninstall = installPaneSplitter(
///   handleId: 'hui-splitter-rail',
///   onDragMove: (double edgeX) { ... },
///   onDragEnd: () { ... },
///   onReset: () { ... },
///   onKey: (String key, bool shift) { ... },
/// );
/// ```
library;

export 'pane_dom_stub.dart' if (dart.library.js_interop) 'pane_dom_web.dart';
