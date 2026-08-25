import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/logic/tablist_selection.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossTablistDoc _doc() => GlossTablistDoc(
  headerFooter: GlossTablistHeaderFooter(
    enabled: true,
    presentation: GlossTablistHeaderFooterPresentation(
      header: 'default header',
      footer: 'default footer',
    ),
    variants: <GlossTablistHeaderFooterVariant>[
      GlossTablistHeaderFooterVariant(
        id: 'arena',
        priority: 50,
        when: "viewer.world == 'arena'",
        presentation: GlossTablistHeaderFooterPresentation(
          header: 'arena header',
          footer: 'arena footer',
        ),
      ),
    ],
  ),
  listNames: GlossTablistListNames(
    enabled: true,
    presentation: GlossTablistListNamePresentation(format: r'&7$player'),
    variants: <GlossTablistListNameVariant>[
      GlossTablistListNameVariant(
        id: 'operator',
        priority: 100,
        when: 'subject.op',
        presentation: GlossTablistListNamePresentation(format: r'&6$player'),
      ),
      GlossTablistListNameVariant(
        id: 'vip',
        priority: 50,
        when: "inGroup('subject', 'vip')",
        presentation: GlossTablistListNamePresentation(
          format: r'&e[$group] $player',
        ),
      ),
    ],
  ),
);

void main() {
  test('header/footer and list names select independently', () {
    final GlossTablistDoc doc = _doc();
    final GlossConditionContext context = GlossConditionContext(
      variables: <String, Object?>{
        'viewer.world': 'arena',
        'subject.op': false,
      },
      groupsByRole: <String, Set<String>>{
        'subject': <String>{'vip'},
      },
    );
    expect(
      glossResolveTablistHeaderFooter(doc, context).header,
      'arena header',
    );
    expect(
      glossResolveTablistListName(doc, context).format,
      r'&e[$group] $player',
    );
  });

  test('priority then id chooses a deterministic list-name variant', () {
    final GlossTablistDoc doc = _doc()
      ..listNames.variants.add(
        GlossTablistListNameVariant(
          id: 'admin',
          priority: 100,
          when: 'subject.op',
          presentation: GlossTablistListNamePresentation(format: 'admin'),
        ),
      );
    final GlossConditionContext context = GlossConditionContext(
      variables: <String, Object?>{'subject.op': true},
    );
    expect(glossResolveTablistListName(doc, context).format, 'admin');
    expect(glossResolveTablistListNameVariantId(doc, context), 'admin');
  });

  test('invalid conditions fail closed to the default presentations', () {
    final GlossTablistDoc doc = _doc()
      ..headerFooter.variants.single.when = 'viewer.health <';
    final GlossConditionContext context = GlossConditionContext(
      variables: <String, Object?>{'viewer.world': 'arena'},
    );
    expect(
      glossResolveTablistHeaderFooter(doc, context).header,
      'default header',
    );
  });

  test('list-name token substitution covers player and group', () {
    expect(
      glossTablistSubstituteTokens(r'&e[$group] $player', 'Alex', 'vip'),
      '&e[vip] Alex',
    );
  });
}
