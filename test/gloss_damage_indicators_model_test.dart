import 'dart:convert';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/damage_indicator_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('shipped schema 2 default decodes and round-trips canonically', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    expect(doc.limits.maxPerSecond, 40);
    expect(doc.damage.when, 'true');
    expect(doc.damage.presentation.motion.horizontalSpeed, 0.8);
    expect(doc.healing.presentation.transform.endScale, 1.1);
    expect(
      doc.audience.when,
      "hasPermission('viewer', 'gloss.indicators.show')",
    );
    expect(
      jsonDecode(encodeGlossDamageIndicatorsDoc(doc)),
      jsonDecode(kGlossDamageIndicatorsDefaultJson),
    );
    expect(validateDamageIndicatorsDoc(doc), isEmpty);
  });

  test('unsupported schema versions are rejected', () {
    expect(
      () => decodeGlossDamageIndicatorsDoc(
        '{"schemaVersion":1,"limits":{},"damage":{},'
        '"healing":{},"filters":{}}',
      ),
      throwsA(isA<HuiFormatException>()),
    );
  });

  test('complete variants preserve their full presentation', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    doc.damage.variants.add(
      GlossDamageIndicatorVariant(
        id: 'critical',
        priority: 100,
        when: 'subject.health < 5',
        presentation: doc.damage.presentation.copy()..format = '&4&l{amount}',
      ),
    );
    final GlossDamageIndicatorsDoc decoded = decodeGlossDamageIndicatorsDoc(
      encodeGlossDamageIndicatorsDoc(doc),
    );
    expect(decoded.damage.variants.single.id, 'critical');
    expect(decoded.damage.variants.single.presentation.format, '&4&l{amount}');
  });

  test('incomplete variant presentations reject at their exact path', () {
    expect(
      () => decodeGlossDamageIndicatorsDoc('''
{
  "schemaVersion": 2,
  "revision": 1,
  "damage": {
    "when": "true",
    "presentation": {
      "format": "{amount}",
      "offset": [0, 0, 0],
      "motion": {},
      "transform": {}
    },
    "variants": [{
      "id": "bad", "priority": 1, "when": "true",
      "presentation": {"format": "{amount}"}
    }]
  },
  "healing": {
    "when": "true",
    "presentation": {
      "format": "{amount}",
      "offset": [0, 0, 0],
      "motion": {},
      "transform": {}
    },
    "variants": []
  },
  "audience": {"when": "true"}
}
'''),
      throwsA(
        isA<HuiFormatException>().having(
          (HuiFormatException error) => error.path,
          'path',
          r'$.damage.variants[0].presentation.offset',
        ),
      ),
    );
  });

  test('validation covers conditions, ids and nested presentation ranges', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    doc.damage.when = 'event.amount >';
    doc.healing.variants = <GlossDamageIndicatorVariant>[
      GlossDamageIndicatorVariant(
        id: 'bad/id',
        when: 'true',
        presentation: doc.healing.presentation.copy()
          ..transform.fadeStartFraction = 2,
      ),
    ];
    final List<HuiIssue> issues = validateDamageIndicatorsDoc(doc);
    expect(
      issues.map((HuiIssue issue) => issue.path),
      containsAll(<String>{
        r'$.damage.when',
        r'$.healing.variants[0].id',
        r'$.healing.variants[0].presentation.transform.fadeStartFraction',
      }),
    );
  });
}
