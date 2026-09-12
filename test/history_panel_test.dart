import 'package:gloss_editor/logic/sync_history.dart';
import 'package:test/test.dart';

/// The sync project carries the versions the server keeps for every document
/// it sent. The History panel lists them per document, newest first, and asks
/// the relay for one only when somebody opens it.
void main() {
  test('history entries decode and sort newest first per document', () {
    final SyncHistory history = SyncHistory.of(<Object?>[
      <String, Object?>{
        'kind': 'boards',
        'id': 'lobby',
        'version': 1700,
        'source': 'watchdog',
        'bytes': 18,
      },
      <String, Object?>{
        'kind': 'boards',
        'id': 'lobby',
        'version': 1900,
        'source': 'editor:abc',
        'bytes': 24,
      },
      <String, Object?>{
        'kind': 'menus',
        'id': 'shop/main',
        'version': 1800,
        'source': 'pack:lobby-starter',
        'bytes': 40,
      },
    ]);

    final List<SyncHistoryVersion> board = history.forDocument('boards', 'lobby');
    expect(board.map((SyncHistoryVersion v) => v.version), <int>[1900, 1700]);
    expect(board.first.source, 'editor:abc');
    expect(history.forDocument('menus', 'shop/main').single.bytes, 40);
    expect(history.forDocument('boards', 'missing'), isEmpty);
  });

  test('a source reads as where the copy came from', () {
    expect(
      SyncHistoryVersion.describeSource('editor:session_abc'),
      'Editor publication',
    );
    expect(
      SyncHistoryVersion.describeSource('pack:lobby-starter'),
      'Pack lobby-starter',
    );
    expect(SyncHistoryVersion.describeSource('watchdog'), 'Edited on disk');
    expect(SyncHistoryVersion.describeSource('restore'), 'Restore');
    expect(
      SyncHistoryVersion.describeSource('import:featherboard'),
      'Import featherboard',
    );
    expect(SyncHistoryVersion.describeSource('something-else'), 'something-else');
  });

  test('a malformed entry is dropped without taking the rest with it', () {
    final SyncHistory history = SyncHistory.of(<Object?>[
      <String, Object?>{'kind': 'boards', 'id': 'lobby'},
      'not an object',
      <String, Object?>{
        'kind': 'boards',
        'id': 'lobby',
        'version': 5,
        'source': 'watchdog',
        'bytes': 1,
      },
    ]);

    expect(history.forDocument('boards', 'lobby'), hasLength(1));
  });

  test('an absent history section is empty, not an error', () {
    expect(SyncHistory.of(null).forDocument('boards', 'lobby'), isEmpty);
    expect(SyncHistory.of(<Object?>[]).documents, isEmpty);
  });

  test('the documents that have history are listed in kind then id order', () {
    final SyncHistory history = SyncHistory.of(<Object?>[
      <String, Object?>{
        'kind': 'menus',
        'id': 'shop',
        'version': 2,
        'source': 'watchdog',
        'bytes': 1,
      },
      <String, Object?>{
        'kind': 'boards',
        'id': 'lobby',
        'version': 1,
        'source': 'watchdog',
        'bytes': 1,
      },
    ]);

    expect(
      history.documents.map((SyncHistoryDocument d) => '${d.kind} ${d.id}'),
      <String>['boards lobby', 'menus shop'],
    );
  });
}
