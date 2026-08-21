/// The editor drop stage's camera: where the viewer is standing, and the one
/// CSS transform that puts them there.
///
/// The stage is a CSS 3D scene, so there is no camera to move — only a
/// transform on the scene that has to be the *inverse* of the move. That
/// inverse is short, and it is worth writing down why, because the shape of it
/// is what makes the three controls agree with each other:
///
///  * `.hui-real-drops-world` owns `perspective`, which fixes the eye at a
///    point in front of the page and cannot be animated without moving the
///    projection itself. The camera transform therefore lives on a child,
///    `.hui-real-drops-camera`, whose `transform-origin` is the pivot the orbit
///    turns around — a point on the ground, out where the stack settles.
///  * Orbiting the eye around a pivot is exactly rotating the scene about that
///    pivot by the opposite angle, with no dependence on how far away the eye
///    started. That is the `rotateX`/`rotateY` pair, and it is why the pivot
///    living in CSS (`transform-origin`) rather than in this file loses
///    nothing.
///  * Dollying the eye toward the pivot along its own view axis moves the
///    scene the same distance toward the viewer, *after* the rotation — the
///    leading `translate3d` on Z.
///  * Walking the eye with WASD is a translation in world space, so it is
///    applied *before* the rotation — the trailing `translate3d`. Keeping the
///    walk in world space is what stops a turn from dragging the eye sideways
///    through everywhere it had already walked to.
///
/// Coordinates are the stage's CSS pixels: +X right, +Y **down**, +Z toward the
/// viewer. Distances are pixels rather than blocks because they are camera
/// framing, not anything the document states — `real_drop_stage.dart` owns the
/// numbers that are in blocks.
///
/// DOM-free on purpose: `real_drops_view.dart` reads the pointer, wheel and key
/// events and this decides what they mean, so every clamp and every basis
/// vector is testable on the VM.
library;

import 'dart:math' as math;

/// Degrees of yaw and pitch one pixel of drag is worth. A full turn takes
/// about three viewport widths, which is slow enough to aim and fast enough to
/// get behind the stack without letting go.
const double dropStageYawDegPerPx = 0.32;
const double dropStagePitchDegPerPx = 0.24;

/// How far the eye may tip, in degrees off the stage's default framing.
///
/// The default is not level: the stage's perspective origin sits well above the
/// ground line, so the eye already looks down at the floor by roughly fifteen
/// degrees. [dropStageMinPitchDeg] therefore keeps a little of that margin
/// instead of reaching for zero — it is stated against the stage's own framing
/// rather than measured per layout, and the stage's minimum height is what
/// keeps that framing from getting shallow enough to matter. The maximum stops
/// short of straight down, where a floor seen exactly edge-on stops reading as
/// a floor.
const double dropStageMinPitchDeg = -12;
const double dropStageMaxPitchDeg = 72;

/// How far the eye may dolly, in pixels toward and away from the pivot.
///
/// In is bounded by the perspective distance — pushing the eye through the
/// scene turns geometry inside out — and out by the point where the stack is
/// too small to read.
const double dropStageMinDollyPx = -520;
const double dropStageMaxDollyPx = 400;

/// Pixels of dolly one pixel of `wheel` delta is worth.
const double dropStageDollyPxPerWheelUnit = 0.55;

/// A `wheel` event's delta in pixels.
///
/// Chrome reports pixels, Firefox reports lines and a page-scrolling
/// configuration reports pages; a dolly that only read `deltaY` would be a
/// sixtieth of the speed outside Chrome. The line and page sizes are the ones
/// browsers themselves use for an unstyled document, which is as close as an
/// event that does not carry them can get.
double dropStageWheelPixels(double delta, int deltaMode) => switch (deltaMode) {
  1 => delta * 16,
  2 => delta * 400,
  _ => delta,
};

/// How far the eye may walk from the throw, on each axis, and how fast a held
/// key walks it. The box is generous enough to stand beside or above the stack
/// and tight enough that nobody loses it off screen.
const double dropStageWalkRangePx = 340;
const double dropStageWalkPxPerSecond = 330;

const double _degToRad = math.pi / 180;

/// Where the viewer is standing, as an offset from the stage's default framing.
///
/// All zeroes is [home] — the fixed view the stage has always had, and the view
/// the `gameContext` frame keeps, because that frame is the client's own and
/// the client does not get to fly.
final class DropStageCamera {
  const DropStageCamera({
    this.yawDeg = 0,
    this.pitchDeg = 0,
    this.dollyPx = 0,
    this.walkXPx = 0,
    this.walkYPx = 0,
    this.walkZPx = 0,
  });

  /// The stage's default framing.
  static const DropStageCamera home = DropStageCamera();

  /// Degrees the eye has orbited around the pivot. Positive yaw walks the eye
  /// to its own left; positive pitch lifts it.
  final double yawDeg;
  final double pitchDeg;

  /// Pixels the eye has dollied toward the pivot along its view axis.
  final double dollyPx;

  /// Pixels the eye has walked, in world space. [walkYPx] is positive
  /// downward, like every other Y on the stage.
  final double walkXPx;
  final double walkYPx;
  final double walkZPx;

  /// True while nothing has been moved, so the stage can say "Reset view" is
  /// pointless and skip writing a transform at all.
  bool get isHome =>
      yawDeg == 0 &&
      pitchDeg == 0 &&
      dollyPx == 0 &&
      walkXPx == 0 &&
      walkYPx == 0 &&
      walkZPx == 0;

  /// A drag of [dxPx] right and [dyPx] down.
  ///
  /// The scene follows the pointer — dragging right brings the stack's left
  /// side around, dragging down tips its top toward the viewer — which is the
  /// grab-the-world convention every other orbit surface in the editor uses.
  DropStageCamera orbitBy(double dxPx, double dyPx) => _with(
    yawDeg: _wrapDegrees(yawDeg - dxPx * dropStageYawDegPerPx),
    pitchDeg: (pitchDeg + dyPx * dropStagePitchDegPerPx).clamp(
      dropStageMinPitchDeg,
      dropStageMaxPitchDeg,
    ),
  );

  /// A wheel notch of [deltaY]. Browsers report scrolling away from the user as
  /// negative, which is the gesture for moving in.
  DropStageCamera dollyBy(double deltaY) => _with(
    dollyPx: (dollyPx - deltaY * dropStageDollyPxPerWheelUnit).clamp(
      dropStageMinDollyPx,
      dropStageMaxDollyPx,
    ),
  );

  /// [seconds] of walking: [forward] and [strafe] along the eye's own axes,
  /// [lift] straight up the world's.
  ///
  /// Each is a signed fraction of [dropStageWalkPxPerSecond], so a held key
  /// passes 1 and the caller's frame length decides the distance — a slow frame
  /// covers the same ground as two fast ones instead of stuttering.
  ///
  /// Forward follows the whole view vector, pitch included, so looking down and
  /// holding W descends toward what you are looking at. Lift is deliberately
  /// world-up instead: Space and Shift that drifted sideways whenever the eye
  /// was pitched would be unusable for getting over the stack.
  DropStageCamera walkBy({
    required double seconds,
    double forward = 0,
    double strafe = 0,
    double lift = 0,
  }) {
    if (seconds <= 0) return this;
    final double yaw = yawDeg * _degToRad;
    final double pitch = pitchDeg * _degToRad;
    final double cosPitch = math.cos(pitch);
    // The eye's basis, as `rotateY(yaw) * rotateX(pitch)` maps it: view is -Z
    // in camera space, right is +X, and world up is -Y.
    final double viewX = -math.sin(yaw) * cosPitch;
    final double viewY = math.sin(pitch);
    final double viewZ = -math.cos(yaw) * cosPitch;
    final double rightX = math.cos(yaw);
    final double rightZ = -math.sin(yaw);
    final double step = dropStageWalkPxPerSecond * seconds;
    return _with(
      walkXPx: _clampWalk(walkXPx + (viewX * forward + rightX * strafe) * step),
      walkYPx: _clampWalk(walkYPx + (viewY * forward - lift) * step),
      walkZPx: _clampWalk(walkZPx + (viewZ * forward + rightZ * strafe) * step),
    );
  }

  /// The `transform` for `.hui-real-drops-camera`, or `none` at [home] so an
  /// untouched stage carries no transform of its own at all.
  String get cssTransform {
    if (isHome) return 'none';
    return 'translate3d(0, 0, ${_px(dollyPx)}) '
        'rotateX(${_deg(-pitchDeg)}) rotateY(${_deg(-yawDeg)}) '
        'translate3d(${_px(-walkXPx)}, ${_px(-walkYPx)}, ${_px(-walkZPx)})';
  }

  DropStageCamera _with({
    double? yawDeg,
    double? pitchDeg,
    double? dollyPx,
    double? walkXPx,
    double? walkYPx,
    double? walkZPx,
  }) => DropStageCamera(
    yawDeg: yawDeg ?? this.yawDeg,
    pitchDeg: pitchDeg ?? this.pitchDeg,
    dollyPx: dollyPx ?? this.dollyPx,
    walkXPx: walkXPx ?? this.walkXPx,
    walkYPx: walkYPx ?? this.walkYPx,
    walkZPx: walkZPx ?? this.walkZPx,
  );
}

double _clampWalk(double value) =>
    value.clamp(-dropStageWalkRangePx, dropStageWalkRangePx);

/// Keeps yaw in `(-180, 180]` so a few turns in one direction do not grow a
/// number nobody can read in a readout.
double _wrapDegrees(double degrees) {
  double wrapped = degrees % 360;
  if (wrapped > 180) wrapped -= 360;
  if (wrapped <= -180) wrapped += 360;
  return wrapped;
}

String _px(double value) => '${value.toStringAsFixed(2)}px';

String _deg(double value) => '${value.toStringAsFixed(2)}deg';
