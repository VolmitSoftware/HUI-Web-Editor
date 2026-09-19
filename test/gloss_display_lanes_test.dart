import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/display_lane_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

void main() {
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

  test('marker template validates', () {
    expect(looksLikeMarkerDoc(jsonDecode(kGlossMarkerDefaultJson)), isTrue);
    expect(looksLikeHologramDoc(jsonDecode(kGlossMarkerDefaultJson)), isFalse);
    expect(
      validateMarkerDoc(buildDefaultGlossMarker())
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
  });
}
