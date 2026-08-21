/// The editor drop stage's free camera: what a drag, a wheel notch and a held
/// key are worth, and the transform that comes out.
library;

import 'package:gloss_editor/components/real_drops/drop_stage_camera.dart';
import 'package:test/test.dart';

/// One second of walking, which is the unit the constants are stated in.
const double _second = 1;

void main() {
  test('an untouched camera writes no transform at all', () {
    expect(DropStageCamera.home.isHome, isTrue);
    expect(DropStageCamera.home.cssTransform, 'none');
  });

  test('the transform reads dolly, then orbit, then walk', () {
    final DropStageCamera camera = DropStageCamera.home
        .orbitBy(-100, 100)
        .dollyBy(-100)
        .walkBy(seconds: _second, strafe: 1);
    final String css = camera.cssTransform;
    expect(css, isNot('none'));

    // Order is the whole correctness argument: the dolly has to happen in the
    // eye's frame (after the rotation), the walk in the world's (before it).
    final int dolly = css.indexOf('translate3d(0, 0,');
    final int pitch = css.indexOf('rotateX(');
    final int yaw = css.indexOf('rotateY(');
    final int walk = css.lastIndexOf('translate3d(');
    expect(dolly, 0);
    expect(pitch, greaterThan(dolly));
    expect(yaw, greaterThan(pitch));
    expect(walk, greaterThan(yaw));
  });

  test('the scene turns opposite the eye, so it follows the pointer', () {
    final DropStageCamera dragged = DropStageCamera.home.orbitBy(100, 0);
    expect(dragged.yawDeg, closeTo(-100 * dropStageYawDegPerPx, 1e-9));
    // The transform is the inverse of the move, so a drag right rotates the
    // scene the way the hand went.
    expect(dragged.cssTransform, contains('rotateY(32.00deg)'));
  });

  test('dragging down lifts the eye, dragging up lowers it', () {
    expect(DropStageCamera.home.orbitBy(0, 100).pitchDeg, greaterThan(0));
    expect(DropStageCamera.home.orbitBy(0, -100).pitchDeg, lessThan(0));
  });

  test('pitch stops above the floor and short of straight down', () {
    expect(
      DropStageCamera.home.orbitBy(0, -100000).pitchDeg,
      dropStageMinPitchDeg,
    );
    expect(
      DropStageCamera.home.orbitBy(0, 100000).pitchDeg,
      dropStageMaxPitchDeg,
    );
  });

  test('yaw wraps instead of growing without bound', () {
    DropStageCamera camera = DropStageCamera.home;
    for (int drag = 0; drag < 40; drag++) {
      camera = camera.orbitBy(-100, 0);
    }
    expect(camera.yawDeg, greaterThan(-180));
    expect(camera.yawDeg, lessThanOrEqualTo(180));
  });

  test('scrolling toward the scene moves in, and both ends clamp', () {
    expect(DropStageCamera.home.dollyBy(-100).dollyPx, greaterThan(0));
    expect(DropStageCamera.home.dollyBy(100).dollyPx, lessThan(0));
    expect(DropStageCamera.home.dollyBy(-1e6).dollyPx, dropStageMaxDollyPx);
    expect(DropStageCamera.home.dollyBy(1e6).dollyPx, dropStageMinDollyPx);
  });

  test('a wheel delta is read in the units the event states', () {
    expect(dropStageWheelPixels(120, 0), 120);
    expect(dropStageWheelPixels(3, 1), 48);
    expect(dropStageWheelPixels(1, 2), 400);
  });

  test('W walks into the screen and S back out of it', () {
    final DropStageCamera forward = DropStageCamera.home.walkBy(
      seconds: _second,
      forward: 1,
    );
    expect(forward.walkZPx, closeTo(-dropStageWalkPxPerSecond, 1e-9));
    expect(forward.walkXPx, closeTo(0, 1e-9));
    expect(forward.walkYPx, closeTo(0, 1e-9));

    final DropStageCamera back = DropStageCamera.home.walkBy(
      seconds: _second,
      forward: -1,
    );
    expect(back.walkZPx, closeTo(dropStageWalkPxPerSecond, 1e-9));
  });

  test('D strafes right and A left, without changing height', () {
    final DropStageCamera right = DropStageCamera.home.walkBy(
      seconds: _second,
      strafe: 1,
    );
    expect(right.walkXPx, closeTo(dropStageWalkPxPerSecond, 1e-9));
    expect(right.walkYPx, 0);
    final DropStageCamera left = DropStageCamera.home.walkBy(
      seconds: _second,
      strafe: -1,
    );
    expect(left.walkXPx, closeTo(-dropStageWalkPxPerSecond, 1e-9));
  });

  test('walking follows the view once the eye has turned', () {
    // A quarter turn puts the view down the X axis, so W stops changing Z.
    final DropStageCamera turned = const DropStageCamera(
      yawDeg: 90,
    ).walkBy(seconds: _second, forward: 1);
    expect(turned.walkZPx, closeTo(0, 1e-9));
    expect(turned.walkXPx.abs(), closeTo(dropStageWalkPxPerSecond, 1e-9));
  });

  test('walking down the view descends when the eye is pitched', () {
    final DropStageCamera pitched = const DropStageCamera(
      pitchDeg: 45,
    ).walkBy(seconds: _second, forward: 1);
    expect(
      pitched.walkYPx,
      greaterThan(0),
      reason: 'positive Y is down, and a lifted eye looks down',
    );
    expect(pitched.walkZPx, lessThan(0));
  });

  test('space and shift are world up and down at any pitch', () {
    for (final double pitch in <double>[dropStageMinPitchDeg, 0, 45, 70]) {
      final DropStageCamera lifted = DropStageCamera(
        pitchDeg: pitch,
        yawDeg: 37,
      ).walkBy(seconds: _second, lift: 1);
      expect(lifted.walkYPx, closeTo(-dropStageWalkPxPerSecond, 1e-9));
      expect(lifted.walkXPx, 0, reason: 'no sideways drift at pitch $pitch');
      expect(lifted.walkZPx, 0);
    }
  });

  test('a turn does not drag the ground already walked', () {
    final DropStageCamera walked = DropStageCamera.home.walkBy(
      seconds: _second,
      forward: 1,
    );
    final DropStageCamera turned = walked.orbitBy(400, 0);
    expect(
      turned.walkZPx,
      walked.walkZPx,
      reason: 'the walk is world space; only new steps use the new heading',
    );
    expect(turned.walkXPx, walked.walkXPx);
  });

  test('a held key cannot walk out of the box', () {
    DropStageCamera camera = DropStageCamera.home;
    for (int frame = 0; frame < 600; frame++) {
      camera = camera.walkBy(seconds: 0.1, forward: -1, strafe: 1, lift: 1);
    }
    expect(camera.walkXPx, dropStageWalkRangePx);
    expect(camera.walkYPx, -dropStageWalkRangePx);
    expect(camera.walkZPx, dropStageWalkRangePx);
  });

  test('a frame that took no time moves nothing', () {
    expect(
      DropStageCamera.home.walkBy(seconds: 0, forward: 1).isHome,
      isTrue,
    );
  });

  test('resetting is exactly the home camera', () {
    final DropStageCamera moved = DropStageCamera.home
        .orbitBy(30, 40)
        .dollyBy(-200)
        .walkBy(seconds: _second, forward: 1, lift: 1);
    expect(moved.isHome, isFalse);
    expect(DropStageCamera.home.cssTransform, 'none');
  });
}
