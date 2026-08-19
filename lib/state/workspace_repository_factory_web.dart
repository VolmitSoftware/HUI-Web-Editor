library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../services/storage_service.dart';
import 'workspace_repository_contract.dart';

WorkspaceRepository createPlatformWorkspaceRepository() =>
    IndexedDbWorkspaceRepository();

final class IndexedDbWorkspaceRepository
    implements
        WorkspaceRepository,
        RecoverableWorkspaceRepository,
        WorkspaceMaintenanceRepository,
        ObservableWorkspaceRepository {
  static const String _databaseName = 'gloss.editor';
  static const String _legacyDatabaseName = 'holoui.editor';
  static const String _recordsStore = 'workspace-records';
  static const String _backupsStore = 'workspace-backups';
  static const String _channelName = 'gloss.workspace.changes';
  static const String _legacyChannelName = 'holoui.workspace.changes';
  static const String _indexedDbUnavailable =
      'IndexedDB could not be opened. Existing localStorage data was left '
      'untouched.';

  IndexedDbWorkspaceRepository() {
    try {
      _channel = web.BroadcastChannel(_channelName);
      _channel!.onmessage = ((web.MessageEvent event) {
        _receiveBroadcast(event.data);
      }).toJS;
    } catch (_) {
      _channel = null;
    }
    // A tab still running the HoloUI-branded editor announces on the old
    // channel with old key names; translate so its writes surface as conflicts
    // here instead of being silently ignored.
    try {
      _legacyChannel = web.BroadcastChannel(_legacyChannelName);
      _legacyChannel!.onmessage = ((web.MessageEvent event) {
        _receiveBroadcast(event.data, translateLegacyKeys: true);
      }).toJS;
    } catch (_) {
      _legacyChannel = null;
    }
  }

  final Map<String, int> _knownRevisions = <String, int>{};
  late final String _sourceId = _newSourceId();
  Future<web.IDBDatabase>? _database;
  web.IDBDatabase? _openedDatabase;
  web.BroadcastChannel? _channel;
  web.BroadcastChannel? _legacyChannel;
  bool _legacyDatabaseAbsent = false;
  WorkspaceRepositoryNoticeListener? _noticeListener;
  String? _lastFailure;
  bool _databaseUnavailable = false;
  bool _requiresReload = false;

  @override
  String? get lastFailure => _lastFailure;

  @override
  bool get requiresReload => _requiresReload;

  @override
  void setNoticeListener(WorkspaceRepositoryNoticeListener? listener) {
    _noticeListener = listener;
  }

  @override
  Future<String?> read(String key) async {
    _lastFailure = null;
    final web.IDBDatabase? database = await _openOrNull();
    if (database == null) {
      return StorageService.read(key);
    }
    final _RecordReadResult stored = await _readRecord(
      database,
      _recordsStore,
      key,
    );
    if (stored.kind == _RecordReadKind.valid) {
      final _StoredRecord record = stored.record!;
      _knownRevisions[key] = record.revision;
      return record.value;
    }
    if (stored.kind == _RecordReadKind.malformed) {
      _knownRevisions[key] = stored.revision;
      _lastFailure =
          'The IndexedDB workspace record was malformed and was left untouched.';
      throw WorkspaceRepositoryCorruption(_lastFailure!);
    }

    final String? fromLegacyDatabase = await _migrateLegacyRecord(key);
    if (fromLegacyDatabase != null) return fromLegacyDatabase;

    final String? legacy = StorageService.read(key);
    if (legacy == null || legacy.isEmpty) return null;
    final bool migrated = await write(key, legacy);
    if (!migrated) {
      _lastFailure ??=
          'The local workspace was opened, but IndexedDB migration failed. '
          'The localStorage copy was retained.';
    }
    return legacy;
  }

  /// One-time rescue of a record written by the HoloUI-branded editor: reads
  /// the old `holoui.editor` database under the old key name and rewrites the
  /// record (and its backup) under the new identity. The old database is left
  /// untouched so an older deployed editor still finds its data; [clear]
  /// deletes it so a reset cannot resurrect anything.
  Future<String?> _migrateLegacyRecord(String key) async {
    if (_legacyDatabaseAbsent) return null;
    final String legacyKey = key.startsWith(StorageService.keyPrefix)
        ? StorageService.legacyKeyPrefix +
              key.substring(StorageService.keyPrefix.length)
        : key;
    web.IDBDatabase? legacy;
    try {
      legacy = await _openLegacyDatabase();
      if (legacy == null) {
        _legacyDatabaseAbsent = true;
        return null;
      }
      if (!legacy.objectStoreNames.contains(_recordsStore)) return null;
      final _RecordReadResult stored = await _readRecord(
        legacy,
        _recordsStore,
        legacyKey,
      );
      if (stored.kind != _RecordReadKind.valid) return null;
      final String value = stored.record!.value;
      if (value.isEmpty) return null;
      _RecordReadResult backup = const _RecordReadResult.missing();
      if (legacy.objectStoreNames.contains(_backupsStore)) {
        try {
          backup = await _readRecord(legacy, _backupsStore, legacyKey);
        } catch (_) {}
      }
      final bool migrated = await write(key, value);
      if (!migrated) {
        _lastFailure ??=
            'The saved HoloUI workspace was found, but could not be migrated '
            'into the new database. The original copy was left untouched.';
      } else if (backup.kind == _RecordReadKind.valid) {
        await _putMigratedBackup(key, backup.record!);
      }
      return value;
    } catch (_) {
      return null;
    } finally {
      try {
        legacy?.close();
      } catch (_) {}
    }
  }

  /// Opens the pre-rebrand database without creating it: a fresh browser hits
  /// `onupgradeneeded`, which aborts the versionchange transaction so no empty
  /// `holoui.editor` database is left behind.
  Future<web.IDBDatabase?> _openLegacyDatabase() {
    final Completer<web.IDBDatabase?> completer = Completer<web.IDBDatabase?>();
    try {
      final web.IDBOpenDBRequest request = web.window.indexedDB.open(
        _legacyDatabaseName,
      );
      request.onupgradeneeded = ((web.Event event) {
        try {
          request.transaction?.abort();
        } catch (_) {}
      }).toJS;
      request.onsuccess = ((web.Event event) {
        final web.IDBDatabase database = request.result as web.IDBDatabase;
        if (completer.isCompleted) {
          database.close();
          return;
        }
        completer.complete(database);
      }).toJS;
      request.onerror = ((web.Event event) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;
      request.onblocked = ((web.Event event) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  /// Carries the pre-rebrand backup entry over so recovery depth survives the
  /// migration. Best-effort: the freshly migrated record is already stored.
  Future<void> _putMigratedBackup(String key, _StoredRecord record) async {
    final web.IDBDatabase? database = await _openOrNull();
    if (database == null) return;
    final Completer<void> completer = Completer<void>();
    try {
      final web.IDBTransaction transaction = database.transaction(
        _backupsStore.toJS,
        'readwrite',
      );
      transaction.objectStore(_backupsStore).put(_encodeRecord(record), key.toJS);
      transaction.oncomplete = ((web.Event event) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      transaction.onabort = ((web.Event event) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      transaction.onerror = ((web.Event event) {}).toJS;
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  @override
  Future<String?> readBackup(String key) async {
    final web.IDBDatabase? database = await _openOrNull();
    if (database == null) return StorageService.read(key);
    final _RecordReadResult backup = await _readRecord(
      database,
      _backupsStore,
      key,
    );
    return backup.record?.value;
  }

  @override
  String? readRetainedCopy(String key) => StorageService.read(key);

  @override
  Future<bool> write(String key, String value) {
    _lastFailure = null;
    if (_requiresReload) {
      _lastFailure =
          'This workspace changed in another browser tab. Export this tab '
          'before reloading to choose which version to keep.';
      return Future<bool>.value(false);
    }
    final web.IDBDatabase? opened = _openedDatabase;
    if (opened != null) return _writeOpened(opened, key, value);
    return _writeAfterOpen(key, value);
  }

  Future<bool> _writeAfterOpen(String key, String value) async {
    final web.IDBDatabase? database = await _openOrNull();
    if (database == null) {
      _lastFailure =
          'IndexedDB is unavailable, so this change remains unsaved. Export '
          'the workspace before closing this tab.';
      return false;
    }
    return _writeOpened(database, key, value);
  }

  Future<bool> _writeOpened(
    web.IDBDatabase database,
    String key,
    String value,
  ) {
    final Completer<bool> completer = Completer<bool>();
    try {
      final web.IDBTransaction transaction = database.transaction(
        <JSString>[_recordsStore.toJS, _backupsStore.toJS].toJS,
        'readwrite',
      );
      final web.IDBObjectStore records = transaction.objectStore(_recordsStore);
      final web.IDBObjectStore backups = transaction.objectStore(_backupsStore);
      final web.IDBRequest currentRequest = records.get(key.toJS);
      int nextRevision = 1;
      bool conflict = false;

      currentRequest.onsuccess = ((web.Event event) {
        final _RecordReadResult decoded = _decodeRecord(currentRequest.result);
        if (decoded.kind == _RecordReadKind.malformed) {
          _requiresReload = true;
          _lastFailure =
              'The IndexedDB workspace record became malformed and was left '
              'untouched. Export this tab before reloading.';
          transaction.abort();
          return;
        }
        final _StoredRecord? current = decoded.record;
        final int actualRevision = decoded.revision;
        final int expectedRevision = _knownRevisions[key] ?? 0;
        if (actualRevision != expectedRevision) {
          conflict = true;
          _markConflict();
          transaction.abort();
          return;
        }
        nextRevision = actualRevision + 1;
        if (current != null) {
          backups.put(_encodeRecord(current), key.toJS);
        }
        records.put(
          _encodeRecord(_StoredRecord(value: value, revision: nextRevision)),
          key.toJS,
        );
      }).toJS;
      currentRequest.onerror = ((web.Event event) {
        _lastFailure = 'The saved workspace could not be inspected.';
      }).toJS;
      transaction.oncomplete = ((web.Event event) {
        _knownRevisions[key] = nextRevision;
        _broadcastChange(key, nextRevision);
        _complete(completer, true);
      }).toJS;
      transaction.onabort = ((web.Event event) {
        if (!conflict) {
          _lastFailure ??=
              'Browser storage refused the workspace transaction. Export '
              'the workspace before closing this tab.';
        }
        _complete(completer, false);
      }).toJS;
      transaction.onerror = ((web.Event event) {
        _lastFailure ??=
            'Browser storage refused the workspace transaction. Export the '
            'workspace before closing this tab.';
      }).toJS;
    } catch (_) {
      _lastFailure =
          'Browser storage refused the workspace transaction. Export the '
          'workspace before closing this tab.';
      return Future<bool>.value(false);
    }
    return completer.future;
  }

  @override
  Future<bool> restore(String key, String value) {
    _lastFailure = null;
    final web.IDBDatabase? opened = _openedDatabase;
    if (opened != null) return _restoreOpened(opened, key, value);
    return _restoreAfterOpen(key, value);
  }

  Future<bool> _restoreAfterOpen(String key, String value) async {
    final web.IDBDatabase? database = await _openOrNull();
    if (database == null) return false;
    return _restoreOpened(database, key, value);
  }

  Future<bool> _restoreOpened(
    web.IDBDatabase database,
    String key,
    String value,
  ) {
    final Completer<bool> completer = Completer<bool>();
    try {
      final web.IDBTransaction transaction = database.transaction(
        <JSString>[_recordsStore.toJS, _backupsStore.toJS].toJS,
        'readwrite',
      );
      final web.IDBObjectStore records = transaction.objectStore(_recordsStore);
      final web.IDBObjectStore backups = transaction.objectStore(_backupsStore);
      final web.IDBRequest currentRequest = records.get(key.toJS);
      int nextRevision = 1;
      bool conflict = false;
      currentRequest.onsuccess = ((web.Event event) {
        final _RecordReadResult current = _decodeRecord(currentRequest.result);
        final int actualRevision = current.revision;
        final int expectedRevision = _knownRevisions[key] ?? 0;
        if (actualRevision != expectedRevision) {
          conflict = true;
          _markConflict();
          transaction.abort();
          return;
        }
        nextRevision = actualRevision + 1;
        final _StoredRecord recovered = _StoredRecord(
          value: value,
          revision: nextRevision,
        );
        final JSAny encoded = _encodeRecord(recovered);
        backups.put(encoded, key.toJS);
        records.put(encoded, key.toJS);
      }).toJS;
      currentRequest.onerror = ((web.Event event) {
        _lastFailure = 'The damaged workspace could not be inspected.';
      }).toJS;
      transaction.oncomplete = ((web.Event event) {
        _knownRevisions[key] = nextRevision;
        _requiresReload = false;
        _broadcastChange(key, nextRevision);
        _complete(completer, true);
      }).toJS;
      transaction.onabort = ((web.Event event) {
        if (!conflict) {
          _lastFailure ??=
              'Browser storage refused to restore the recovered workspace.';
        }
        _complete(completer, false);
      }).toJS;
      transaction.onerror = ((web.Event event) {
        _lastFailure ??=
            'Browser storage refused to restore the recovered workspace.';
      }).toJS;
    } catch (_) {
      _lastFailure =
          'Browser storage refused to restore the recovered workspace.';
      return Future<bool>.value(false);
    }
    return completer.future;
  }

  @override
  Future<bool> clear() {
    _lastFailure = null;
    final web.IDBDatabase? opened = _openedDatabase;
    if (opened != null) return _clearOpened(opened);
    return _clearAfterOpen();
  }

  Future<bool> _clearAfterOpen() async {
    final web.IDBDatabase? database = await _openOrNull();
    if (database == null) return false;
    return _clearOpened(database);
  }

  Future<bool> _clearOpened(web.IDBDatabase database) {
    final Completer<bool> completer = Completer<bool>();
    try {
      final web.IDBTransaction transaction = database.transaction(
        <JSString>[_recordsStore.toJS, _backupsStore.toJS].toJS,
        'readwrite',
      );
      transaction.objectStore(_recordsStore).clear();
      transaction.objectStore(_backupsStore).clear();
      transaction.oncomplete = ((web.Event event) {
        _knownRevisions.clear();
        _requiresReload = false;
        _deleteLegacyDatabase();
        _broadcastClear();
        _complete(completer, true);
      }).toJS;
      transaction.onabort = ((web.Event event) {
        _lastFailure = 'Browser storage refused to clear the workspace.';
        _complete(completer, false);
      }).toJS;
      transaction.onerror = ((web.Event event) {
        _lastFailure = 'Browser storage refused to clear the workspace.';
      }).toJS;
    } catch (_) {
      _lastFailure = 'Browser storage refused to clear the workspace.';
      return Future<bool>.value(false);
    }
    return completer.future;
  }

  /// Best-effort removal of the pre-rebrand database after an explicit reset,
  /// so [_migrateLegacyRecord] cannot resurrect cleared data. May be blocked
  /// by an old tab holding the database open; that is fine — this tab's
  /// [_legacyDatabaseAbsent] latch already stops re-migration for the session.
  void _deleteLegacyDatabase() {
    _legacyDatabaseAbsent = true;
    try {
      web.window.indexedDB.deleteDatabase(_legacyDatabaseName);
    } catch (_) {}
  }

  Future<web.IDBDatabase?> _openOrNull() async {
    if (_databaseUnavailable) {
      _lastFailure = _indexedDbUnavailable;
      return null;
    }
    try {
      _database ??= _openDatabase();
      return await _database!;
    } catch (_) {
      _databaseUnavailable = true;
      _lastFailure = _indexedDbUnavailable;
      return null;
    }
  }

  Future<web.IDBDatabase> _openDatabase() {
    final Completer<web.IDBDatabase> completer = Completer<web.IDBDatabase>();
    final web.IDBOpenDBRequest request = web.window.indexedDB.open(
      _databaseName,
      1,
    );
    request.onupgradeneeded = ((web.Event event) {
      final web.IDBDatabase database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_recordsStore)) {
        database.createObjectStore(_recordsStore);
      }
      if (!database.objectStoreNames.contains(_backupsStore)) {
        database.createObjectStore(_backupsStore);
      }
    }).toJS;
    request.onsuccess = ((web.Event event) {
      final web.IDBDatabase database = request.result as web.IDBDatabase;
      _openedDatabase = database;
      database.onversionchange = ((web.Event event) {
        database.close();
        if (identical(_openedDatabase, database)) _openedDatabase = null;
        _database = null;
      }).toJS;
      database.onclose = ((web.Event event) {
        if (identical(_openedDatabase, database)) _openedDatabase = null;
        _database = null;
      }).toJS;
      if (completer.isCompleted) {
        database.close();
        return;
      }
      completer.complete(database);
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          request.error ?? StateError('IndexedDB open failed.'),
        );
      }
    }).toJS;
    request.onblocked = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB upgrade was blocked by another tab.'),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<_RecordReadResult> _readRecord(
    web.IDBDatabase database,
    String storeName,
    String key,
  ) {
    final Completer<_RecordReadResult> completer =
        Completer<_RecordReadResult>();
    try {
      final web.IDBTransaction transaction = database.transaction(
        storeName.toJS,
        'readonly',
      );
      final web.IDBRequest request = transaction
          .objectStore(storeName)
          .get(key.toJS);
      request.onsuccess = ((web.Event event) {
        if (!completer.isCompleted) {
          completer.complete(_decodeRecord(request.result));
        }
      }).toJS;
      request.onerror = ((web.Event event) {
        if (!completer.isCompleted) {
          completer.completeError(
            request.error ?? StateError('IndexedDB read failed.'),
          );
        }
      }).toJS;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  JSAny _encodeRecord(_StoredRecord record) => <String, Object>{
    'value': record.value,
    'revision': record.revision,
  }.jsify()!;

  _RecordReadResult _decodeRecord(JSAny? raw) {
    if (raw == null) return const _RecordReadResult.missing();
    if (raw.isA<JSString>()) {
      final JSString value = raw as JSString;
      return _RecordReadResult.valid(
        _StoredRecord(value: value.toDart, revision: 0),
      );
    }
    final Object? decoded = raw.dartify();
    if (decoded is! Map) return const _RecordReadResult.malformed();
    final Object? value = decoded['value'];
    final Object? revision = decoded['revision'];
    final bool validRevision =
        revision is num &&
        revision.toDouble().isFinite &&
        revision.toInt() >= 0 &&
        revision.toDouble() == revision.toInt().toDouble();
    if (value is! String || !validRevision) {
      return _RecordReadResult.malformed(
        revision: validRevision ? revision.toInt() : 0,
      );
    }
    return _RecordReadResult.valid(
      _StoredRecord(value: value, revision: revision.toInt()),
    );
  }

  void _broadcastChange(String key, int revision) {
    _broadcast(<String, Object>{
      'kind': 'changed',
      'key': key,
      'revision': revision,
      'source': _sourceId,
    });
  }

  void _broadcastClear() {
    _broadcast(<String, Object>{'kind': 'cleared', 'source': _sourceId});
  }

  void _broadcast(Map<String, Object> message) {
    final web.BroadcastChannel? channel = _channel;
    if (channel == null) return;
    try {
      channel.postMessage(jsonEncode(message).toJS);
    } catch (_) {}
  }

  void _receiveBroadcast(JSAny? raw, {bool translateLegacyKeys = false}) {
    if (raw == null || !raw.isA<JSString>()) return;
    final JSString message = raw as JSString;
    try {
      final Object? decoded = jsonDecode(message.toDart);
      if (decoded is! Map) return;
      final Object? kind = decoded['kind'];
      Object? key = decoded['key'];
      if (translateLegacyKeys &&
          key is String &&
          key.startsWith(StorageService.legacyKeyPrefix)) {
        key =
            StorageService.keyPrefix +
            key.substring(StorageService.legacyKeyPrefix.length);
      }
      final Object? revision = decoded['revision'];
      final Object? source = decoded['source'];
      if (source == _sourceId) return;
      if (kind == 'cleared') {
        _requiresReload = true;
        _lastFailure =
            'Local workspace data was reset in another browser tab. Export '
            'this tab before reloading if it contains work you need.';
        _noticeListener?.call(
          const WorkspaceRepositoryNotice(
            kind: WorkspaceRepositoryNoticeKind.cleared,
            key: '',
          ),
        );
        return;
      }
      if (kind != 'changed' || key is! String || revision is! num) return;
      final int remoteRevision = revision.toInt();
      final int localRevision = _knownRevisions[key] ?? 0;
      if (remoteRevision > localRevision) {
        _markConflict();
        _noticeListener?.call(
          WorkspaceRepositoryNotice(
            kind: WorkspaceRepositoryNoticeKind.changed,
            key: key,
            revision: remoteRevision,
          ),
        );
      }
    } catch (_) {}
  }

  void _markConflict() {
    _requiresReload = true;
    _lastFailure =
        'This workspace changed in another browser tab. Export this tab '
        'before reloading to choose which version to keep.';
  }

  String _newSourceId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  void _complete(Completer<bool> completer, bool value) {
    if (!completer.isCompleted) completer.complete(value);
  }
}

enum _RecordReadKind { missing, valid, malformed }

final class _RecordReadResult {
  const _RecordReadResult.missing()
    : kind = _RecordReadKind.missing,
      record = null,
      revision = 0;

  _RecordReadResult.valid(_StoredRecord value)
    : kind = _RecordReadKind.valid,
      record = value,
      revision = value.revision;

  const _RecordReadResult.malformed({this.revision = 0})
    : kind = _RecordReadKind.malformed,
      record = null;

  final _RecordReadKind kind;
  final _StoredRecord? record;
  final int revision;
}

final class _StoredRecord {
  const _StoredRecord({required this.value, required this.revision});

  final String value;
  final int revision;
}
