/// The mob rigs: bounds inside their textures, heights, the right entity map.
library;

import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:gloss_editor/mc/rigs/mc_mob_rigs.dart';
import 'package:gloss_editor/mc/rigs/mc_rig.dart';
import 'package:gloss_editor/mc/rigs/mc_rig_mesher.dart';
import 'package:gloss_editor/mc/rigs/mc_rigs.dart';
import 'package:test/test.dart';

double _top(McMesh mesh) {
  double maxY = -99;
  for (int v = 0; v < mesh.vertexCount; v++) {
    if (mesh.positions[v * 3 + 1] > maxY) maxY = mesh.positions[v * 3 + 1];
  }
  return maxY;
}

double _bottom(McMesh mesh) {
  double minY = 99;
  for (int v = 0; v < mesh.vertexCount; v++) {
    if (mesh.positions[v * 3 + 1] < minY) minY = mesh.positions[v * 3 + 1];
  }
  return minY;
}

void main() {
  test('every rigged mob keeps its UVs inside its texture', () {
    for (final String id in mcRiggedEntityTypes) {
      final McRig rig = mcRigById(id, slim: false)!;
      for (final McRigPart part in rig.allParts) {
        for (final McBox box in part.boxes) {
          expect(box.u + 2 * box.size.z + 2 * box.size.x, lessThanOrEqualTo(rig.textureWidth), reason: '$id ${part.name}');
          expect(box.v + box.size.z + box.size.y, lessThanOrEqualTo(rig.textureHeight), reason: '$id ${part.name}');
        }
      }
    }
  });

  test('feet rest at zero and heads reach roughly the hitbox height', () {
    for (final String id in mcRiggedEntityTypes) {
      final McRig rig = mcRigById(id, slim: false)!;
      final McMesh mesh = mcMeshRig(rig);
      expect(_bottom(mesh), closeTo(0, 0.02), reason: id);
      expect(_top(mesh), closeTo(rig.heightBlocks, 0.3), reason: id);
    }
  });

  test('the pig snout sits flush against the head', () {
    final McRigPart head = mcPigRig().part('head');
    final McBox skull = head.boxes[0];
    final McBox snout = head.boxes[1];
    // Both boxes hang off the same pivot, so the snout's far Z face has to
    // meet the skull's near Z face exactly: no gap, no overlap.
    expect(snout.origin.z + snout.size.z, skull.origin.z);
    expect(snout.size.toList(), <double>[4, 3, 1]);
  });

  test('the skeleton is thin and the zombie holds its arms out', () {
    expect(mcSkeletonRig().part('right_arm').boxes.first.size.x, 2);
    expect(mcZombieRig().part('right_arm').rotationDeg.x, -90);
  });

  test('the sheep has wool overlay parts drawn separately', () {
    final McRig sheep = mcSheepRig();
    expect(sheep.allParts.where((McRigPart p) => p.overlay), isNotEmpty);
    expect(mcMeshRig(sheep, overlayOnly: true).triangleCount, greaterThan(0));
    expect(mcMeshRig(sheep).triangleCount, greaterThan(0));
  });

  test('entity types map onto rigs the plugin spells them', () {
    expect(mcRigForEntityType('ZOMBIE'), 'zombie');
    expect(mcRigForEntityType('minecraft:cow'), 'cow');
    expect(mcRigForEntityType('PLAYER'), 'player');
    expect(mcRigForEntityType('minecraft:allay'), isNull);
  });
}
