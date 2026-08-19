import 'dart:io';
import 'dart:convert';

import 'package:gloss_sync_relay/gloss_sync_relay.dart';
import 'package:test/test.dart';

void main() {
  test('file store survives restart and never writes raw capabilities', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final RelaySession session = _session();
    final FileRelayStore first = FileRelayStore(directory);
    await first.start();
    await first.create(session);
    await first.close();
    final String disk = await File(
      '${directory.path}/${session.id}.json',
    ).readAsString();
    expect(disk, isNot(contains('editor-secret')));
    expect(disk, isNot(contains('server-secret')));

    final FileRelayStore second = FileRelayStore(directory);
    await second.start();
    expect((await second.read(session.id))?.baseRevision, session.baseRevision);
    final RelayPublication publication = RelayPublication(
      revision: 1,
      baseRevision: session.baseRevision,
      snapshot: <String, Object?>{
        'baseRevision':
            'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      },
      publishedAt: DateTime.utc(2026, 8, 12, 0, 10),
    );
    await second.update(
      session.id,
      (RelaySession current) => current.publish(publication),
    );
    await second.close();

    final FileRelayStore third = FileRelayStore(directory);
    await third.start();
    final RelaySession restored = (await third.read(session.id))!;
    expect(restored.publication?.revision, 1);
    expect(restored.publication?.state, RelayPublicationState.pending);
    expect(restored.nextPublicationRevision, 2);
    await third.close();
  });

  test('file store rejects a symlink root', () async {
    if (Platform.isWindows) return;
    final Directory parent = await Directory.systemTemp.createTemp(
      'holoui-relay-link-',
    );
    addTearDown(() => parent.delete(recursive: true));
    final Directory outside = Directory('${parent.path}/outside');
    await outside.create();
    final Link link = Link('${parent.path}/sessions');
    await link.create(outside.path);
    final FileRelayStore store = FileRelayStore(Directory(link.path));
    await expectLater(store.start(), throwsStateError);
  });

  test(
    'file store rejects corrupt session state instead of dropping it',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'holoui-relay-corrupt-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}/broken.json',
      ).writeAsString('{not valid json');
      final FileRelayStore store = FileRelayStore(directory);
      await expectLater(store.start(), throwsA(anything));
    },
  );

  test('file store rejects internally inconsistent revision state', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-inconsistent-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final RelaySession session = _session();
    final Map<String, Object?> encoded = session.toJson()
      ..['baseRevision'] =
          'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    await File(
      '${directory.path}/${session.id}.json',
    ).writeAsString(jsonEncode(encoded));
    final FileRelayStore store = FileRelayStore(directory);
    await expectLater(store.start(), throwsA(anything));
  });

  test('file store rejects an under-reserved session', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-under-reserved-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final Map<String, Object?> encoded = _session().toJson();
    final Map<String, Object?> snapshot = Map<String, Object?>.of(
      encoded['snapshot']! as Map<String, Object?>,
    )..['padding'] = List<String>.filled(2048, 'x').join();
    encoded['snapshot'] = snapshot;
    encoded['reservedBytes'] = relayMinimumReservedSessionBytes;
    await File(
      '${directory.path}/${_session().id}.json',
    ).writeAsString(jsonEncode(encoded));
    final FileRelayStore store = FileRelayStore(directory);
    await expectLater(store.start(), throwsFormatException);
  });

  test('file store rejects JSON symlink entries', () async {
    if (Platform.isWindows) return;
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-entry-link-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File outside = File('${directory.path}/outside-session.state');
    await outside.writeAsString(jsonEncode(_session().toJson()));
    await Link('${directory.path}/${_session().id}.json').create(outside.path);
    final FileRelayStore store = FileRelayStore(directory);
    await expectLater(store.start(), throwsA(anything));
  });

  test('file store removes only recognized interrupted temp writes', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-temp-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File interrupted = File(
      '${directory.path}/.${_session().id}.123456.tmp',
    );
    final File unrelated = File('${directory.path}/operator-note.tmp');
    await interrupted.writeAsString('partial');
    await unrelated.writeAsString('keep');
    final FileRelayStore store = FileRelayStore(directory);
    await store.start();
    expect(await interrupted.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    await store.close();
  });

  test('file store rejects a session whose filename does not match', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-name-',
    );
    addTearDown(() => directory.delete(recursive: true));
    await File(
      '${directory.path}/bbbbbbbbbbbbbbbbbbbbbb.json',
    ).writeAsString(jsonEncode(_session().toJson()));
    final FileRelayStore store = FileRelayStore(directory);
    await expectLater(store.start(), throwsStateError);
  });

  test('file store preserves the null rejected server revision', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-rejected-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final RelaySession session = _session();
    final RelayPublication pending = RelayPublication(
      revision: 1,
      baseRevision: session.baseRevision,
      snapshot: <String, Object?>{
        'baseRevision':
            'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      },
      publishedAt: DateTime.utc(2026, 8, 12, 0, 10),
    );
    final RelayAck acknowledgement = RelayAck(
      status: RelayPublicationState.rejected,
      message: 'Invalid project.',
      serverRevision: null,
      acknowledgedAt: DateTime.utc(2026, 8, 12, 0, 11),
    );
    final RelaySession rejected = session
        .publish(pending)
        .acknowledge(pending.acknowledge(acknowledgement));
    final FileRelayStore first = FileRelayStore(directory);
    await first.start();
    await first.create(rejected);
    await first.close();
    final FileRelayStore second = FileRelayStore(directory);
    await second.start();
    final RelaySession restored = (await second.read(session.id))!;
    expect(restored.publication?.state, RelayPublicationState.rejected);
    expect(restored.publication?.ack?.serverRevision, isNull);
    await second.close();
  });

  test('file store syncs its directory before returning mutations', () async {
    final Directory parent = await Directory.systemTemp.createTemp(
      'holoui-relay-sync-order-',
    );
    addTearDown(() => parent.delete(recursive: true));
    final Directory directory = Directory('${parent.path}/sessions');
    final List<String> synced = <String>[];
    final FileRelayStore store = FileRelayStore(
      directory,
      syncDirectory: (Directory value) async => synced.add(value.path),
    );
    await store.start();
    expect(synced, <String>[parent.path]);
    final String resolvedDirectory = await directory.resolveSymbolicLinks();
    synced.clear();

    final RelaySession session = _session();
    await store.create(session);
    expect(synced, <String>[resolvedDirectory]);
    expect((await store.read(session.id))?.publication, isNull);
    synced.clear();

    final RelayPublication publication = RelayPublication(
      revision: 1,
      baseRevision: session.baseRevision,
      snapshot: <String, Object?>{
        'baseRevision':
            'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      },
      publishedAt: DateTime.utc(2026, 8, 12, 0, 10),
    );
    await store.update(
      session.id,
      (RelaySession current) => current.publish(publication),
    );
    expect(synced, <String>[resolvedDirectory]);
    expect((await store.read(session.id))?.publication?.revision, 1);
    synced.clear();

    await store.delete(session.id);
    expect(synced, <String>[resolvedDirectory]);
    expect(await store.read(session.id), isNull);
    await store.close();
  });

  test('directory sync failure fails closed with disk-visible state', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'holoui-relay-sync-failure-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final RelaySession session = _session();
    final FileRelayStore seed = FileRelayStore(directory);
    await seed.start();
    await seed.create(session);
    await seed.close();

    int calls = 0;
    final FileRelayStore store = FileRelayStore(
      directory,
      syncDirectory: (Directory _) async {
        calls++;
        throw const FileSystemException('injected directory sync failure');
      },
    );
    await store.start();
    final RelayPublication publication = RelayPublication(
      revision: 1,
      baseRevision: session.baseRevision,
      snapshot: <String, Object?>{
        'baseRevision':
            'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      },
      publishedAt: DateTime.utc(2026, 8, 12, 0, 10),
    );
    await expectLater(
      store.update(
        session.id,
        (RelaySession current) => current.publish(publication),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(calls, 1);
    await expectLater(store.read(session.id), throwsStateError);

    final FileRelayStore restarted = FileRelayStore(directory);
    await restarted.start();
    expect((await restarted.read(session.id))?.publication?.revision, 1);
    await restarted.close();
  });
}

RelaySession _session() => RelaySession(
  id: 'aaaaaaaaaaaaaaaaaaaaaa',
  createPrincipalHash: tokenHash('create-principal'),
  reservedBytes: (16 * 1024 * 1024) + RelayConfig.protocolEnvelopeBytes,
  editorTokenHash: tokenHash('editor-secret'),
  serverTokenHash: tokenHash('server-secret'),
  createdAt: DateTime.utc(2026, 8, 12),
  expiresAt: DateTime.utc(2026, 8, 12, 1),
  baseRevision:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  snapshot: <String, Object?>{
    'baseRevision':
        'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  nextPublicationRevision: 1,
);
