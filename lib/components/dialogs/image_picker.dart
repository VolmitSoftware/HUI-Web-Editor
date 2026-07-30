/// Click-to-upload image picker.
///
/// `file_transfer.dart` covers JSON picking and document-wide drag-and-drop, but
/// the image manager also needs a multi-select image chooser. The browser
/// implementation lives behind a conditional import so `package:web` never
/// reaches Jaspr's off-web style analysis.
library;

export 'image_picker_stub.dart'
    if (dart.library.js_interop) 'image_picker_web.dart';
