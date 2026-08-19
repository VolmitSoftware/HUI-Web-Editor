/// The menu lifted into three dimensions.
///
/// This module does exactly one thing the 2D canvas does not: it applies the
/// current menu transform and each icon's billboard mode. Every measurement —
/// plane widths, visual extents, the item hitbox drop, the true-render bias —
/// comes from [buildCanvasScene] and `hui_geometry.dart` unchanged, because the
/// only way the two views can never disagree is if there is one layout pass.
///
/// Two things move at different rates and the difference is the point of the
/// preview:
///
///  * A [PreviewQuad] carries the fixed menu transform. A static personal menu
///    keeps that transform from open; `followPlayer` replaces its anchor and
///    facing yaw as the player moves or looks.
///  * [aimQuadPlane] applies the icon's `fixed`, `vertical`, `horizontal`, or
///    `center` billboard rule for the current viewer. The visual and collision
///    plane use the same rule.
library;

import '../logic/canvas_scene.dart';
import '../logic/gloss_text.dart' show GlossEmojiResolver, GlossNoEmoji;
import '../model/model.dart';
import '../services/catalogs.dart';
import '../services/image_library.dart';
import 'preview_types.dart';
import 'projection.dart';

/// One component as a flat, axis-aligned quad in the world.
class PreviewQuad {
  const PreviewQuad({
    required this.item,
    required this.anchor,
    required this.planeCenter,
    required this.visualCenter,
    required this.fixedPlane,
    required this.billboard,
    required this.highlightModifier,
  });

  /// The resolved 2D item: icon kind, sprite inputs, measured rectangles.
  final CanvasItem item;

  /// World position of the component anchor — the plugin's `location`.
  final PVec3 anchor;

  /// Centre of the collision plane. Items drop `0.05 × uiScale` below the
  /// anchor (`ItemMenuIcon.java:74-77`); everything else sits on it.
  final PVec3 planeCenter;

  /// Centre of the drawn icon. Equal to [anchor] unless the scene was built
  /// with `trueRender`, which reproduces the in-game vertical bias.
  final PVec3 visualCenter;

  /// The menu-transformed collision plane before client billboarding.
  final PlaneAim fixedPlane;

  /// Runtime display metadata: fixed, vertical, horizontal, or center.
  final String billboard;

  /// Raw `highlightModifier`, unclamped, 0 for decorations. Gson bypasses the
  /// API's 0..1 clamp (`HoloComponent.java:33`), so a file may say anything.
  final double highlightModifier;

  String get id => item.id;

  /// Declaration index, used as the tie-break when planes are equally near.
  int get index => item.index;

  bool get clickable => item.clickable;

  double get planeWidth => item.hitbox.w;

  double get planeHeight => item.hitbox.h;

  double get visualWidth => item.visual.w;

  double get visualHeight => item.visual.h;

  /// True when the plugin would build a plane at all: a zero-size rectangle can
  /// never be hit (`CollisionPlane.java:53`).
  bool get hasPlane => clickable && planeWidth > 0 && planeHeight > 0;

  @override
  String toString() => 'PreviewQuad($id at $anchor, $billboard)';
}

/// One resolved 3D frame.
class PreviewScene {
  PreviewScene({
    required this.quads,
    required this.canvas,
    required this.openFeet,
    required this.anchorFeet,
    required this.center,
    required this.menuOffset,
    required this.openYawDeg,
    required this.facingYawDeg,
    required this.pitchDeg,
    required this.rollDeg,
  });

  /// Declaration order, matching [CanvasScene.items].
  final List<PreviewQuad> quads;

  /// The 2D pass this was lifted from. Sprite lookup and hit testing on the
  /// canvas both read it, so it is kept rather than copied.
  final CanvasScene canvas;

  /// Where the player stood when the menu opened. The avatar marker and the
  /// ground anchor hang off this.
  final PVec3 openFeet;

  final double openYawDeg;

  /// The feet the layout is currently pivoting on. Equal to [openFeet] unless
  /// `followPlayer` moved the transform anchor.
  final PVec3 anchorFeet;

  /// The transformed menu origin used for drawing and max-distance checks.
  final PVec3 center;

  /// The menu offset, never multiplied by uiScale (`HuiSettings.java:60-66`).
  final PVec3 menuOffset;

  final double facingYawDeg;
  final double pitchDeg;
  final double rollDeg;

  double get uiScale => canvas.uiScale;

  late final List<PreviewQuad> clickables = List<PreviewQuad>.unmodifiable(
    quads.where((PreviewQuad quad) => quad.clickable),
  );

  bool get isEmpty => quads.isEmpty;

  /// The quad with this id. Scene construction applies the runtime's first-wins
  /// component rule, so a duplicated id has only one quad.
  PreviewQuad? byId(String id) {
    for (final PreviewQuad quad in quads) {
      if (quad.id == id) return quad;
    }
    return null;
  }

  /// Lifts a canvas-space block point — menu-local, y up, z depth — into the
  /// world, applying the current menu transform and player anchor.
  ///
  /// Overlays and markers should go through this rather than re-deriving the
  /// rotation, which is how the 2D and 3D views stay in lockstep.
  PVec3 lift(double x, double y, double z) =>
      liftDirection(PVec3(x, y, z)) + anchorFeet;

  /// [lift] without the translation, for directions and extents.
  PVec3 liftDirection(PVec3 direction) => huiMenuVector(
    direction,
    facingYawDegrees: facingYawDeg,
    pitchDegrees: pitchDeg,
    rollDegrees: rollDeg,
  );

  @override
  String toString() =>
      'PreviewScene(${quads.length} quads, centre $center, yaw $facingYawDeg)';
}

/// Builds the 3D frame.
///
/// [openFeet] is where the player stood at open. [anchorFeet] and
/// [facingYawDeg] are the current runtime transform; they change together when
/// `followPlayer` handles player movement or look rotation. Personal menu JSON
/// has no pitch or roll, so both default to zero; the parameters keep the core
/// transform accurate for positioned menu previews.
///
/// Supply [canvas] when one has already been built for this menu and scale —
/// the 3D stage needs its [CanvasItem]s for sprites anyway, and rebuilding it
/// would re-parse every string. Without it, one is built here from the
/// remaining parameters.
PreviewScene buildPreviewScene({
  required HuiMenu menu,
  required double uiScale,
  required PVec3 openFeet,
  required double facingYawDeg,
  double? openYawDeg,
  PVec3? anchorFeet,
  double pitchDeg = 0,
  double rollDeg = 0,
  CanvasScene? canvas,
  bool trueRender = false,
  bool Function(String id)? togglePreview,
  McTextCache? textCache,
  ImageLibrary? images,
  HuiCatalogs? catalogs,
  ImageCharCache? charCache,
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int animationTicks = 0,
}) {
  assert(
    canvas == null || canvas.uiScale == uiScale,
    'a supplied canvas scene must have been built at the same uiScale',
  );
  final CanvasScene resolved =
      canvas ??
      buildCanvasScene(
        menu: menu,
        uiScale: uiScale,
        trueRender: trueRender,
        togglePreview: togglePreview ?? (String _) => true,
        textCache: textCache ?? McTextCache(),
        images: images,
        catalogs: catalogs,
        charCache: charCache,
        emoji: emoji,
        animationTicks: animationTicks,
      );

  // Read the offset off the scene, not the menu: it is the one that was baked
  // into every item anchor, so the pivot can never drift from the layout.
  final Vec3 offset = resolved.menuOffset;
  final PVec3 menuOffset = PVec3(offset.x, offset.y, offset.z);
  final PVec3 resolvedAnchorFeet = anchorFeet ?? openFeet;

  PVec3 lift(double x, double y, double z) =>
      huiMenuVector(
        PVec3(x, y, z),
        facingYawDegrees: facingYawDeg,
        pitchDegrees: pitchDeg,
        rollDegrees: rollDeg,
      ) +
      resolvedAnchorFeet;

  final List<PreviewQuad> quads = <PreviewQuad>[];
  final Set<String> componentIds = <String>{};
  for (final CanvasItem item in resolved.items) {
    if (!componentIds.add(item.id)) continue;
    quads.add(
      PreviewQuad(
        item: item,
        anchor: lift(item.anchor.x, item.anchor.y, item.depth),
        planeCenter: lift(item.hitbox.x, item.hitbox.y, item.hitboxDepth),
        visualCenter: lift(item.visual.x, item.visual.y, item.depth),
        fixedPlane: fixedMenuPlane(
          center: lift(item.hitbox.x, item.hitbox.y, item.hitboxDepth),
          facingYawDegrees: facingYawDeg,
          pitchDegrees: pitchDeg,
          rollDegrees: rollDeg,
        ),
        billboard: item.icon?.style?.billboard ?? 'fixed',
        highlightModifier: _highlightModifier(item.component.data),
      ),
    );
  }

  return PreviewScene(
    quads: List<PreviewQuad>.unmodifiable(quads),
    canvas: resolved,
    openFeet: openFeet,
    anchorFeet: resolvedAnchorFeet,
    center: lift(menuOffset.x, menuOffset.y, menuOffset.z),
    menuOffset: menuOffset,
    openYawDeg: openYawDeg ?? facingYawDeg,
    facingYawDeg: facingYawDeg,
    pitchDeg: pitchDeg,
    rollDeg: rollDeg,
  );
}

PlaneAim aimQuadPlane(PreviewQuad quad, PVec3 eye) => orientBillboardPlane(
  fixed: quad.fixedPlane,
  billboard: quad.billboard,
  viewer: eye,
);

PlaneAim aimQuadVisual(PreviewQuad quad, PVec3 center, PVec3 eye) =>
    orientBillboardPlane(
      fixed: movePlane(quad.fixedPlane, center),
      billboard: quad.billboard,
      viewer: eye,
    );

/// Every clickable the look ray is currently inside, in declaration order.
///
/// This is one tick of `ClickableComponent.onTick` for the whole menu: apply
/// each icon's billboard rule, then hit-test (`ClickableComponent.java:59-70`).
/// Decorations are excluded because they never build a plane at all.
List<String> hoveredClickableIds({
  required PreviewScene scene,
  required LookRay ray,
  required PVec3 eye,
}) {
  final List<String> hovered = <String>[];
  for (final PreviewQuad quad in scene.quads) {
    if (!quad.hasPlane) continue;
    if (rayHitsPlane(
      ray,
      aimQuadPlane(quad, eye),
      quad.planeWidth,
      quad.planeHeight,
    )) {
      hovered.add(quad.id);
    }
  }
  return hovered;
}

String? nearestClickableId({
  required PreviewScene scene,
  required LookRay ray,
  required PVec3 eye,
}) {
  String? nearest;
  double nearestDistance = double.infinity;
  for (final PreviewQuad quad in scene.quads) {
    if (!quad.hasPlane) continue;
    final double? distance = rayPlaneIntersectionDistance(
      ray,
      aimQuadPlane(quad, eye),
      quad.planeWidth,
      quad.planeHeight,
    );
    if (distance != null && distance < nearestDistance) {
      nearest = quad.id;
      nearestDistance = distance;
    }
  }
  return nearest;
}

/// Decorations have no highlight of any kind; both clickable types carry a raw,
/// unclamped modifier.
double _highlightModifier(HuiComponentData data) => switch (data) {
  HuiButtonData() => data.highlightModifier,
  HuiToggleData() => data.highlightModifier,
  HuiDecorationData() => 0,
};
