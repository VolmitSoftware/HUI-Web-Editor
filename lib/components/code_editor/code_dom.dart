/// The one DOM read the code view cannot express through jaspr props.
///
/// Conditionally imported so `package:web` never enters a file that
/// jaspr_builder analyses for styles off-web (the same pattern the inspector
/// uses for its own bridge).
///
/// The highlight layer sits behind the textarea and has to follow its scroll
/// exactly; a textarea's scroll position is not observable any other way.
library;

export 'code_dom_stub.dart' if (dart.library.js_interop) 'code_dom_web.dart';
