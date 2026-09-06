/// The drop stage's frame as scene nodes: what the plugin spawns, where.
///
/// BLOCK kinds are BlockDisplays (`RealDropService.java:320`), so their node
/// is the block's default-state model; FLAT and THIN kinds are ItemDisplays
/// at `ItemDisplayTransform.FIXED` (`RealDropService.java:316`), so their node
/// is the item model at the `fixed` pose. Position, tumble and per-axis
/// script scale come straight off the frame; nothing here decides physics.
library;

import 'dart:typed_data';

import '../mc/assets/mc_display_pose.dart';
import '../mc/scene/mc_math.dart';
import '../mc/scene/mc_scene.dart';
import 'real_drop_model.dart';
import 'real_drop_stage.dart';

/// Shadow disc radius: half the CSS shadow's 1.35x edge diameter
/// (`real_drops_view.dart`'s `hui-real-drops-shadow` sizing).
double realDropShadowRadius(double modelScale) => modelScale * 0.675;

/// The world transform for one visual: carrier position plus its own offset,
/// its tumble, then its own edge scale times the script's per-axis
/// multipliers — about the model's centre, matching `_itemModel`'s CSS order.
McMat4 realDropVisualTransform(DropStageVisual visual, DropStageFrame frame, McVec3 origin) {
  final List<double> r = visual.rotation.m;
  final McMat4 rotation = McMat4(
    Float64List.fromList(<double>[
      r[0], r[3], r[6], 0, //
      r[1], r[4], r[7], 0, //
      r[2], r[5], r[8], 0, //
      0, 0, 0, 1, //
    ]),
  );
  final double s = visual.scale;
  return McMat4.translation(
        origin.x + visual.x,
        origin.y + frame.carrierY + visual.y,
        origin.z + frame.carrierZ + visual.z,
      )
      .multiply(rotation)
      .multiply(McMat4.scale(s * visual.scaleX, s * visual.scaleY, s * visual.scaleZ))
      .multiply(McMat4.translation(-0.5, -0.5, -0.5));
}

/// The frame's visuals plus the stage's shadow and (when [water] is on) the
/// stage's water plane, as nodes ready for the renderer.
///
/// [spriteFallback] is the pack's verdict that the material has no model
/// geometry (`McPackManifest.spriteFallbacks`); every visible visual is then
/// the catalog sprite [spriteUrl] as a camera-facing billboard the size of the
/// model, bottom-centred where the model's box would rest. No sprite, no
/// node: the renderer would drop the model anyway.
List<McSceneNode> realDropSceneNodes({
  required DropStageFrame frame,
  required String material,
  required bool block,
  required bool water,
  required McVec3 origin,
  bool spriteFallback = false,
  String? spriteUrl,
}) {
  final List<McSceneNode> nodes = <McSceneNode>[];
  for (final DropStageVisual visual in frame.visuals) {
    if (!visual.visible) continue;
    final McMat4 transform = realDropVisualTransform(visual, frame, origin);
    final String key = 'drop-${visual.index}';
    if (spriteFallback) {
      if (spriteUrl == null) continue;
      final McVec3 centre = transform.transformPoint(const McVec3(0.5, 0.5, 0.5));
      nodes.add(
        McBillboardNode(
          key: key,
          textureUrl: spriteUrl,
          position: McVec3(centre.x, centre.y - frame.modelScale / 2, centre.z),
          widthBlocks: frame.modelScale,
          heightBlocks: frame.modelScale,
        ),
      );
      continue;
    }
    nodes.add(
      block && frame.modelKind == DropModelKind.block
          ? McBlockModelNode(key: key, blockId: material, transform: transform, glowArgb: visual.glowArgb)
          : McItemModelNode(
              key: key,
              itemId: material,
              pose: McDisplayPose.fixed,
              transform: transform,
              glowArgb: visual.glowArgb,
            ),
    );
  }
  nodes.add(
    McShadowNode(
      key: 'drop-shadow',
      position: McVec3(origin.x, origin.y, origin.z + frame.carrierZ),
      radiusBlocks: realDropShadowRadius(frame.modelScale),
      alpha: 0.45 / (1 + frame.carrierY * 1.4),
    ),
  );
  if (water) {
    nodes.add(const McWaterNode(key: 'drop-water', levelBlocks: dropStageWaterLevel, halfExtentBlocks: 16));
  }
  return nodes;
}
