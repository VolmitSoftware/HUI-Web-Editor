/// `glossSelectBoard` against the Gloss suite's own `BoardSelectionTest`.
///
/// Every case below is the editor's restatement of a case in
/// `Gloss/src/test/java/art/arcane/gloss/board/BoardSelectionTest.java`, plus
/// the group pass and the document-derived candidate the editor adds.
library;

import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossBoardCandidate _board(
  String id, {
  bool primary = false,
  String permission = glossBoardUnrestrictedPermission,
  List<String> groups = const <String>[],
}) => GlossBoardCandidate(
  id: id,
  primary: primary,
  permission: permission,
  groups: groups,
);

bool Function(String) _granted(Set<String> nodes) =>
    (String node) => nodes.contains(node);

void main() {
  test('the first granted gated board wins in scan order', () {
    final GlossBoardSelection chosen = glossSelectBoard(
      primaryGroup: null,
      boards: <GlossBoardCandidate>[
        _board('first', permission: 'one'),
        _board('second', permission: 'two'),
      ],
      permissionTest: (String _) => true,
    );

    expect(chosen.boardId, 'first');
    expect(chosen.pass, GlossBoardSelectionPass.permission);
  });

  test('a granted gated board outranks the primary board', () {
    final GlossBoardSelection chosen = glossSelectBoard(
      primaryGroup: null,
      boards: <GlossBoardCandidate>[
        _board('gated', permission: 'vip'),
        _board('main', primary: true),
      ],
      permissionTest: _granted(<String>{'gloss.board.vip'}),
    );

    expect(chosen.boardId, 'gated');
    expect(chosen.pass, GlossBoardSelectionPass.permission);
  });

  test('an ungated board never wins the permission pass', () {
    final GlossBoardSelection chosen = glossSelectBoard(
      primaryGroup: null,
      boards: <GlossBoardCandidate>[
        _board('open'),
        _board('main', primary: true),
      ],
      permissionTest: (String _) => true,
    );

    expect(chosen.boardId, 'main');
    expect(chosen.pass, GlossBoardSelectionPass.primary);
  });

  test('a denied gated board falls through to the primary board', () {
    final GlossBoardSelection chosen = glossSelectBoard(
      primaryGroup: null,
      boards: <GlossBoardCandidate>[
        _board('gated', permission: 'vip'),
        _board('main', primary: true),
      ],
      permissionTest: (String _) => false,
    );

    expect(chosen.boardId, 'main');
    expect(chosen.pass, GlossBoardSelectionPass.primary);
  });

  test('the first primary board wins when nothing else matches', () {
    final GlossBoardSelection chosen = glossSelectBoard(
      primaryGroup: null,
      boards: <GlossBoardCandidate>[
        _board('open'),
        _board('primary-a', primary: true),
        _board('primary-b', primary: true),
      ],
      permissionTest: (String _) => false,
    );

    expect(chosen.boardId, 'primary-a');
  });

  test('nothing matching leaves the viewer with no sidebar', () {
    final GlossBoardSelection chosen = glossSelectBoard(
      primaryGroup: null,
      boards: <GlossBoardCandidate>[
        _board('open'),
        _board('gated', permission: 'vip'),
      ],
      permissionTest: (String _) => false,
    );

    expect(chosen.boardId, isNull);
    expect(chosen.pass, GlossBoardSelectionPass.none);
  });

  test('an empty board set selects nothing', () {
    final GlossBoardSelection chosen = glossSelectBoard(
      primaryGroup: 'vip',
      boards: const <GlossBoardCandidate>[],
      permissionTest: (String _) => true,
    );

    expect(chosen.boardId, isNull);
  });

  group('the group pass', () {
    test('a matching group outranks both later passes', () {
      final GlossBoardSelection chosen = glossSelectBoard(
        primaryGroup: 'vip',
        boards: <GlossBoardCandidate>[
          _board('gated', permission: 'staff'),
          _board('grouped', groups: <String>['vip']),
          _board('main', primary: true),
        ],
        permissionTest: (String _) => true,
      );

      expect(chosen.boardId, 'grouped');
      expect(chosen.pass, GlossBoardSelectionPass.group);
    });

    test('a group match still needs the board permission', () {
      final GlossBoardSelection chosen = glossSelectBoard(
        primaryGroup: 'vip',
        boards: <GlossBoardCandidate>[
          _board('grouped', permission: 'vip', groups: <String>['vip']),
          _board('main', primary: true),
        ],
        permissionTest: (String _) => false,
      );

      expect(chosen.boardId, 'main');
      expect(chosen.pass, GlossBoardSelectionPass.primary);
    });

    test('a blank primary group skips the pass entirely', () {
      final GlossBoardSelection chosen = glossSelectBoard(
        primaryGroup: '   ',
        boards: <GlossBoardCandidate>[
          _board('grouped', groups: <String>['vip']),
          _board('main', primary: true),
        ],
        permissionTest: (String _) => false,
      );

      expect(chosen.boardId, 'main');
    });

    test('group names compare exactly against the normalized list', () {
      final GlossBoardSelection chosen = glossSelectBoard(
        primaryGroup: 'VIP',
        boards: <GlossBoardCandidate>[
          _board('grouped', groups: <String>['vip']),
          _board('main', primary: true),
        ],
        permissionTest: (String _) => false,
      );

      expect(chosen.boardId, 'main');
    });
  });

  group('candidates from documents', () {
    test('a document contributes its normalized permission and groups', () {
      final GlossScoreboardDoc doc = GlossScoreboardDoc(
        primary: true,
        permission: '  VIP  ',
        groups: <String>[' MVP ', 'mvp', ''],
      );

      final GlossBoardCandidate candidate = GlossBoardCandidate.fromDoc(
        'welcome',
        doc,
      );

      expect(candidate.id, 'welcome');
      expect(candidate.primary, isTrue);
      expect(candidate.permission, 'vip');
      expect(candidate.permissionGated, isTrue);
      expect(candidate.permissionNode, 'gloss.board.vip');
      expect(candidate.groups, <String>['mvp']);
    });

    test('the default permission is not a gate', () {
      final GlossBoardCandidate candidate = GlossBoardCandidate.fromDoc(
        'welcome',
        GlossScoreboardDoc(),
      );

      expect(candidate.permission, glossBoardUnrestrictedPermission);
      expect(candidate.permissionGated, isFalse);
    });
  });
}
