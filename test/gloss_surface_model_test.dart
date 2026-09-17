/// GlossSurfaceDoc: the per-file HUD documents under `plugins/Gloss/surfaces/`,
/// their three presentation shapes, and the keys `SurfaceDoc.java` silently
/// drops or clamps.
///
/// The shape is `SurfaceDoc.java`: one `surface` discriminator picks which
/// presentation fields survive `Presentation.forKind`, every other authored
/// field is dropped rather than refused, and `select` defaults to
/// `Selection.NEVER` — priority 0, condition `false`.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

/// `defaults/surfaces/welcome.json`, byte for byte.
const String _shipped = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "surface": "actionbar",
  "show": "true",
  "select": { "priority": 0, "when": "false" },
  "presentation": { "text": "&7Welcome, &f{{ player.name }}", "slots": ["center"], "priority": "ambient", "ttlTicks": 40 },
  "variants": []
}
''';

void main() {
  group('decode', () {
    test('reads the shipped default', () {
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(_shipped);
      expect(doc.schemaVersion, 1);
      expect(doc.revision, 1);
      expect(doc.surface, glossSurfaceKindActionbar);
      expect(doc.extras['show'], 'true');
      expect(doc.select.priority, 0);
      expect(doc.select.when, 'false');
      expect(doc.presentation.text, '&7Welcome, &f{{ player.name }}');
      expect(doc.presentation.slots, <String>['center']);
      expect(doc.presentation.priority, 'ambient');
      expect(doc.presentation.ttlTicks, 40);
      expect(doc.variants, isEmpty);
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossSurfaceDoc('{"schemaVersion": 2}'),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossSurfaceDoc('{}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('an unknown surface decodes leniently for validation to name', () {
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(
        '{"schemaVersion": 1, "revision": 1, "surface": "subtitle", '
        '"presentation": {"text": "hi"}}',
      );
      expect(doc.surface, 'subtitle');
    });

    test('a missing select block is Selection.NEVER', () {
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(
        '{"schemaVersion": 1, "revision": 1, "surface": "actionbar", '
        '"presentation": {"text": "hi"}}',
      );
      expect(doc.select.priority, 0);
      expect(doc.select.when, 'false');
    });

    test('a present select with a blank condition keeps the blank', () {
      // SurfaceDoc.Selection refuses it; the decoder keeps it so validation
      // can name the field instead of the decoder repairing it.
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(
        '{"schemaVersion": 1, "revision": 1, "surface": "actionbar", '
        '"select": {"priority": 4, "when": "  "}, '
        '"presentation": {"text": "hi"}}',
      );
      expect(doc.select.priority, 4);
      expect(doc.select.when, '  ');
    });

    test('an absent presentation field stays absent, not zero', () {
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(
        '{"schemaVersion": 1, "revision": 1, "surface": "bossbar", '
        '"presentation": {"title": "&6Boss"}}',
      );
      expect(doc.presentation.title, '&6Boss');
      expect(doc.presentation.text, isNull);
      expect(doc.presentation.slots, isNull);
      expect(doc.presentation.ttlTicks, isNull);
      expect(doc.presentation.progress, isNull);
    });

    test('variants keep the authored order, not the runtime sort', () {
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(
        '{"schemaVersion": 1, "revision": 1, "surface": "actionbar", '
        '"presentation": {"text": "base"}, "variants": ['
        '{"id": "low", "priority": 1, "when": "true", '
        '"presentation": {"text": "low"}}, '
        '{"id": "high", "priority": 9, "when": "true", '
        '"presentation": {"text": "high"}}]}',
      );
      expect(
        doc.variants.map((GlossSurfaceVariant variant) => variant.id),
        <String>['low', 'high'],
      );
    });
  });

  group('round-trip', () {
    test('the shipped default re-encodes to the same tree', () {
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(_shipped);
      final String encoded = encodeGlossSurfaceDoc(doc);
      expect(jsonDecode(encoded), jsonDecode(_shipped));
      expect(encodeGlossSurfaceDoc(decodeGlossSurfaceDoc(encoded)), encoded);
    });

    test('a field the kind drops still survives the round trip', () {
      // Presentation.forKind drops it on the server; rewriting the file
      // without it would be an edit the author never asked for.
      const String source =
          '{"schemaVersion": 1, "revision": 1, "surface": "bossbar", '
          '"presentation": {"title": "&6Boss", "text": "&7leftover", '
          '"stayTicks": 60}}';
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(source);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossSurfaceDoc(doc)) as Map<String, dynamic>;
      final Map<String, dynamic> presentation =
          out['presentation']! as Map<String, dynamic>;
      expect(presentation['text'], '&7leftover');
      expect(presentation['stayTicks'], 60);
    });

    test('unknown keys survive at every level', () {
      const String source =
          '{"schemaVersion": 1, "revision": 1, "surface": "title", '
          '"futureFlag": 7, '
          '"select": {"priority": 1, "when": "true", "futureSelect": "x"}, '
          '"presentation": {"title": "t", "futureStyle": "bold"}, '
          '"variants": [{"id": "v", "priority": 2, "when": "true", '
          '"presentation": {"title": "v", "futureInner": 3}, '
          '"futureVariant": true}]}';
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(source);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossSurfaceDoc(doc)) as Map<String, dynamic>;
      expect(out['futureFlag'], 7);
      expect((out['select']! as Map<String, dynamic>)['futureSelect'], 'x');
      expect(
        (out['presentation']! as Map<String, dynamic>)['futureStyle'],
        'bold',
      );
      final Map<String, dynamic> variant =
          (out['variants']! as List<dynamic>)[0] as Map<String, dynamic>;
      expect(variant['futureVariant'], isTrue);
      expect(
        (variant['presentation']! as Map<String, dynamic>)['futureInner'],
        3,
      );
    });

    test('clone is deep', () {
      final GlossSurfaceDoc doc = decodeGlossSurfaceDoc(_shipped);
      final GlossSurfaceDoc clone = cloneGlossSurfaceDoc(doc);
      clone.presentation.text = 'changed';
      expect(doc.presentation.text, '&7Welcome, &f{{ player.name }}');
      expect(doc.copy().presentation.text, doc.presentation.text);
    });
  });

  group('effective presentation', () {
    test('an actionbar keeps text and drops everything else', () {
      final GlossSurfacePresentation effective = glossSurfaceEffective(
        glossSurfaceKindActionbar,
        GlossSurfacePresentation(
          text: '&7hi',
          title: '&6dropped',
          subtitle: 'dropped',
          progress: '0.5',
          color: 'red',
          style: 'segmented_6',
          trigger: 'once',
          stayTicks: 90,
        ),
      );
      expect(effective.text, '&7hi');
      expect(effective.title, isNull);
      expect(effective.subtitle, isNull);
      expect(effective.progress, isNull);
      expect(effective.color, isNull);
      expect(effective.style, isNull);
      expect(effective.trigger, isNull);
      expect(effective.stayTicks, isNull);
      expect(effective.slots, <String>['center']);
      expect(effective.priority, glossSurfaceDefaultPriority);
    });

    test('a bossbar fills in the progress, colour and style defaults', () {
      final GlossSurfacePresentation effective = glossSurfaceEffective(
        glossSurfaceKindBossbar,
        GlossSurfacePresentation(title: '&6Boss'),
      );
      expect(effective.title, '&6Boss');
      expect(effective.progress, '1');
      expect(effective.color, 'white');
      expect(effective.style, 'solid');
      expect(effective.text, isNull);
    });

    test('a bossbar progress expression loses its {{ }} wrapper', () {
      final GlossSurfacePresentation effective = glossSurfaceEffective(
        glossSurfaceKindBossbar,
        GlossSurfacePresentation(
          title: '&6Boss',
          progress: '{{ viewer.healthPercent / 100 }}',
        ),
      );
      expect(effective.progress, 'viewer.healthPercent / 100');
    });

    test('a title fills in the fade, stay and trigger defaults', () {
      final GlossSurfacePresentation effective = glossSurfaceEffective(
        glossSurfaceKindTitle,
        GlossSurfacePresentation(title: '&dWelcome'),
      );
      expect(effective.title, '&dWelcome');
      expect(effective.subtitle, '');
      expect(effective.fadeInTicks, glossSurfaceDefaultFadeInTicks);
      expect(effective.stayTicks, glossSurfaceDefaultStayTicks);
      expect(effective.fadeOutTicks, glossSurfaceDefaultFadeOutTicks);
      expect(effective.trigger, glossSurfaceDefaultTrigger);
      expect(effective.repeatTicks, isNull);
    });

    test('a repeat trigger never repeats faster than it stays', () {
      // SurfaceDoc.forTitle: max(stay, repeatTicks).
      final GlossSurfacePresentation effective = glossSurfaceEffective(
        glossSurfaceKindTitle,
        GlossSurfacePresentation(
          title: '&dWelcome',
          trigger: 'repeat',
          stayTicks: 200,
          repeatTicks: 20,
        ),
      );
      expect(effective.repeatTicks, 200);
    });

    test('out-of-range ticks clamp the way the server clamps them', () {
      final GlossSurfacePresentation effective = glossSurfaceEffective(
        glossSurfaceKindTitle,
        GlossSurfacePresentation(
          title: '&dWelcome',
          ttlTicks: 5000,
          fadeInTicks: -4,
          stayTicks: 9000,
          fadeOutTicks: 4000,
          trigger: 'repeat',
          repeatTicks: 900000,
        ),
      );
      expect(effective.ttlTicks, glossSurfaceMaxTtlTicks);
      expect(effective.fadeInTicks, 0);
      expect(effective.stayTicks, glossSurfaceMaxFadeTicks);
      expect(effective.fadeOutTicks, glossSurfaceMaxFadeTicks);
      expect(effective.repeatTicks, glossSurfaceMaxRepeatTicks);
    });

    test('slots normalize, deduplicate and default to centre', () {
      expect(
        glossSurfaceEffective(
          glossSurfaceKindActionbar,
          GlossSurfacePresentation(
            text: 'hi',
            slots: <String>[' LEFT ', 'left', 'right'],
          ),
        ).slots,
        <String>['left', 'right'],
      );
      expect(
        glossSurfaceEffective(
          glossSurfaceKindActionbar,
          GlossSurfacePresentation(text: 'hi', slots: <String>[]),
        ).slots,
        <String>['center'],
      );
    });
  });

  group('shape check', () {
    test('claims surface documents and nothing else', () {
      expect(looksLikeSurfaceDoc(jsonDecode(_shipped)), isTrue);
      expect(
        looksLikeSurfaceDoc(<String, Object?>{
          'schemaVersion': 2,
          'select': <String, Object?>{},
          'presentation': <String, Object?>{},
          'variants': <Object?>[],
        }),
        isFalse,
        reason: 'a scoreboard carries no surface discriminator',
      );
      expect(
        looksLikeSurfaceDoc(<String, Object?>{
          'schemaVersion': 1,
          'surface': 'actionbar',
        }),
        isFalse,
        reason: 'a surface document always carries a presentation',
      );
      // The kind that shares select/presentation/variants must not claim it.
      expect(looksLikeScoreboardDoc(jsonDecode(_shipped)), isFalse);
      expect(looksLikeMotdDoc(jsonDecode(_shipped)), isFalse);
      expect(looksLikeTablistDoc(jsonDecode(_shipped)), isFalse);
      expect(looksLikeConnectionsDoc(jsonDecode(_shipped)), isFalse);
    });
  });
}
