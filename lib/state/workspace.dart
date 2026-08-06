/// Multi-document persistence for the editor.
///
/// Everything lives in one `localStorage` key so a single write keeps the whole
/// workspace consistent. Storage access goes through injected functions: the
/// browser build passes `StorageService`, tests pass an in-memory map, and the
/// class itself never touches `package:web`.
///
/// Corruption tolerance is a hard requirement — the previous editor lost whole
/// documents to a half-written payload. A malformed entry is skipped, a
/// malformed payload degrades to an empty workspace, and neither ever throws.
library;

import 'dart:convert';

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../config/defaults.dart';
import '../services/storage_service.dart';

typedef StorageReader = String? Function(String key);
typedef StorageWriter = bool Function(String key, String value);

String? defaultStorageRead(String key) => StorageService.read(key);

bool defaultStorageWrite(String key, String value) =>
    StorageService.write(key, value);

/// Which model a stored document holds. `menu` is the original and default
/// kind; `containerPreview` was added for the HoloUI container-preview JSON
/// editor.
enum WorkspaceDocKind {
  menu,
  containerPreview;

  /// Falls back to [menu] for anything that is not one of its own names —
  /// including `null`, which is exactly what a document saved before this
  /// field existed reads back as. Never breaks on legacy storage.
  static WorkspaceDocKind fromName(Object? raw) {
    for (final WorkspaceDocKind value in values) {
      if (value.name == raw) return value;
    }
    return WorkspaceDocKind.menu;
  }
}

/// One saved document. [name] is the sanitized id, which is also the export
/// file base name; [json] is the encoded document, in the shape [kind] says it
/// is.
class WorkspaceDoc {
  WorkspaceDoc({
    required this.id,
    required this.name,
    required this.json,
    required this.updatedAt,
    this.kind = WorkspaceDocKind.menu,
  });

  final String id;
  String name;
  String json;
  WorkspaceDocKind kind;

  /// Epoch milliseconds, monotonically increasing within a session so the
  /// "recent documents" order is stable even for edits in the same millisecond.
  int updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'json': json,
        'updatedAt': updatedAt,
        'kind': kind.name,
      };

  /// Null when the entry is unusable; the caller skips it.
  static WorkspaceDoc? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? id = raw['id'];
    final Object? json = raw['json'];
    if (id is! String || id.isEmpty) return null;
    if (json is! String || json.isEmpty) return null;
    try {
      jsonDecode(json);
    } catch (_) {
      // A document whose payload is not JSON can never be opened; dropping it
      // is better than booting the editor into a parse error.
      return null;
    }
    final Object? name = raw['name'];
    final Object? updatedAt = raw['updatedAt'];
    return WorkspaceDoc(
      id: id,
      name: name is String && name.isNotEmpty ? name : huiDefaultMenuId,
      json: json,
      updatedAt: updatedAt is num ? updatedAt.toInt() : 0,
      // Absent on every document saved before this field existed; reading it
      // as `menu` is the null-tolerant default that keeps legacy storage
      // opening exactly as it always has.
      kind: WorkspaceDocKind.fromName(raw['kind']),
    );
  }
}

class Workspace extends ChangeNotifier {
  Workspace({
    this.read = defaultStorageRead,
    this.write = defaultStorageWrite,
    bool autoLoad = true,
  }) {
    if (autoLoad) load();
  }

  static const String storageKey = 'holoui.workspace.v1';

  /// Beyond this the oldest documents are dropped on save: the whole workspace
  /// shares a 5 MB origin budget with the image library.
  static const int maxDocuments = 40;

  final StorageReader read;
  final StorageWriter write;

  final List<WorkspaceDoc> _docs = <WorkspaceDoc>[];
  String? _activeId;
  String? _lastError;
  bool _quotaExceeded = false;
  int _lastStamp = 0;
  int _idCounter = 0;

  List<WorkspaceDoc> get docs => List<WorkspaceDoc>.unmodifiable(_docs);

  /// Newest first, for the document switcher.
  List<WorkspaceDoc> get recent {
    final List<WorkspaceDoc> sorted = List<WorkspaceDoc>.of(_docs);
    sorted.sort((WorkspaceDoc a, WorkspaceDoc b) =>
        b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  String? get activeId => _activeId;

  WorkspaceDoc? get active => byId(_activeId);

  bool get isEmpty => _docs.isEmpty;

  /// Set when a load found damage or a write was refused; the status bar shows
  /// it and it is cleared by the next successful save.
  String? get lastError => _lastError;

  bool get quotaExceeded => _quotaExceeded;

  WorkspaceDoc? byId(String? id) {
    if (id == null) return null;
    for (final WorkspaceDoc doc in _docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  /// Re-reads persisted state. Never throws.
  void load() {
    _docs.clear();
    _activeId = null;
    final String? raw = read(storageKey);
    if (raw == null || raw.isEmpty) {
      notifyListeners();
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      _lastError = 'The saved workspace was unreadable and was reset.';
      notifyListeners();
      return;
    }
    if (decoded is! Map) {
      _lastError = 'The saved workspace had an unexpected shape and was reset.';
      notifyListeners();
      return;
    }
    final Object? rawDocs = decoded['docs'];
    int skipped = 0;
    if (rawDocs is List) {
      for (final Object? entry in rawDocs) {
        final WorkspaceDoc? doc = WorkspaceDoc.fromJson(entry);
        if (doc == null) {
          skipped++;
          continue;
        }
        if (byId(doc.id) != null) {
          skipped++;
          continue;
        }
        _docs.add(doc);
        if (doc.updatedAt > _lastStamp) _lastStamp = doc.updatedAt;
      }
    }
    if (skipped > 0) {
      _lastError =
          '$skipped saved document${skipped == 1 ? ' was' : 's were'} damaged '
          'and skipped.';
    }
    final Object? storedActive = decoded['activeId'];
    if (storedActive is String && byId(storedActive) != null) {
      _activeId = storedActive;
    } else if (_docs.isNotEmpty) {
      _activeId = _docs.first.id;
    }
    notifyListeners();
  }

  /// Adds a document and makes it active.
  WorkspaceDoc create({
    required String name,
    required String json,
    WorkspaceDocKind kind = WorkspaceDocKind.menu,
  }) {
    final WorkspaceDoc doc = WorkspaceDoc(
      id: _newId(),
      name: sanitizeMenuId(name),
      json: json,
      updatedAt: _stamp(),
      kind: kind,
    );
    _docs.add(doc);
    _activeId = doc.id;
    save();
    notifyListeners();
    return doc;
  }

  bool rename(String id, String name) {
    final WorkspaceDoc? doc = byId(id);
    if (doc == null) return false;
    final String sanitized = sanitizeMenuId(name);
    if (doc.name == sanitized) return true;
    doc.name = sanitized;
    doc.updatedAt = _stamp();
    save();
    notifyListeners();
    return true;
  }

  bool delete(String id) {
    final WorkspaceDoc? doc = byId(id);
    if (doc == null) return false;
    _docs.remove(doc);
    if (_activeId == id) {
      _activeId = _docs.isEmpty ? null : recent.first.id;
    }
    save();
    notifyListeners();
    return true;
  }

  bool switchTo(String id) {
    if (byId(id) == null) return false;
    if (_activeId == id) return true;
    _activeId = id;
    save();
    notifyListeners();
    return true;
  }

  /// Writes the live document back. Returns false when there is no active
  /// document or the browser refused the write. [kind] only needs passing
  /// when an import replaced the document with a different kind of content;
  /// omitting it leaves the stored kind untouched.
  bool updateActive({String? name, String? json, WorkspaceDocKind? kind}) {
    final WorkspaceDoc? doc = active;
    if (doc == null) return false;
    bool changed = false;
    if (name != null && name != doc.name) {
      doc.name = name;
      changed = true;
    }
    if (json != null && json != doc.json) {
      doc.json = json;
      changed = true;
    }
    if (kind != null && kind != doc.kind) {
      doc.kind = kind;
      changed = true;
    }
    if (!changed) return true;
    doc.updatedAt = _stamp();
    final bool stored = save();
    notifyListeners();
    return stored;
  }

  /// Persists the whole workspace. On refusal the in-memory documents are kept
  /// deliberately: dropping the user's live edits to match a failed write would
  /// lose more than it protects. The failure is reported instead.
  bool save() {
    while (_docs.length > maxDocuments) {
      final WorkspaceDoc oldest = recent.last;
      if (oldest.id == _activeId) break;
      _docs.remove(oldest);
    }
    final String payload = jsonEncode(<String, dynamic>{
      'docs': _docs.map((WorkspaceDoc doc) => doc.toJson()).toList(),
      'activeId': _activeId,
    });
    final bool stored = write(storageKey, payload);
    if (stored) {
      _quotaExceeded = false;
      _lastError = null;
    } else {
      _quotaExceeded = true;
      _lastError = 'Browser storage is full, so this change was not saved. '
          'Export the menu to keep it.';
    }
    return stored;
  }

  int estimateBytes() {
    int total = storageKey.length * 2;
    for (final WorkspaceDoc doc in _docs) {
      total += (doc.json.length + doc.name.length + doc.id.length + 48) * 2;
    }
    return total;
  }

  int _stamp() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    _lastStamp = now > _lastStamp ? now : _lastStamp + 1;
    return _lastStamp;
  }

  String _newId() {
    for (int attempt = 0; attempt < 1000; attempt++) {
      final String candidate =
          'doc-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
          '-${_idCounter++}';
      if (byId(candidate) == null) return candidate;
    }
    return 'doc-${_idCounter++}';
  }
}
