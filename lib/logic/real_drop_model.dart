/// The dropped-item presentation model, ported from Gloss `RealDropModel.java`.
///
/// The drop stage used to draw a grey slab that ignored the document; every
/// number that decides what a dropped stack looks like in game lives here
/// instead, spelled the way the plugin spells it: how many displays one stack
/// grows, which model family a material belongs to, the scale that family
/// takes, the fixed offset table, the authored Y lift, the tumble rates and
/// the settled pose.
///
/// Two deliberate departures from the Java, both because this is a preview and
/// not a server:
///
///  * Seeds. The plugin mixes an item's `UUID` through a 64-bit SplitMix step.
///    Web `int` is a double, so a faithful 64-bit mix is not available and a
///    preview has no live entity to seed from anyway. [realDropSpin] and
///    [realDropLanding] take a caller-supplied unit source instead, so the
///    *shape* of the math — per-axis rate, variance band, sign flip, speed
///    multiplier, tilt bounds — is exact while the randomness is the stage's.
///  * Rolling. `groundedBlockRotation` / `faceAlignedRotation` settle a block
///    that is still sliding onto its nearest face. The stage drops straight
///    down, so it goes from tumbling to [realDropLandingRotation] and never
///    needs the roll.
///
/// Rotations are 3x3 matrices in Minecraft space (right-handed, +Y up) so the
/// composition order matches JOML exactly; [DropRotation.cssMatrix3d] is the
/// only place the browser's Y-down convention is applied.
library;

import 'dart:math' as math;

import '../config/real_drop_shapes.dart';
import '../model/gloss_real_drops.dart';

/// `RealDropModel.OFFSETS`, in blocks before [GlossRealDropLimits.spread]
/// scales them. Its length is also the hard ceiling on displays per stack.
const List<({double x, double y, double z})> glossRealDropOffsets =
    <({double x, double y, double z})>[
      (x: 0.0, y: 0.0, z: 0.0),
      (x: 0.7, y: 0.04, z: 0.35),
      (x: -0.55, y: 0.08, z: 0.55),
      (x: 0.4, y: 0.12, z: -0.65),
      (x: -0.7, y: 0.16, z: -0.35),
    ];

/// `RealDropModel.STACK_YAW_RADIANS`: every extra display in a stack is yawed
/// this much further so the models do not overlap into one silhouette.
const double glossRealDropStackYawRadians = 0.41;

/// Which model family a material's item form belongs to.
enum DropModelKind {
  /// A full cube — the [GlossRealDropScale.defaultScale] family.
  block,

  /// A flat sprite: every non-block item, plus the block items Minecraft
  /// itself draws flat. The [GlossRealDropScale.flatItems] family.
  flat,

  /// Slabs, carpets, pressure plates and snow layers. The
  /// [GlossRealDropScale.thinBlocks] family.
  thin,
}

/// `RealDropModel.visualCount`: how many item displays one stack grows.
///
/// Deliberately not one per item — a 64 stack is five models, not sixty-four.
int realDropVisualCount(int amount, int maxStackSize, int configuredMaximum) {
  final int maximum = math.max(
    1,
    math.min(configuredMaximum, glossRealDropOffsets.length),
  );
  if (maxStackSize <= 1 || amount <= 1) return 1;
  if (amount <= 16) return math.min(2, maximum);
  if (amount <= 32) return math.min(3, maximum);
  if (amount <= 48) return math.min(4, maximum);
  return maximum;
}

/// `RealDropModel.modelKind`. [name] is an upper-case registry name and
/// [block] is `Material.isBlock()`, which no browser catalog carries — the
/// stage's sample table states it per entry.
DropModelKind realDropModelKind(String name, {required bool block}) {
  final String material = name.toUpperCase();
  if (!block || glossFlatBlockItems.contains(material)) {
    return DropModelKind.flat;
  }
  if (material.endsWith('_SLAB') ||
      material.endsWith('_CARPET') ||
      material.endsWith('_PRESSURE_PLATE') ||
      material == 'SNOW') {
    return DropModelKind.thin;
  }
  return DropModelKind.block;
}

/// `RealDropModel.scale`: the configured scale family [kind] draws at.
double realDropScale(DropModelKind kind, GlossRealDropScale scale) =>
    switch (kind) {
      DropModelKind.block => scale.defaultScale,
      DropModelKind.flat => scale.flatItems,
      DropModelKind.thin => scale.thinBlocks,
    };

/// `RealDropModel.offset`: display [index]'s place in the stack, in blocks.
({double x, double y, double z}) realDropOffset(int index, double spread) {
  final ({double x, double y, double z}) offset =
      glossRealDropOffsets[index.clamp(0, glossRealDropOffsets.length - 1)];
  return (x: offset.x * spread, y: offset.y * spread, z: offset.z * spread);
}

/// `RealDropModel.authoredYOffset`: the hand-authored lift that keeps a model
/// whose geometry sits low in its own cube from sinking into the ground.
double realDropAuthoredYOffset(String name) {
  final String material = name.toUpperCase();
  if (material.endsWith('SNOW')) return 0.2;
  if (material.endsWith('TRIDENT')) return 0.32;
  if (material.endsWith('_CARPET') ||
      material.endsWith('_PRESSURE_PLATE') ||
      material.endsWith('SHIELD')) {
    return 0.26;
  }
  if (material.endsWith('_SLAB') ||
      material.endsWith('_STAIRS') ||
      material.endsWith('_WALL') ||
      material.endsWith('_FENCE') ||
      material.endsWith('_FENCE_GATE') ||
      material == 'DAYLIGHT_DETECTOR') {
    return 0.16;
  }
  if (material.contains('BED') ||
      material.contains('SKULL') ||
      material.contains('HEAD') ||
      material.contains('SCULK') ||
      material.contains('_TRAPDOOR') ||
      material == 'HEAVY_CORE') {
    return 0.22;
  }
  return 0.0;
}

/// `RealDropModel.yOffset`: the authored lift, raised for a grounded cube so
/// its lowest corner rests on the surface rather than through it.
double realDropYOffset(
  String name,
  DropModelKind kind,
  double scale,
  DropRotation rotation, {
  required bool grounded,
}) {
  final double authored = realDropAuthoredYOffset(name);
  if (!grounded || kind != DropModelKind.block) return authored;
  return math.max(authored, rotation.verticalHalfExtent(scale));
}

/// One tumble or landing pose in degrees per axis.
typedef DropAngles = ({double x, double y, double z});

/// `RealDropModel.spin`: the tumble rate in degrees per second per axis.
///
/// [units] supplies the three variance draws in `-1..1` and [negative] the
/// three direction bits, which the plugin takes from a different part of the
/// same seed — a narrowed band and a reversed axis are independent there, so
/// they stay independent here.
DropAngles realDropSpin(
  GlossRealDropMotion motion,
  ({double x, double y, double z}) units,
  ({bool x, bool y, bool z}) negative,
) => (
  x:
      _varied(
        motion.degreesPerSecondX,
        motion.variance,
        units.x,
        negative.x,
      ) *
      motion.speedMultiplier,
  y:
      _varied(
        motion.degreesPerSecondY,
        motion.variance,
        units.y,
        negative.y,
      ) *
      motion.speedMultiplier,
  z:
      _varied(
        motion.degreesPerSecondZ,
        motion.variance,
        units.z,
        negative.z,
      ) *
      motion.speedMultiplier,
);

/// `RealDropModel.landing`: the settled pose in degrees.
///
/// [units] carries the yaw draw and, for a naturally settled cube, the two
/// tilt draws — each in `-1..1`.
DropAngles realDropLanding(
  DropModelKind kind,
  GlossRealDropLanding landing,
  ({double yaw, double tiltX, double tiltZ}) units,
) {
  final String mode = landing.mode.toUpperCase();
  final double yaw = landing.randomYaw ? units.yaw * 180 : 0;
  if (mode == 'FLAT' || kind == DropModelKind.flat) {
    return (x: 90, y: yaw, z: 0);
  }
  if (mode == 'UPRIGHT' || kind == DropModelKind.thin) {
    return (x: 0, y: yaw, z: 0);
  }
  return (
    x: units.tiltX * landing.tiltDegrees,
    y: yaw,
    z: units.tiltZ * landing.tiltDegrees,
  );
}

/// `RealDropModel.baseRotation`: the pose a model tumbles around, which lays
/// a flat sprite down before the spin is applied.
DropRotation realDropBaseRotation(DropModelKind kind) =>
    kind == DropModelKind.flat
    ? DropRotation.identity.rotateX(_degToRad * 90)
    : DropRotation.identity;

/// `RealDropModel.landingRotation`: the settled pose as a rotation.
DropRotation realDropLandingRotation(
  DropModelKind kind,
  GlossRealDropLanding landing,
  ({double yaw, double tiltX, double tiltZ}) units,
) {
  final DropAngles angles = realDropLanding(kind, landing, units);
  final String mode = landing.mode.toUpperCase();
  if (mode == 'FLAT' || kind == DropModelKind.flat) {
    return DropRotation.identity
        .rotateY(angles.y * _degToRad)
        .rotateX(angles.x * _degToRad);
  }
  if (mode == 'NATURAL' && kind == DropModelKind.block) {
    // `blockLandingRotation` with face 0: the tilt draws become one twist
    // around the upright cube instead of leaning it off its face.
    final double twist = (angles.x + angles.z) * 0.5;
    return DropRotation.identity.rotateY((angles.y + twist) * _degToRad);
  }
  return DropRotation.identity
      .rotateX(angles.x * _degToRad)
      .rotateY(angles.y * _degToRad)
      .rotateZ(angles.z * _degToRad);
}

/// `RealDropModel.indexedRotation`: display [index]'s extra stack yaw, applied
/// outside [rotation] the way the plugin pre-multiplies it.
DropRotation realDropIndexedRotation(DropRotation rotation, int index) =>
    index <= 0
    ? rotation
    : DropRotation.identity
          .rotateY(index * glossRealDropStackYawRadians)
          .mul(rotation);

const double _degToRad = math.pi / 180;

/// `RealDropModel.varied`: the configured rate widened by the variance band,
/// then signed. [unit] is the plugin's `-1..1` draw and [negative] its
/// direction bit.
double _varied(
  double configured,
  double variance,
  double unit,
  bool negative,
) {
  final double magnitude = configured * (1 + unit * variance);
  return negative ? -magnitude : magnitude;
}

/// A rotation in Minecraft space: row-major 3x3, `v' = M v`, right-handed with
/// +Y up.
///
/// Only the operations the drop model needs, with JOML's post-multiply
/// semantics — `rotation.rotateX(a)` is `rotation * Rx(a)`, so a chain reads
/// in the same order as the Java it mirrors.
final class DropRotation {
  const DropRotation(this.m);

  /// Nine entries, `m[row * 3 + column]`.
  final List<double> m;

  static const DropRotation identity = DropRotation(<double>[
    1, 0, 0, //
    0, 1, 0, //
    0, 0, 1, //
  ]);

  DropRotation rotateX(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    return mulRight(<double>[1, 0, 0, 0, c, -s, 0, s, c]);
  }

  DropRotation rotateY(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    return mulRight(<double>[c, 0, s, 0, 1, 0, -s, 0, c]);
  }

  DropRotation rotateZ(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    return mulRight(<double>[c, -s, 0, s, c, 0, 0, 0, 1]);
  }

  /// `this * other`, matching `Quaternionf.mul`.
  DropRotation mul(DropRotation other) => mulRight(other.m);

  DropRotation mulRight(List<double> other) {
    final List<double> out = List<double>.filled(9, 0);
    for (int row = 0; row < 3; row++) {
      for (int column = 0; column < 3; column++) {
        double sum = 0;
        for (int k = 0; k < 3; k++) {
          sum += m[row * 3 + k] * other[k * 3 + column];
        }
        out[row * 3 + column] = sum;
      }
    }
    return DropRotation(out);
  }

  /// `RealDropModel.verticalHalfExtent`: half the height the model's own
  /// bounding cube spans once this rotation is applied.
  double verticalHalfExtent(double scale) =>
      scale * 0.5 * (m[3].abs() + m[4].abs() + m[5].abs());

  /// The same rotation as a CSS `matrix3d(...)` argument list.
  ///
  /// The browser's Y axis points down, so the matrix is conjugated by
  /// `diag(1, -1, 1)` — which negates exactly the entries that couple Y to X
  /// and Z — and then written column-major the way CSS reads it.
  String cssMatrix3d() {
    final List<double> f = <double>[
      m[0], -m[1], m[2], //
      -m[3], m[4], -m[5], //
      m[6], -m[7], m[8], //
    ];
    // Negated zeros would print as `-0.000000`: valid CSS, but it makes two
    // identical matrices compare unequal as strings.
    String n(double value) => (value == 0 ? 0.0 : value).toStringAsFixed(6);
    return 'matrix3d('
        '${n(f[0])}, ${n(f[3])}, ${n(f[6])}, 0, '
        '${n(f[1])}, ${n(f[4])}, ${n(f[7])}, 0, '
        '${n(f[2])}, ${n(f[5])}, ${n(f[8])}, 0, '
        '0, 0, 0, 1)';
  }
}
