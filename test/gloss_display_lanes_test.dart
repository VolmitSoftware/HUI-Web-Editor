import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/display_lane_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

void main() {
  test('dialog example round-trips and matches the plugin resource', () {
    final File plugin = File(
      glossRepositoryFilePath('src/main/resources/defaults/dialogs/example.json'),
    );
    expect(plugin.existsSync(), isTrue);
    expect(kGlossDialogExampleJson, plugin.readAsStringSync());
    final GlossDialogDoc doc = buildShowcaseGlossDialog();
    expect(doc.type, 'multi_action');
    expect(doc.buttons, hasLength(2));
    expect(looksLikeDialogDoc(jsonDecode(kGlossDialogExampleJson)), isTrue);
    expect(looksLikeInventoryDoc(jsonDecode(kGlossDialogExampleJson)), isFalse);
    expect(
      validateDialogDoc(doc)
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
    expect(
      jsonDecode(encodeGlossDialogDoc(decodeGlossDialogDoc(encodeGlossDialogDoc(doc)))),
      jsonDecode(encodeGlossDialogDoc(doc)),
    );
  });

  test('inventory example round-trips and matches the plugin resource', () {
    final File plugin = File(
      glossRepositoryFilePath(
        'src/main/resources/defaults/inventories/example.json',
      ),
    );
    expect(kGlossInventoryExampleJson, plugin.readAsStringSync());
    final GlossInventoryDoc doc = buildShowcaseGlossInventory();
    expect(doc.resolution, '9x6');
    expect(doc.list?.area, '.');
    expect(looksLikeInventoryDoc(jsonDecode(kGlossInventoryExampleJson)), isTrue);
    expect(
      validateInventoryDoc(doc)
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
  });

  test('nameplate default matches the plugin resource', () {
    final File plugin = File(
      glossRepositoryFilePath(
        'src/main/resources/defaults/nameplates/default.json',
      ),
    );
    expect(kGlossNameplateDefaultJson, plugin.readAsStringSync());
    final GlossNameplateDoc doc = buildDefaultGlossNameplate();
    expect(doc.presentation.lines, hasLength(2));
    expect(looksLikeNameplateDoc(jsonDecode(kGlossNameplateDefaultJson)), isTrue);
    expect(looksLikeScoreboardDoc(jsonDecode(kGlossNameplateDefaultJson)), isFalse);
    expect(looksLikeNametagDoc(jsonDecode(kGlossNameplateDefaultJson)), isFalse);
  });

  test('nametag default matches the plugin resource', () {
    final File plugin = File(
      glossRepositoryFilePath(
        'src/main/resources/defaults/nametags/default.json',
      ),
    );
    expect(kGlossNametagDefaultJson, plugin.readAsStringSync());
    final GlossNametagDoc doc = buildDefaultGlossNametag();
    expect(doc.presentation.prefix, contains('subject.group'));
    expect(looksLikeNametagDoc(jsonDecode(kGlossNametagDefaultJson)), isTrue);
    expect(looksLikeNameplateDoc(jsonDecode(kGlossNametagDefaultJson)), isFalse);
  });

  test('motion clips match the plugin resources', () {
    expect(
      kGlossMotionBreatheJson,
      File(
        glossRepositoryFilePath('src/main/resources/defaults/motion/breathe.json'),
      ).readAsStringSync(),
    );
    expect(
      kGlossMotionSpinJson,
      File(
        glossRepositoryFilePath('src/main/resources/defaults/motion/spin.json'),
      ).readAsStringSync(),
    );
    expect(buildDefaultGlossMotion().tracks, hasLength(2));
    expect(buildShowcaseGlossMotion().loop, 'loop');
    expect(looksLikeMotionDoc(jsonDecode(kGlossMotionBreatheJson)), isTrue);
    expect(looksLikeRigDoc(jsonDecode(kGlossMotionBreatheJson)), isFalse);
    expect(
      validateMotionDoc(buildDefaultGlossMotion())
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
  });

  test('rig pedestal matches the plugin resource', () {
    expect(
      kGlossRigPedestalJson,
      File(
        glossRepositoryFilePath('src/main/resources/defaults/rigs/pedestal.json'),
      ).readAsStringSync(),
    );
    final GlossRigDoc doc = buildDefaultGlossRig();
    expect(doc.bones, hasLength(2));
    expect(doc.parts, hasLength(3));
    expect(doc.clips['idle']?.motion, 'breathe');
    expect(looksLikeRigDoc(jsonDecode(kGlossRigPedestalJson)), isTrue);
    expect(
      validateRigDoc(doc)
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
  });

  test('marker and zone templates validate', () {
    expect(looksLikeMarkerDoc(jsonDecode(kGlossMarkerDefaultJson)), isTrue);
    expect(looksLikeHologramDoc(jsonDecode(kGlossMarkerDefaultJson)), isFalse);
    expect(looksLikeZoneDoc(jsonDecode(kGlossZoneDefaultJson)), isTrue);
    expect(
      validateMarkerDoc(buildDefaultGlossMarker())
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
    expect(
      validateZoneDoc(buildDefaultGlossZone())
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
  });
}
