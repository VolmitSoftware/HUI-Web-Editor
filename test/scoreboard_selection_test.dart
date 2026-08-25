import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossConditionContext _context({
  double health = 20,
  String world = 'world',
  Set<String> groups = const <String>{},
  Set<String> permissions = const <String>{},
}) => GlossConditionContext(
  variables: <String, Object?>{
    'viewer.health': health,
    'viewer.healthPercent': health * 100 / 20,
    'viewer.world': world,
  },
  groups: groups,
  permissions: permissions,
);

void main() {
  test('highest-priority matching board wins', () {
    final GlossBoardSelection selected = glossSelectBoard(
      boards: const <GlossBoardCandidate>[
        GlossBoardCandidate(id: 'default', priority: 0, when: 'true'),
        GlossBoardCandidate(
          id: 'critical',
          priority: 100,
          when: 'viewer.health < 5',
        ),
      ],
      context: _context(health: 4),
    );
    expect(selected.boardId, 'critical');
  });

  test('equal priorities use the lexicographically smaller id', () {
    final GlossBoardSelection selected = glossSelectBoard(
      boards: const <GlossBoardCandidate>[
        GlossBoardCandidate(id: 'zeta', priority: 10, when: 'true'),
        GlossBoardCandidate(id: 'alpha', priority: 10, when: 'true'),
      ],
      context: _context(),
    );
    expect(selected.boardId, 'alpha');
  });

  test('permission, group and glob helpers participate in conditions', () {
    final GlossConditionContext context = _context(
      world: 'dungeon_12',
      groups: <String>{'vip'},
      permissions: <String>{'gloss.board.vip'},
    );
    expect(
      glossConditionMatches(
        "hasPermission('viewer', 'gloss.board.vip') && "
        "inGroup('viewer', 'vip') && "
        "matchesGlob(viewer.world, 'dungeon_*')",
        context,
      ).matches,
      isTrue,
    );
  });

  test('role-scoped helpers do not leak subject state to the viewer', () {
    final GlossConditionContext context = GlossConditionContext(
      groupsByRole: <String, Set<String>>{
        'subject': <String>{'vip'},
      },
    );
    expect(
      glossConditionMatches("inGroup('subject', 'vip')", context).matches,
      isTrue,
    );
    expect(
      glossConditionMatches("inGroup('viewer', 'vip')", context).matches,
      isFalse,
    );
  });

  test('glob helper supports both runtime wildcards', () {
    final GlossConditionContext context = _context(world: 'dungeon_12');
    expect(
      glossConditionMatches(
        "matchesGlob(viewer.world, 'dungeon_??')",
        context,
      ).matches,
      isTrue,
    );
  });

  test('bad conditions fail closed and expose the evaluation error', () {
    final ({bool matches, String? error}) result = glossConditionMatches(
      'viewer.missing > 0',
      _context(),
    );
    expect(result.matches, isFalse);
    expect(result.error, contains('unknown variable'));
  });

  test('variant resolution uses priority, id and default fallback', () {
    final GlossScoreboardPresentation fallback = GlossScoreboardPresentation(
      title: 'default',
    );
    final GlossScoreboardDoc doc = GlossScoreboardDoc(
      presentation: fallback,
      variants: <GlossScoreboardVariant>[
        GlossScoreboardVariant(
          id: 'world',
          priority: 20,
          when: "viewer.world == 'world'",
          presentation: GlossScoreboardPresentation(title: 'world'),
        ),
        GlossScoreboardVariant(
          id: 'critical',
          priority: 100,
          when: 'viewer.health < 5',
          presentation: GlossScoreboardPresentation(title: 'critical'),
        ),
      ],
    );
    expect(
      glossResolveScoreboardPresentation(doc, _context(health: 4)).title,
      'critical',
    );
    expect(
      glossResolveScoreboardPresentation(doc, _context(world: 'other')),
      same(fallback),
    );
  });
}
