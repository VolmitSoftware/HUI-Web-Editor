/// The menu lifted into three dimensions.
///
/// This module does exactly one thing the 2D canvas does not: it applies the
/// player anchor and the single frozen open-yaw rotation. Every measurement —
/// plane widths, visual extents, the item hitbox drop, the true-render bias —
/// comes from [buildCanvasScene] and `hui_geometry.dart` unchanged, because the
/// only way the two views can never disagree is if there is one layout pass.
///
/// Two things move at different rates and the difference is the point of the
/// preview:
///
///  * A [PreviewQuad] is **frozen**. Its position and its facing are fixed at
///    open by the player's yaw (`MenuSession.java:119-122`,
///    `MenuComponent.java:142-144`); billboarding is always FIXED
///    (`MenuIcon.java:112-114`). Nothing in this file takes a camera, so no
///    amount of orbiting can move a quad.
///  * A [PlaneAim] is rebuilt **every tick**, aimed at the player's eye
///    (`ClickableComponent.java:60-62`). [aimQuadPlane] and
///    [hoveredClickableIds] are the per-tick half.
library;

import '../logic/canvas_scene.dart';
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
    required this.facingYawDeg,
    required this.normal,
    required this.right,
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

  /// The player's yaw at open, frozen. Never re-aimed — billboarding is always
  /// FIXED (`MenuIcon.java:112-114`).
  ///
  /// The runtime only actually spawns *item* displays facing the player
  /// (`ItemMenuIcon.java:115-121` yaws them to `playerYaw + 180` once). Text and
  /// image displays are spawned at yaw 0 and never rotated: `MenuIcon.rotate`
  /// reaches them solely through `MenuSession.rotate`, which nothing calls. The
  /// preview faces every quad at the open yaw, which is what a builder means to
  /// author; see the T1.1 report for the divergence.
  final double facingYawDeg;

  /// Outward face of the quad: the reverse of the open look direction.
  final PVec3 normal;

  /// The quad's horizontal axis in the world; `up` is always +Y, since the one
  /// rotation the menu gets is about the vertical axis.
  final PVec3 right;

  /// Raw `highlightModifier`, unclamped, 0 for decorations. Gson bypasses the
  /// API's 0..1 clamp (`HoloComponent.java:33`), so a file may say anything.
  final double highlightModifier;

  String get id => item.id;

  /// Declaration index — the click dispatch order
  /// (`SessionHolder.java:145-159`).
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
  String toString() => 'PreviewQuad($id at $anchor, yaw $facingYawDeg)';
}

/// One resolved 3D frame.
class PreviewScene {
  PreviewScene({
    required this.quads,
    required this.canvas,
    required this.openFeet,
    required this.anchorFeet,
    required this.center,
    required this.sessionCenter,
    required this.menuOffset,
    required this.openYawDeg,
  });

  /// Declaration order, matching [CanvasScene.items].
  final List<PreviewQuad> quads;

  /// The 2D pass this was lifted from. Sprite lookup and hit testing on the
  /// canvas both read it, so it is kept rather than copied.
  final CanvasScene canvas;

  /// Where the player stood when the menu opened. The avatar marker and the
  /// ground anchor hang off this.
  final PVec3 openFeet;

  /// The feet the layout is currently pivoting on. Equal to [openFeet] unless
  /// `followPlayer` moved the centre, in which case the runtime re-derives
  /// every location from the player's *current* position
  /// (`MenuSession.java:103-109`).
  final PVec3 anchorFeet;

  /// Where the menu centre actually is once the frozen rotation has been
  /// applied — the point the centre marker marks, the camera frames, and the
  /// stage's menu group translates to. Every quad is this plus its own rotated
  /// component offset.
  final PVec3 center;

  /// The runtime's raw `centerPoint`: [anchorFeet] plus the unscaled menu
  /// offset, **before** the open-yaw rotation (`MenuSession.java:73,103-109`).
  /// Identical to the `currentCenter` this scene was built from.
  ///
  /// It is not where the menu draws, but it is what the range check compares
  /// against (`MenuSession.java:147-151`). The two distances agree, because the
  /// rotation pivots on the player, but the points do not.
  final PVec3 sessionCenter;

  /// The menu offset, never multiplied by uiScale (`HuiSettings.java:60-66`).
  final PVec3 menuOffset;

  /// The player's yaw at open, in degrees.
  final double openYawDeg;

  double get uiScale => canvas.uiScale;

  /// The frozen rotation, in radians (`initialY`, i.e. the negated yaw).
  late final double rotationRadians = huiOpenYawRadians(openYawDeg);

  late final List<PreviewQuad> clickables = List<PreviewQuad>.unmodifiable(
    quads.where((PreviewQuad quad) => quad.clickable),
  );

  bool get isEmpty => quads.isEmpty;

  /// First quad with this id. Duplicate ids all render, but only the first is
  /// addressable (`MenuSession.java:79` uses `putIfAbsent`).
  PreviewQuad? byId(String id) {
    for (final PreviewQuad quad in quads) {
      if (quad.id == id) return quad;
    }
    return null;
  }

  /// Lifts a canvas-space block point — menu-local, y up, z depth — into the
  /// world, applying the frozen rotation and the player anchor.
  ///
  /// Overlays and markers should go through this rather than re-deriving the
  /// rotation, which is how the 2D and 3D views stay in lockstep.
  PVec3 lift(double x, double y, double z) =>
      PVec3(x, y, z).rotateAroundY(PVec3.zero, rotationRadians) + anchorFeet;

  /// [lift] without the translation, for directions and extents.
  PVec3 liftDirection(PVec3 direction) =>
      direction.rotateAroundY(PVec3.zero, rotationRadians);

  @override
  String toString() =>
      'PreviewScene(${quads.length} quads, centre $center, yaw $openYawDeg)';
}

/// Builds the 3D frame.
///
/// [openFeet] is where the player stood at open; [openYawDeg] is the yaw they
/// had at that moment and the only rotation the menu will ever get.
/// [currentCenter] is the runtime's unrotated `centerPoint`
/// (`MenuSession.java:73,103-109`) — what the simulation computes per tick. It
/// defaults to `openFeet + menuOffset` and only differs while `followPlayer` is
/// walking the menu around; the pivot is derived back out of it exactly as the
/// runtime does with `getCenterNoOffset()` (`MenuSession.java:138-140`). Read
/// [PreviewScene.center] for where the menu actually draws.
///
/// Supply [canvas] when one has already been built for this menu and scale —
/// the 3D stage needs its [CanvasItem]s for sprites anyway, and rebuilding it
/// would re-parse every string. Without it, one is built here from the
/// remaining parameters.
PreviewScene buildPreviewScene({
  required HuiMenu menu,
  required double uiScale,
  required PVec3 openFeet,
  required double openYawDeg,
  PVec3? currentCenter,
  CanvasScene? canvas,
  bool trueRender = false,
  bool Function(String id)? togglePreview,
  McTextCache? textCache,
  ImageLibrary? images,
  HuiCatalogs? catalogs,
  ImageCharCache? charCache,
  int animationTicks = 0,
}) {
  assert(
    canvas == null || canvas.uiScale == uiScale,
    'a supplied canvas scene must have been built at the same uiScale',
  );
  final CanvasScene resolved = canvas ??
      buildCanvasScene(
        menu: menu,
        uiScale: uiScale,
        trueRender: trueRender,
        togglePreview: togglePreview ?? (String _) => true,
        textCache: textCache ?? McTextCache(),
        images: images,
        catalogs: catalogs,
        charCache: charCache,
        animationTicks: animationTicks,
      );

  // Read the offset off the scene, not the menu: it is the one that was baked
  // into every item anchor, so the pivot can never drift from the layout.
  final Vec3 offset = resolved.menuOffset;
  final PVec3 menuOffset = PVec3(offset.x, offset.y, offset.z);
  final PVec3 sessionCenter = currentCenter ?? (openFeet + menuOffset);
  final PVec3 anchorFeet = sessionCenter - menuOffset;
  final double angle = huiOpenYawRadians(openYawDeg);
  final PVec3 normal = -huiLookDirection(yawDegrees: openYawDeg);
  final PVec3 right = PVec3.right.rotateAroundY(PVec3.zero, angle);

  PVec3 lift(double x, double y, double z) =>
      PVec3(x, y, z).rotateAroundY(PVec3.zero, angle) + anchorFeet;

  final List<PreviewQuad> quads = <PreviewQuad>[
    for (final CanvasItem item in resolved.items)
      PreviewQuad(
        item: item,
        anchor: lift(item.anchor.x, item.anchor.y, item.depth),
        planeCenter: lift(item.hitbox.x, item.hitbox.y, item.depth),
        visualCenter: lift(item.visual.x, item.visual.y, item.depth),
        facingYawDeg: openYawDeg,
        normal: normal,
        right: right,
        highlightModifier: _highlightModifier(item.component.data),
      ),
  ];

  return PreviewScene(
    quads: List<PreviewQuad>.unmodifiable(quads),
    canvas: resolved,
    openFeet: openFeet,
    anchorFeet: anchorFeet,
    center: lift(menuOffset.x, menuOffset.y, menuOffset.z),
    sessionCenter: sessionCenter,
    menuOffset: menuOffset,
    openYawDeg: openYawDeg,
  );
}

/// The quad's collision plane, re-aimed at [eye] for this tick.
PlaneAim aimQuadPlane(PreviewQuad quad, PVec3 eye) =>
    aimPlaneAt(quad.planeCenter, eye);

/// Every clickable the look ray is currently inside, in declaration order.
///
/// This is one tick of `ClickableComponent.onTick` for the whole menu: re-aim
/// each plane at the eye, then hit-test (`ClickableComponent.java:59-70`).
/// Declaration order matters because a click fires all of them in that order
/// (`SessionHolder.java:145-159`), and decorations are excluded because they
/// never build a plane at all (`MenuComponent.java:62-67`).
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

/// Decorations have no highlight of any kind; both clickable types carry a raw,
/// unclamped modifier.
double _highlightModifier(HuiComponentData data) => switch (data) {
      HuiButtonData() => data.highlightModifier,
      HuiToggleData() => data.highlightModifier,
      HuiDecorationData() => 0,
    };
