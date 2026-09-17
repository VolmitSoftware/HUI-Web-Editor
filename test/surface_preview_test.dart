/// What the surface stage draws for the sampled viewer.
///
/// The mock renders the RESOLVED presentation — the winning variant put
/// through `Presentation.forKind` — so these are the functions that decide
/// what appears on screen: which variant wins, whether anything shows at all,
/// and the boss-bar geometry the fill and notches come from.
library;

import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/gloss_show.dart';
import 'package:gloss_editor/logic/surface_selection.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossSurfaceVariant _variant(
  String id,
  int priority,
  String when,
  String text,
) => GlossSurfaceVariant(
  id: id,
  priority: priority,
  when: when,
  presentation: GlossSurfacePresentation(text: text),
);

GlossSurfaceDoc _actionbar({
  String when = 'true',
  List<GlossSurfaceVariant>? variants,
}) => GlossSurfaceDoc(
  surface: glossSurfaceKindActionbar,
  select: GlossSurfaceSelect(when: when),
  presentation: GlossSurfacePresentation(text: '&7base'),
  variants: variants,
);

void main() {
  group('selection', () {
    test('the sampled viewer sees a selected document', () {
      expect(glossSurfaceSilence(_actionbar()), isNull);
    });

    test('a false selection condition names itself as the reason', () {
      expect(
        glossSurfaceSilence(
          _actionbar(when: glossSurfaceNeverCondition),
        ),
        GlossSurfaceSilence.notSelected,
      );
    });

    test('a false document show condition outranks the selection', () {
      final GlossSurfaceDoc doc = _actionbar();
      doc.extras['show'] = false;
      expect(glossSurfaceSilence(doc), GlossSurfaceSilence.documentHidden);
    });

    test('a broken condition fails closed and says so', () {
      expect(
        glossSurfaceSilence(_actionbar(when: 'viewer.health <')),
        GlossSurfaceSilence.brokenCondition,
      );
    });

    test('the sampled viewer is the one the scope describes', () {
      expect(
        glossScopedSampleValues['viewer.name'],
        glossSurfaceSampleViewerName,
      );
    });
  });

  group('variant resolution', () {
    test('the document presentation wins when nothing matches', () {
      final GlossSurfaceDoc doc = _actionbar(
        variants: <GlossSurfaceVariant>[
          _variant('low', 50, 'viewer.healthPercent <= 25', '&clow'),
        ],
      );
      expect(glossResolveSurfaceVariantId(doc), isNull);
      expect(glossResolveSurfacePresentation(doc).text, '&7base');
    });

    test('the highest-priority matching variant wins', () {
      final GlossSurfaceDoc doc = _actionbar(
        variants: <GlossSurfaceVariant>[
          _variant('quiet', 5, 'true', '&7quiet'),
          _variant('loud', 50, 'viewer.healthPercent > 25', '&cloud'),
        ],
      );
      expect(glossResolveSurfaceVariantId(doc), 'loud');
      expect(glossResolveSurfacePresentation(doc).text, '&cloud');
    });

    test('a priority tie breaks on the smaller id', () {
      final GlossSurfaceDoc doc = _actionbar(
        variants: <GlossSurfaceVariant>[
          _variant('beta', 10, 'true', '&7beta'),
          _variant('alpha', 10, 'true', '&7alpha'),
        ],
      );
      expect(glossResolveSurfaceVariantId(doc), 'alpha');
    });

    test('a variant with a blank condition never wins', () {
      final GlossSurfaceDoc doc = _actionbar(
        variants: <GlossSurfaceVariant>[_variant('blank', 90, '  ', '&7x')],
      );
      expect(glossResolveSurfaceVariantId(doc), isNull);
    });

    test('a simulated viewer resolves a different variant', () {
      final GlossSurfaceDoc doc = _actionbar(
        variants: <GlossSurfaceVariant>[
          _variant('low', 50, 'viewer.healthPercent <= 25', '&clow'),
        ],
      );
      final GlossConditionContext hurt = GlossConditionContext(
        variables: <String, Object?>{
          ...glossScopedSampleValues,
          'viewer.healthPercent': 10.0,
        },
      );
      expect(glossResolveSurfaceVariantId(doc, context: hurt), 'low');
    });
  });

  group('what the mock actually draws', () {
    test('the resolved presentation is the kind-filtered one', () {
      // The document is a bossbar, so the winning variant's `text` is not
      // what the client gets — the mock must not draw it either.
      final GlossSurfaceDoc doc = GlossSurfaceDoc(
        surface: glossSurfaceKindBossbar,
        select: GlossSurfaceSelect(when: 'true'),
        presentation: GlossSurfacePresentation(title: '&6base'),
        variants: <GlossSurfaceVariant>[
          GlossSurfaceVariant(
            id: 'push',
            priority: 10,
            when: 'true',
            presentation: GlossSurfacePresentation(
              title: '&6push',
              text: '&7dropped',
            ),
          ),
        ],
      );
      final GlossSurfacePresentation resolved =
          glossResolveEffectiveSurfacePresentation(doc);
      expect(resolved.title, '&6push');
      expect(resolved.text, isNull);
      expect(resolved.progress, glossSurfaceDefaultProgress);
      expect(resolved.color, glossSurfaceDefaultColor);
      expect(resolved.style, glossSurfaceDefaultStyle);
    });

    test('the action-bar lanes come from the resolved slots', () {
      final GlossSurfaceDoc doc = GlossSurfaceDoc(
        surface: glossSurfaceKindActionbar,
        select: GlossSurfaceSelect(when: 'true'),
        presentation: GlossSurfacePresentation(
          text: '&7hi',
          slots: <String>['right', 'left'],
        ),
      );
      expect(glossResolveEffectiveSurfacePresentation(doc).slots, <String>[
        'right',
        'left',
      ]);
    });

    test('a solid bar has no notches and a segmented one has its count', () {
      expect(glossSurfaceStyleSegments(glossSurfaceDefaultStyle), 0);
      expect(glossSurfaceStyleSegments('segmented_6'), 6);
      expect(glossSurfaceStyleSegments('segmented_10'), 10);
      expect(glossSurfaceStyleSegments('segmented_12'), 12);
      expect(glossSurfaceStyleSegments('segmented_20'), 20);
    });

    test('the fill evaluates the expression for the sampled viewer', () {
      expect(
        glossSurfaceProgressValue('{{ viewer.healthPercent / 100 }}'),
        closeTo(0.9, 1e-9),
      );
      expect(glossSurfaceProgressValue('0.25'), closeTo(0.25, 1e-9));
    });

    test('the fill is pinned into 0..1 and a broken one draws full', () {
      expect(glossSurfaceProgressValue('4'), 1);
      expect(glossSurfaceProgressValue('-2'), 0);
      expect(glossSurfaceProgressValue('viewer.health /'), 1);
      expect(glossSurfaceProgressValue(null), 1);
    });
  });

  group('the shipped and showcase documents through the same path', () {
    test('the shipped welcome shows nothing until a condition is written', () {
      expect(
        glossSurfaceSilence(buildDefaultGlossSurface()),
        GlossSurfaceSilence.notSelected,
      );
    });

    test('every showcase draws for the sampled viewer', () {
      for (final GlossSurfaceDoc doc in <GlossSurfaceDoc>[
        buildActionbarShowcaseGlossSurface(),
        buildBossbarShowcaseGlossSurface(),
        buildTitleShowcaseGlossSurface(),
      ]) {
        expect(glossSurfaceSilence(doc), isNull, reason: doc.surface);
        final GlossSurfacePresentation resolved =
            glossResolveEffectiveSurfacePresentation(doc);
        final String required = glossSurfaceRequiredField[doc.surface]!;
        expect(
          required == 'text' ? resolved.text : resolved.title,
          isNotNull,
          reason: doc.surface,
        );
      }
    });

    test('the bossbar showcase fills from its own expression', () {
      final GlossSurfacePresentation resolved =
          glossResolveEffectiveSurfacePresentation(
            buildBossbarShowcaseGlossSurface(),
          );
      // viewer.level is 27 in the sample scope, so level / 30 is 0.9.
      expect(
        glossSurfaceProgressValue(resolved.progress),
        closeTo(0.9, 1e-9),
      );
      expect(glossSurfaceStyleSegments(resolved.style), 10);
    });

    test('the title showcase carries the whole timing set', () {
      final GlossSurfacePresentation resolved =
          glossResolveEffectiveSurfacePresentation(
            buildTitleShowcaseGlossSurface(),
          );
      expect(resolved.fadeInTicks, 12);
      expect(resolved.stayTicks, 70);
      expect(resolved.fadeOutTicks, 16);
      expect(resolved.trigger, 'once');
      expect(resolved.subtitle, isNotEmpty);
    });
  });
}
