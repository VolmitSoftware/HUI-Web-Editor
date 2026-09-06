/// The CSS-3D text layer's transforms, computed from the shared camera so the
/// DOM and the GL canvas agree (Task 12 pins that).
///
/// The layer element carries `perspective: 900px`; its child carries the
/// camera matrix from `projection.dart`; each anchored element carries a plane
/// matrix at its world position, aimed by its billboard mode.
///
/// The plane axes are built here, in WORLD coordinates. The menu preview's
/// `fixedMenuPlane`/`orientBillboardPlane` build theirs in the authoring frame,
/// whose X runs opposite the world's, so borrowing them put every anchored
/// string's local +X on the viewer's left and read it backwards.
/// [cssPlaneMatrix]'s `(x, -y, -z)` column flip is the inverse of
/// [cssCameraMatrix]'s block flip, so world-frame axes come through it
/// unchanged. `translate(-50%, -100%)` trails so the element's bottom-centre is
/// the anchor, which is where a TextDisplay grows from.
library;

import 'dart:math' as math;

import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_projection_bridge.dart';
import '../../preview/preview_types.dart';
import '../../preview/projection.dart';

const double _degToRad = math.pi / 180;

enum McBillboardMode {
  fixed,
  vertical,
  horizontal,
  center;

  static McBillboardMode parse(String value) => switch (value.trim().toUpperCase()) {
    'VERTICAL' => McBillboardMode.vertical,
    'HORIZONTAL' => McBillboardMode.horizontal,
    'CENTER' => McBillboardMode.center,
    _ => McBillboardMode.fixed,
  };
}

String mcDomCameraTransform(
  McCamera camera, {
  double perspectivePx = huiPreviewPerspectivePx,
  double pxPerBlock = huiPreviewPxPerBlock,
}) => mcCssCameraMatrix(camera, perspectivePx: perspectivePx, pxPerBlock: pxPerBlock);

String mcDomAnchorTransform({
  required McCamera camera,
  required McVec3 position,
  required McBillboardMode billboard,
  double yawDeg = 0,
  double pitchDeg = 0,
  double scale = 1,
  double pxPerBlock = huiPreviewPxPerBlock,
}) {
  final List<double> plane = mcDomAnchorMatrix(
    camera: camera,
    position: position,
    billboard: billboard,
    yawDeg: yawDeg,
    pitchDeg: pitchDeg,
    pxPerBlock: pxPerBlock,
  );
  final String scaled = scale == 1 ? '' : ' scale($scale)';
  return '${cssMatrix3d(plane)}$scaled translate(-50%, -100%)';
}

/// The anchor's plane matrix, column-major, before the css string. Split out
/// so the axes can be asserted as numbers instead of parsed back out of
/// `matrix3d(...)`.
List<double> mcDomAnchorMatrix({
  required McCamera camera,
  required McVec3 position,
  required McBillboardMode billboard,
  double yawDeg = 0,
  double pitchDeg = 0,
  double pxPerBlock = huiPreviewPxPerBlock,
}) => cssPlaneMatrix(
  _anchorAim(
    camera: camera,
    position: position,
    billboard: billboard,
    yawDeg: yawDeg,
    pitchDeg: pitchDeg,
  ),
  pxPerBlock: pxPerBlock,
);

/// A plate is readable by a viewer whose forward is `f` when its normal is
/// `-f`, its right `up × normal` and its up `normal × right` — a right-handed
/// basis whose +X lands on that viewer's right.
PlaneAim _anchorAim({
  required McCamera camera,
  required McVec3 position,
  required McBillboardMode billboard,
  required double yawDeg,
  required double pitchDeg,
}) {
  final McVec3 toViewer = -camera.forward;
  switch (billboard) {
    case McBillboardMode.center:
      final McVec3 normal = toViewer.normalized;
      final McVec3 right = _horizontalRight(normal);
      return _aim(position, normal, right, normal.cross(right));

    // Yaws to the viewer about the vertical axis, then keeps the document's
    // pitch: the client tilts the plate about its own horizontal right, so
    // positive pitch tips the face down and the right stays level.
    case McBillboardMode.vertical:
      final McVec3 flat = McVec3(toViewer.x, 0, toViewer.z);
      final McVec3 facing = flat.length <= 1e-9
          ? const McVec3(0, 0, 1)
          : flat.normalized;
      final McVec3 right = McVec3.up.cross(facing).normalized;
      final double pitch = pitchDeg * _degToRad;
      final McVec3 normal = facing * math.cos(pitch) - McVec3.up * math.sin(pitch);
      return _aim(position, normal, right, normal.cross(right));

    // Keeps the document's yaw and pitches toward the viewer about it.
    case McBillboardMode.horizontal:
      final McVec3 right = _horizontalRight(_facingDirection(yawDeg, 0));
      final McVec3 tilted = toViewer - right * toViewer.dot(right);
      final McVec3 normal = tilted.length <= 1e-9
          ? _facingDirection(yawDeg, 0)
          : tilted.normalized;
      return _aim(position, normal, right, normal.cross(right));

    case McBillboardMode.fixed:
      final McVec3 normal = _facingDirection(yawDeg, pitchDeg);
      final McVec3 right = _horizontalRight(normal);
      return _aim(position, normal, right, normal.cross(right));
  }
}

/// Minecraft's look direction, the same one [McCamera.forward] builds: yaw 0
/// points along +Z, positive pitch tilts down.
McVec3 _facingDirection(double yawDeg, double pitchDeg) {
  final double yaw = yawDeg * _degToRad, pitch = pitchDeg * _degToRad;
  return McVec3(
    -math.cos(pitch) * math.sin(yaw),
    -math.sin(pitch),
    math.cos(pitch) * math.cos(yaw),
  );
}

/// `up × normal`, falling back to +X at the poles the way
/// `CameraBasis._facing` does.
McVec3 _horizontalRight(McVec3 normal) {
  final McVec3 right = McVec3.up.cross(normal);
  return right.length <= 1e-9 ? const McVec3(1, 0, 0) : right.normalized;
}

PlaneAim _aim(McVec3 center, McVec3 normal, McVec3 right, McVec3 up) => PlaneAim(
  center: PVec3(center.x, center.y, center.z),
  normal: PVec3(normal.x, normal.y, normal.z),
  right: PVec3(right.x, right.y, right.z),
  up: PVec3(up.x, up.y, up.z),
);
