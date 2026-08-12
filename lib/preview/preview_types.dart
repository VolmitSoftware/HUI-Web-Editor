/// Shared value types for the 3D preview.
///
/// Everything here is pure and DOM-free so the projection, the simulation and
/// the store can all speak the same language on the VM.
///
/// Authoring frame, stated once: the player's feet are the origin, **+X is the
/// player's right, +Y is up, +Z is forward/away**. That already folds in the
/// runtime's X negation at load (`MenuSession.java:70`), so nothing downstream
/// mirrors a second time — the preview *teaches* the mirror instead.
library;

import 'dart:math' as math;

import '../model/hui_menu.dart' show huiMaxDistanceCeiling;

/// Player eye height in blocks. Mirrors `huiPlayerEyeHeight` in
/// `components/canvas/backdrop.dart`, which cannot be imported here: that file
/// pulls in `package:web` and this one has to run on the VM.
const double huiPreviewEyeHeight = 1.62;

/// An immutable point or direction in the authoring frame.
class PVec3 {
  const PVec3(this.x, this.y, this.z);

  static const PVec3 zero = PVec3(0, 0, 0);
  static const PVec3 up = PVec3(0, 1, 0);
  static const PVec3 forward = PVec3(0, 0, 1);
  static const PVec3 right = PVec3(1, 0, 0);

  final double x;
  final double y;
  final double z;

  PVec3 operator +(PVec3 other) => PVec3(x + other.x, y + other.y, z + other.z);

  PVec3 operator -(PVec3 other) => PVec3(x - other.x, y - other.y, z - other.z);

  PVec3 operator -() => PVec3(-x, -y, -z);

  PVec3 operator *(double scalar) => PVec3(x * scalar, y * scalar, z * scalar);

  PVec3 scale(double scalar) => this * scalar;

  /// Component-wise scale: the runtime multiplies component offsets by
  /// `uiScale` on all three axes but leaves the menu offset alone
  /// (`HuiSettings.java:60-66`), and some callers need only one of those.
  PVec3 scaleXYZ(double sx, double sy, double sz) =>
      PVec3(x * sx, y * sy, z * sz);

  double dot(PVec3 other) => x * other.x + y * other.y + z * other.z;

  PVec3 cross(PVec3 other) => PVec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  double get lengthSquared => x * x + y * y + z * z;

  double get length => math.sqrt(lengthSquared);

  double distanceSquaredTo(PVec3 other) => (this - other).lengthSquared;

  double distanceTo(PVec3 other) => (this - other).length;

  /// Zero-length vectors normalize to zero rather than to NaN: a degenerate
  /// plane normal must not poison a whole frame of transforms.
  PVec3 get normalized {
    final double len = length;
    return len <= 0 || !len.isFinite ? zero : PVec3(x / len, y / len, z / len);
  }

  @override
  bool operator ==(Object other) =>
      other is PVec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'PVec3($x, $y, $z)';
}

/// A picking ray in the authoring frame. [direction] is expected normalized;
/// [LookRay.normalized] guarantees it.
class LookRay {
  const LookRay(this.origin, this.direction);

  LookRay.normalized(this.origin, PVec3 direction)
    : direction = direction.normalized;

  final PVec3 origin;
  final PVec3 direction;

  PVec3 pointAt(double t) => origin + direction * t;

  @override
  bool operator ==(Object other) =>
      other is LookRay &&
      other.origin == origin &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(origin, direction);

  @override
  String toString() => 'LookRay($origin -> $direction)';
}

/// How the preview camera is driven.
enum PreviewCameraMode {
  orbit,
  player;

  static PreviewCameraMode fromName(Object? raw) {
    for (final PreviewCameraMode value in PreviewCameraMode.values) {
      if (value.name == raw) return value;
    }
    return PreviewCameraMode.orbit;
  }
}

/// Orbit-camera pose. Pure data — `preview/projection.dart` turns it into a
/// matrix.
class OrbitCamera {
  const OrbitCamera({
    this.target = PVec3.zero,
    this.yawDegrees = 0,
    this.pitchDegrees = 0,
    this.distance = 4,
  });

  /// Looking straight down or up degenerates the derived up vector.
  static const double minPitchDegrees = -89;
  static const double maxPitchDegrees = 89;
  static const double minDistance = 0.4;
  static const double maxDistance = 64;

  final PVec3 target;
  final double yawDegrees;
  final double pitchDegrees;
  final double distance;

  OrbitCamera copyWith({
    PVec3? target,
    double? yawDegrees,
    double? pitchDegrees,
    double? distance,
  }) => OrbitCamera(
    target: target ?? this.target,
    yawDegrees: yawDegrees ?? this.yawDegrees,
    pitchDegrees: pitchDegrees ?? this.pitchDegrees,
    distance: distance ?? this.distance,
  );

  /// Pitch and dolly clamped into a usable range; yaw is free.
  OrbitCamera clamped() => OrbitCamera(
    target: target,
    yawDegrees: yawDegrees,
    pitchDegrees: _clamp(pitchDegrees, minPitchDegrees, maxPitchDegrees),
    distance: _clamp(distance, minDistance, maxDistance),
  );

  @override
  bool operator ==(Object other) =>
      other is OrbitCamera &&
      other.target == target &&
      other.yawDegrees == yawDegrees &&
      other.pitchDegrees == pitchDegrees &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(target, yawDegrees, pitchDegrees, distance);

  @override
  String toString() =>
      'OrbitCamera($target, yaw: $yawDegrees, pitch: $pitchDegrees, '
      'distance: $distance)';
}

/// Where the simulated player is standing and looking.
///
/// [feet] is the anchor the runtime uses: menus hang off `player.getLocation()`,
/// which is the feet, not the eyes (`MenuSession.java:73`).
class PlayerPose {
  const PlayerPose({
    this.feet = PVec3.zero,
    this.yawDegrees = 0,
    this.pitchDegrees = 0,
  });

  final PVec3 feet;
  final double yawDegrees;
  final double pitchDegrees;

  PVec3 get eye => PVec3(feet.x, feet.y + huiPreviewEyeHeight, feet.z);

  PlayerPose copyWith({
    PVec3? feet,
    double? yawDegrees,
    double? pitchDegrees,
  }) => PlayerPose(
    feet: feet ?? this.feet,
    yawDegrees: yawDegrees ?? this.yawDegrees,
    pitchDegrees: pitchDegrees ?? this.pitchDegrees,
  );

  PlayerPose clamped() => PlayerPose(
    feet: feet,
    yawDegrees: yawDegrees,
    pitchDegrees: _clamp(pitchDegrees, -89.9, 89.9),
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerPose &&
      other.feet == feet &&
      other.yawDegrees == yawDegrees &&
      other.pitchDegrees == pitchDegrees;

  @override
  int get hashCode => Object.hash(feet, yawDegrees, pitchDegrees);

  @override
  String toString() =>
      'PlayerPose($feet, yaw: $yawDegrees, pitch: $pitchDegrees)';
}

/// Why a simulated session closed.
///
/// Only one reason is reachable in the preview: the editor has no death,
/// teleport or world change to react to. The wire name is the runtime's own
/// token so the HUD quotes what a server admin would see
/// (`HoloCloseReason` / `MenuSessionManager.java:112`).
enum PreviewCloseReason {
  movedOutOfRange;

  String get wireName => switch (this) {
    PreviewCloseReason.movedOutOfRange => 'MOVED_OUT_OF_RANGE',
  };
}

/// The runtime's range test, warts and all.
///
/// `MenuSession.java:147-151` compares the SQUARED distance from the player to
/// the menu centre against `maxDistance² + offset.lengthSquared()`, so a menu
/// held further out is allowed to travel proportionally further before it
/// closes. A null [maxDistance] means the key was absent, which the plugin
/// reads as the 6e7 ceiling — effectively unlimited.
bool huiWithinMaxDistance({
  required PVec3 playerFeet,
  required PVec3 center,
  required double? maxDistance,
  required PVec3 menuOffset,
}) {
  final double raw = maxDistance ?? huiMaxDistanceCeiling;
  if (raw.isNaN) return true;
  final double limit = _clamp(raw, 0, huiMaxDistanceCeiling);
  return center.distanceSquaredTo(playerFeet) <=
      limit * limit + menuOffset.lengthSquared;
}

double _clamp(double value, double min, double max) {
  if (value.isNaN) return min;
  return value < min ? min : (value > max ? max : value);
}
