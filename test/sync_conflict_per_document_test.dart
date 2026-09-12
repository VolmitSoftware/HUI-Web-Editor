import 'package:gloss_editor/logic/sync_problems.dart';
import 'package:test/test.dart';

/// A publication that landed except for a few documents comes back as
/// `applied` with a `conflicts` list. The whole-project conflict flow stays for
/// `conflict` alone, so one moved document no longer costs a whole publish.
void main() {
  test('an acknowledgement conflict list decodes to documents', () {
    final List<SyncConflict> conflicts = SyncConflict.of(<Object?>[
      <String, Object?>{'kind': 'menu', 'id': 'shop/main'},
      <String, Object?>{'kind': 'scoreboard', 'id': 'lobby'},
    ]);

    expect(conflicts.map((SyncConflict c) => '${c.kind} ${c.id}'), <String>[
      'menu shop/main',
      'scoreboard lobby',
    ]);
  });

  test('a malformed conflict entry is dropped without taking the rest', () {
    final List<SyncConflict> conflicts = SyncConflict.of(<Object?>[
      'not an object',
      <String, Object?>{'kind': 'menu'},
      <String, Object?>{'kind': '', 'id': 'shop'},
      <String, Object?>{'kind': 'menu', 'id': 'shop'},
    ]);

    expect(conflicts, hasLength(1));
    expect(conflicts.single.id, 'shop');
  });

  test('an absent list is empty rather than an error', () {
    expect(SyncConflict.of(null), isEmpty);
    expect(SyncConflict.of(<Object?>[]), isEmpty);
  });
}
