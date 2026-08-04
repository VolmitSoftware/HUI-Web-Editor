/// Document-level keydown plumbing.
///
/// Conditionally imported so the widget that uses it stays free of
/// `package:web`, which jaspr_builder's off-web style analysis cannot load.
///
/// ```dart
/// final void Function() uninstall = installShellKeyListener(_onKey);
/// ```
library;

export 'key_listener_stub.dart'
    if (dart.library.js_interop) 'key_listener_web.dart';
