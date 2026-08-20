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
