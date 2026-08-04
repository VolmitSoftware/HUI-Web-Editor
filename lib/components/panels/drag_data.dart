/// The two `DataTransfer` calls the rail's drag-to-reorder needs.
///
/// Firefox refuses to start a drag unless `setData` is called in `dragstart`,
/// and the cursor only shows a move affordance when `dropEffect` is set in
/// `dragover`. Both live behind a conditional import so the rail itself never
/// touches `package:web`.
library;

export 'drag_data_stub.dart'
    if (dart.library.js_interop) 'drag_data_web.dart';
