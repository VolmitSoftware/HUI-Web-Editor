/// The `display` transform a stage asks a model for.
library;

import 'package:gloss_editor/mc/assets/mc_display_pose.dart';
import 'package:gloss_editor/mc/assets/mc_model_json.dart';
import 'package:gloss_editor/mc/assets/mc_model_resolver.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:test/test.dart';

McResolvedModel _model(Map<String, McDisplayTransformJson> display) =>
    McResolvedModel(
      id: 'item/test',
      elements: const <McResolvedElement>[],
      textures: const <String, String>{},
      display: display,
      generated: true,
      entityBuiltin: false,
      layers: const <String>['item/test'],
    );

void main() {
  test('pose keys match the model JSON', () {
    expect(McDisplayPose.fixed.key, 'fixed');
    expect(McDisplayPose.thirdPersonRightHand.key, 'thirdperson_righthand');
    expect(McDisplayPose.firstPersonLeftHand.key, 'firstperson_lefthand');
  });

  test('none never reads the model, fixed reads its entry', () {
    final McResolvedModel model = _model(<String, McDisplayTransformJson>{
      'fixed': const McDisplayTransformJson(rotation: <double>[0, 180, 0]),
    });
    expect(mcDisplayTransform(model, McDisplayPose.none), isNull);
    expect(mcDisplayTransform(model, McDisplayPose.fixed)!.rotation, <double>[0, 180, 0]);
    expect(mcDisplayTransform(model, McDisplayPose.gui), isNull);
  });

  test('a left hand falls back to the right hand entry like the client', () {
    final McResolvedModel model = _model(<String, McDisplayTransformJson>{
      'thirdperson_righthand': const McDisplayTransformJson(scale: <double>[0.5, 0.5, 0.5]),
    });
    expect(
      mcDisplayTransform(model, McDisplayPose.thirdPersonLeftHand)!.scale,
      <double>[0.5, 0.5, 0.5],
    );
  });

  test('a display pose applies scale, then rotation, then translation about the centre', () {
    final McMat4 pose = mcDisplayPoseMatrix(const McDisplayTransformJson(
      rotation: <double>[0, 180, 0],
      translation: <double>[0, 16, 0],
      scale: <double>[0.5, 0.5, 0.5],
    ));
    final McVec3 p = pose.transformPoint(const McVec3(1, 1, 1));
    expect(p.x, closeTo(0.25, 1e-9));
    expect(p.y, closeTo(1.75, 1e-9));
    expect(p.z, closeTo(0.25, 1e-9));
    expect(mcDisplayPoseMatrix(null).toList(), McMat4.identity().toList());
  });

  test('two rotation axes compose as the client Rx * Ry * Rz, Z first', () {
    // `ItemTransform` uses `rotationXYZ(x, y, z)` = Rx * Ry * Rz, so the
    // vertex meets Z first. By hand for rotation [90, 0, 90] on the corner
    // (1, 1, 1), no translation and unit scale:
    //   centre it:  (1,1,1) - 0.5      = ( 0.5,  0.5, 0.5)
    //   Rz(90):     (x c - y s, x s + y c, z) = (-0.5,  0.5, 0.5)
    //   Rx(90):     (x, y c - z s, y s + z c) = (-0.5, -0.5, 0.5)
    //   re-centre:  + 0.5              = ( 0.0,  0.0, 1.0)
    // The reverse order (Rz * Ry * Rx) would leave the corner at (1, 1, 1).
    final McMat4 pose = mcDisplayPoseMatrix(const McDisplayTransformJson(
      rotation: <double>[90, 0, 90],
    ));
    final McVec3 p = pose.transformPoint(const McVec3(1, 1, 1));
    expect(p.x, closeTo(0, 1e-9));
    expect(p.y, closeTo(0, 1e-9));
    expect(p.z, closeTo(1, 1e-9));
  });
}
