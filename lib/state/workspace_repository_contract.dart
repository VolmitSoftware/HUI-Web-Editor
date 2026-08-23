library;

import 'dart:async';

import '../l10n/hui_localizations.dart';
import '../services/storage_service.dart';

typedef WorkspaceStorageReader = String? Function(String key);
typedef WorkspaceStorageWriter = bool Function(String key, String value);
typedef WorkspaceRepositoryNoticeListener =
    void Function(WorkspaceRepositoryNotice notice);

enum WorkspaceRepositoryNoticeKind { changed, cleared }

final class WorkspaceRepositoryNotice {
  const WorkspaceRepositoryNotice({
    required this.kind,
    required this.key,
    this.revision,
  });

  final WorkspaceRepositoryNoticeKind kind;
  final String key;
  final int? revision;
}

final class WorkspaceRepositoryCorruption implements Exception {
  const WorkspaceRepositoryCorruption(this._message);

  final String _message;

  String get message => huiText(_message);

  @override
  String toString() => message;
}

abstract interface class WorkspaceRepository {
  FutureOr<String?> read(String key);

  FutureOr<bool> write(String key, String value);
}

abstract interface class RecoverableWorkspaceRepository {
  FutureOr<String?> readBackup(String key);

  FutureOr<String?> readRetainedCopy(String key);

  FutureOr<bool> restore(String key, String value);

  String? get lastFailure;
}

abstract interface class ObservableWorkspaceRepository {
  bool get requiresReload;

  void setNoticeListener(WorkspaceRepositoryNoticeListener? listener);
}

abstract interface class WorkspaceMaintenanceRepository {
  FutureOr<bool> clear();
}

final class CallbackWorkspaceRepository implements WorkspaceRepository {
  const CallbackWorkspaceRepository({
    required this.reader,
    required this.writer,
  });

  final WorkspaceStorageReader reader;
  final WorkspaceStorageWriter writer;

  @override
  String? read(String key) => reader(key);

  @override
  bool write(String key, String value) => writer(key, value);
}

final class CallbackWorkspaceMaintenanceRepository
    implements WorkspaceRepository, WorkspaceMaintenanceRepository {
  const CallbackWorkspaceMaintenanceRepository({
    required this.reader,
    required this.writer,
    required this.clearer,
  });

  final WorkspaceStorageReader reader;
  final WorkspaceStorageWriter writer;
  final bool Function() clearer;

  @override
  String? read(String key) => reader(key);

  @override
  bool write(String key, String value) => writer(key, value);

  @override
  bool clear() => clearer();
}

final class LocalStorageWorkspaceRepository
    implements
        WorkspaceRepository,
        RecoverableWorkspaceRepository,
        WorkspaceMaintenanceRepository {
  const LocalStorageWorkspaceRepository();

  @override
  String? get lastFailure => null;

  @override
  String? read(String key) => StorageService.read(key);

  @override
  String? readBackup(String key) => null;

  @override
  String? readRetainedCopy(String key) => StorageService.read(key);

  @override
  bool restore(String key, String value) => StorageService.write(key, value);

  @override
  bool write(String key, String value) => StorageService.write(key, value);

  @override
  bool clear() {
    final bool current = StorageService.remove('gloss.workspace.v2');
    final bool legacy = StorageService.remove('gloss.workspace.v1');
    // Pre-rebrand copies must go too, or the one-time key migration could
    // resurrect them after a reset.
    StorageService.remove('holoui.workspace.v2');
    StorageService.remove('holoui.workspace.v1');
    return current && legacy;
  }
}
