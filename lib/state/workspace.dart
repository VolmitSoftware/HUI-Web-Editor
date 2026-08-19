library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../config/defaults.dart';
import '../services/storage_service.dart';
import 'workspace_repository.dart';

typedef StorageReader = String? Function(String key);
typedef StorageWriter = bool Function(String key, String value);
typedef WorkspaceIdFactory = String Function();

String? defaultStorageRead(String key) => StorageService.read(key);

bool defaultStorageWrite(String key, String value) =>
    StorageService.write(key, value);

enum WorkspaceDocKind {
  menu,
  containerPreview,
  panel,
  hologram,
  animation,
  scoreboard,
  motd,
  emoji,
  bubbleStyle,
  tablist;

  bool get hasRuntimeId => this != WorkspaceDocKind.panel;

  /// World panels were stored as `board` before the Gloss rename. Stored
  /// documents carrying the old slug must keep loading forever, so the legacy
  /// name maps here rather than being migrated in place.
  static const String _legacyPanelName = 'board';

  static WorkspaceDocKind? fromName(Object? raw) {
    if (raw == _legacyPanelName) return WorkspaceDocKind.panel;
    for (final WorkspaceDocKind value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

class WorkspaceFolder {
  WorkspaceFolder({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.parentId,
  });

  final String id;
  String title;
  String? parentId;
  int updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'parentId': parentId,
    'updatedAt': updatedAt,
  };

  static WorkspaceFolder? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? id = raw['id'];
    if (id is! String || !isWorkspaceUuid(id)) return null;
    final Object? title = raw['title'];
    final Object? parentId = raw['parentId'];
    final Object? updatedAt = raw['updatedAt'];
    if (parentId != null &&
        (parentId is! String || !isWorkspaceUuid(parentId))) {
      return null;
    }
    return WorkspaceFolder(
      id: id,
      title: normalizeWorkspaceTitle(title, fallback: 'Folder'),
      parentId: parentId as String?,
      updatedAt: updatedAt is num ? updatedAt.toInt() : 0,
    );
  }
}

class WorkspaceDoc {
  WorkspaceDoc({
    required this.id,
    required this.title,
    required this.runtimeId,
    required this.json,
    required this.updatedAt,
    required this.folderId,
    this.kind = WorkspaceDocKind.menu,
  });

  final String id;
  String title;
  String? runtimeId;
  String json;
  WorkspaceDocKind kind;
  String folderId;
  int updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'runtimeId': runtimeId,
    'json': json,
    'updatedAt': updatedAt,
    'kind': kind.name,
    'folderId': folderId,
  };

  static WorkspaceDoc? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? id = raw['id'];
    final Object? json = raw['json'];
    final WorkspaceDocKind? kind = WorkspaceDocKind.fromName(raw['kind']);
    final Object? folderId = raw['folderId'];
    if (id is! String || !isWorkspaceUuid(id)) return null;
    if (json is! String || json.isEmpty || !_isJson(json)) return null;
    if (kind == null) return null;
    if (folderId is! String || !isWorkspaceUuid(folderId)) return null;

    String? runtimeId;
    if (kind.hasRuntimeId) {
      final Object? rawRuntimeId = raw['runtimeId'];
      if (rawRuntimeId is! String || validateMenuId(rawRuntimeId) != null) {
        return null;
      }
      runtimeId = rawRuntimeId;
    }
    final Object? updatedAt = raw['updatedAt'];
    return WorkspaceDoc(
      id: id,
      title: normalizeWorkspaceTitle(
        raw['title'],
        fallback: runtimeId ?? 'Untitled panel',
      ),
      runtimeId: runtimeId,
      json: json,
      updatedAt: updatedAt is num ? updatedAt.toInt() : 0,
      kind: kind,
      folderId: folderId,
    );
  }
}

class WorkspaceDocumentUpdate {
  const WorkspaceDocumentUpdate({
    required this.documentId,
    this.runtimeId,
    this.json,
  });

  final String documentId;
  final String? runtimeId;
  final String? json;
}

class WorkspaceRuntimeIdConflict {
  const WorkspaceRuntimeIdConflict({
    required this.kind,
    required this.runtimeId,
    required this.documents,
  });

  final WorkspaceDocKind kind;
  final String runtimeId;
  final List<WorkspaceDoc> documents;
}

class WorkspacePortableStateCheck {
  const WorkspacePortableStateCheck({
    required this.isValid,
    required this.documentCount,
    required this.folderCount,
    this.warning,
    this.error,
  });

  final bool isValid;
  final int documentCount;
  final int folderCount;
  final String? warning;
  final String? error;
}

class Workspace extends ChangeNotifier {
  Workspace({
    this.read = defaultStorageRead,
    this.write = defaultStorageWrite,
    WorkspaceRepository? repository,
    WorkspaceIdFactory idFactory = newWorkspaceUuid,
    bool autoLoad = true,
  }) : _idFactory = idFactory {
    this.repository =
        repository ??
        CallbackWorkspaceMaintenanceRepository(
          reader: read,
          writer: write,
          clearer: () {
            final bool current = StorageService.remove(storageKey);
            final bool legacy = StorageService.remove(legacyStorageKey);
            StorageService.remove(preRebrandStorageKey);
            StorageService.remove(preRebrandLegacyStorageKey);
            return current && legacy;
          },
        );
    final WorkspaceRepository source = this.repository;
    if (source is ObservableWorkspaceRepository) {
      final ObservableWorkspaceRepository observable =
          source as ObservableWorkspaceRepository;
      observable.setNoticeListener(_handleRepositoryNotice);
    }
    _resetToEmpty();
    if (autoLoad) {
      _ready = _load();
    } else {
      _isReady = true;
      _ready = Future<void>.value();
    }
  }

  static const int schemaVersion = 2;
  static const String storageKey = 'gloss.workspace.v2';
  static const String legacyStorageKey = 'gloss.workspace.v1';

  /// Pre-rebrand key names. [StorageService] migrates the localStorage copies
  /// and the IndexedDB repository migrates its records, but explicit clears
  /// must also drop these so old data cannot re-migrate after a reset.
  static const String preRebrandStorageKey = 'holoui.workspace.v2';
  static const String preRebrandLegacyStorageKey = 'holoui.workspace.v1';
  static const String unfiledTitle = 'Unfiled';

  final StorageReader read;
  final StorageWriter write;
  late final WorkspaceRepository repository;
  final WorkspaceIdFactory _idFactory;

  final List<WorkspaceDoc> _docs = <WorkspaceDoc>[];
  final List<WorkspaceFolder> _folders = <WorkspaceFolder>[];
  late String _workspaceId;
  late String _unfiledFolderId;
  String? _activeId;
  String? _lastError;
  bool _quotaExceeded = false;
  bool _isReady = false;
  int _lastStamp = 0;
  int _saveRevision = 0;
  int _persistedRevision = 0;
  bool _loadProtected = false;
  bool _requiresReload = false;
  Future<void>? _writeTail;
  late Future<void> _ready;

  static Future<Workspace> open({
    required WorkspaceRepository repository,
    StorageReader read = defaultStorageRead,
    StorageWriter write = defaultStorageWrite,
    WorkspaceIdFactory idFactory = newWorkspaceUuid,
  }) async {
    final Workspace workspace = Workspace(
      read: read,
      write: write,
      repository: repository,
      idFactory: idFactory,
      autoLoad: false,
    );
    await workspace.load();
    return workspace;
  }

  String get id => _workspaceId;

  String get unfiledFolderId => _unfiledFolderId;

  Future<void> get ready => _ready;

  bool get isReady => _isReady;

  List<WorkspaceDoc> get docs => List<WorkspaceDoc>.unmodifiable(_docs);

  List<WorkspaceFolder> get folders =>
      List<WorkspaceFolder>.unmodifiable(_folders);

  List<WorkspaceDoc> get recent {
    final List<WorkspaceDoc> sorted = List<WorkspaceDoc>.of(_docs);
    sorted.sort(
      (WorkspaceDoc a, WorkspaceDoc b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return sorted;
  }

  String? get activeId => _activeId;

  WorkspaceDoc? get active => byId(_activeId);

  bool get isEmpty => _docs.isEmpty;

  String? get lastError => _lastError;

  bool get quotaExceeded => _quotaExceeded;

  bool get hasPendingWrites => _writeTail != null;

  bool get hasUnsavedChanges => _persistedRevision < _saveRevision;

  Future<void> get writesSettled => _writeTail ?? Future<void>.value();

  bool get isLoadProtected => _loadProtected;

  bool get requiresReload => _requiresReload;

  bool get canWrite => _isReady && !_loadProtected && !_requiresReload;

  int get saveRevision => _saveRevision;

  int get persistedRevision => _persistedRevision;

  List<WorkspaceRuntimeIdConflict> get runtimeIdConflicts {
    final Map<String, List<WorkspaceDoc>> grouped =
        <String, List<WorkspaceDoc>>{};
    for (final WorkspaceDoc doc in _docs) {
      final String? runtimeId = doc.runtimeId;
      if (!doc.kind.hasRuntimeId || runtimeId == null) continue;
      final String key = '${doc.kind.name}\u0000${runtimeId.toLowerCase()}';
      grouped.putIfAbsent(key, () => <WorkspaceDoc>[]).add(doc);
    }
    final List<WorkspaceRuntimeIdConflict> conflicts =
        <WorkspaceRuntimeIdConflict>[];
    for (final List<WorkspaceDoc> documents in grouped.values) {
      if (documents.length < 2) continue;
      conflicts.add(
        WorkspaceRuntimeIdConflict(
          kind: documents.first.kind,
          runtimeId: documents.first.runtimeId!,
          documents: List<WorkspaceDoc>.unmodifiable(documents),
        ),
      );
    }
    conflicts.sort(
      (WorkspaceRuntimeIdConflict a, WorkspaceRuntimeIdConflict b) =>
          a.runtimeId.compareTo(b.runtimeId),
    );
    return conflicts;
  }

  WorkspaceDoc? byId(String? id) {
    if (id == null) return null;
    for (final WorkspaceDoc doc in _docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  WorkspaceFolder? folderById(String? id) {
    if (id == null) return null;
    for (final WorkspaceFolder folder in _folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  List<WorkspaceFolder> childFolders(String? parentId) =>
      List<WorkspaceFolder>.unmodifiable(
        _folders.where((WorkspaceFolder folder) => folder.parentId == parentId),
      );

  List<WorkspaceDoc> documentsInFolder(String folderId) =>
      List<WorkspaceDoc>.unmodifiable(
        _docs.where((WorkspaceDoc doc) => doc.folderId == folderId),
      );

  Future<void> load() {
    _ready = _load();
    return _ready;
  }

  WorkspaceDoc create({
    required String title,
    required String json,
    String? runtimeId,
    WorkspaceDocKind kind = WorkspaceDocKind.menu,
    String? folderId,
  }) {
    _requireReady();
    _requireWritable();
    final String targetFolder = folderById(folderId)?.id ?? _unfiledFolderId;
    final String? canonicalRuntimeId = kind.hasRuntimeId
        ? sanitizeMenuId(runtimeId ?? title)
        : null;
    final WorkspaceDoc doc = WorkspaceDoc(
      id: _newUniqueId(<String>{for (final WorkspaceDoc doc in _docs) doc.id}),
      title: normalizeWorkspaceTitle(
        title,
        fallback: canonicalRuntimeId ?? 'Untitled panel',
      ),
      runtimeId: canonicalRuntimeId,
      json: json,
      updatedAt: _stamp(),
      kind: kind,
      folderId: targetFolder,
    );
    _docs.add(doc);
    _activeId = doc.id;
    save();
    notifyListeners();
    return doc;
  }

  bool renameDocumentTitle(String id, String title) {
    if (!canWrite) return false;
    final WorkspaceDoc? doc = byId(id);
    if (doc == null) return false;
    final String normalized = normalizeWorkspaceTitle(
      title,
      fallback: doc.runtimeId ?? 'Untitled panel',
    );
    if (doc.title == normalized) return true;
    doc.title = normalized;
    doc.updatedAt = _stamp();
    save();
    notifyListeners();
    return true;
  }

  bool renameDocumentRuntimeId(String id, String runtimeId) {
    if (!canWrite) return false;
    final WorkspaceDoc? doc = byId(id);
    if (doc == null || !doc.kind.hasRuntimeId) return false;
    final String canonical = sanitizeMenuId(runtimeId);
    if (doc.runtimeId == canonical) return true;
    doc.runtimeId = canonical;
    doc.updatedAt = _stamp();
    save();
    notifyListeners();
    return true;
  }

  bool updateDocuments(List<WorkspaceDocumentUpdate> updates) {
    if (!canWrite || updates.isEmpty) return false;
    final Set<String> ids = <String>{};
    for (final WorkspaceDocumentUpdate update in updates) {
      if (!ids.add(update.documentId)) return false;
      final WorkspaceDoc? document = byId(update.documentId);
      if (document == null) return false;
      if (update.runtimeId != null && !document.kind.hasRuntimeId) return false;
      if (update.json != null && !_isJson(update.json!)) return false;
    }

    bool changed = false;
    for (final WorkspaceDocumentUpdate update in updates) {
      final WorkspaceDoc document = byId(update.documentId)!;
      bool documentChanged = false;
      if (update.runtimeId != null) {
        final String canonical = sanitizeMenuId(update.runtimeId!);
        if (canonical != document.runtimeId) {
          document.runtimeId = canonical;
          documentChanged = true;
        }
      }
      if (update.json != null && update.json != document.json) {
        document.json = update.json!;
        documentChanged = true;
      }
      if (documentChanged) {
        document.updatedAt = _stamp();
        changed = true;
      }
    }
    if (!changed) return true;
    final bool stored = save();
    notifyListeners();
    return stored;
  }

  bool replaceDocument({
    required String id,
    required String title,
    required String json,
    required WorkspaceDocKind kind,
    required String folderId,
    String? runtimeId,
  }) {
    if (!canWrite || !_isJson(json) || folderById(folderId) == null) {
      return false;
    }
    final WorkspaceDoc? doc = byId(id);
    if (doc == null) return false;
    final String? canonicalRuntimeId = kind.hasRuntimeId
        ? sanitizeMenuId(runtimeId ?? title)
        : null;
    doc
      ..title = normalizeWorkspaceTitle(
        title,
        fallback: canonicalRuntimeId ?? 'Untitled panel',
      )
      ..runtimeId = canonicalRuntimeId
      ..json = json
      ..kind = kind
      ..folderId = folderId
      ..updatedAt = _stamp();
    save();
    notifyListeners();
    return true;
  }

  bool delete(String id) {
    if (!canWrite) return false;
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

  bool moveDocument(String id, String folderId) {
    if (!canWrite) return false;
    final WorkspaceDoc? doc = byId(id);
    if (doc == null || folderById(folderId) == null) return false;
    if (doc.folderId == folderId) return true;
    doc.folderId = folderId;
    doc.updatedAt = _stamp();
    save();
    notifyListeners();
    return true;
  }

  WorkspaceFolder createFolder({required String title, String? parentId}) {
    _requireReady();
    _requireWritable();
    final String? canonicalParent = folderById(parentId)?.id;
    final WorkspaceFolder folder = WorkspaceFolder(
      id: _newUniqueId(<String>{
        for (final WorkspaceFolder folder in _folders) folder.id,
      }),
      title: normalizeWorkspaceTitle(title, fallback: 'Folder'),
      parentId: canonicalParent,
      updatedAt: _stamp(),
    );
    _folders.add(folder);
    save();
    notifyListeners();
    return folder;
  }

  bool renameFolder(String id, String title) {
    if (!canWrite) return false;
    final WorkspaceFolder? folder = folderById(id);
    if (folder == null || id == _unfiledFolderId) return false;
    final String normalized = normalizeWorkspaceTitle(
      title,
      fallback: id == _unfiledFolderId ? unfiledTitle : 'Folder',
    );
    if (folder.title == normalized) return true;
    folder.title = normalized;
    folder.updatedAt = _stamp();
    save();
    notifyListeners();
    return true;
  }

  bool moveFolder(String id, String? parentId) {
    if (!canWrite) return false;
    final WorkspaceFolder? folder = folderById(id);
    if (folder == null || id == _unfiledFolderId) return false;
    final String? canonicalParent = parentId == null
        ? null
        : folderById(parentId)?.id;
    if (parentId != null && canonicalParent == null) return false;
    if (canonicalParent == id || _isDescendant(canonicalParent, id)) {
      return false;
    }
    if (folder.parentId == canonicalParent) return true;
    folder.parentId = canonicalParent;
    folder.updatedAt = _stamp();
    save();
    notifyListeners();
    return true;
  }

  bool deleteFolder(String id) {
    if (!canWrite) return false;
    final WorkspaceFolder? folder = folderById(id);
    if (folder == null || id == _unfiledFolderId) return false;
    final String replacement = folder.parentId ?? _unfiledFolderId;
    for (final WorkspaceDoc doc in _docs) {
      if (doc.folderId == id) doc.folderId = replacement;
    }
    for (final WorkspaceFolder child in _folders) {
      if (child.parentId == id) child.parentId = replacement;
    }
    _folders.remove(folder);
    save();
    notifyListeners();
    return true;
  }

  bool updateActive({
    String? title,
    String? runtimeId,
    String? json,
    WorkspaceDocKind? kind,
    String? folderId,
  }) {
    if (!canWrite) return false;
    final WorkspaceDoc? doc = active;
    if (doc == null) return false;
    bool changed = false;
    if (title != null) {
      final String normalized = normalizeWorkspaceTitle(
        title,
        fallback: doc.runtimeId ?? 'Untitled panel',
      );
      if (normalized != doc.title) {
        doc.title = normalized;
        changed = true;
      }
    }
    if (kind != null && kind != doc.kind) {
      doc.kind = kind;
      doc.runtimeId = kind.hasRuntimeId
          ? sanitizeMenuId(runtimeId ?? doc.runtimeId ?? doc.title)
          : null;
      changed = true;
    } else if (runtimeId != null && doc.kind.hasRuntimeId) {
      final String canonical = sanitizeMenuId(runtimeId);
      if (canonical != doc.runtimeId) {
        doc.runtimeId = canonical;
        changed = true;
      }
    }
    if (json != null && json != doc.json) {
      doc.json = json;
      changed = true;
    }
    if (folderId != null &&
        folderById(folderId) != null &&
        folderId != doc.folderId) {
      doc.folderId = folderId;
      changed = true;
    }
    if (!changed) return true;
    doc.updatedAt = _stamp();
    final bool stored = save();
    notifyListeners();
    return stored;
  }

  bool save() {
    if (!_isReady || _loadProtected || _requiresReload) return false;
    final String payload = jsonEncode(_snapshot().toJson());
    final int revision = ++_saveRevision;
    final Future<void>? tail = _writeTail;
    if (tail != null) {
      final Future<void> queued = tail.then((_) async {
        try {
          final bool stored = await repository.write(storageKey, payload);
          _finishWrite(revision, stored);
        } catch (_) {
          _finishWrite(revision, false);
        }
      });
      _trackWrite(queued);
      return true;
    }

    final FutureOr<bool> result;
    try {
      result = repository.write(storageKey, payload);
    } catch (_) {
      _finishWrite(revision, false);
      return false;
    }
    if (result is bool) {
      _finishWrite(revision, result);
      return result;
    }
    final Future<void> pending = _finishAsyncWrite(result, revision);
    _trackWrite(pending);
    return true;
  }

  Future<bool> retrySave() async {
    if (!canWrite) return false;
    save();
    await writesSettled;
    return !hasUnsavedChanges;
  }

  int estimateBytes() {
    final String payload = jsonEncode(_snapshot().toJson());
    return (storageKey.length + payload.length) * 2;
  }

  Map<String, dynamic> exportPortableState() => _snapshot().toJson();

  String createRollbackSnapshot() => jsonEncode(_snapshot().toJson());

  Future<bool> restoreRollbackSnapshot(String raw) async {
    final _DecodedWorkspace decoded = _decodeV2(raw);
    final Future<void>? pending = _writeTail;
    if (pending != null) await pending;
    _applyState(decoded.state, warning: decoded.warning);
    if (!save()) return false;
    await writesSettled;
    return !hasUnsavedChanges;
  }

  WorkspacePortableStateCheck inspectPortableState(Object? raw) {
    try {
      final _DecodedWorkspace decoded = _decodeV2(jsonEncode(raw));
      return WorkspacePortableStateCheck(
        isValid: true,
        documentCount: decoded.state.docs.length,
        folderCount: decoded.state.folders.length,
        warning: decoded.warning,
      );
    } on _FutureWorkspaceVersion catch (error) {
      return WorkspacePortableStateCheck(
        isValid: false,
        documentCount: 0,
        folderCount: 0,
        error: error.message,
      );
    } catch (_) {
      return const WorkspacePortableStateCheck(
        isValid: false,
        documentCount: 0,
        folderCount: 0,
        error: 'The workspace state is unreadable.',
      );
    }
  }

  Future<bool> replacePortableState(Object? raw) async {
    if (_requiresReload) {
      _lastError =
          'This workspace changed in another browser tab. Export this tab '
          'before reloading to choose which version to keep.';
      notifyListeners();
      return false;
    }
    final _DecodedWorkspace decoded;
    try {
      decoded = _decodeV2(jsonEncode(raw));
    } catch (_) {
      _lastError = 'The workspace state is unreadable.';
      notifyListeners();
      return false;
    }
    final Future<void>? pending = _writeTail;
    if (pending != null) await pending;
    final String payload = jsonEncode(decoded.state.toJson());
    final int revision = _saveRevision + 1;
    final bool stored;
    try {
      final WorkspaceRepository source = repository;
      stored = _loadProtected && source is RecoverableWorkspaceRepository
          ? await (source as RecoverableWorkspaceRepository).restore(
              storageKey,
              payload,
            )
          : await source.write(storageKey, payload);
    } catch (_) {
      _syncRepositoryConflict();
      _lastError = _repositoryFailure();
      _lastError ??= 'The imported workspace could not be saved.';
      _quotaExceeded = !_requiresReload;
      notifyListeners();
      return false;
    }
    if (!stored) {
      _syncRepositoryConflict();
      _lastError = _repositoryFailure();
      _lastError ??= 'The imported workspace could not be saved.';
      _quotaExceeded = !_requiresReload;
      notifyListeners();
      return false;
    }
    _saveRevision = revision;
    _persistedRevision = revision;
    _loadProtected = false;
    _requiresReload = false;
    _applyState(decoded.state, warning: decoded.warning);
    return true;
  }

  Future<bool> reset() async {
    final Future<void>? pending = _writeTail;
    if (pending != null) await pending;
    final WorkspaceRepository source = repository;
    if (source is! WorkspaceMaintenanceRepository) {
      _lastError = 'This workspace repository cannot clear saved data.';
      notifyListeners();
      return false;
    }
    final bool cleared;
    try {
      final WorkspaceMaintenanceRepository maintenance =
          source as WorkspaceMaintenanceRepository;
      cleared = await maintenance.clear();
    } catch (_) {
      _lastError = 'Browser storage refused to clear the workspace.';
      notifyListeners();
      return false;
    }
    if (!cleared) {
      final RecoverableWorkspaceRepository? recoverable =
          source is RecoverableWorkspaceRepository
          ? source as RecoverableWorkspaceRepository
          : null;
      _lastError =
          recoverable?.lastFailure ??
          'Browser storage refused to clear the workspace.';
      notifyListeners();
      return false;
    }
    _saveRevision = 0;
    _persistedRevision = 0;
    _requiresReload = false;
    _resetToEmpty();
    _lastError = null;
    _isReady = true;
    notifyListeners();
    return true;
  }

  Future<void> _load() {
    _isReady = false;
    _lastError = null;
    final FutureOr<String?> result;
    try {
      result = repository.read(storageKey);
    } on WorkspaceRepositoryCorruption {
      return _loadBackup(
        fallbackError:
            'The saved IndexedDB workspace record was malformed and no valid recovery copy was found.',
      );
    } catch (_) {
      return _loadBackup(
        fallbackError:
            'The saved workspace could not be read and no valid recovery copy was found.',
      );
    }
    if (result is String?) {
      return _loadV2(result);
    }
    return result.then(_loadV2).catchError((Object error) {
      if (error is WorkspaceRepositoryCorruption) {
        return _loadBackup(
          fallbackError:
              'The saved IndexedDB workspace record was malformed and no valid recovery copy was found.',
        );
      }
      return _loadBackup(
        fallbackError:
            'The saved workspace could not be read and no valid recovery copy was found.',
      );
    });
  }

  Future<void> _loadV2(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      try {
        final _DecodedWorkspace decoded = _decodeV2(raw);
        _syncRepositoryConflict();
        _applyState(
          decoded.state,
          warning: _mergeWarnings(decoded.warning, _repositoryFailure()),
        );
        return Future<void>.value();
      } on _FutureWorkspaceVersion catch (error) {
        _completeEmpty(error.message, protectStoredData: true);
        return Future<void>.value();
      } catch (_) {
        return _loadBackup(
          fallbackError:
              'The saved v2 workspace was unreadable and no valid backup was found.',
        );
      }
    }
    return _loadLegacy();
  }

  Future<void> _loadBackup({required String fallbackError}) async {
    final WorkspaceRepository source = repository;
    if (source is! RecoverableWorkspaceRepository) {
      await _loadLegacy(fallbackError: fallbackError);
      return;
    }
    final RecoverableWorkspaceRepository recoverable =
        source as RecoverableWorkspaceRepository;
    String? backup;
    try {
      backup = await recoverable.readBackup(storageKey);
    } catch (_) {
      backup = null;
    }
    if (await _tryRecoveryCandidate(backup, recoverable)) return;

    final String? retained;
    try {
      retained = await recoverable.readRetainedCopy(storageKey);
    } catch (_) {
      await _loadLegacy(fallbackError: fallbackError);
      return;
    }
    if (await _tryRecoveryCandidate(retained, recoverable)) return;
    await _loadLegacy(fallbackError: fallbackError);
  }

  Future<bool> _tryRecoveryCandidate(
    String? raw,
    RecoverableWorkspaceRepository recoverable,
  ) async {
    if (raw == null || raw.isEmpty) return false;
    final _DecodedWorkspace recovered;
    try {
      recovered = _decodeV2(raw);
    } on _FutureWorkspaceVersion catch (error) {
      _completeEmpty(error.message, protectStoredData: true);
      return true;
    } catch (_) {
      return false;
    }
    final bool stored;
    try {
      stored = await recoverable.restore(storageKey, raw);
    } catch (_) {
      _applyRecoveredBackup(recovered, false);
      return true;
    }
    _applyRecoveredBackup(recovered, stored);
    return true;
  }

  void _applyRecoveredBackup(_DecodedWorkspace recovered, bool stored) {
    if (!stored) _syncRepositoryConflict();
    _applyState(
      recovered.state,
      warning: stored
          ? 'The latest workspace snapshot was unreadable, so the previous '
                'transaction was restored.'
          : 'The previous workspace transaction was recovered in memory, but '
                'could not be restored to browser storage. Export it before '
                'closing this tab.',
      quotaExceeded: !stored,
      loadProtected: !stored,
    );
  }

  Future<void> _loadLegacy({String? fallbackError}) {
    final FutureOr<String?> result;
    try {
      result = repository.read(legacyStorageKey);
    } catch (_) {
      _completeEmpty(
        fallbackError ?? 'The saved workspace could not be read.',
        protectStoredData: true,
      );
      return Future<void>.value();
    }
    if (result is String?) {
      return _finishLegacy(result, fallbackError: fallbackError);
    }
    return result
        .then((String? raw) => _finishLegacy(raw, fallbackError: fallbackError))
        .catchError((Object _) {
          _completeEmpty(
            fallbackError ?? 'The saved workspace could not be read.',
            protectStoredData: true,
          );
        });
  }

  Future<void> _finishLegacy(String? raw, {String? fallbackError}) {
    if (raw == null || raw.isEmpty) {
      if (fallbackError == null) {
        _completeEmpty(null);
      } else {
        _completeEmpty(fallbackError, protectStoredData: true);
      }
      return Future<void>.value();
    }

    final _DecodedWorkspace migrated;
    try {
      migrated = _decodeLegacy(raw);
    } catch (_) {
      _completeEmpty(
        fallbackError ?? 'The saved workspace was unreadable and was reset.',
        protectStoredData: true,
      );
      return Future<void>.value();
    }

    final String payload = jsonEncode(migrated.state.toJson());
    final FutureOr<bool> result;
    try {
      final WorkspaceRepository source = repository;
      result = fallbackError != null && source is RecoverableWorkspaceRepository
          ? (source as RecoverableWorkspaceRepository).restore(
              storageKey,
              payload,
            )
          : source.write(storageKey, payload);
    } catch (_) {
      _applyState(
        migrated.state,
        warning:
            'The legacy workspace was recovered in memory, but its v2 migration could not be saved.',
        quotaExceeded: true,
        loadProtected: true,
      );
      return Future<void>.value();
    }
    if (result is bool) {
      _finishMigration(migrated, result);
      return Future<void>.value();
    }
    return result
        .then((bool stored) => _finishMigration(migrated, stored))
        .catchError((Object _) => _finishMigration(migrated, false));
  }

  void _finishMigration(_DecodedWorkspace migrated, bool stored) {
    final String? warning = stored
        ? migrated.warning
        : 'The legacy workspace was recovered in memory, but its v2 migration could not be saved.';
    if (!stored) _syncRepositoryConflict();
    _applyState(
      migrated.state,
      warning: warning,
      quotaExceeded: !stored,
      loadProtected: !stored,
    );
  }

  _DecodedWorkspace _decodeV2(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Workspace is not a map');
    final Object? rawVersion = decoded['schemaVersion'];
    if (rawVersion is num && rawVersion.toInt() > schemaVersion) {
      throw const _FutureWorkspaceVersion(
        'This workspace was written by a newer editor and was left untouched.',
      );
    }
    if (rawVersion is! num || rawVersion.toInt() != schemaVersion) {
      throw const FormatException('Unknown workspace schema');
    }

    int repaired = 0;
    final Set<String> folderIds = <String>{};
    final List<WorkspaceFolder> folders = <WorkspaceFolder>[];
    final Object? rawFolders = decoded['folders'];
    if (rawFolders is List) {
      for (final Object? entry in rawFolders) {
        final WorkspaceFolder? folder = WorkspaceFolder.fromJson(entry);
        if (folder == null || !folderIds.add(folder.id)) {
          repaired++;
          continue;
        }
        folders.add(folder);
      }
    }

    String? unfiledId = decoded['unfiledFolderId'] is String
        ? decoded['unfiledFolderId'] as String
        : null;
    if (unfiledId == null || folderIds.contains(unfiledId) == false) {
      unfiledId = _newUniqueId(folderIds);
      folderIds.add(unfiledId);
      folders.add(
        WorkspaceFolder(id: unfiledId, title: unfiledTitle, updatedAt: 0),
      );
      repaired++;
    }
    final WorkspaceFolder unfiled = folders.firstWhere(
      (WorkspaceFolder folder) => folder.id == unfiledId,
    );
    unfiled.parentId = null;
    unfiled.title = unfiledTitle;
    repaired += _repairFolderTree(folders, unfiledId);

    final Set<String> documentIds = <String>{};
    final List<WorkspaceDoc> docs = <WorkspaceDoc>[];
    final Object? rawDocuments = decoded['documents'];
    if (rawDocuments is! List) {
      throw const FormatException('Workspace documents are missing.');
    }
    for (final Object? entry in rawDocuments) {
      final WorkspaceDoc? doc = WorkspaceDoc.fromJson(entry);
      if (doc == null || !documentIds.add(doc.id)) {
        repaired++;
        continue;
      }
      if (!folderIds.contains(doc.folderId)) {
        doc.folderId = unfiledId;
        repaired++;
      }
      docs.add(doc);
    }
    if (rawDocuments.isNotEmpty && docs.isEmpty) {
      throw const FormatException(
        'Every stored workspace document was rejected.',
      );
    }

    String workspaceId = decoded['workspaceId'] is String
        ? decoded['workspaceId'] as String
        : '';
    if (!isWorkspaceUuid(workspaceId)) {
      workspaceId = _newUniqueId(<String>{...folderIds, ...documentIds});
      repaired++;
    }
    final Object? rawActive = decoded['activeDocumentId'];
    String? activeId = rawActive is String && documentIds.contains(rawActive)
        ? rawActive
        : null;
    if (activeId == null && docs.isNotEmpty) {
      activeId = _newest(docs).id;
      if (rawActive != null) repaired++;
    }
    final _WorkspaceState state = _WorkspaceState(
      workspaceId: workspaceId,
      unfiledFolderId: unfiledId,
      folders: folders,
      docs: docs,
      activeId: activeId,
    );
    return _DecodedWorkspace(
      state,
      repaired == 0
          ? null
          : '$repaired damaged workspace entr${repaired == 1 ? 'y was' : 'ies were'} repaired or skipped.',
    );
  }

  _DecodedWorkspace _decodeLegacy(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Workspace is not a map');

    final Set<String> used = <String>{};
    final String workspaceId = _newUniqueId(used);
    used.add(workspaceId);
    final String unfiledId = _newUniqueId(used);
    used.add(unfiledId);
    final WorkspaceFolder unfiled = WorkspaceFolder(
      id: unfiledId,
      title: unfiledTitle,
      updatedAt: 0,
    );

    final Map<String, String> migratedIds = <String, String>{};
    final List<WorkspaceDoc> docs = <WorkspaceDoc>[];
    int skipped = 0;
    final Object? rawDocs = decoded['docs'];
    if (rawDocs is List) {
      for (final Object? entry in rawDocs) {
        if (entry is! Map) {
          skipped++;
          continue;
        }
        final Object? legacyId = entry['id'];
        final Object? rawJson = entry['json'];
        if (legacyId is! String ||
            legacyId.isEmpty ||
            migratedIds.containsKey(legacyId) ||
            rawJson is! String ||
            rawJson.isEmpty ||
            !_isJson(rawJson)) {
          skipped++;
          continue;
        }
        final WorkspaceDocKind? kind = entry['kind'] == null
            ? WorkspaceDocKind.menu
            : WorkspaceDocKind.fromName(entry['kind']);
        if (kind == null || kind == WorkspaceDocKind.panel) {
          skipped++;
          continue;
        }
        final String id = isWorkspaceUuid(legacyId) && used.add(legacyId)
            ? legacyId
            : _newUniqueId(used);
        used.add(id);
        migratedIds[legacyId] = id;
        final String rawName = entry['name'] is String
            ? entry['name'] as String
            : huiDefaultMenuId;
        final String runtimeId = sanitizeMenuId(rawName);
        final Object? rawUpdatedAt = entry['updatedAt'];
        docs.add(
          WorkspaceDoc(
            id: id,
            title: normalizeWorkspaceTitle(rawName, fallback: runtimeId),
            runtimeId: runtimeId,
            json: rawJson,
            updatedAt: rawUpdatedAt is num ? rawUpdatedAt.toInt() : 0,
            folderId: unfiledId,
            kind: kind,
          ),
        );
      }
    }
    final Object? legacyActive = decoded['activeId'];
    String? activeId = legacyActive is String
        ? migratedIds[legacyActive]
        : null;
    if (activeId == null && docs.isNotEmpty) activeId = _newest(docs).id;

    return _DecodedWorkspace(
      _WorkspaceState(
        workspaceId: workspaceId,
        unfiledFolderId: unfiledId,
        folders: <WorkspaceFolder>[unfiled],
        docs: docs,
        activeId: activeId,
      ),
      skipped == 0
          ? null
          : '$skipped legacy document${skipped == 1 ? ' was' : 's were'} damaged and skipped.',
    );
  }

  void _applyState(
    _WorkspaceState state, {
    String? warning,
    bool quotaExceeded = false,
    bool loadProtected = false,
  }) {
    _workspaceId = state.workspaceId;
    _unfiledFolderId = state.unfiledFolderId;
    _folders
      ..clear()
      ..addAll(state.folders);
    _docs
      ..clear()
      ..addAll(state.docs);
    _activeId = state.activeId;
    _lastStamp = 0;
    for (final WorkspaceFolder folder in _folders) {
      if (folder.updatedAt > _lastStamp) _lastStamp = folder.updatedAt;
    }
    for (final WorkspaceDoc doc in _docs) {
      if (doc.updatedAt > _lastStamp) _lastStamp = doc.updatedAt;
    }
    _lastError = warning;
    _quotaExceeded = quotaExceeded;
    _loadProtected = loadProtected;
    _isReady = true;
    notifyListeners();
  }

  void _completeEmpty(String? error, {bool protectStoredData = false}) {
    _resetToEmpty();
    _lastError = error;
    _loadProtected = protectStoredData;
    _isReady = true;
    notifyListeners();
  }

  void _resetToEmpty() {
    final Set<String> used = <String>{};
    _workspaceId = _newUniqueId(used);
    used.add(_workspaceId);
    _unfiledFolderId = _newUniqueId(used);
    _folders
      ..clear()
      ..add(
        WorkspaceFolder(
          id: _unfiledFolderId,
          title: unfiledTitle,
          updatedAt: 0,
        ),
      );
    _docs.clear();
    _activeId = null;
    _lastStamp = 0;
    _quotaExceeded = false;
    _loadProtected = false;
    _requiresReload = false;
  }

  _WorkspaceState _snapshot() => _WorkspaceState(
    workspaceId: _workspaceId,
    unfiledFolderId: _unfiledFolderId,
    folders: _folders,
    docs: _docs,
    activeId: _activeId,
  );

  int _stamp() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    _lastStamp = now > _lastStamp ? now : _lastStamp + 1;
    return _lastStamp;
  }

  String _newUniqueId(Set<String> used) {
    for (int attempt = 0; attempt < 1000; attempt++) {
      final String candidate = _idFactory();
      if (isWorkspaceUuid(candidate) && !used.contains(candidate)) {
        return candidate;
      }
    }
    throw StateError('The workspace id factory did not produce a unique UUID.');
  }

  bool _isDescendant(String? candidateId, String ancestorId) {
    String? cursor = candidateId;
    final Set<String> seen = <String>{};
    while (cursor != null && seen.add(cursor)) {
      if (cursor == ancestorId) return true;
      cursor = folderById(cursor)?.parentId;
    }
    return false;
  }

  void _requireReady() {
    if (!_isReady) {
      throw StateError('The workspace repository has not finished loading.');
    }
  }

  void _requireWritable() {
    if (_loadProtected || _requiresReload) {
      throw StateError(
        _requiresReload
            ? 'This workspace changed in another browser tab. Export this tab '
                  'before reloading.'
            : 'The saved workspace is protected from overwrite. Export or '
                  'import a workspace before creating documents.',
      );
    }
  }

  void _trackWrite(Future<void> pending) {
    _writeTail = pending;
    pending.whenComplete(() {
      if (identical(_writeTail, pending)) _writeTail = null;
    });
  }

  Future<void> _finishAsyncWrite(Future<bool> result, int revision) async {
    try {
      _finishWrite(revision, await result);
    } catch (_) {
      _finishWrite(revision, false);
    }
  }

  void _finishWrite(int revision, bool stored) {
    if (revision != _saveRevision) return;
    if (stored) {
      _persistedRevision = revision;
      _quotaExceeded = false;
      _lastError = null;
    } else {
      _syncRepositoryConflict();
      _quotaExceeded = !_requiresReload;
      final WorkspaceRepository source = repository;
      final RecoverableWorkspaceRepository? recoverable =
          source is RecoverableWorkspaceRepository
          ? source as RecoverableWorkspaceRepository
          : null;
      _lastError = recoverable?.lastFailure;
      _lastError ??=
          'Browser storage is full, so this change was not saved. '
          'Export the document to keep it.';
    }
    if (_writeTail != null) notifyListeners();
  }

  String? _repositoryFailure() {
    final WorkspaceRepository source = repository;
    if (source is! RecoverableWorkspaceRepository) return null;
    final RecoverableWorkspaceRepository recoverable =
        source as RecoverableWorkspaceRepository;
    return recoverable.lastFailure;
  }

  void _syncRepositoryConflict() {
    final WorkspaceRepository source = repository;
    if (source is ObservableWorkspaceRepository &&
        (source as ObservableWorkspaceRepository).requiresReload) {
      _requiresReload = true;
    }
  }

  void _handleRepositoryNotice(WorkspaceRepositoryNotice notice) {
    if (notice.kind == WorkspaceRepositoryNoticeKind.changed &&
        notice.key != storageKey) {
      return;
    }
    _requiresReload = true;
    _quotaExceeded = false;
    _lastError = notice.kind == WorkspaceRepositoryNoticeKind.cleared
        ? 'Local workspace data was reset in another browser tab. Export this '
              'tab before reloading if it contains work you need.'
        : 'This workspace changed in another browser tab. Export this tab '
              'before reloading to choose which version to keep.';
    notifyListeners();
  }

  @override
  void dispose() {
    final WorkspaceRepository source = repository;
    if (source is ObservableWorkspaceRepository) {
      final ObservableWorkspaceRepository observable =
          source as ObservableWorkspaceRepository;
      observable.setNoticeListener(null);
    }
    super.dispose();
  }

  String? _mergeWarnings(String? first, String? second) {
    if (first == null || first.isEmpty) return second;
    if (second == null || second.isEmpty) return first;
    return '$first $second';
  }

  int _repairFolderTree(List<WorkspaceFolder> folders, String unfiledId) {
    int repaired = 0;
    final Map<String, WorkspaceFolder> byId = <String, WorkspaceFolder>{
      for (final WorkspaceFolder folder in folders) folder.id: folder,
    };
    for (final WorkspaceFolder folder in folders) {
      if (folder.id == unfiledId) continue;
      final String? parentId = folder.parentId;
      if (parentId != null && !byId.containsKey(parentId)) {
        folder.parentId = unfiledId;
        repaired++;
      }
    }
    for (final WorkspaceFolder folder in folders) {
      if (folder.id == unfiledId) continue;
      final Set<String> seen = <String>{folder.id};
      String? cursor = folder.parentId;
      while (cursor != null) {
        if (!seen.add(cursor)) {
          folder.parentId = unfiledId;
          repaired++;
          break;
        }
        cursor = byId[cursor]?.parentId;
      }
    }
    return repaired;
  }

  static WorkspaceDoc _newest(List<WorkspaceDoc> docs) {
    WorkspaceDoc newest = docs.first;
    for (int index = 1; index < docs.length; index++) {
      if (docs[index].updatedAt > newest.updatedAt) newest = docs[index];
    }
    return newest;
  }
}

class _WorkspaceState {
  const _WorkspaceState({
    required this.workspaceId,
    required this.unfiledFolderId,
    required this.folders,
    required this.docs,
    required this.activeId,
  });

  final String workspaceId;
  final String unfiledFolderId;
  final List<WorkspaceFolder> folders;
  final List<WorkspaceDoc> docs;
  final String? activeId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': Workspace.schemaVersion,
    'workspaceId': workspaceId,
    'unfiledFolderId': unfiledFolderId,
    'folders': folders
        .map((WorkspaceFolder folder) => folder.toJson())
        .toList(),
    'documents': docs.map((WorkspaceDoc doc) => doc.toJson()).toList(),
    'activeDocumentId': activeId,
  };
}

class _DecodedWorkspace {
  const _DecodedWorkspace(this.state, this.warning);

  final _WorkspaceState state;
  final String? warning;
}

class _FutureWorkspaceVersion implements Exception {
  const _FutureWorkspaceVersion(this.message);

  final String message;
}

final RegExp _workspaceUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool isWorkspaceUuid(String value) => _workspaceUuidPattern.hasMatch(value);

String newWorkspaceUuid() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

String normalizeWorkspaceTitle(Object? raw, {required String fallback}) {
  if (raw is! String) return fallback;
  final StringBuffer out = StringBuffer();
  for (final int rune in raw.trim().runes) {
    if (rune >= 32 && rune != 127) out.writeCharCode(rune);
    if (out.length >= 120) break;
  }
  final String title = out.toString().trim();
  return title.isEmpty ? fallback : title;
}

bool _isJson(String raw) {
  try {
    jsonDecode(raw);
    return true;
  } catch (_) {
    return false;
  }
}
