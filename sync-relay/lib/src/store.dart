library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'config.dart';
import 'model.dart';

typedef RelayDirectorySync = Future<void> Function(Directory directory);

abstract interface class RelayStore {
  Future<void> start();

  Future<RelaySession?> read(String id);

  Future<List<RelaySession>> list();

  Future<void> create(RelaySession session);

  Future<void> delete(String id);

  Future<RelaySession> update(
    String id,
    RelaySession Function(RelaySession current) change,
  );

  Future<void> close();
}

final class MemoryRelayStore implements RelayStore {
  final Map<String, RelaySession> _sessions = <String, RelaySession>{};
  bool _closed = false;

  @override
  Future<void> start() async {
    _closed = false;
  }

  @override
  Future<RelaySession?> read(String id) async {
    _requireOpen();
    return _sessions[id];
  }

  @override
  Future<List<RelaySession>> list() async {
    _requireOpen();
    return List<RelaySession>.unmodifiable(_sessions.values);
  }

  @override
  Future<void> create(RelaySession session) async {
    _requireOpen();
    if (_sessions.containsKey(session.id)) {
      throw StateError('session already exists');
    }
    _sessions[session.id] = session;
  }

  @override
  Future<void> delete(String id) async {
    _requireOpen();
    _sessions.remove(id);
  }

  @override
  Future<RelaySession> update(
    String id,
    RelaySession Function(RelaySession current) change,
  ) async {
    _requireOpen();
    final RelaySession? current = _sessions[id];
    if (current == null) throw StateError('session does not exist');
    final RelaySession next = change(current);
    if (next.id != id) throw StateError('session identity changed');
    _sessions[id] = next;
    return next;
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  void _requireOpen() {
    if (_closed) throw StateError('relay store is closed');
  }
}

final class FileRelayStore implements RelayStore {
  static const int _maximumSessionFileBytes =
      RelayConfig.maximumProtocolResponseBytes;

  FileRelayStore(Directory directory, {RelayDirectorySync? syncDirectory})
    : _directory = Directory(directory.absolute.path),
      _syncDirectory = syncDirectory ?? _syncDirectoryDurably;

  final Directory _directory;
  final RelayDirectorySync _syncDirectory;
  String? _resolvedRoot;
  final Map<String, RelaySession> _sessions = <String, RelaySession>{};
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  @override
  Future<void> start() => _serial<void>(() async {
    _closed = false;
    await _ensureRoot();
    _sessions.clear();
    await for (final FileSystemEntity entity in Directory(
      _root,
    ).list(followLinks: false)) {
      if (_isTemporaryEntry(entity.path)) {
        if (entity is! File || await FileSystemEntity.isLink(entity.path)) {
          throw StateError(
            'relay temporary entry is not a regular file: ${entity.path}',
          );
        }
        await entity.delete();
        await _syncRootOrFail();
        continue;
      }
      if (!entity.path.endsWith('.json')) continue;
      if (entity is! File) {
        throw StateError('relay session entry is not a file: ${entity.path}');
      }
      final FileStat stat = await entity.stat();
      if (stat.type != FileSystemEntityType.file) {
        throw StateError('relay store contains a non-file: ${entity.path}');
      }
      if (stat.size > _maximumSessionFileBytes) {
        throw StateError('relay session file exceeds the size limit');
      }
      final Object? decoded = jsonDecode(await entity.readAsString());
      final RelaySession session = RelaySession.fromJson(decoded);
      if (_fileFor(session.id).path != entity.path) {
        throw StateError('relay session filename does not match its id');
      }
      if (_sessions.containsKey(session.id)) {
        throw StateError('duplicate relay session id');
      }
      _sessions[session.id] = session;
    }
  }, allowClosed: true);

  @override
  Future<RelaySession?> read(String id) =>
      _serial<RelaySession?>(() async => _sessions[id]);

  @override
  Future<List<RelaySession>> list() => _serial<List<RelaySession>>(
    () async => List<RelaySession>.unmodifiable(_sessions.values),
  );

  @override
  Future<void> create(RelaySession session) => _serial<void>(() async {
    if (_sessions.containsKey(session.id)) {
      throw StateError('session already exists');
    }
    await _write(session, createOnly: true);
    _sessions[session.id] = session;
  });

  @override
  Future<void> delete(String id) => _serial<void>(() async {
    await _ensureRoot();
    final File target = _fileFor(id);
    if (await FileSystemEntity.isLink(target.path)) {
      throw StateError('relay session target must not be a symbolic link');
    }
    if (await target.exists()) {
      await target.delete();
      await _syncRootOrFail();
    }
    _sessions.remove(id);
  });

  @override
  Future<RelaySession> update(
    String id,
    RelaySession Function(RelaySession current) change,
  ) => _serial<RelaySession>(() async {
    final RelaySession? current = _sessions[id];
    if (current == null) throw StateError('session does not exist');
    final RelaySession next = change(current);
    if (next.id != id) throw StateError('session identity changed');
    await _write(next, createOnly: false);
    _sessions[id] = next;
    return next;
  });

  @override
  Future<void> close() => _serial<void>(() async {
    _closed = true;
  }, allowClosed: true);

  Future<T> _serial<T>(
    Future<T> Function() operation, {
    bool allowClosed = false,
  }) {
    final Future<T> result = _tail.then<T>((_) async {
      if (_closed && !allowClosed) throw StateError('relay store is closed');
      return operation();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _ensureRoot() async {
    final Directory parent = _directory.parent;
    await parent.create(recursive: true);
    final FileStat parentStat = await parent.stat();
    if (parentStat.type != FileSystemEntityType.directory) {
      throw StateError('relay store parent is not a directory');
    }
    if (await FileSystemEntity.isLink(_directory.path)) {
      throw StateError('relay store root must not be a symbolic link');
    }
    final bool rootExisted = await _directory.exists();
    await _directory.create();
    if (!rootExisted) await _syncDirectoryOrFail(parent);
    final FileStat rootStat = await _directory.stat();
    if (rootStat.type != FileSystemEntityType.directory) {
      throw StateError('relay store root is not a directory');
    }
    final String resolved = await _directory.resolveSymbolicLinks();
    final String? previous = _resolvedRoot;
    if (previous != null && resolved != previous) {
      throw StateError('relay store root changed its resolved location');
    }
    _resolvedRoot = resolved;
  }

  String get _root => _resolvedRoot ?? _directory.absolute.path;

  File _fileFor(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{22,128}$').hasMatch(id)) {
      throw StateError('invalid relay session id');
    }
    final File file = File('$_root/$id.json');
    if (!file.absolute.path.startsWith('$_root${Platform.pathSeparator}')) {
      throw StateError('relay session path escapes its store');
    }
    return file;
  }

  Future<void> _write(RelaySession session, {required bool createOnly}) async {
    await _ensureRoot();
    final File target = _fileFor(session.id);
    if (await FileSystemEntity.isLink(target.path)) {
      throw StateError('relay session target must not be a symbolic link');
    }
    if (createOnly && await target.exists()) {
      throw StateError('session already exists');
    }
    final File temporary = File(
      '$_root/.${session.id}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode('${jsonEncode(session.toJson())}\n'),
    );
    if (bytes.length > _maximumSessionFileBytes) {
      throw StateError('relay session exceeds the stored size limit');
    }
    RandomAccessFile? handle;
    try {
      await temporary.create(exclusive: true);
      handle = await temporary.open(mode: FileMode.writeOnly);
      await handle.writeFrom(bytes);
      await handle.flush();
      await handle.close();
      handle = null;
      if (createOnly && await target.exists()) {
        throw StateError('session already exists');
      }
      await temporary.rename(target.path);
      await _syncRootOrFail();
    } finally {
      await handle?.close();
      if (await temporary.exists()) await temporary.delete();
    }
  }

  bool _isTemporaryEntry(String path) {
    final int separator = path.lastIndexOf(Platform.pathSeparator);
    final String name = separator < 0 ? path : path.substring(separator + 1);
    return RegExp(r'^\.[A-Za-z0-9_-]{22,128}\.[0-9]+\.tmp$').hasMatch(name);
  }

  Future<void> _syncRootOrFail() => _syncDirectoryOrFail(Directory(_root));

  Future<void> _syncDirectoryOrFail(Directory directory) async {
    try {
      await _syncDirectory(directory);
    } catch (_) {
      _closed = true;
      await _reloadSessionsAfterDurabilityFailure();
      rethrow;
    }
  }

  Future<void> _reloadSessionsAfterDurabilityFailure() async {
    final Map<String, RelaySession> restored = <String, RelaySession>{};
    await for (final FileSystemEntity entity in Directory(
      _root,
    ).list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final RelaySession session = RelaySession.fromJson(
        jsonDecode(await entity.readAsString()),
      );
      if (_fileFor(session.id).path != entity.path ||
          restored.containsKey(session.id)) {
        throw StateError('relay state is inconsistent after sync failure');
      }
      restored[session.id] = session;
    }
    _sessions
      ..clear()
      ..addAll(restored);
  }
}

Future<void> _syncDirectoryDurably(Directory directory) async {
  if (Platform.isWindows) {
    throw UnsupportedError(
      'the durable relay file store requires POSIX directory fsync',
    );
  }
  final Pointer<Utf8> path = directory.path.toNativeUtf8();
  final int descriptor;
  try {
    descriptor = _PosixDirectorySync.open(path, 0);
  } finally {
    malloc.free(path);
  }
  if (descriptor < 0) {
    throw FileSystemException(
      'could not open relay directory for durability sync',
      directory.path,
    );
  }
  Object? failure;
  try {
    if (_PosixDirectorySync.fsync(descriptor) != 0) {
      failure = FileSystemException(
        'could not sync relay directory',
        directory.path,
      );
    }
  } finally {
    if (_PosixDirectorySync.close(descriptor) != 0 && failure == null) {
      failure = FileSystemException(
        'could not close relay directory after durability sync',
        directory.path,
      );
    }
  }
  if (failure != null) throw failure;
}

final class _PosixDirectorySync {
  static final DynamicLibrary _process = DynamicLibrary.process();
  static final int Function(Pointer<Utf8>, int) open = _process
      .lookupFunction<_OpenNative, _OpenDart>('open');
  static final int Function(int) fsync = _process
      .lookupFunction<_DescriptorNative, _DescriptorDart>('fsync');
  static final int Function(int) close = _process
      .lookupFunction<_DescriptorNative, _DescriptorDart>('close');
}

typedef _OpenNative = Int32 Function(Pointer<Utf8> path, Int32 flags);
typedef _OpenDart = int Function(Pointer<Utf8> path, int flags);
typedef _DescriptorNative = Int32 Function(Int32 descriptor);
typedef _DescriptorDart = int Function(int descriptor);
