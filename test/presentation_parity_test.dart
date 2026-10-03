import 'package:gloss_editor/logic/entity_overlay_preview.dart';
import 'package:gloss_editor/logic/gloss_hologram_scene.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/presentation_variants.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test(
    'health bars render configured glyphs, thresholds and decimal rounding',
    () {
      final GlossHealthBar bar = GlossHealthBar(
        glyph: 'x',
        emptyGlyph: '.',
        healthyColor: '&b',
        warningColor: '&6',
        criticalColor: '&4',
        warningThreshold: 0.8,
        criticalThreshold: 0.4,
        decimals: 2,
      );
      expect(bar.render(10, 12, 20, 16), '&6xxxxxx&cxx&8..');
      expect(bar.number(1.005), '1.01');
      expect(bar.number(18.0), '18');
      expect(bar.copy().toJson(), bar.toJson());
      final GlossNameplateDoc plate = GlossNameplateDoc();
      plate.presentation.healthBar = bar;
      expect(cloneGlossNameplateDoc(plate).presentation.healthBar.number(1.005), '1.01');
    },
  );

  test(
    'overlay variants inherit omitted fields and resolve priority ties by id',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        variants: <GlossPresentationVariant>[
          GlossPresentationVariant(
            id: 'zebra',
            priority: 9,
            when: 'entity.health < 10',
            presentation: <String, Object?>{
              'lines': <Object?>[
                <String, Object?>{'id': 'z', 'type': 'text', 'text': 'Z'},
              ],
            },
          ),
          GlossPresentationVariant(
            id: 'alpha',
            priority: 9,
            when: 'entity.health < 10',
            presentation: <String, Object?>{
              'lines': <Object?>[
                <String, Object?>{'id': 'a', 'type': 'text', 'text': 'A'},
              ],
              'verticalOffset': 2.0,
            },
          ),
        ],
      );
      final GlossEntityOverlaysDoc copy = doc.copy();
      expect(
        copy.variants.map((variant) => variant.toJson()),
        doc.variants.map((variant) => variant.toJson()),
      );
      final GlossEntityOverlaysDoc selected = resolveEntityOverlayDocument(
        copy,
        const EntityOverlaySample(health: 8),
      );
      expect(selected.lines.single.text, 'A');
      expect(selected.verticalOffset, 2);
      expect(selected.healthBar.toJson(), doc.healthBar.toJson());
      expect(selected.style.toJson(), doc.style.toJson());
      expect(
        resolveEntityOverlayPreview(
          doc,
          const EntityOverlaySample(health: 8),
        ).lines,
        <String>['A'],
      );
      expect(validatePresentationVariants(doc.variants), isEmpty);
    },
  );

  test(
    'hologram page visibility and object lines survive variant round trips',
    () {
      final GlossHologramDoc doc = GlossHologramDoc();
      doc.extras['pages'] = <Object?>[
        <String, Object?>{
          'id': 'hidden',
          'show': false,
          'lines': <Object?>['Hidden'],
        },
        <String, Object?>{
          'id': 'visible',
          'show': true,
          'lines': <Object?>[
            'Visible',
            <String, Object?>{'item': 'minecraft:diamond', 'show': false},
          ],
        },
      ];
      doc.extras['actions'] = <Object?>[
        <String, Object?>{'type': 'command', 'command': 'help'},
      ];
      doc.extras['hitbox'] = <String, Object?>{
        'width': 3,
        'height': 1,
        'perLine': true,
      };
      doc.variants.add(
        GlossPresentationVariant(
          id: 'later',
          when: 'time.ms > 100',
          presentation: <String, Object?>{
            'lines': <Object?>[
              'Changed',
              <String, Object?>{'block': 'minecraft:stone', 'show': false},
            ],
          },
        ),
      );
      expect(doc.copy().toJson(), doc.toJson());
      expect(
        hologramRenderedLines(doc, nowMs: 0).map((line) => line.plainText),
        <String>['Visible'],
      );
      expect(
        hologramRenderedLines(doc, nowMs: 200).map((line) => line.plainText),
        <String>['Changed'],
      );
      expect(
        resolveHologramPreview(
          resolveHologramPreview(doc, nowMs: 200),
          nowMs: 200,
        ).textLines,
        <String>['Changed'],
      );
    },
  );

  test(
    'icons and tooltips retain authored inventory names and decorations',
    () {
      for (final String type in <String>[
        'item',
        'customItem',
        'playerHead',
        'block',
      ]) {
        final HuiIcon icon = HuiIcon.fromJson(<String, Object?>{
          'type': type,
          'item': 'minecraft:diamond',
          'block': 'minecraft:stone',
          'player': 'Builder',
          'name': '&aExample',
          'lore': <String>['&7Details'],
          'countFormat': '&b[{count}]',
        });
        expect(icon.copy().toJson(), icon.toJson());
        expect(icon.toJson()['name'], '&aExample');
        expect(icon.toJson()['lore'], <String>['&7Details']);
      }
      final HuiComponentData button = HuiComponentData.fromJson(
        <String, Object?>{
          'type': 'button',
          'tooltip': <String, Object?>{
            'delayTicks': 12,
            'lines': <String>['Hover'],
            'style': <String, Object?>{'shadow': true},
            'box': <String, Object?>{'enabled': true},
          },
        },
      );
      expect(button.copy().toJson(), button.toJson());
    },
  );

  test('marker beam and trail colors retain anchor and label presentation', () {
    final GlossMarkerDoc marker = GlossMarkerDoc(
      anchor: GlossMarkerAnchor(player: 'Builder'),
      beam: GlossMarkerBeam(glowColor: '#12ABEF'),
      trail: GlossMarkerTrail(color: '#BB11AA'),
    );
    marker.style.shadow = true;
    marker.box.enabled = true;
    final GlossMarkerDoc copy = cloneGlossMarkerDoc(marker);
    expect(copy.toJson(), marker.toJson());
    expect(copy.anchor.player, 'Builder');
    expect(copy.beam.glowColor, '#12ABEF');
    expect(copy.trail.color, '#BB11AA');
  });

  test('word emoji triggers respect Unicode word boundaries', () {
    expect(
      glossReplaceEmojiTrigger('cat scatter cat猫 _cat cat_ cat!', 'cat', 'X'),
      'X scatter cat猫 _cat cat_ X!',
    );
    expect(
      glossReplaceEmojiTrigger('cafe\u0301 cafe', 'cafe', 'X'),
      'cafe\u0301 X',
    );
    expect(glossReplaceEmojiTrigger('a>.<b', '>.<', 'X'), 'aXb');
  });
}
