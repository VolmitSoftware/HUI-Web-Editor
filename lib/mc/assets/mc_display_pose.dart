/// Which `display` transform a stage draws a model with.
///
/// Drops are `fixed` (`RealDropService.java:316` sets
/// `ItemDisplayTransform.FIXED`), menu item icons are `none`
/// (`MenuIcon.itemDisplay` leaves the type byte at 0). The client falls back
/// from a left hand to the right hand entry when the model has only one.
library;

import '../scene/mc_math.dart';
import 'mc_model_json.dart';
import 'mc_model_resolver.dart';

enum McDisplayPose {
  none,
  fixed,
  gui,
  ground,
  head,
  thirdPersonRightHand,
  thirdPersonLeftHand,
  firstPersonRightHand,
  firstPersonLeftHand;

  String get key => switch (this) {
    McDisplayPose.none => 'none',
    McDisplayPose.fixed => 'fixed',
    McDisplayPose.gui => 'gui',
    McDisplayPose.ground => 'ground',
    McDisplayPose.head => 'head',
    McDisplayPose.thirdPersonRightHand => 'thirdperson_righthand',
    McDisplayPose.thirdPersonLeftHand => 'thirdperson_lefthand',
    McDisplayPose.firstPersonRightHand => 'firstperson_righthand',
    McDisplayPose.firstPersonLeftHand => 'firstperson_lefthand',
  };
}

McDisplayTransformJson? mcDisplayTransform(McResolvedModel model, McDisplayPose pose) {
  if (pose == McDisplayPose.none) return null;
  final McDisplayTransformJson? own = model.display[pose.key];
  if (own != null) return own;
  return switch (pose) {
    McDisplayPose.thirdPersonLeftHand => model.display['thirdperson_righthand'],
    McDisplayPose.firstPersonLeftHand => model.display['firstperson_righthand'],
    _ => null,
  };
}

/// The client applies `display` as scale, then rotation, then translation in
/// sixteenths, all about the model's centre (0.5, 0.5, 0.5). Null (pose
/// `none`, or a model without the entry) is the identity.
///
/// `ItemTransform.apply` composes the rotation with
/// `Quaternionf().rotationXYZ(x, y, z)`, which is the matrix `Rx * Ry * Rz` —
/// Z reaches the vertex first. (`ModelPart.translateAndRotate` uses
/// `rotationZYX` instead, which is why `mc_rig_mesher.dart` builds the
/// opposite chain; the two client call sites genuinely differ.)
McMat4 mcDisplayPoseMatrix(McDisplayTransformJson? transform) {
  if (transform == null) return McMat4.identity();
  final List<double> r = transform.rotation;
  final List<double> t = transform.translation;
  final List<double> s = transform.scale;
  return McMat4.translation(0.5 + t[0] / 16, 0.5 + t[1] / 16, 0.5 + t[2] / 16)
      .multiply(McMat4.rotationX(r[0]))
      .multiply(McMat4.rotationY(r[1]))
      .multiply(McMat4.rotationZ(r[2]))
      .multiply(McMat4.scale(s[0], s[1], s[2]))
      .multiply(McMat4.translation(-0.5, -0.5, -0.5));
}
