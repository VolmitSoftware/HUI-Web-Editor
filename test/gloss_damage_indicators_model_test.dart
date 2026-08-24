library;

import 'dart:convert';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/damage_indicator_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('shipped default decodes and round-trips canonically', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    expect(doc.limits.maxPerSecond, 40);
    expect(doc.limits.lifetimeMs, 3000);
    expect(doc.damage.motion.horizontalSpeed, 0.8);
    expect(doc.healing.presentation.endScale, 1.1);
    expect(
      jsonDecode(encodeGlossDamageIndicatorsDoc(doc)),
      jsonDecode(kGlossDamageIndicatorsDefaultJson),
    );
    expect(validateDamageIndicatorsDoc(doc), isEmpty);
  });

  test('missing nested blocks resolve to runtime defaults', () {
    final GlossDamageIndicatorsDoc doc = decodeGlossDamageIndicatorsDoc(
      '{"schemaVersion":1,"revision":1,"limits":{},'
      '"damage":{},"healing":{},"filters":{}}',
    );
    expect(doc.limits.minimumDelta, 0.009);
    expect(doc.damage.offset, Vec3(0, 0.7, 0));
    expect(doc.damage.presentation.fadeStartFraction, 0.68);
    expect(doc.healing.motion.verticalAcceleration, 0.05);
  });

  test('explicit false and unknown extension keys round-trip', () {
    final GlossDamageIndicatorsDoc doc = decodeGlossDamageIndicatorsDoc('''
{
  "schemaVersion": 1,
  "revision": 7,
  "limits": {"futureLimit": 3},
  "damage": {"enabled": false, "futureStyle": true},
  "healing": {"enabled": false},
  "filters": {"disabledWorlds": ["world_nether"]},
  "futureRoot": {"kept": true}
}
''');
    final String encoded = encodeGlossDamageIndicatorsDoc(doc);
    expect(doc.damage.enabled, isFalse);
    expect(doc.healing.enabled, isFalse);
    expect(encoded, contains('"futureLimit": 3'));
    expect(encoded, contains('"futureStyle": true'));
    expect(encoded, contains('"futureRoot"'));
  });

  test('bad vectors and unsupported schema reject the document', () {
    expect(
      () => decodeGlossDamageIndicatorsDoc(
        '{"schemaVersion":1,"damage":{"offset":[0,1]},'
        '"limits":{},"healing":{},"filters":{}}',
      ),
      throwsA(isA<HuiFormatException>()),
    );
    expect(
      () => decodeGlossDamageIndicatorsDoc(
        '{"schemaVersion":2,"limits":{},"damage":{},'
        '"healing":{},"filters":{}}',
      ),
      throwsA(isA<HuiFormatException>()),
    );
  });

  test('validation reports contract clamps and missing amount tokens', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    doc.limits.decimals = 5;
    doc.damage.presentation.fadeStartFraction = -0.1;
    doc.healing.format = '&aHeal';
    doc.filters.disabledWorlds = <String>[
      '',
      'world',
      'WORLD',
      ' world',
      'world',
    ];
    final List<HuiIssue> issues = validateDamageIndicatorsDoc(doc);
    expect(
      issues.any((HuiIssue issue) => issue.path == r'$.limits.decimals'),
      isTrue,
    );
    expect(
      issues.any(
        (HuiIssue issue) =>
            issue.path == r'$.healing.format' &&
            issue.severity == HuiSeverity.error,
      ),
      isTrue,
    );
    expect(
      issues
          .where((HuiIssue issue) => issue.messageArguments['world'] == 'world')
          .map((HuiIssue issue) => issue.path),
      <String>[r'$.filters.disabledWorlds[4]'],
    );
    expect(issues, hasLength(greaterThanOrEqualTo(5)));
  });

  test('validation pins every runtime numeric boundary', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    doc.limits.maxPerSecond = 1000;
    doc.limits.lifetimeMs = 30000;
    doc.limits.minimumDelta = 1000;
    doc.limits.decimals = 4;
    doc.damage.motion.horizontalSpeed = 16;
    doc.damage.motion.verticalSpeed = -16;
    doc.damage.motion.verticalAcceleration = 32;
    doc.damage.motion.spinDegreesPerSecond = -1440;
    doc.damage.offset = Vec3(-32, 32, 32);
    doc.damage.presentation.startScale = 0;
    doc.damage.presentation.endScale = 16;
    doc.damage.presentation.fadeStartFraction = 1;
    expect(validateDamageIndicatorsDoc(doc), isEmpty);

    doc.limits.maxPerSecond = 1001;
    doc.limits.lifetimeMs = 30001;
    doc.limits.minimumDelta = 1000.001;
    doc.limits.decimals = 5;
    doc.damage.motion.horizontalSpeed = 16.001;
    doc.damage.motion.verticalSpeed = -16.001;
    doc.damage.motion.verticalAcceleration = 32.001;
    doc.damage.motion.spinDegreesPerSecond = 1440.001;
    doc.damage.offset = Vec3(-32.001, 32.001, 32.001);
    doc.damage.presentation.startScale = -0.001;
    doc.damage.presentation.endScale = 16.001;
    doc.damage.presentation.fadeStartFraction = 1.001;
    final Set<String> paths = validateDamageIndicatorsDoc(
      doc,
    ).map((HuiIssue issue) => issue.path).toSet();
    expect(
      paths,
      containsAll(<String>{
        r'$.limits.maxPerSecond',
        r'$.limits.lifetimeMs',
        r'$.limits.minimumDelta',
        r'$.limits.decimals',
        r'$.damage.offset.x',
        r'$.damage.offset.y',
        r'$.damage.offset.z',
        r'$.damage.motion.horizontalSpeed',
        r'$.damage.motion.verticalSpeed',
        r'$.damage.motion.verticalAcceleration',
        r'$.damage.motion.spinDegreesPerSecond',
        r'$.damage.presentation.startScale',
        r'$.damage.presentation.endScale',
        r'$.damage.presentation.fadeStartFraction',
      }),
    );
  });
}
