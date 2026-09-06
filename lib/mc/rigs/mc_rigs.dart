/// Rig lookup by id and by the plugin's entity-type spelling.
library;

import 'mc_mob_rigs.dart';
import 'mc_player_rig.dart';
import 'mc_rig.dart';

const List<String> mcRiggedEntityTypes = <String>['player', 'zombie', 'skeleton', 'creeper', 'pig', 'cow', 'sheep'];

McRig? mcRigById(String id, {required bool slim}) => switch (id) {
  'player' => mcPlayerRig(slim: slim),
  'player_head' => mcHeadRig(slim: slim),
  'zombie' => mcZombieRig(),
  'skeleton' => mcSkeletonRig(),
  'creeper' => mcCreeperRig(),
  'pig' => mcPigRig(),
  'cow' => mcCowRig(),
  'sheep' => mcSheepRig(),
  _ => null,
};

/// Maps the plugin's entity-type spellings (`ZOMBIE`, `minecraft:zombie`,
/// `zombie`) onto a rig id, or null when there is no rig for that type.
String? mcRigForEntityType(String entityType) {
  final String id = entityType.trim().toLowerCase().replaceFirst('minecraft:', '');
  return mcRiggedEntityTypes.contains(id) ? id : null;
}
