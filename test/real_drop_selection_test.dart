import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/logic/real_drop_selection.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('priority and id select a complete real-drop presentation', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc();
    doc.variants.addAll(<GlossRealDropVariant>[
      GlossRealDropVariant(
        id: 'zeta',
        priority: 20,
        when: "drop.material == 'DIAMOND'",
        presentation: doc.presentation.copy()
          ..scale.defaultScale = 0.8,
      ),
      GlossRealDropVariant(
        id: 'alpha',
        priority: 20,
        when: "drop.material == 'DIAMOND'",
        presentation: doc.presentation.copy()
          ..scale.defaultScale = 1.2,
      ),
    ]);
    final GlossConditionContext context = GlossConditionContext(
      variables: const <String, Object?>{'drop.material': 'DIAMOND'},
    );

    expect(glossResolveRealDropVariantId(doc, context), 'alpha');
    expect(glossResolveRealDropPresentation(doc, context).scale.defaultScale, 1.2);
  });

  test('no matching variant falls back to the default presentation', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc(
      variants: <GlossRealDropVariant>[
        GlossRealDropVariant(
          id: 'diamond',
          priority: 10,
          when: "drop.material == 'DIAMOND'",
        ),
      ],
    );
    final GlossConditionContext context = GlossConditionContext(
      variables: const <String, Object?>{'drop.material': 'STONE'},
    );

    expect(glossResolveRealDropVariantId(doc, context), isNull);
    expect(glossResolveRealDropPresentation(doc, context), same(doc.presentation));
  });

  test('audience is evaluated independently for each viewer', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc(
      audience: GlossRealDropAudience(
        when: "inGroup('viewer', 'vip') && viewer.world == drop.world",
      ),
    );

    expect(
      glossRealDropAudienceVisible(
        doc,
        GlossConditionContext(
          variables: const <String, Object?>{
            'viewer.world': 'world',
            'drop.world': 'world',
          },
          groups: const <String>{'vip'},
        ),
      ),
      isTrue,
    );
    expect(
      glossRealDropAudienceVisible(
        doc,
        GlossConditionContext(
          variables: const <String, Object?>{
            'viewer.world': 'world_nether',
            'drop.world': 'world',
          },
          groups: const <String>{'vip'},
        ),
      ),
      isFalse,
    );
  });
}
