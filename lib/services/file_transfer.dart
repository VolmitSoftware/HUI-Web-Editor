/// Browser file in/out: Blob downloads, a JSON file picker, and a document-wide
/// drag-and-drop hookup.
///
/// The implementation is conditionally imported so styled component files can
/// depend on this API without dragging `package:web` into jaspr_builder's
/// off-web style analysis.
///
/// ```dart
/// downloadText('shop.json', json);
/// final (String, String)? picked = await pickJsonFile();
/// final void Function() uninstall = installDropHandler(
///   onJson: (String name, String content) {},
///   onImages: (List<Object> files) {},
/// );
/// ```
library;

export 'file_transfer_stub.dart'
    if (dart.library.js_interop) 'file_transfer_web.dart';
