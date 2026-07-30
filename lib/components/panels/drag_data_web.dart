/// Browser backend for `drag_data.dart`.
library;

import 'package:web/web.dart' as web;

void setDragPayload(Object? event, String value) {
  try {
    final web.DataTransfer? transfer = (event as web.DragEvent).dataTransfer;
    if (transfer == null) return;
    transfer.effectAllowed = 'move';
    transfer.setData('text/plain', value);
  } catch (_) {
    // Not a drag event, or the browser refused the payload; the up/down
    // buttons and the context menu still reorder.
  }
}

void setDropEffectMove(Object? event) {
  try {
    (event as web.DragEvent).dataTransfer?.dropEffect = 'move';
  } catch (_) {}
}
