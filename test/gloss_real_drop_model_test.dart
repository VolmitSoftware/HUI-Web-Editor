library;

import 'package:gloss_editor/logic/real_drop_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('missing nested values use the runtime defaults', () {
    final GlossRealDropSettingsDoc doc = decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 1,
  "revision": 1,
  "limits": {},
  "scale": {},
  "motion": {},
  "landing": {},
  "labels": {},
  "filters": {}
}
''');
    expect(doc.limits.updateIntervalTicks, 2);
    expect(doc.motion.speedMultiplier, 1.35);
    expect(doc.motion.tumble, isTrue);
    expect(doc.motion.velocityInfluence, 0.35);
    expect(doc.motion.groundRollMultiplier, 1);
    expect(doc.landing.faceAttraction, 0.55);
    expect(doc.landing.settleDelayTicks, 4);
    expect(doc.labels.seeThrough, isTrue);
    expect(doc.filters.materialBlacklist, <String>['BEDROCK', 'BARRIER']);
    expect(validateRealDropSettingsDoc(doc), isEmpty);
  });

  test('explicit false values and unknown keys round-trip', () {
    final GlossRealDropSettingsDoc doc = decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 1,
  "revision": 4,
  "limits": {"futureLimit": 7},
  "scale": {},
  "motion": {"tumble": false, "changeOnBounce": false},
  "landing": {"randomYaw": false},
  "labels": {"enabled": false, "seeThrough": false},
  "filters": {"onlyPlayerDrops": true},
  "futureRoot": {"kept": true}
}
''');
    expect(doc.motion.tumble, isFalse);
    expect(doc.motion.changeOnBounce, isFalse);
    expect(doc.landing.randomYaw, isFalse);
    expect(doc.labels.enabled, isFalse);
    expect(doc.labels.seeThrough, isFalse);
    expect(doc.filters.onlyPlayerDrops, isTrue);
    final String encoded = encodeGlossRealDropSettingsDoc(doc);
    expect(encoded, contains('"futureLimit": 7'));
    expect(encoded, contains('"futureRoot"'));
  });

  test('out-of-range settings remain editable and report runtime clamps', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc();
    doc.motion.speedMultiplier = 9;
    doc.labels.backgroundAlpha = -1;
    final List<HuiIssue> issues = validateRealDropSettingsDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.severity == HuiSeverity.warning),
      hasLength(2),
    );
  });

  test(
    'continuous motion controls round-trip through the authored document',
    () {
      final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc();
      doc.motion.velocityInfluence = 1.4;
      doc.motion.submergedSpinMultiplier = 0.2;
      doc.motion.groundRollMultiplier = 0.8;
      doc.landing.faceAttraction = 0.7;
      doc.landing.movingFaceAttraction = 0.1;
      doc.landing.alignmentDegrees = 0.25;
      doc.landing.settleDelayTicks = 12;

      final GlossRealDropSettingsDoc decoded = decodeGlossRealDropSettingsDoc(
        encodeGlossRealDropSettingsDoc(doc),
      );
      expect(decoded.motion.velocityInfluence, 1.4);
      expect(decoded.motion.submergedSpinMultiplier, 0.2);
      expect(decoded.motion.groundRollMultiplier, 0.8);
      expect(decoded.landing.faceAttraction, 0.7);
      expect(decoded.landing.movingFaceAttraction, 0.1);
      expect(decoded.landing.alignmentDegrees, 0.25);
      expect(decoded.landing.settleDelayTicks, 12);
    },
  );

  test('unsupported schema is rejected', () {
    expect(
      () => decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 2,
  "limits": {},
  "scale": {},
  "motion": {},
  "landing": {},
  "labels": {},
  "filters": {}
}
'''),
      throwsA(isA<HuiFormatException>()),
    );
  });
}
