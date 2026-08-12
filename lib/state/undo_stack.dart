/// Snapshot-based undo/redo history for the editor document.
///
/// Entries hold the encoded JSON of the whole menu rather than a diff: the
/// documents are a few kilobytes at most, and a full snapshot makes every
/// mutation path (canvas drag, inspector edit, code edit, import) share one
/// trivially correct implementation.
library;

/// One reversible step. [snapshot] is the document as it was *before* the
/// mutation named by [label], so undoing it means restoring [snapshot].
class UndoEntry {
  const UndoEntry({required this.label, required this.snapshot});

  final String label;
  final String snapshot;

  @override
  String toString() => 'UndoEntry($label)';
}

class UndoStack {
  UndoStack({int capacity = defaultCapacity})
    : capacity = capacity < 1 ? 1 : capacity;

  /// Roughly a session's worth of edits; each entry is a whole document, so the
  /// ceiling is what keeps a long session from growing without bound.
  static const int defaultCapacity = 100;

  final int capacity;

  final List<UndoEntry> _undo = <UndoEntry>[];
  final List<UndoEntry> _redo = <UndoEntry>[];

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  /// Label of the step [undo] would reverse, for the button tooltip.
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;

  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  int get undoDepth => _undo.length;

  int get redoDepth => _redo.length;

  /// Oldest first. Exposed for the history UI; both lists are copies.
  List<UndoEntry> get undoEntries => List<UndoEntry>.unmodifiable(_undo);

  List<UndoEntry> get redoEntries => List<UndoEntry>.unmodifiable(_redo);

  /// Records the pre-mutation [snapshot]. Any redo branch is discarded, exactly
  /// like every other editor: once you edit after undoing, the future is gone.
  void push(String label, String snapshot) {
    _undo.add(UndoEntry(label: label, snapshot: snapshot));
    _redo.clear();
    while (_undo.length > capacity) {
      _undo.removeAt(0);
    }
  }

  /// Returns the snapshot to restore, or null when there is nothing to undo.
  /// [current] is the document as it is right now and becomes the redo target.
  String? undo(String current) {
    if (_undo.isEmpty) return null;
    final UndoEntry entry = _undo.removeLast();
    _redo.add(UndoEntry(label: entry.label, snapshot: current));
    return entry.snapshot;
  }

  String? redo(String current) {
    if (_redo.isEmpty) return null;
    final UndoEntry entry = _redo.removeLast();
    _undo.add(UndoEntry(label: entry.label, snapshot: current));
    return entry.snapshot;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
