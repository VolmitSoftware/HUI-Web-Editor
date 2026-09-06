/// Box-model entities the way the client builds them: parts with a pivot,
/// boxes in model pixels with the vanilla box unwrap (`u, v` at the top-left
/// of the unwrap: top and bottom above, then east, north, west, south in a
/// row). Y is DOWN in model space, like the client; the mesher flips it.
library;

import 'dart:math' as math;

import '../scene/mc_math.dart';

final class McBox {
  const McBox({
    required this.origin,
    required this.size,
    required this.u,
    required this.v,
    this.mirror = false,
    this.inflate = 0,
  });

  /// Corner nearest the origin, relative to the part pivot, model pixels.
  final McVec3 origin;
  final McVec3 size;
  final int u;
  final int v;

  /// Swaps the U direction of every side face relative to the client's
  /// default (unmirrored) unwrap, for the client's mirrored limbs.
  final bool mirror;

  /// Pixels the box grows on every side (overlay layers).
  final double inflate;
}

final class McRigPart {
  const McRigPart({
    required this.name,
    required this.pivot,
    required this.boxes,
    this.children = const <McRigPart>[],
    this.rotationDeg = McVec3.zero,
    this.overlay = false,
  });

  final String name;

  /// Model pixels, relative to the parent's pivot.
  final McVec3 pivot;
  final List<McBox> boxes;
  final List<McRigPart> children;
  final McVec3 rotationDeg;

  /// Drawn with the overlay texture (sheep wool) instead of the base.
  final bool overlay;
}

final class McRig {
  const McRig({
    required this.id,
    required this.textureWidth,
    required this.textureHeight,
    required this.parts,
    required this.heightBlocks,
    required this.eyeHeightBlocks,
    this.scale = 1,
  });

  final String id;
  final int textureWidth;
  final int textureHeight;
  final List<McRigPart> parts;

  /// The client's render scale (`0.9375` for the player).
  final double scale;

  /// Hitbox height, blocks: where overlays and bubbles anchor.
  final double heightBlocks;
  final double eyeHeightBlocks;

  Iterable<McRigPart> get allParts sync* {
    Iterable<McRigPart> walk(McRigPart part) sync* {
      yield part;
      for (final McRigPart child in part.children) {
        yield* walk(child);
      }
    }

    for (final McRigPart part in parts) {
      yield* walk(part);
    }
  }

  McRigPart part(String name) => allParts.firstWhere((McRigPart p) => p.name == name);
}

final class McRigPose {
  const McRigPose({this.partRotationsDeg = const <String, McVec3>{}, this.breathe = 0});
  final Map<String, McVec3> partRotationsDeg;

  /// 0..1 body scale offset; the mesher applies `1 + breathe * 0.015` in Y
  /// to parts named `body`.
  final double breathe;
}

/// A slow breathe and nothing else: the plugin previews a standing entity.
McRigPose mcIdlePose(McRig rig, int timeMs) =>
    McRigPose(breathe: 0.5 + 0.5 * math.sin(timeMs / 1800 * 2 * math.pi));
