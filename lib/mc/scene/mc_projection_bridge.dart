/// Where the DOM text layer and the GL world agree.
///
/// The text layer is CSS 3D with `perspective: 900px` and the camera matrix
/// `projection.dart` already builds from a [CameraBasis]. The GL pass needs a
/// projection matrix; the one that puts every world point on the same pixel
/// as the CSS layer has vertical FOV `2 * atan(H / (2 * perspective))` for an
/// `H` px tall viewport. Both derive from one [McCamera].
///
/// [McCamera.forward] uses Minecraft yaw (0 looks along +Z); the preview's
/// `huiLookDirection` mirrors X for its authoring frame. The bridge passes
/// the raw world vectors, so the menu preview (which authors in its own
/// frame) converts through `preview_stage.dart`'s existing mirror, not here.
///
/// [McCamera.right] is `forward.cross(up)`, the same true-right convention
/// `McMat4.lookAt` (mc_math.dart) builds its view basis from, so both the GL
/// path ([mcProjectToPixels], through [McCamera.view]) and the CSS path
/// ([projectToScreen], through this basis) already agree — no correction
/// needed here.
library;

import 'dart:math' as math;

import '../../preview/preview_types.dart';
import '../../preview/projection.dart';
import 'mc_camera.dart';
import 'mc_math.dart';

CameraBasis mcCameraBasis(McCamera camera) {
  final McVec3 e = camera.eye, f = camera.forward, r = camera.right, u = camera.up;
  return CameraBasis(
    position: PVec3(e.x, e.y, e.z),
    forward: PVec3(f.x, f.y, f.z),
    right: PVec3(r.x, r.y, r.z),
    up: PVec3(u.x, u.y, u.z),
  );
}

double mcFovYRad(double viewportHeightPx, double perspectivePx) =>
    2 * math.atan((viewportHeightPx / 2) / perspectivePx);

McMat4 mcGlProjection({
  required double viewportWidthPx,
  required double viewportHeightPx,
  required double perspectivePx,
  double near = 0.05,
  double far = 96,
}) => McMat4.perspective(
  mcFovYRad(viewportHeightPx, perspectivePx),
  viewportWidthPx / viewportHeightPx,
  near,
  far,
);

/// Viewport pixels (x right, y down) and the depth in blocks, through the GL
/// matrices; null at or behind the eye.
McVec3? mcProjectToPixels(
  McCamera camera,
  McVec3 point, {
  required double viewportWidthPx,
  required double viewportHeightPx,
  required double perspectivePx,
}) {
  final McVec3 view = camera.view().transformPoint(point);
  if (!(-view.z > 0)) return null;
  final McMat4 projection = mcGlProjection(
    viewportWidthPx: viewportWidthPx,
    viewportHeightPx: viewportHeightPx,
    perspectivePx: perspectivePx,
  );
  final McVec3 clip = projection.transformPoint(view);
  return McVec3(
    (clip.x + 1) / 2 * viewportWidthPx,
    (1 - clip.y) / 2 * viewportHeightPx,
    -view.z,
  );
}

String mcCssCameraMatrix(
  McCamera camera, {
  required double perspectivePx,
  required double pxPerBlock,
}) => cssMatrix3d(
  cssCameraMatrix(
    basis: mcCameraBasis(camera),
    perspectivePx: perspectivePx,
    pxPerBlock: pxPerBlock,
  ),
);

/// The menu preview's orbit camera as the GL world's.
///
/// The preview authors in the world with X mirrored (`MenuSession.java:70`
/// negates the json x), so the pivot reflects. Yaw and pitch carry over
/// verbatim: [McCamera.forward] is Minecraft's own direction and
/// [huiLookDirection] is that direction already mirrored, so the same angles
/// name the mirrored look. The eye that comes out is therefore
/// `CameraBasis.orbit(orbit).position` with x negated.
McCamera mcCameraFromOrbit(OrbitCamera orbit) => McCamera(
  pivot: McVec3(-orbit.target.x, orbit.target.y, orbit.target.z),
  yawDeg: orbit.yawDegrees,
  pitchDeg: orbit.pitchDegrees,
  distance: orbit.distance,
);

/// Distance the player camera parks its pivot ahead of the eye. [McCamera] has
/// no first-person form and clamps the distance to `mcCameraMinDistance`, so
/// the pivot goes out in front and the eye lands back on the player's.
const double mcPlayerPivotBlocks = 4;

/// The simulated player's eye as the GL world's camera. Mirrored exactly as
/// [mcCameraFromOrbit] is.
McCamera mcCameraFromPlayer(PlayerPose pose) {
  final McCamera aim = McCamera(
    pivot: McVec3.zero,
    yawDeg: pose.yawDegrees,
    pitchDeg: pose.pitchDegrees,
    distance: mcPlayerPivotBlocks,
  );
  final PVec3 eye = pose.eye;
  final McVec3 mirrored = McVec3(-eye.x, eye.y, eye.z);
  return aim.copyWith(pivot: mirrored + aim.forward * mcPlayerPivotBlocks);
}
