/// The one camera every stage shares, in blocks.
///
/// An orbit camera: [pivot] is the point on screen centre, [distance] how far
/// the eye stands back along the look direction, [yawDeg]/[pitchDeg] where
/// that direction points (Minecraft's convention: yaw 0 looks along +Z,
/// increasing yaw turns right, positive pitch looks DOWN). Panning moves the
/// pivot in the view plane; flying moves it in world space with the eye
/// riding along, so a walk never changes the framing.
///
/// Clamps, once: pitch within the poles, the eye above the ground, the
/// distance inside a readable band, the pivot inside the world patch. A stage
/// can therefore never be lost off screen.
///
/// Input sensitivities are the drop stage's, which were the one part of it
/// that felt right (`drop_stage_camera.dart`, retired by this file).
library;

import 'dart:math' as math;

import 'mc_math.dart';

/// The five stage views plus the game frame; the menu preview drives the
/// renderer through `mc_projection_bridge.dart` and has no home of its own.
enum McStageKind { drops, hologram, bubbles, indicators, overlays, frame }

const double mcCameraYawDegPerPx = 0.32;
const double mcCameraPitchDegPerPx = 0.24;
const double mcCameraDollyPerWheelPx = 0.0015;
const double mcCameraWalkBlocksPerSecond = 4.317;
const double mcCameraMinDistance = 0.75;
const double mcCameraMaxDistance = 24;
const double mcCameraMinEyeY = 0.05;
const double mcCameraPivotRange = 16;
const double mcCameraEyeHeight = 1.62;

const double _degToRad = math.pi / 180;

/// A `wheel` event's delta in pixels across browsers' three delta modes.
double mcWheelPixels(double delta, int deltaMode) => switch (deltaMode) {
  1 => delta * 16,
  2 => delta * 400,
  _ => delta,
};

final class McCamera {
  const McCamera({
    required this.pivot,
    required this.yawDeg,
    required this.pitchDeg,
    required this.distance,
  });

  final McVec3 pivot;
  final double yawDeg;
  final double pitchDeg;
  final double distance;

  /// Unit look direction, Minecraft yaw/pitch.
  McVec3 get forward {
    final double yaw = yawDeg * _degToRad, pitch = pitchDeg * _degToRad;
    return McVec3(
      -math.cos(pitch) * math.sin(yaw),
      -math.sin(pitch),
      math.cos(pitch) * math.cos(yaw),
    );
  }

  /// True right-handed right: `forward × up`, matching `McMat4.lookAt`'s own
  /// view basis. (`up × forward` is the viewer's left, not right.)
  McVec3 get right {
    final McVec3 r = forward.cross(McVec3.up);
    return r.length <= 1e-9 ? const McVec3(1, 0, 0) : r.normalized;
  }

  McVec3 get up => right.cross(forward);

  McVec3 get eye => pivot - forward * distance;

  McCamera copyWith({McVec3? pivot, double? yawDeg, double? pitchDeg, double? distance}) =>
      McCamera(
        pivot: pivot ?? this.pivot,
        yawDeg: yawDeg ?? this.yawDeg,
        pitchDeg: pitchDeg ?? this.pitchDeg,
        distance: distance ?? this.distance,
      );

  /// Grab the world: drag right brings the scene's left side around, yaw
  /// decreases. Drag down tips the subject's top toward the viewer — looks
  /// further down — so pitch increases toward the +89 pole.
  McCamera orbitBy(double dxPx, double dyPx) => copyWith(
    yawDeg: _wrap(yawDeg - dxPx * mcCameraYawDegPerPx),
    pitchDeg: pitchDeg + dyPx * mcCameraPitchDegPerPx,
  ).clamped();

  McCamera dollyBy(double wheelPx) =>
      copyWith(distance: distance * math.exp(wheelPx * mcCameraDollyPerWheelPx)).clamped();

  /// Blocks per pixel at the pivot's depth, from the projection's own vertical
  /// field of view: `mcFovYRad(H, perspective) = 2 * atan((H / 2) /
  /// perspective)` (`mc_projection_bridge.dart`, inlined here so `lib/mc`'s
  /// camera does not depend on the preview). `2 * tan(fov / 2)` is therefore
  /// `H / perspective` and the height cancels — a pixel is `distance /
  /// perspective` blocks — but keeping the full form makes the identity
  /// visible. [perspectivePx] defaults to `huiPreviewPerspectivePx`, the CSS
  /// perspective every stage renders with.
  double blocksPerPixel(double viewportHeightPx, {double perspectivePx = 900}) {
    final double fovY = 2 * math.atan((viewportHeightPx / 2) / perspectivePx);
    return (distance * 2 * math.tan(fovY / 2)) / viewportHeightPx;
  }

  /// Drag the world with the pointer: the pivot moves opposite the drag.
  McCamera panBy(double dxPx, double dyPx, double viewportHeightPx, {double perspectivePx = 900}) {
    final double k = blocksPerPixel(viewportHeightPx, perspectivePx: perspectivePx);
    return copyWith(pivot: pivot - right * (dxPx * k) + up * (dyPx * k)).clamped();
  }

  /// WASD, space and shift: world-space, gravity-free walking.
  McCamera flyBy({
    required double seconds,
    required double forward,
    required double strafe,
    required double lift,
  }) {
    final McVec3 flat = McVec3(this.forward.x, 0, this.forward.z).normalized;
    final McVec3 side = flat.cross(McVec3.up).normalized;
    final McVec3 step = (flat * forward + side * strafe + McVec3.up * lift) *
        (mcCameraWalkBlocksPerSecond * seconds);
    return copyWith(pivot: pivot + step).clamped();
  }

  McCamera clamped() {
    double pitch = pitchDeg.clamp(-89, 89).toDouble();
    final double dist = distance.clamp(mcCameraMinDistance, mcCameraMaxDistance).toDouble();
    final McVec3 p = McVec3(
      pivot.x.clamp(-mcCameraPivotRange, mcCameraPivotRange).toDouble(),
      pivot.y.clamp(0, mcCameraPivotRange).toDouble(),
      pivot.z.clamp(-mcCameraPivotRange, mcCameraPivotRange).toDouble(),
    );
    McCamera c = McCamera(pivot: p, yawDeg: yawDeg, pitchDeg: pitch, distance: dist);
    // Raise the eye out of the ground by flattening the pitch, never by
    // moving the pivot: the framing is the user's.
    for (int i = 0; i < 90 && c.eye.y < mcCameraMinEyeY; i++) {
      pitch += 1;
      c = c.copyWith(pitchDeg: pitch.clamp(-89, 89).toDouble());
    }
    return c;
  }

  McMat4 view() => McMat4.lookAt(eye, pivot, McVec3.up);

  @override
  bool operator ==(Object other) =>
      other is McCamera &&
      other.pivot == pivot &&
      other.yawDeg == yawDeg &&
      other.pitchDeg == pitchDeg &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(pivot, yawDeg, pitchDeg, distance);

  static double _wrap(double degrees) {
    double d = degrees % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }
}

/// Spec section 5: the home framing per stage. Yaw 180 looks along -Z, back
/// toward the origin from the south, which is where every stage puts its
/// subject relative to the throw.
McCamera mcCameraHome(McStageKind kind, McVec3 pivot) => switch (kind) {
  McStageKind.drops => McCamera(pivot: pivot, yawDeg: 160, pitchDeg: 22, distance: 3.2),
  McStageKind.hologram => McCamera(pivot: pivot, yawDeg: 180, pitchDeg: 10, distance: 5),
  McStageKind.bubbles => McCamera(pivot: pivot, yawDeg: 180, pitchDeg: 6, distance: 4),
  McStageKind.indicators => McCamera(pivot: pivot, yawDeg: 180, pitchDeg: 8, distance: 4.5),
  McStageKind.overlays => McCamera(pivot: pivot, yawDeg: 180, pitchDeg: 8, distance: 4.5),
  McStageKind.frame => McCamera(
      pivot: McVec3(pivot.x, mcCameraEyeHeight, pivot.z),
      yawDeg: 180,
      pitchDeg: 0,
      distance: 4,
    ),
};
