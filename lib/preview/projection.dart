/// Cameras, rays and collision planes for the 3D preview.
///
/// Pure and DOM-free: everything here is numbers, so the whole projection is
/// testable on the VM and the DOM stage only has to write the strings out.
///
/// Three frames meet in this file and they are stated once, here:
///
///  * **Authoring frame** (`preview_types.dart`): the player's feet are the
///    origin, +X is the player's right, +Y is up, +Z is forward/away. This is
///    the json frame verbatim — `MenuSession.java:70` multiplies the parsed
///    offset by (-1, 1, 1) precisely so that json +X means "player's right",
///    so the preview adds no second mirror.
///  * **Rotation** uses Minecraft yaw, pitch and roll in degrees. Yaw 0 looks
///    along +Z, increasing yaw turns the player to their right, and positive
///    pitch looks down. [huiMenuVector] applies the same roll, pitch, yaw order
///    as `MenuTransform.localVector` after accounting for the authoring frame's
///    mirrored X axis.
///  * **CSS frame**: +x right, +y **down**, +z toward the viewer. The mapping
///    from authoring blocks to css pixels is `(S·x, −S·y, −S·z)` for a scene
///    scale `S` px per block. That flip is orientation-preserving, so rotations
///    survive it unchanged (a rotation by `θ` about the authoring vertical axis
///    is exactly `rotateY(θ)` in css).
///
/// Matrices are 16 doubles in **column-major** order, which is both the OpenGL
/// convention and the argument order of the css `matrix3d()` function, so no
/// transpose ever happens between here and the stage.
library;

import 'dart:math' as math;

import '../model/hui_component.dart';

import 'preview_types.dart';

/// Default scene scale. One block is this many css pixels before perspective.
const double huiPreviewPxPerBlock = 96;

/// Default css `perspective`. With [huiPreviewPxPerBlock] this puts the 1:1
/// plane a little over 9 blocks from the camera, which frames a typical menu.
const double huiPreviewPerspectivePx = 900;

/// Unit look direction for a Minecraft yaw/pitch pair, in the authoring frame.
///
/// Minecraft's own direction is `(−cos p·sin y, −sin p, cos p·cos y)`; the
/// authoring frame negates X, which is what turns "world east" into "player's
/// right".
PVec3 huiLookDirection({required double yawDegrees, double pitchDegrees = 0}) {
  final double yaw = yawDegrees * math.pi / 180;
  final double pitch = pitchDegrees * math.pi / 180;
  final double cosPitch = math.cos(pitch);
  return PVec3(
    cosPitch * math.sin(yaw),
    -math.sin(pitch),
    cosPitch * math.cos(yaw),
  );
}

PVec3 huiMenuVector(
  PVec3 vector, {
  required double facingYawDegrees,
  double pitchDegrees = 0,
  double rollDegrees = 0,
}) {
  final double roll = rollDegrees * math.pi / 180;
  final double rollCos = math.cos(roll);
  final double rollSin = math.sin(roll);
  final PVec3 rolled = PVec3(
    vector.x * rollCos + vector.y * rollSin,
    -vector.x * rollSin + vector.y * rollCos,
    vector.z,
  );

  final double pitch = pitchDegrees * math.pi / 180;
  final double pitchCos = math.cos(pitch);
  final double pitchSin = math.sin(pitch);
  final PVec3 pitched = PVec3(
    rolled.x,
    rolled.y * pitchCos - rolled.z * pitchSin,
    rolled.y * pitchSin + rolled.z * pitchCos,
  );

  final double yaw = facingYawDegrees * math.pi / 180;
  final double yawCos = math.cos(yaw);
  final double yawSin = math.sin(yaw);
  return PVec3(
    pitched.x * yawCos + pitched.z * yawSin,
    pitched.y,
    -pitched.x * yawSin + pitched.z * yawCos,
  );
}

/// A camera reduced to a position and an orthonormal basis.
///
/// Built once per frame and handed to [projectToScreen], [rayThrough] and
/// [cssCameraMatrix] so none of them re-derive trigonometry.
class CameraBasis {
  const CameraBasis({
    required this.position,
    required this.forward,
    required this.right,
    required this.up,
  });

  /// Camera behind [OrbitCamera.target] along its look direction.
  factory CameraBasis.orbit(OrbitCamera camera) {
    final PVec3 forward = huiLookDirection(
      yawDegrees: camera.yawDegrees,
      pitchDegrees: camera.pitchDegrees,
    );
    return CameraBasis._facing(
      camera.target - forward * camera.distance,
      forward,
    );
  }

  /// First-person camera at the player's eye (`feet + 1.62`).
  factory CameraBasis.player(PlayerPose pose) => CameraBasis._facing(
    pose.eye,
    huiLookDirection(
      yawDegrees: pose.yawDegrees,
      pitchDegrees: pose.pitchDegrees,
    ),
  );

  /// Derives a roll-free basis: [right] is horizontal, so the horizon never
  /// tilts. A camera aimed exactly at the poles falls back to +X, which is what
  /// the pitch clamps in `preview_types.dart` normally keep out of reach.
  factory CameraBasis._facing(PVec3 position, PVec3 forward) {
    final PVec3 look = forward.normalized;
    PVec3 right = PVec3.up.cross(look);
    right = right.lengthSquared <= 1e-18 ? PVec3.right : right.normalized;
    return CameraBasis(
      position: position,
      forward: look,
      right: right,
      up: look.cross(right),
    );
  }

  final PVec3 position;
  final PVec3 forward;
  final PVec3 right;
  final PVec3 up;

  @override
  String toString() => 'CameraBasis($position -> $forward)';
}

/// A world point resolved to viewport pixels.
class ProjectedPoint {
  const ProjectedPoint({
    required this.x,
    required this.y,
    required this.distance,
  });

  /// Pixels from the left of the viewport.
  final double x;

  /// Pixels from the top of the viewport — css y grows downward.
  final double y;

  /// Blocks in front of the camera along its forward axis.
  final double distance;

  @override
  String toString() => 'ProjectedPoint($x, $y, d: $distance)';
}

/// Where [point] lands on screen, or null when it is at or behind the camera.
///
/// The scene scale cancels out of this: a quad's *size* is measured in pixels
/// per block, but where its centre lands is `perspective / distance` either
/// way.
ProjectedPoint? projectToScreen({
  required CameraBasis basis,
  required PVec3 point,
  required double viewportWidth,
  required double viewportHeight,
  required double perspectivePx,
}) {
  final PVec3 relative = point - basis.position;
  final double distance = relative.dot(basis.forward);
  if (!(distance > 0)) return null;
  final double scale = perspectivePx / distance;
  return ProjectedPoint(
    x: viewportWidth / 2 + relative.dot(basis.right) * scale,
    y: viewportHeight / 2 - relative.dot(basis.up) * scale,
    distance: distance,
  );
}

/// Picking ray through a viewport pixel — the inverse of [projectToScreen].
///
/// The player's own look ray is this with the pointer at the viewport centre,
/// which is what pointer-lock mode uses.
LookRay rayThrough({
  required CameraBasis basis,
  required double viewportWidth,
  required double viewportHeight,
  required double pointerX,
  required double pointerY,
  required double perspectivePx,
}) {
  final double offsetX = pointerX - viewportWidth / 2;
  final double offsetY = pointerY - viewportHeight / 2;
  return LookRay.normalized(
    basis.position,
    basis.right * offsetX - basis.up * offsetY + basis.forward * perspectivePx,
  );
}

/// An oriented plane in the preview world.
///
/// [normal] is its outward axis; [right] and [up] span the rectangle. A value
/// may be the fixed menu plane or the viewer-resolved form of a billboard.
class PlaneAim {
  const PlaneAim({
    required this.center,
    required this.normal,
    required this.right,
    required this.up,
  });

  final PVec3 center;
  final PVec3 normal;
  final PVec3 right;
  final PVec3 up;

  @override
  String toString() => 'PlaneAim($center, n: $normal)';
}

/// Builds a fully viewer-facing plane for preview markers. Runtime icon and
/// click-plane orientation goes through [orientBillboardPlane], because its
/// fixed axes and billboard-specific degeneracy rules are part of the result.
PlaneAim aimPlaneAt(PVec3 planeCenter, PVec3 eye) {
  final PVec3 toEye = eye - planeCenter;
  final double horizontal = math.sqrt(toEye.x * toEye.x + toEye.z * toEye.z);
  final PVec3 normal;
  final PVec3 right;
  if (horizontal == 0) {
    normal = toEye.y >= 0 ? PVec3.up : -PVec3.up;
    right = PVec3.right;
  } else {
    normal = toEye.normalized;
    right = PVec3(-toEye.z / horizontal, 0, toEye.x / horizontal);
  }
  return PlaneAim(
    center: planeCenter,
    normal: normal,
    right: right,
    up: right.cross(normal),
  );
}

PlaneAim fixedMenuPlane({
  required PVec3 center,
  required double facingYawDegrees,
  double pitchDegrees = 0,
  double rollDegrees = 0,
}) {
  final PVec3 right = huiMenuVector(
    PVec3.right,
    facingYawDegrees: facingYawDegrees,
    pitchDegrees: pitchDegrees,
    rollDegrees: rollDegrees,
  ).normalized;
  final PVec3 up = huiMenuVector(
    PVec3.up,
    facingYawDegrees: facingYawDegrees,
    pitchDegrees: pitchDegrees,
    rollDegrees: rollDegrees,
  ).normalized;
  return PlaneAim(
    center: center,
    normal: up.cross(right).normalized,
    right: right,
    up: up,
  );
}

PlaneAim movePlane(PlaneAim plane, PVec3 center) => PlaneAim(
  center: center,
  normal: plane.normal,
  right: plane.right,
  up: plane.up,
);

PlaneAim orientBillboardPlane({
  required PlaneAim fixed,
  required String billboard,
  required PVec3 viewer,
}) {
  if (billboard == 'fixed') return fixed;
  final PVec3 toViewer = viewer - fixed.center;
  if (toViewer.lengthSquared < 1e-12) return fixed;

  if (billboard == 'vertical') {
    final PVec3 normal = PVec3(toViewer.x, 0, toViewer.z);
    if (normal.lengthSquared < 1e-12) return fixed;
    final PVec3 resolvedNormal = normal.normalized;
    const PVec3 up = PVec3.up;
    return PlaneAim(
      center: fixed.center,
      normal: resolvedNormal,
      right: resolvedNormal.cross(up).normalized,
      up: up,
    );
  }

  if (billboard == 'horizontal') {
    final PVec3 right = fixed.right.normalized;
    final PVec3 normal = toViewer - right * toViewer.dot(right);
    if (normal.lengthSquared < 1e-12) return fixed;
    final PVec3 resolvedNormal = normal.normalized;
    return PlaneAim(
      center: fixed.center,
      normal: resolvedNormal,
      right: right,
      up: right.cross(resolvedNormal).normalized,
    );
  }

  if (billboard != 'center') return fixed;
  final PVec3 normal = toViewer.normalized;
  final PVec3 referenceUp = normal.dot(PVec3.up).abs() > 0.999
      ? fixed.up
      : PVec3.up;
  final PVec3 right = normal.cross(referenceUp);
  if (right.lengthSquared < 1e-12) return fixed;
  final PVec3 resolvedRight = right.normalized;
  return PlaneAim(
    center: fixed.center,
    normal: normal,
    right: resolvedRight,
    up: resolvedRight.cross(normal).normalized,
  );
}

/// Port of `CollisionPlane.isLookingAt` (`CollisionPlane.java:42-54`).
///
/// Two rejections match the runtime: a near-parallel ray bails when
/// `abs(proj) < 1e-9`, and a plane behind the ray bails on
/// `distance < 0`. The edge test is strictly `<`, so a ray through a corner of
/// the rectangle misses, and a zero-width plane can never be hit at all.
double? rayPlaneIntersectionDistance(
  LookRay ray,
  PlaneAim aim,
  double width,
  double height,
) {
  final double projection = aim.normal.dot(ray.direction);
  if (projection.abs() < 1e-9) return null;
  final double distance = aim.normal.dot(aim.center - ray.origin) / projection;
  if (distance < 0) return null;
  final PVec3 intersect = ray.pointAt(distance) - aim.center;
  return aim.right.dot(intersect).abs() < width / 2 &&
          aim.up.dot(intersect).abs() < height / 2
      ? distance
      : null;
}

bool rayHitsPlane(LookRay ray, PlaneAim aim, double width, double height) =>
    rayPlaneIntersectionDistance(ray, aim, width, height) != null;

PVec3 hoverPush(
  PlaneAim aim,
  double modifier,
  int hoverTicks, {
  double uiScale = 1,
  int durationTicks = huiRuntimeDefaultHoverDurationTicks,
  HuiHoverEasing easing = huiRuntimeDefaultHoverEasing,
}) {
  if (hoverTicks <= 0) return PVec3.zero;
  final double progress = durationTicks == 0
      ? 1
      : (hoverTicks / durationTicks).clamp(0, 1);
  return aim.normal * modifier * uiScale * hoverEasing(progress, easing);
}

double hoverEasing(double progress, HuiHoverEasing easing) {
  final double value = progress.clamp(0, 1);
  switch (easing) {
    case HuiHoverEasing.linear:
      return value;
    case HuiHoverEasing.easeOutCubic:
      final double inverse = 1 - value;
      return 1 - inverse * inverse * inverse;
    case HuiHoverEasing.easeInOutCubic:
      if (value < 0.5) return 4 * value * value * value;
      final double inverse = -2 * value + 2;
      return 1 - inverse * inverse * inverse / 2;
    case HuiHoverEasing.backOut:
      final double shifted = value - 1;
      return 1 +
          2.70158 * shifted * shifted * shifted +
          1.70158 * shifted * shifted;
  }
}

/// Column-major 4x4 identity.
List<double> huiIdentityMatrix() => <double>[
  1, 0, 0, 0, //
  0, 1, 0, 0, //
  0, 0, 1, 0, //
  0, 0, 0, 1, //
];

/// `a · b`, i.e. [b] applied first.
List<double> huiMultiplyMatrix(List<double> a, List<double> b) {
  _requireMatrix(a);
  _requireMatrix(b);
  final List<double> out = List<double>.filled(16, 0);
  for (int column = 0; column < 4; column++) {
    for (int row = 0; row < 4; row++) {
      double sum = 0;
      for (int k = 0; k < 4; k++) {
        sum += a[k * 4 + row] * b[column * 4 + k];
      }
      out[column * 4 + row] = sum;
    }
  }
  return out;
}

/// Transforms a point (w = 1) by a column-major matrix.
PVec3 huiTransformPoint(List<double> matrix, PVec3 point) {
  _requireMatrix(matrix);
  final double x =
      matrix[0] * point.x +
      matrix[4] * point.y +
      matrix[8] * point.z +
      matrix[12];
  final double y =
      matrix[1] * point.x +
      matrix[5] * point.y +
      matrix[9] * point.z +
      matrix[13];
  final double z =
      matrix[2] * point.x +
      matrix[6] * point.y +
      matrix[10] * point.z +
      matrix[14];
  final double w =
      matrix[3] * point.x +
      matrix[7] * point.y +
      matrix[11] * point.z +
      matrix[15];
  return w == 1 || w == 0 ? PVec3(x, y, z) : PVec3(x / w, y / w, z / w);
}

/// World blocks to camera blocks: right, up, backward, with the camera at the
/// origin. Exposed because it is the numerically checkable half of
/// [cssCameraMatrix].
List<double> viewMatrix(CameraBasis basis) {
  final PVec3 r = basis.right;
  final PVec3 u = basis.up;
  final PVec3 f = basis.forward;
  final PVec3 e = basis.position;
  return <double>[
    r.x, u.x, -f.x, 0, //
    r.y, u.y, -f.y, 0, //
    r.z, u.z, -f.z, 0, //
    -r.dot(e), -u.dot(e), f.dot(e), 1, //
  ];
}

/// Transform for the stage's camera element.
///
/// Composed as `translateZ(perspective) · pxFlip · view · blockFlip⁻¹` so that a
/// child placed at the css-world position of a point exactly `perspective /
/// pxPerBlock` blocks ahead of the camera renders 1:1. The parent must carry
/// `perspective: perspectivePx` and a centred `perspective-origin`.
List<double> cssCameraMatrix({
  required CameraBasis basis,
  required double perspectivePx,
  required double pxPerBlock,
}) {
  final double scale = pxPerBlock == 0 ? 1 : pxPerBlock;
  final List<double> toBlocks = <double>[
    1 / scale, 0, 0, 0, //
    0, -1 / scale, 0, 0, //
    0, 0, -1 / scale, 0, //
    0, 0, 0, 1, //
  ];
  final List<double> toPixels = <double>[
    scale, 0, 0, 0, //
    0, -scale, 0, 0, //
    0, 0, scale, 0, //
    0, 0, 0, 1, //
  ];
  final List<double> depth = <double>[
    1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    0, 0, perspectivePx, 1, //
  ];
  return huiMultiplyMatrix(
    depth,
    huiMultiplyMatrix(toPixels, huiMultiplyMatrix(viewMatrix(basis), toBlocks)),
  );
}

/// Transform for an aimed collision-plane overlay.
///
/// Columns are the css images of `right`, `−up` (css y is down) and `normal`,
/// so the overlay lies exactly on the plane the hit test uses. Push it a few
/// thousandths of a block along [PlaneAim.normal] before calling this if it is
/// coplanar with a quad, or the two will z-fight.
List<double> cssPlaneMatrix(PlaneAim aim, {required double pxPerBlock}) =>
    <double>[
      aim.right.x, -aim.right.y, -aim.right.z, 0, //
      -aim.up.x, aim.up.y, aim.up.z, 0, //
      aim.normal.x, -aim.normal.y, -aim.normal.z, 0, //
      aim.center.x * pxPerBlock,
      -aim.center.y * pxPerBlock,
      -aim.center.z * pxPerBlock,
      1,
    ];

/// Formats a column-major matrix as a css `matrix3d()`.
///
/// Fixed notation only: css cannot parse `1e-9`, and a single exponent anywhere
/// invalidates the whole declaration, silently dropping an element off the
/// stage. Non-finite values collapse to 0 for the same reason.
String cssMatrix3d(List<double> matrix) {
  _requireMatrix(matrix);
  final StringBuffer buffer = StringBuffer('matrix3d(');
  for (int i = 0; i < 16; i++) {
    if (i > 0) buffer.write(',');
    buffer.write(_css(matrix[i]));
  }
  buffer.write(')');
  return buffer.toString();
}

/// Six decimals is a thousandth of a pixel at any scale this stage uses.
String _css(double value) {
  if (!value.isFinite) return '0';
  final String text = value.toStringAsFixed(6);
  int end = text.length;
  if (text.contains('.')) {
    while (end > 0 && text[end - 1] == '0') {
      end--;
    }
    if (end > 0 && text[end - 1] == '.') end--;
  }
  final String trimmed = text.substring(0, end);
  return trimmed.isEmpty || trimmed == '-' || trimmed == '-0' ? '0' : trimmed;
}

void _requireMatrix(List<double> matrix) {
  if (matrix.length != 16) {
    throw ArgumentError.value(
      matrix.length,
      'matrix',
      'a 4x4 column-major matrix needs exactly 16 values',
    );
  }
}
