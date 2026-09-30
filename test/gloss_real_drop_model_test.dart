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

  test('label text fields default to the shipped runtime values', () {
    final GlossRealDropLabels labels = GlossRealDropLabels.fromJson(
      <String, Object?>{},
    );
    expect(labels.format, '&7{count}x {type}');
    expect(labels.useItemDisplayNames, isFalse);
    expect(labels.names, isEmpty);
    expect(
      labels.bundle.format,
      '&7Bundle &8(&7{total} items&8): &7{contents}',
    );
    expect(labels.bundle.entryLimit, 3);
    expect(labels.bundle.vertical, isTrue);
    expect(labels.bundle.headerFormat, '&eBundle &8(&e{total} items&8)');
    expect(labels.bundle.entryFormat, '&7- &f{count}x {type}');
    expect(labels.bundle.moreFormat, '&8+{remaining} more');
    expect(labels.extras, isEmpty);
  });

  test('label text, names and bundle round-trip in file order', () {
    final GlossRealDropSettingsDoc doc = decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 4,
  "revision": 1,
  "presentation": {
    "labels": {
      "format": "{type} &8x{count}",
      "useItemDisplayNames": true,
      "names": {"STONE": "&7Rock", "COBBLESTONE": "&7Cobble", "dirt": "Soil"},
      "bundle": {
        "format": "{contents}",
        "entryLimit": 6,
        "vertical": false,
        "headerFormat": "{total}",
        "entryFormat": "{type}",
        "moreFormat": "+{remaining}",
        "futureBundleKey": 1
      }
    }
  },
  "variants": [],
  "audience": {"when": "true"}
}
''');
    final GlossRealDropLabels labels = doc.presentation.labels;
    expect(labels.format, '{type} &8x{count}');
    expect(labels.useItemDisplayNames, isTrue);
    expect(labels.names.keys, <String>['STONE', 'COBBLESTONE', 'dirt']);
    expect(labels.bundle.entryLimit, 6);
    expect(labels.bundle.vertical, isFalse);
    expect(labels.extras, isEmpty);

    final Map<String, Object?> json = decodeGlossRealDropSettingsDoc(
      encodeGlossRealDropSettingsDoc(doc),
    ).presentation.labels.toJson();
    expect(json.keys, <String>[
      'enabled',
      'yOffset',
      'format',
      'useItemDisplayNames',
      'names',
      'bundle',
      'style',
      'box',
    ]);
    expect(json['names'], <String, String>{
      'STONE': '&7Rock',
      'COBBLESTONE': '&7Cobble',
      'dirt': 'Soil',
    });
    expect(json['bundle'], <String, Object?>{
      'format': '{contents}',
      'entryLimit': 6,
      'vertical': false,
      'headerFormat': '{total}',
      'entryFormat': '{type}',
      'moreFormat': '+{remaining}',
      'futureBundleKey': 1,
    });
  });

  test('label entries the server clamps or drops are reported', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc();
    doc.presentation.labels.bundle.entryLimit = 12;
    doc.presentation.labels.names['STONE'] = ' ';
    final List<String> paths = <String>[
      for (final HuiIssue issue in validateRealDropSettingsDoc(doc))
        if (issue.severity == HuiSeverity.warning) issue.path,
    ];
    expect(paths, <String>[
      r'$.presentation.labels.names.STONE',
      r'$.presentation.labels.bundle.entryLimit',
    ]);
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
