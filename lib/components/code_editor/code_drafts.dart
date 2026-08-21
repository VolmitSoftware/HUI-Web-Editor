/// Unsaved code text, parked per document.
///
/// The code pane is unmounted whenever the view leaves Code or Split
/// (`editor_shell.dart` does that on purpose — a live pane re-serializes the
/// document on every store notification), and the store swaps the document out
/// from under it when the user opens another one. Both would throw away a dirty
/// buffer without this.
///
/// So nothing is ever discarded silently: on unmount and on a document switch
/// the dirty text is parked here under the workspace document's id, and the
/// pane picks it back up the next time that document is the one on screen. A
/// draft is dropped only when the user acts — a successful save, or the Revert
/// button — which are the two moments they have said the text is finished with.
///
/// Memory is bounded by the workspace: one entry per document that has been
/// edited and not saved, holding text the user typed. Clearing the workspace
/// does not reach in here, which is fine — [park] overwrites and [drop]
/// removes, so a stale entry can only ever be re-offered for a document id
/// that still exists.
library;

class HuiCodeDrafts {
  HuiCodeDrafts();

  /// The pane's own store. Tests build their own instead of reaching for this.
  static final HuiCodeDrafts shared = HuiCodeDrafts();

  final Map<String, String> _byDocument = <String, String>{};

  /// Parks [text] for [documentId]. An empty id is ignored: a pane with no
  /// active document has nothing to come back to.
  void park(String documentId, String text) {
    if (documentId.isEmpty) return;
    _byDocument[documentId] = text;
  }

  /// The parked text for [documentId], or null.
  String? peek(String documentId) => _byDocument[documentId];

  /// Forgets [documentId]'s draft.
  void drop(String documentId) {
    _byDocument.remove(documentId);
  }

  /// True when [documentId] has text waiting.
  bool has(String documentId) => _byDocument.containsKey(documentId);

  int get length => _byDocument.length;
}
