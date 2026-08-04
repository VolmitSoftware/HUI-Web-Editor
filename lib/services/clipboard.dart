/// Clipboard read/write that never throws.
///
/// `navigator.clipboard` only exists in secure contexts, so an editor served
/// over plain HTTP (an Undertow instance on a LAN address) falls back to the
/// legacy `execCommand('copy')` path. Both entry points report success instead of
/// throwing so the UI can toast the failure.
library;

export 'clipboard_stub.dart' if (dart.library.js_interop) 'clipboard_web.dart';
