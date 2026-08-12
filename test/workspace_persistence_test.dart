library;

import 'dart:async';
import 'dart:convert';

import 'package:holoui_editor/state/editor_store.dart';
import 'package:holoui_editor/state/workspace.dart';
import 'package:holoui_editor/state/workspace_repository.dart';
import 'package:test/test.dart';

final class _DeferredRepository implements WorkspaceRepository {
  final Map<String, String> values = <String, String>{};
  final List<_PendingWrite> writes = <_PendingWrite>[];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> write(String key, String value) {
    final Completer<bool> completer = Completer<bool>();
    writes.add(_PendingWrite(key: key, value: value, completer: completer));
    return completer.future.then((bool stored) {
      if (stored) values[key] = value;
      return stored;
    });
  }

  Future<void> completeNext(bool stored) async {
    final _PendingWrite pending = writes.removeAt(0);
    pending.completer.complete(stored);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }
}

final class _PendingWrite {
  const _PendingWrite({
    required this.key,
    required this.value,
    required this.completer,
  });

  final String key;
  final String value;
  final Completer<bool> completer;
}

final class _RecoverableRepository
    implements
        WorkspaceRepository,
        RecoverableWorkspaceRepository,
        WorkspaceMaintenanceRepository,
        ObservableWorkspaceRepository {
  _RecoverableRepository({
    this.current,
    this.backup,
    this.retained,
    this.throwCorruption = false,
    this.throwReadFailure = false,
    this.throwBackupFailure = false,
  });

  String? current;
  String? backup;
  String? retained;
  bool throwCorruption;
  bool throwReadFailure;
  bool throwBackupFailure;
  int writeCount = 0;
  WorkspaceRepositoryNoticeListener? listener;

  @override
  bool requiresReload = false;

  @override
  String? get lastFailure => null;

  @override
  String? read(String key) {
    if (key == Workspace.storageKey && throwReadFailure) {
      throw StateError('Workspace read failed.');
    }
    if (key == Workspace.storageKey && throwCorruption) {
      throw const WorkspaceRepositoryCorruption('Malformed record.');
    }
    return key == Workspace.storageKey ? current : null;
  }

  @override
  String? readBackup(String key) {
    if (key == Workspace.storageKey && throwBackupFailure) {
      throw StateError('Backup read failed.');
    }
    return key == Workspace.storageKey ? backup : null;
  }

  @override
  String? readRetainedCopy(String key) =>
      key == Workspace.storageKey ? retained : null;

  @override
  bool restore(String key, String value) {
    writeCount++;
    if (key != Workspace.storageKey) return false;
    current = value;
    backup = value;
    return true;
  }

  @override
  bool write(String key, String value) {
    writeCount++;
    if (key != Workspace.storageKey) return false;
    backup = current;
    current = value;
    return true;
  }

  @override
  bool clear() {
    current = null;
    backup = null;
    requiresReload = false;
    return true;
  }

  @override
  void setNoticeListener(WorkspaceRepositoryNoticeListener? value) {
    listener = value;
  }

  void emit(WorkspaceRepositoryNotice notice) {
    requiresReload = true;
    listener?.call(notice);
  }
}

Map<String, dynamic> _workspacePayload() => <String, dynamic>{
  'schemaVersion': Workspace.schemaVersion,
  'workspaceId': '00000000-0000-4000-8000-000000000001',
  'unfiledFolderId': '00000000-0000-4000-8000-000000000002',
  'folders': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000002',
      'title': Workspace.unfiledTitle,
      'parentId': null,
      'updatedAt': 0,
    },
  ],
  'documents': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000003',
      'title': 'Recovered menu',
      'runtimeId': 'recovered',
      'json': '{}',
      'updatedAt': 1,
      'kind': 'menu',
      'folderId': '00000000-0000-4000-8000-000000000002',
    },
  ],
  'activeDocumentId': '00000000-0000-4000-8000-000000000003',
};

void main() {
  test(
    'async write failure keeps the editor dirty until a commit succeeds',
    () async {
      final _DeferredRepository repository = _DeferredRepository();
      final Workspace workspace = await Workspace.open(repository: repository);
      final EditorStore store = EditorStore(
        workspace: workspace,
        autosaveDelay: const Duration(days: 1),
      );

      expect(repository.writes, hasLength(1));
      await repository.completeNext(true);
      expect(workspace.hasUnsavedChanges, isFalse);

      store.menuId = 'first-change';
      store.flushAutosave();
      expect(store.hasUnsavedChanges, isTrue);
      await repository.completeNext(false);
      expect(store.hasUnsavedChanges, isTrue);
      expect(workspace.lastError, contains('not saved'));

      final Future<bool> retry = store.retryAutosave();
      expect(repository.writes, hasLength(1));
      await repository.completeNext(true);
      expect(await retry, isTrue);
      expect(store.hasUnsavedChanges, isFalse);

      store.menuId = 'second-change';
      store.flushAutosave();
      await repository.completeNext(true);
      expect(store.hasUnsavedChanges, isFalse);
      expect(workspace.lastError, isNull);
      store.dispose();
    },
  );

  test('an unreadable current transaction restores the valid backup', () async {
    final _RecoverableRepository repository = _RecoverableRepository(
      current: '{broken',
      backup: jsonEncode(_workspacePayload()),
    );
    final Workspace workspace = await Workspace.open(repository: repository);

    expect(workspace.active?.runtimeId, 'recovered');
    expect(workspace.isLoadProtected, isFalse);
    expect(workspace.lastError, contains('previous transaction was restored'));
    expect(repository.writeCount, 1);
    expect(repository.current, jsonEncode(_workspacePayload()));
    expect(repository.backup, jsonEncode(_workspacePayload()));
  });

  test(
    'unrecoverable storage is protected from blank startup writes',
    () async {
      final _RecoverableRepository repository = _RecoverableRepository(
        current: '{broken',
      );
      final Workspace workspace = await Workspace.open(repository: repository);

      expect(workspace.isLoadProtected, isTrue);
      expect(workspace.docs, isEmpty);
      expect(repository.writeCount, 0);

      final EditorStore store = EditorStore(
        workspace: workspace,
        autosaveDelay: const Duration(days: 1),
      );
      expect(workspace.docs, isEmpty);
      expect(repository.writeCount, 0);
      store.menuId = 'must-not-overwrite';
      store.flushAutosave();
      expect(repository.writeCount, 0);
      expect(store.hasUnsavedChanges, isTrue);
      store.dispose();
    },
  );

  test('reset clears the current and recovery transactions together', () async {
    final String payload = jsonEncode(_workspacePayload());
    final _RecoverableRepository repository = _RecoverableRepository(
      current: payload,
      backup: payload,
    );
    final Workspace workspace = await Workspace.open(repository: repository);

    expect(await workspace.reset(), isTrue);
    expect(workspace.docs, isEmpty);
    expect(workspace.isLoadProtected, isFalse);
    expect(repository.current, isNull);
    expect(repository.backup, isNull);
  });

  test('a refused bundle replacement does not invent unsaved state', () async {
    final _DeferredRepository repository = _DeferredRepository();
    final Workspace workspace = await Workspace.open(repository: repository);

    final Future<bool> replacement = workspace.replacePortableState(
      _workspacePayload(),
    );
    expect(repository.writes, hasLength(1));
    await repository.completeNext(false);

    expect(await replacement, isFalse);
    expect(workspace.docs, isEmpty);
    expect(workspace.hasUnsavedChanges, isFalse);
  });

  test(
    'a malformed repository record recovers without treating it as missing',
    () async {
      final String payload = jsonEncode(_workspacePayload());
      final _RecoverableRepository repository = _RecoverableRepository(
        backup: payload,
        throwCorruption: true,
      );

      final Workspace workspace = await Workspace.open(repository: repository);

      expect(workspace.active?.runtimeId, 'recovered');
      expect(repository.current, payload);
      expect(repository.backup, payload);
    },
  );

  test('an all-rejected current workspace recovers from its backup', () async {
    final Map<String, dynamic> damaged = _workspacePayload();
    damaged['documents'] = <Object?>[
      <String, Object>{'id': 'not-a-uuid', 'json': '{}'},
    ];
    final String payload = jsonEncode(_workspacePayload());
    final _RecoverableRepository repository = _RecoverableRepository(
      current: jsonEncode(damaged),
      backup: payload,
    );

    final Workspace workspace = await Workspace.open(repository: repository);

    expect(workspace.active?.runtimeId, 'recovered');
    expect(repository.current, payload);
    expect(repository.backup, payload);
  });

  test('a workspace missing its document list recovers from backup', () async {
    final Map<String, dynamic> damaged = _workspacePayload()
      ..remove('documents');
    final String payload = jsonEncode(_workspacePayload());
    final _RecoverableRepository repository = _RecoverableRepository(
      current: jsonEncode(damaged),
      backup: payload,
    );

    final Workspace workspace = await Workspace.open(repository: repository);

    expect(workspace.active?.runtimeId, 'recovered');
    expect(repository.current, payload);
    expect(repository.backup, payload);
  });

  test(
    'a future-version backup is protected without any recovery write',
    () async {
      final _RecoverableRepository repository = _RecoverableRepository(
        current: '{broken',
        backup: '{"schemaVersion":99,"documents":[]}',
      );

      final Workspace workspace = await Workspace.open(repository: repository);

      expect(workspace.isLoadProtected, isTrue);
      expect(workspace.lastError, contains('newer editor'));
      expect(repository.writeCount, 0);
      expect(repository.backup, contains('schemaVersion'));
    },
  );

  test('retained localStorage v2 is the final recovery candidate', () async {
    final String payload = jsonEncode(_workspacePayload());
    final _RecoverableRepository repository = _RecoverableRepository(
      current: '{broken',
      backup: '{also broken',
      retained: payload,
    );

    final Workspace workspace = await Workspace.open(repository: repository);

    expect(workspace.active?.runtimeId, 'recovered');
    expect(repository.current, payload);
    expect(repository.backup, payload);
  });

  test(
    'retained localStorage v2 survives current and backup read failures',
    () async {
      final String payload = jsonEncode(_workspacePayload());
      final _RecoverableRepository repository = _RecoverableRepository(
        retained: payload,
        throwReadFailure: true,
        throwBackupFailure: true,
      );

      final Workspace workspace = await Workspace.open(repository: repository);

      expect(workspace.active?.runtimeId, 'recovered');
      expect(repository.current, payload);
      expect(repository.backup, payload);
    },
  );

  test(
    'external changes are observable and require export or reload',
    () async {
      final String payload = jsonEncode(_workspacePayload());
      final _RecoverableRepository repository = _RecoverableRepository(
        current: payload,
      );
      final Workspace workspace = await Workspace.open(repository: repository);
      final EditorStore store = EditorStore(
        workspace: workspace,
        autosaveDelay: const Duration(days: 1),
      );
      int workspaceNotifications = 0;
      int storeNotifications = 0;
      workspace.addListener(() => workspaceNotifications++);
      store.addListener(() => storeNotifications++);

      repository.emit(
        const WorkspaceRepositoryNotice(
          kind: WorkspaceRepositoryNoticeKind.changed,
          key: Workspace.storageKey,
          revision: 2,
        ),
      );

      expect(workspace.requiresReload, isTrue);
      expect(workspace.canWrite, isFalse);
      expect(workspace.lastError, contains('another browser tab'));
      expect(workspaceNotifications, 1);
      expect(storeNotifications, 1);
      expect(workspace.save(), isFalse);
      store.dispose();
    },
  );

  test('an external reset is surfaced immediately', () async {
    final _RecoverableRepository repository = _RecoverableRepository(
      current: jsonEncode(_workspacePayload()),
    );
    final Workspace workspace = await Workspace.open(repository: repository);

    repository.emit(
      const WorkspaceRepositoryNotice(
        kind: WorkspaceRepositoryNoticeKind.cleared,
        key: '',
      ),
    );

    expect(workspace.requiresReload, isTrue);
    expect(workspace.lastError, contains('reset in another browser tab'));
  });
}
