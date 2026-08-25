/// Hit-testing a pointer against the highlight layer, and what a key means.
///
/// The boxes are the browser's own measurements at runtime; here they are
/// written by hand so the geometry can be tested without a DOM.
library;

import 'package:gloss_editor/components/code_editor/code_hover.dart';
import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:test/test.dart';

/// A row of key boxes on one text line, each ten units wide.
List<HuiCodeKeyBox> _row(List<int> offsets) => <HuiCodeKeyBox>[
  for (int i = 0; i < offsets.length; i++)
    HuiCodeKeyBox(
      offset: offsets[i],
      left: i * 20,
      top: 0,
      right: i * 20 + 10,
      bottom: 16,
    ),
];

void main() {
  group('hit testing', () {
    final List<HuiCodeKeyBox> boxes = _row(<int>[4, 40, 90]);

    test('finds the box the point is inside', () {
      expect(huiCodeHoverHit(boxes, 5, 8), 4);
      expect(huiCodeHoverHit(boxes, 25, 8), 40);
      expect(huiCodeHoverHit(boxes, 45, 1), 90);
    });

    test('the top-left corner is inside and the bottom-right is not', () {
      expect(huiCodeHoverHit(boxes, 0, 0), 4);
      expect(huiCodeHoverHit(boxes, 10, 16), isNull);
    });

    test('the gap between two keys is nothing', () {
      expect(huiCodeHoverHit(boxes, 15, 8), isNull);
    });

    test('a point off the line is nothing', () {
      expect(huiCodeHoverHit(boxes, 5, 20), isNull);
      expect(huiCodeHoverHit(boxes, -1, 8), isNull);
    });

    test('an empty table is nothing', () {
      expect(huiCodeHoverHit(const <HuiCodeKeyBox>[], 5, 8), isNull);
    });

    test('the box itself comes back for positioning', () {
      expect(huiCodeHoverBox(boxes, 25, 8)?.offset, 40);
      expect(huiCodeHoverBox(boxes, 15, 8), isNull);
    });
  });

  group('key documentation', () {
    final GlossJsonObject menu = glossJsonSchemaFor('menu')!;

    HuiCodeKeyDoc? docFor(String source, String key) => huiCodeKeyDoc(
      root: menu,
      source: source,
      offset: source.indexOf('"$key"') + 1,
    );

    test('answers with the inspector help where there is some', () {
      const String source = '{"closeOnDeath": true}';
      final HuiCodeKeyDoc? doc = docFor(source, 'closeOnDeath');
      expect(doc, isNotNull);
      expect(doc!.title, 'Close on death');
      expect(doc.body, contains('Personal-menu behavior only'));
      expect(doc.citation, 'MenuSessionManager.java:121-140');
      expect(doc.path, r'$.closeOnDeath');
    });

    test('falls back to the model summary where there is no help', () {
      final GlossJsonObject drops = glossJsonSchemaFor('realDrops')!;
      const String source = '{"presentation": {"limits": {"spread": 0.2}}}';
      final HuiCodeKeyDoc? doc = huiCodeKeyDoc(
        root: drops,
        source: source,
        offset: source.indexOf('"spread"') + 1,
      );
      expect(doc!.title, 'Spread');
      expect(doc.body, contains('fan out'));
      expect(doc.citation, isNull);
      expect(doc.path, r'$.presentation.limits.spread');
    });

    test('documents nested damage-indicator motion fields', () {
      final GlossJsonObject indicators = glossJsonSchemaFor(
        'damageIndicators',
      )!;
      const String source =
          '{"damage":{"presentation":{"motion":'
          '{"verticalAcceleration":-0.93}}}}';
      final HuiCodeKeyDoc? doc = huiCodeKeyDoc(
        root: indicators,
        source: source,
        offset: source.indexOf('"verticalAcceleration"') + 1,
      );
      expect(doc!.title, 'Vertical acceleration');
      expect(doc.body, contains('-32..32'));
      expect(doc.path, r'$.damage.presentation.motion.verticalAcceleration');
    });

    test('names the path through a list and a variant', () {
      const String source =
          '{"components": [{"data": {"type": "button", "hitbox": '
          '{"anchor": "menu"}}}]}';
      final HuiCodeKeyDoc? doc = huiCodeKeyDoc(
        root: menu,
        source: source,
        offset: source.indexOf('"anchor"') + 1,
      );
      expect(doc!.path, r'$.components[0].data.hitbox.anchor');
      expect(doc.title, 'Anchor');
    });

    test('prints the type, the default and the accepted values', () {
      const String source = '{"components": [{"data": {"type": "toggle"}}]}';
      final HuiCodeKeyDoc? doc = huiCodeKeyDoc(
        root: menu,
        source: source,
        offset: source.indexOf('"type"', 20) + 1,
      );
      expect(doc!.detail, 'string · one of "button", "decoration", "toggle"');
    });

    test('counts the rest when a set is longer than a tooltip', () {
      final GlossJsonField entity = glossJsonFieldAt(menu, <JsonPathStep>[
        const JsonPathStep.key('components'),
        const JsonPathStep.index(0),
        const JsonPathStep.key('data'),
        const JsonPathStep.key('icon', ownerType: 'button'),
        const JsonPathStep.key('entity', ownerType: 'entity'),
      ])!;
      final String detail = huiCodeFieldDetail(entity);
      final String listed = detail.split('one of ').last;
      expect(
        RegExp('"minecraft:').allMatches(listed).length,
        huiCodeHoverValueLimit,
      );
      expect(
        listed,
        endsWith('and ${entity.values.length - huiCodeHoverValueLimit} more'),
      );
    });

    test('says an unknown key is preserved rather than wrong', () {
      const String source = '{"somethingNew": 1}';
      final HuiCodeKeyDoc? doc = docFor(source, 'somethingNew');
      expect(doc!.title, 'somethingNew');
      expect(doc.body, contains('keeps it through every round trip'));
      expect(doc.detail, isEmpty);
    });

    test('explains a nested conditional list-name field', () {
      final GlossJsonObject tablist = glossJsonSchemaFor('tablist')!;
      const String source =
          '{"listNames":{"variants":[{"when":"subject.op"}]}}';
      final HuiCodeKeyDoc? doc = huiCodeKeyDoc(
        root: tablist,
        source: source,
        offset: source.indexOf('"when"') + 1,
      );
      expect(doc!.title, 'Condition');
      expect(doc.body, contains('boolean expression'));
    });

    test('a value string is not a key and gets no card', () {
      const String source = '{"closeOnDeath": "true"}';
      expect(
        huiCodeKeyDoc(
          root: menu,
          source: source,
          offset: source.indexOf('"true"') + 1,
        ),
        isNull,
      );
    });
  });
}
