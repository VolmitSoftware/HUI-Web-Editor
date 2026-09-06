/// One camera for every stage: blocks in, matrices out.
library;

import 'dart:math' as math;

import 'package:gloss_editor/mc/scene/mc_camera.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:test/test.dart';

void main() {
  test('home framings look at their pivot from the stated distance', () {
    final McCamera drops = mcCameraHome(McStageKind.drops, const McVec3(0, 0, 1.15));
    expect(drops.distance, 3.2);
    expect(drops.pitchDeg, 22);
    expect((drops.eye - drops.pivot).length, closeTo(3.2, 1e-9));
    final McCamera frame = mcCameraHome(McStageKind.frame, McVec3.zero);
    expect(frame.pitchDeg, 0);
    expect(frame.eye.y, closeTo(1.62, 1e-9));
  });

  test('dragging right orbits so the scene follows the pointer', () {
    final McCamera home = mcCameraHome(McStageKind.drops, McVec3.zero);
    final McCamera dragged = home.orbitBy(100, 0);
    expect(dragged.yawDeg, closeTo(home.yawDeg - 100 * mcCameraYawDegPerPx, 1e-9));
    expect(dragged.distance, home.distance);
    expect((dragged.eye - dragged.pivot).length, closeTo(home.distance, 1e-9));
  });

  test('pitch is clamped short of the poles and the eye never sinks below ground', () {
    final McCamera home = mcCameraHome(McStageKind.hologram, const McVec3(0, 0.5, 0));
    expect(home.orbitBy(0, 100000).pitchDeg, 89);
    final McCamera low = home.orbitBy(0, -100000);
    expect(low.pitchDeg, greaterThanOrEqualTo(-89));
    expect(low.eye.y, greaterThanOrEqualTo(mcCameraMinEyeY));
  });

  test('the wheel dollies exponentially inside the distance clamps', () {
    final McCamera home = mcCameraHome(McStageKind.drops, McVec3.zero);
    expect(home.dollyBy(100).distance, closeTo(home.distance * math.exp(100 * mcCameraDollyPerWheelPx), 1e-9));
    expect(home.dollyBy(100000).distance, mcCameraMaxDistance);
    expect(home.dollyBy(-100000).distance, mcCameraMinDistance);
    expect(mcWheelPixels(3, 1), 48);
    expect(mcWheelPixels(1, 2), 400);
    expect(mcWheelPixels(7, 0), 7);
  });

  test('panning tracks the pointer at the projection field of view', () {
    final McCamera home = mcCameraHome(McStageKind.drops, McVec3.zero);
    final McCamera panned = home.panBy(-50, 0, 500);
    // The projection's FOV is 2*atan((H/2)/perspective), so 2*tan(fov/2) is
    // H/perspective and the viewport height cancels: a pixel is
    // distance/perspective blocks, whatever the stage is tall.
    final double blocks = 50 * home.distance / 900;
    expect(home.blocksPerPixel(500), closeTo(home.distance / 900, 1e-12));
    expect(home.blocksPerPixel(1080), closeTo(home.blocksPerPixel(500), 1e-12));
    expect((panned.pivot - home.pivot).length, closeTo(blocks, 1e-9));
    expect(panned.pivot.dot(home.right), closeTo(blocks, 1e-9));
    // A shallower perspective magnifies, so one pixel is fewer blocks.
    expect(home.blocksPerPixel(500, perspectivePx: 450), closeTo(home.distance / 450, 1e-12));
    expect(
      (home.panBy(-50, 0, 500, perspectivePx: 450).pivot - home.pivot).length,
      closeTo(50 * home.distance / 450, 1e-9),
    );
  });

  test('flying walks pivot and eye together at vanilla speed in world space', () {
    final McCamera home = mcCameraHome(McStageKind.drops, McVec3.zero);
    final McCamera flown = home.flyBy(seconds: 1, forward: 1, strafe: 0, lift: 0);
    final McVec3 horizontal = McVec3(home.forward.x, 0, home.forward.z).normalized;
    expect((flown.pivot - home.pivot).length, closeTo(mcCameraWalkBlocksPerSecond, 1e-9));
    expect((flown.pivot - home.pivot).normalized.dot(horizontal), closeTo(1, 1e-9));
    expect(flown.distance, home.distance);
    final McCamera lifted = home.flyBy(seconds: 0.5, forward: 0, strafe: 0, lift: 1);
    expect(lifted.pivot.y - home.pivot.y, closeTo(mcCameraWalkBlocksPerSecond / 2, 1e-9));
    final McCamera strafed = home.flyBy(seconds: 1, forward: 0, strafe: 1, lift: 0);
    expect((strafed.pivot - home.pivot).dot(home.right), greaterThan(0));
  });

  test('the pivot cannot leave the world patch', () {
    final McCamera home = mcCameraHome(McStageKind.drops, McVec3.zero);
    final McCamera far = home.flyBy(seconds: 100, forward: 1, strafe: 0, lift: 0);
    expect(far.pivot.x.abs(), lessThanOrEqualTo(mcCameraPivotRange));
    expect(far.pivot.z.abs(), lessThanOrEqualTo(mcCameraPivotRange));
  });

  test('the view matrix puts the pivot straight ahead', () {
    final McCamera home = mcCameraHome(McStageKind.bubbles, const McVec3(0, 1.62, 0));
    final McVec3 p = home.view().transformPoint(home.pivot);
    expect(p.x, closeTo(0, 1e-9));
    expect(p.y, closeTo(0, 1e-9));
    expect(p.z, closeTo(-home.distance, 1e-9));
  });

  test('the hologram home frames the stack midpoint', () {
    final McCamera camera = mcCameraHome(McStageKind.hologram, const McVec3(0.5, 0.75, 0.5));
    expect(camera.pivot.y, 0.75);
    expect(camera.distance, 5);
  });
}
