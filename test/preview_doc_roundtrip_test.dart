import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

/// Verbatim copy of `HoloUi/src/main/resources/previews/furnace.json` (the
/// plugin's own shipped preview document), not a hand-authored fixture: it
/// exercises real key ordering (`visible`/`repeat` hoisted ahead of `x`/`y`
/// in several cell elements), variants, and every expression shape the
/// format supports.
const String furnaceJson = r'''
{
  "match": {
    "blocks": ["FURNACE", "BLAST_FURNACE", "SMOKER"],
    "priority": 10,
    "vars": {
      "style": "furnace",
      "segments": 8,
      "wellColor": "#FF15151B",
      "fill": "#FFF2A535",
      "pulseBright": "#FFFFD978",
      "pulseDim": "#FF8A5E1E",
      "chase": "#FF9A5E22",
      "idle": "#FF2A2A33",
      "flame0": "#FFE2641E",
      "flame1": "#FFF2A535",
      "flame2": "#FFF7D14C",
      "smoke0": "#FF5E5E66",
      "smoke1": "#FF8A8A92",
      "smoke2": "#FFB8B8C0",
      "activeItemKey": "holoui.preview.state.smelting_item",
      "activeKey": "holoui.preview.state.smelting",
      "stateColor": "<#F2A535>",
      "surgeColor": "<#FFD978>",
      "titleKey": "holoui.preview.theme.title.furnace",
      "accent": "#F2A535"
    }
  },
  "variants": [
    {
      "blocks": ["BLAST_FURNACE"],
      "vars": {
        "style": "blast",
        "fill": "#FF6FB8E8",
        "pulseBright": "#FFE8F7FF",
        "pulseDim": "#FF2E5E80",
        "chase": "#FF4FA8D8",
        "idle": "#FF23262E",
        "flame0": "#FF4FA8E8",
        "flame1": "#FF8ED4FF",
        "flame2": "#FFE8F7FF",
        "activeItemKey": "holoui.preview.state.blasting_item",
        "activeKey": "holoui.preview.state.blasting",
        "stateColor": "<#6FB8E8>",
        "surgeColor": "<#E8F7FF>",
        "titleKey": "holoui.preview.theme.title.blast_furnace",
        "accent": "#6FEAEA"
      }
    },
    {
      "blocks": ["SMOKER"],
      "vars": {
        "style": "smoker",
        "fill": "#FFC8893A",
        "pulseBright": "#FFF2C878",
        "pulseDim": "#FF6E4A1E",
        "chase": "#FF8A6234",
        "idle": "#FF2A2A33",
        "flame0": "#FFE25822",
        "flame1": "#FFF2A535",
        "flame2": "#FFC23B22",
        "activeItemKey": "holoui.preview.state.smoking_item",
        "activeKey": "holoui.preview.state.smoking",
        "stateColor": "<#C8893A>",
        "surgeColor": "<#F2C878>",
        "titleKey": "holoui.preview.theme.title.smoker",
        "accent": "#F2D451"
      }
    }
  ],
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey)))",
    "accent": "vars.accent"
  },
  "elements": [
    { "type": "slot", "x": -40, "y": 10, "size": 18, "index": 0 },
    { "type": "slot", "x": -40, "y": -10, "size": 18, "index": 1 },
    { "type": "slot", "x": 40, "y": 10, "size": 18, "index": 2 },
    {
      "type": "cell",
      "repeat": { "count": "vars.segments", "var": "i" },
      "x": "-24 + i * 7",
      "y": 10,
      "size": 5,
      "color": "cookTime > 0 && cookTimeTotal > 0 ? (i < floor(cookTime / cookTimeTotal * vars.segments) ? (surge.active ? (mod(floor(cookTime / 2) + i, 2) == 0 ? vars.pulseBright : vars.fill) : vars.fill) : (i == floor(cookTime / cookTimeTotal * vars.segments) ? (mod(floor(cookTime / 4), 2) == 0 ? vars.pulseBright : vars.pulseDim) : vars.wellColor)) : (burnTime > 0 && i == mod(floor(burnTime / 4), vars.segments) ? vars.chase : vars.wellColor)"
    },
    {
      "type": "cell",
      "visible": "vars.style != 'blast'",
      "x": -20,
      "y": -10,
      "size": 12,
      "color": "burnTime > 0 ? palette([vars.flame0, vars.flame1, vars.flame2], floor(burnTime / (surge.active ? 2 : 4))) : vars.idle"
    },
    {
      "type": "cell",
      "visible": "vars.style == 'blast'",
      "repeat": { "count": 3, "var": "vent" },
      "x": "-20 + vent * 8",
      "y": -10,
      "size": 6,
      "color": "burnTime > 0 ? palette([vars.flame0, vars.flame1, vars.flame2], floor(burnTime / (surge.active ? 2 : 4)) + vent) : vars.idle"
    },
    {
      "type": "cell",
      "visible": "vars.style == 'smoker'",
      "repeat": { "count": 2, "var": "wisp" },
      "x": "wisp == 0 ? -8 : 2",
      "y": -10,
      "size": "wisp == 0 ? 8 : 6",
      "color": "burnTime > 0 ? palette([vars.smoke0, vars.smoke1, vars.smoke2], floor(burnTime / (surge.active ? 2 : 4)) + wisp + 1) : vars.idle"
    },
    {
      "type": "label",
      "x": 0,
      "y": -32,
      "text": "(cookTime > 0 && cookTimeTotal > 0 ? vars.stateColor + lang(occupied(0) ? vars.activeItemKey : vars.activeKey, occupied(0) ? readable(item(0)) : round(cookTime * 100 / cookTimeTotal), round(cookTime * 100 / cookTimeTotal)) : (burnTime > 0 && occupied(0) ? '&e' + lang('holoui.preview.state.heating') : (occupied(0) && !occupied(1) ? '&c' + lang('holoui.preview.state.needs_fuel') : (!occupied(0) ? '&7' + lang('holoui.preview.state.no_input') : '&7' + lang('holoui.preview.state.waiting'))))) + (surge.active ? vars.surgeColor + lang('holoui.preview.state.surge_suffix', surge.gain == floor(surge.gain) ? str(surge.gain) : fixed(surge.gain, 1)) : '')"
    },
    {
      "type": "label",
      "x": 0,
      "y": -46,
      "text": "(burnTime > 0 ? '&e' + lang('holoui.preview.stat.fuel_seconds', fuelSeconds) : (occupied(1) ? '&7' + lang('holoui.preview.stat.fuel_ready') : '&8' + lang('holoui.preview.stat.no_fuel'))) + (bankedXp >= 0 ? '<dark_gray>  •  </dark_gray>' + (bankedXp > 0 ? '<green>' + lang('holoui.preview.stat.xp_gain', bankedXp == floor(bankedXp) ? str(bankedXp) : fixed(bankedXp, 1)) + '</green>' : '<dark_gray>' + lang('holoui.preview.stat.xp_zero') + '</dark_gray>') : '')"
    }
  ]
}
''';

void main() {
  group('detection', () {
    test('a document with elements and no components looks like a preview', () {
      expect(looksLikePreviewDoc(jsonDecode(furnaceJson)), isTrue);
    });

    test('a component menu does not look like a preview document', () {
      expect(
        looksLikePreviewDoc(jsonDecode('{"offset":[0,0,0],"components":[]}')),
        isFalse,
      );
    });

    test('a document with elements AND components is not a preview', () {
      expect(
        looksLikePreviewDoc(jsonDecode('{"elements":[],"components":[]}')),
        isFalse,
      );
    });

    test('neither shape is detected as a preview', () {
      expect(looksLikePreviewDoc(jsonDecode('{}')), isFalse);
      expect(looksLikePreviewDoc(jsonDecode('[1,2]')), isFalse);
    });
  });

  group('furnace.json decode', () {
    test('reads the top-level match', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(furnaceJson);
      expect(doc.match.blocks, <String>['FURNACE', 'BLAST_FURNACE', 'SMOKER']);
      expect(doc.match.entities, isEmpty);
      expect(doc.match.special, isNull);
      expect(doc.match.priority, 10);
      expect(doc.match.vars['segments'], 8.0);
      expect(doc.match.vars['style'], 'furnace');
    });

    test("a vars value leading with '#' stays a plain string in the model", () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(furnaceJson);
      expect(doc.match.vars['wellColor'], '#FF15151B');
      expect(doc.match.vars['stateColor'], '<#F2A535>');
    });

    test('reads two variants', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(furnaceJson);
      expect(doc.variants.length, 2);
      expect(doc.variants[0].blocks, <String>['BLAST_FURNACE']);
      expect(doc.variants[0].vars['style'], 'blast');
      expect(doc.variants[1].blocks, <String>['SMOKER']);
      expect(doc.variants[1].vars['style'], 'smoker');
    });

    test('reads the card as raw expression strings', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(furnaceJson);
      expect(doc.card, isNotNull);
      expect(
        doc.card!.title,
        "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey)))",
      );
      expect(doc.card!.accent, 'vars.accent');
      expect(doc.card!.framed, isNull);
      expect(doc.card!.minHalfWidth, isNull);
    });

    test('card framed/minHalfWidth absence is recorded, not defaulted', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(furnaceJson);
      expect(
        doc.card!.absentKeys,
        containsAll(<String>['framed', 'minHalfWidth']),
      );
    });

    test('reads every element in paint order with raw unevaluated values', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(furnaceJson);
      expect(doc.elements.length, 9);

      final HuiPreviewElement slot0 = doc.elements[0];
      expect(slot0.type, 'slot');
      expect(slot0.x, -40);
      expect(slot0.y, 10);
      expect(slot0.size, 18);
      expect(slot0.index, 0);
      expect(slot0.wellColor, isNull);
      // z has a type-dependent default the parser applies, not the model.
      expect(slot0.z, isNull);
      expect(slot0.absentKeys, contains('z'));
      expect(slot0.absentKeys, contains('wellColor'));

      final HuiPreviewElement segments = doc.elements[3];
      expect(segments.type, 'cell');
      expect(segments.x, '-24 + i * 7');
      expect(segments.repeat, isNotNull);
      expect(segments.repeat!.count, 'vars.segments');
      expect(segments.repeat!.varName, 'i');
      expect(segments.color, contains('cookTime > 0 && cookTimeTotal > 0'));

      final HuiPreviewElement blastVent = doc.elements[5];
      expect(blastVent.visible, "vars.style == 'blast'");
      expect(blastVent.repeat!.count, 3);
      expect(blastVent.repeat!.varName, 'vent');

      final HuiPreviewElement label0 = doc.elements[7];
      expect(label0.type, 'label');
      expect(label0.text, contains('lang(occupied(0)'));
      expect(label0.visible, isNull);
    });
  });

  group('byte-stable round trip', () {
    test('re-exporting an untouched document is a fixed point', () {
      final HuiPreviewDoc once = decodeHuiPreviewDoc(furnaceJson);
      final String firstExport = encodeHuiPreviewDoc(once);
      final HuiPreviewDoc twice = decodeHuiPreviewDoc(firstExport);
      expect(encodeHuiPreviewDoc(twice), firstExport);
    });

    test('decoding the re-export reproduces the same semantic document', () {
      final HuiPreviewDoc once = decodeHuiPreviewDoc(furnaceJson);
      final HuiPreviewDoc twice = decodeHuiPreviewDoc(
        encodeHuiPreviewDoc(once),
      );
      expect(twice.elements.length, once.elements.length);
      expect(twice.variants.length, once.variants.length);
      expect(twice.match.blocks, once.match.blocks);
      expect(twice.elements[3].color, once.elements[3].color);
    });
  });

  group('unknown key preservation', () {
    const String withExtras = '''
{
  "weirdRoot": "x",
  "match": {"blocks": ["CHEST"], "weirdMatch": 1},
  "variants": [{"blocks": ["BARREL"], "weirdVariant": 2}],
  "card": {"title": "'hi'", "weirdCard": 3},
  "elements": [
    {"type": "panel", "width": 10, "height": 10, "color": 0, "weirdElement": 4,
     "repeat": {"count": 2, "weirdRepeat": 5}}
  ]
}
''';

    test('unknown keys survive a round trip at every level', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(withExtras);
      expect(doc.extras['weirdRoot'], 'x');
      expect(doc.match.extras['weirdMatch'], 1);
      expect(doc.variants.single.extras['weirdVariant'], 2);
      expect(doc.card!.extras['weirdCard'], 3);
      expect(doc.elements.single.extras['weirdElement'], 4);
      expect(doc.elements.single.repeat!.extras['weirdRepeat'], 5);

      final String out = encodeHuiPreviewDoc(doc);
      final Map<String, dynamic> tree = jsonDecode(out) as Map<String, dynamic>;
      expect(tree['weirdRoot'], 'x');
      expect((tree['match'] as Map<String, dynamic>)['weirdMatch'], 1);
      expect(
        ((tree['variants'] as List<dynamic>).single
            as Map<String, dynamic>)['weirdVariant'],
        2,
      );
      expect((tree['card'] as Map<String, dynamic>)['weirdCard'], 3);
      final Map<String, dynamic> element =
          (tree['elements'] as List<dynamic>).single as Map<String, dynamic>;
      expect(element['weirdElement'], 4);
      expect((element['repeat'] as Map<String, dynamic>)['weirdRepeat'], 5);
    });

    test('re-decoding an export with extras is a fixed point', () {
      final String first = encodeHuiPreviewDoc(decodeHuiPreviewDoc(withExtras));
      expect(encodeHuiPreviewDoc(decodeHuiPreviewDoc(first)), first);
    });
  });

  group('absent defaultable keys are recorded, not defaulted', () {
    test('match.priority absence is recorded', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(
        '{"match":{"blocks":["CHEST"]},"elements":[]}',
      );
      expect(doc.match.priority, isNull);
      expect(doc.match.absentKeys, contains('priority'));
    });

    test('repeat.var absence is recorded and stays absent, not "i"', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(
        '{"elements":[{"type":"cell","repeat":{"count":3}}]}',
      );
      final HuiPreviewRepeat repeat = doc.elements.single.repeat!;
      expect(repeat.varName, isNull);
      expect(repeat.absentKeys, contains('var'));
    });

    test('element visible/background absence is recorded', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(
        '{"elements":[{"type":"label","text":"hi"}]}',
      );
      final HuiPreviewElement label = doc.elements.single;
      expect(label.visible, isNull);
      expect(label.background, isNull);
      expect(
        label.absentKeys,
        containsAll(<String>['visible', 'background', 'z']),
      );
    });
  });

  group('empty document', () {
    test('an empty object decodes to an empty preview document', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc('{}');
      expect(doc.match.blocks, isEmpty);
      expect(doc.variants, isEmpty);
      expect(doc.card, isNull);
      expect(doc.elements, isEmpty);
    });

    test('elements is always emitted, even when empty, for round-trip '
        'detection stability', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc('{}');
      final String out = encodeHuiPreviewDoc(doc);
      expect(looksLikePreviewDoc(jsonDecode(out)), isTrue);
    });

    test('an empty document omits match/variants/card entirely', () {
      final String out = encodeHuiPreviewDoc(decodeHuiPreviewDoc('{}'));
      expect(out, isNot(contains('"match"')));
      expect(out, isNot(contains('"variants"')));
      expect(out, isNot(contains('"card"')));
    });
  });

  group('copies', () {
    test('copy() is deep and independent', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(furnaceJson);
      final HuiPreviewDoc copy = doc.copy();
      copy.elements.removeLast();
      copy.match.blocks.add('X');
      expect(doc.elements.length, 9);
      expect(doc.match.blocks, isNot(contains('X')));
      expect(encodeHuiPreviewDoc(copy), isNot(encodeHuiPreviewDoc(doc)));
    });
  });
}
