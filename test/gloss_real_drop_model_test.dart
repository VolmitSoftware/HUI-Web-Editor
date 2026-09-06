library;

import 'package:gloss_editor/logic/real_drop_validation.dart';
import 'package:gloss_editor/model/gloss_hologram_box.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('missing nested values use the runtime defaults', () {
    final GlossRealDropSettingsDoc doc = decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 4,
  "revision": 1,
  "presentation": {
  "limits": {},
  "scale": {},
  "motion": {},
  "landing": {},
  "labels": {},
  "filters": {}
  },
  "variants": [],
  "audience": {"when": "true"}
}
''');
    expect(doc.presentation.limits.updateIntervalTicks, 2);
    expect(doc.presentation.motion.speedMultiplier, 1.35);
    expect(doc.presentation.motion.tumble, isTrue);
    expect(doc.presentation.motion.velocityInfluence, 0.35);
    expect(doc.presentation.motion.groundRollMultiplier, 1);
    expect(doc.presentation.landing.faceAttraction, 0.55);
    expect(doc.presentation.landing.settleDelayTicks, 4);
    expect(doc.presentation.labels.style.seeThrough, isTrue);
    expect(doc.presentation.filters.materialBlacklist, <String>[
      'BEDROCK',
      'BARRIER',
    ]);
    expect(validateRealDropSettingsDoc(doc), isEmpty);
  });

  test('explicit false values and unknown keys round-trip', () {
    final GlossRealDropSettingsDoc doc = decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 4,
  "revision": 4,
  "presentation": {
  "limits": {"futureLimit": 7},
  "scale": {},
  "motion": {"tumble": false, "changeOnBounce": false},
  "landing": {"randomYaw": false},
  "labels": {"enabled": false, "style": {"seeThrough": false}},
  "filters": {"onlyPlayerDrops": true}
  },
  "variants": [],
  "audience": {"when": "true"},
  "futureRoot": {"kept": true}
}
''');
    expect(doc.presentation.motion.tumble, isFalse);
    expect(doc.presentation.motion.changeOnBounce, isFalse);
    expect(doc.presentation.landing.randomYaw, isFalse);
    expect(doc.presentation.labels.enabled, isFalse);
    expect(doc.presentation.labels.style.seeThrough, isFalse);
    expect(doc.presentation.filters.onlyPlayerDrops, isTrue);
    final String encoded = encodeGlossRealDropSettingsDoc(doc);
    expect(encoded, contains('"futureLimit": 7'));
    expect(encoded, contains('"futureRoot"'));
  });

  test('out-of-range settings remain editable and report runtime clamps', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc();
    doc.presentation.motion.speedMultiplier = 9;
    doc.presentation.labels.yOffset = -99;
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
      doc.presentation.motion.velocityInfluence = 1.4;
      doc.presentation.motion.submergedSpinMultiplier = 0.2;
      doc.presentation.motion.groundRollMultiplier = 0.8;
      doc.presentation.landing.faceAttraction = 0.7;
      doc.presentation.landing.movingFaceAttraction = 0.1;
      doc.presentation.landing.alignmentDegrees = 0.25;
      doc.presentation.landing.settleDelayTicks = 12;

      final GlossRealDropSettingsDoc decoded = decodeGlossRealDropSettingsDoc(
        encodeGlossRealDropSettingsDoc(doc),
      );
      expect(decoded.presentation.motion.velocityInfluence, 1.4);
      expect(decoded.presentation.motion.submergedSpinMultiplier, 0.2);
      expect(decoded.presentation.motion.groundRollMultiplier, 0.8);
      expect(decoded.presentation.landing.faceAttraction, 0.7);
      expect(decoded.presentation.landing.movingFaceAttraction, 0.1);
      expect(decoded.presentation.landing.alignmentDegrees, 0.25);
      expect(decoded.presentation.landing.settleDelayTicks, 12);
    },
  );

  test('label style and box round-trip independent axes and colors', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc();
    doc.presentation.labels.style = HuiIconStyle(
      billboard: 'horizontal',
      scaleX: 2,
      scaleY: 0.5,
      scaleZ: 3,
      textOpacity: 142,
      backgroundArgb: '#80224466',
      blockLight: 8,
      skyLight: 12,
      textAlignment: 'right',
    );
    doc.presentation.labels.box = GlossHologramBox(
      enabled: true,
      padding: 9,
      borderWidth: 3,
      backgroundArgb: '#33224466',
      borderArgb: '#FF334455',
    );
    final GlossRealDropSettingsDoc restored = decodeGlossRealDropSettingsDoc(
      encodeGlossRealDropSettingsDoc(doc),
    );
    expect(
      restored.presentation.labels.style.toJson(),
      doc.presentation.labels.style.toJson(),
    );
    expect(
      restored.presentation.labels.box.toJson(),
      doc.presentation.labels.box.toJson(),
    );
    expect(validateRealDropSettingsDoc(restored), isEmpty);
  });

  test('unsupported schema is rejected', () {
    expect(
      () => decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 1,
  "presentation": {},
  "variants": [],
  "audience": {"when": "true"}
}
'''),
      throwsA(isA<HuiFormatException>()),
    );
  });
}
