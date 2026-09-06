/// What a stage view owns and the stage widget reads: the scene, the camera,
/// whether frames should keep coming, the home framing, and the sprite a
/// model falls back to when the browser has no WebGL2.
library;

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_scene.dart';
import '../../services/catalogs.dart';

/// The stage views' [McStageController.spriteFor]: item and block models from
/// the material catalog, rigs from the entity catalog under their
/// `minecraft:` key (the player only when the catalog carries
/// `minecraft:player`, which it does not today), billboards as they are.
String? mcCatalogSpriteFor(HuiCatalogs catalogs, McSceneNode node) => switch (node) {
  McItemModelNode(:final String itemId) => catalogs.textureFor(itemId),
  McBlockModelNode(:final String blockId) => catalogs.textureFor(blockId),
  McRigNode(:final String rigId) => catalogs.entityTextureFor('minecraft:$rigId'),
  McBillboardNode(:final String textureUrl) => textureUrl,
  McShadowNode() || McWaterNode() || McParticleNode() => null,
};

final class McStageController extends ChangeNotifier {
  McStageController({
    required this.kind,
    required McVec3 homePivot,
    this.freeCamera = true,
  })  : _homePivot = homePivot,
        _camera = mcCameraHome(kind, homePivot);

  final McStageKind kind;

  /// False inside the game frame: the client does not get to fly.
  final bool freeCamera;

  /// The catalog sprite for a model node, drawn as a DOM billboard where the
  /// model would stand once [webGlAvailable] is false. Null, or a null
  /// answer, draws nothing for that node.
  String? Function(McSceneNode node)? spriteFor;

  McVec3 _homePivot;
  McCamera _camera;
  McScene _scene = McScene.empty;
  bool _animating = false;

  /// Frames rendered so far; the browser verification reads it off
  /// `data-frames` to prove idle costs nothing.
  int frames = 0;

  /// The stage's measured size in CSS pixels, written by the stage widget.
  double widthPx = 0;
  double heightPx = 0;

  bool _webGlAvailable = true;

  /// False once `McGl.create` returned null or the pack failed to load; the
  /// stage shows the still and the owning view can drop its 3D-only chrome.
  bool get webGlAvailable => _webGlAvailable;
  set webGlAvailable(bool value) {
    if (value == _webGlAvailable) return;
    _webGlAvailable = value;
    notifyListeners();
  }

  McCamera get camera => _camera;
  set camera(McCamera value) {
    if (value == _camera) return;
    _camera = value;
    notifyListeners();
  }

  /// Stages rebuild the whole scene every frame, so the setter takes the
  /// structural diff and stays quiet when the frame drew the same thing: a
  /// write from inside `build` then never re-enters `setState`.
  McScene get scene => _scene;
  set scene(McScene value) {
    final McScene previous = _scene;
    _scene = value;
    if (value.gridVisible == previous.gridVisible &&
        value.worldVisible == previous.worldVisible &&
        value.diff(previous).isEmpty) {
      return;
    }
    notifyListeners();
  }

  /// True while a stage clock is running, so the canvas keeps drawing.
  bool get animating => _animating;
  set animating(bool value) {
    if (value == _animating) return;
    _animating = value;
    notifyListeners();
  }

  McVec3 get homePivot => _homePivot;
  set homePivot(McVec3 value) {
    if (value == _homePivot) return;
    final bool wasHome = isHome;
    _homePivot = value;
    if (wasHome) _camera = mcCameraHome(kind, value);
    notifyListeners();
  }

  bool get isHome => _camera == mcCameraHome(kind, _homePivot);

  void resetCamera() => camera = mcCameraHome(kind, _homePivot);

  /// Wakes the stage after an out-of-band change (a pack image prefetched).
  void notify() => notifyListeners();
}
