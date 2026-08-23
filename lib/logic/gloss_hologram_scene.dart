/// DOM-free scene math for the hologram surface.
///
/// What the stage draws is what Gloss spawns: ONE unscaled `TextDisplay` at
/// the anchor with `Billboard.CENTER`, no shadow, not see-through and the
/// default background (`HologramService.configureDisplay`,
/// `HologramService.java:235-245`), holding every line joined with `\n`
/// (`PersistentHologram.composeViewerText`, `PersistentHologram.java:594-609`).
/// Gloss has no per-line spacing constants of its own — the stack metrics are
/// vanilla's `TextDisplay` glyph geometry, stated here once:
///
///  * one text pixel is 1/40 block (`VANILLA_TEXT_BLOCKS_PER_PIXEL`, the same
///    constant `hui_geometry.dart` builds on),
///  * a line advances 10 px — 8 px of glyph plus 1 px above and below — so
///    one line is 0.25 blocks tall at display scale 1,
///  * the text block sits bottom-anchored just above the entity position and
///    grows upward, with vanilla's default 0x40000000 background behind it.
///
/// A camera-facing billboard needs no 3D transform of its own: the anchor
/// projects to a screen point and the stack scales by `perspective/distance`,
/// which is exactly what `projectToScreen` returns. The other three
/// `Display.Billboard` modes do need one, and [hologramPlaneTransform] builds
/// it as a 2D affine matrix that is the identity for `CENTER`.
///
/// Handedness, once, because the cross products below look inverted next to a
/// textbook: points here are raw world coordinates, and `CameraBasis` derives
/// `right` as `up x forward`, which in world coordinates is the viewer's
/// LEFT. The stage's screen X therefore runs opposite the world's — invisible
/// while the grid is symmetric and the text always faces the camera. The
/// plane basis is built in that same frame, so the relationship the modes are
/// about (which side of the plane the camera is on, and whether the text
/// reads forwards or mirrored) comes out exact.
library;

import 'dart:math' as math;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import '../model/gloss_hologram.dart';
import '../preview/preview_types.dart';
import '../preview/projection.dart';
import 'gloss_text.dart';

/// Blocks per vanilla text pixel.
const double glossTextBlocksPerPixel = 1 / 40;

/// One `TextDisplay` text line, in blocks, at display scale 1: a 10 px
/// advance at 1/40 block per pixel.
const double glossHologramLineHeightBlocks = 10 * glossTextBlocksPerPixel;

/// `HologramMath.PAPER_VIEW_RANGE_BASE_BLOCKS` — the divisor behind
/// `setViewRange(viewRangeBlocks / 64)` (`HologramMath.java:6,11-13`). The
/// stage shows this only as a readout; the editor has no config viewRange.
const double glossHologramViewRangeBaseBlocks = 64;

/// Half-extent of the drawn ground grid, in blocks around the anchor.
const int glossHologramGridRadiusBlocks = 8;

/// Where the anchor lands on screen, and how large one block is there.
final class HologramBillboardPlacement {
  const HologramBillboardPlacement({
    required this.x,
    required this.y,
    required this.pxPerBlock,
    required this.distance,
  });

  /// Viewport pixels from the left / top.
  final double x;
  final double y;

  /// On-screen pixels per world block at the anchor's depth.
  final double pxPerBlock;

  /// Blocks in front of the camera.
  final double distance;
}

/// Projects the hologram anchor, or null while the camera looks away.
HologramBillboardPlacement? hologramBillboardPlacement({
  required CameraBasis basis,
  required GlossHologramAnchor anchor,
  required double viewportWidth,
  required double viewportHeight,
  double perspectivePx = huiPreviewPerspectivePx,
}) {
  final List<double> position = anchor.position;
  final ProjectedPoint? projected = projectToScreen(
    basis: basis,
    point: PVec3(position[0], position[1], position[2]),
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    perspectivePx: perspectivePx,
  );
  if (projected == null) return null;
  return HologramBillboardPlacement(
    x: projected.x,
    y: projected.y,
    pxPerBlock: perspectivePx / projected.distance,
    distance: projected.distance,
  );
}

/// One projected grid segment in viewport pixels.
final class HologramGridSegment {
  const HologramGridSegment({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.throughAnchor,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  /// The two lines crossing the anchor column, drawn stronger.
  final bool throughAnchor;
}

/// The ground grid: block lines on the anchor's Y level (holograms hang where
/// they are told — the grid marks that height, not sea level), snapped to
/// whole blocks around the anchor so the lines sit on world coordinates. A
/// segment with an endpoint at or behind the camera is dropped rather than
/// clipped; the orbit camera keeps that a corner case.
List<HologramGridSegment> hologramGroundSegments({
  required CameraBasis basis,
  required GlossHologramAnchor anchor,
  required double viewportWidth,
  required double viewportHeight,
  double perspectivePx = huiPreviewPerspectivePx,
  int radiusBlocks = glossHologramGridRadiusBlocks,
}) {
  final List<double> position = anchor.position;
  final double centerX = position[0].roundToDouble();
  final double y = position[1];
  final double centerZ = position[2].roundToDouble();

  ProjectedPoint? project(double x, double z) => projectToScreen(
    basis: basis,
    point: PVec3(x, y, z),
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    perspectivePx: perspectivePx,
  );

  final List<HologramGridSegment> segments = <HologramGridSegment>[];
  for (int offset = -radiusBlocks; offset <= radiusBlocks; offset++) {
    final ProjectedPoint? xStart = project(
      centerX + offset,
      centerZ - radiusBlocks,
    );
    final ProjectedPoint? xEnd = project(
      centerX + offset,
      centerZ + radiusBlocks,
    );
    if (xStart != null && xEnd != null) {
      segments.add(
        HologramGridSegment(
          x1: xStart.x,
          y1: xStart.y,
          x2: xEnd.x,
          y2: xEnd.y,
          throughAnchor: offset == 0,
        ),
      );
    }
    final ProjectedPoint? zStart = project(
      centerX - radiusBlocks,
      centerZ + offset,
    );
    final ProjectedPoint? zEnd = project(
      centerX + radiusBlocks,
      centerZ + offset,
    );
    if (zStart != null && zEnd != null) {
      segments.add(
        HologramGridSegment(
          x1: zStart.x,
          y1: zStart.y,
          x2: zEnd.x,
          y2: zEnd.y,
          throughAnchor: offset == 0,
        ),
      );
    }
  }
  return segments;
}

/// Offset used to read the plane's screen basis off [projectToScreen], in
/// blocks. Small enough that the finite difference stays a good reading of
/// the perspective quad, large enough to stay clear of float noise.
const double _planeProbeBlocks = 0.5;

/// Unit normal of a `TextDisplay`'s readable face for a Minecraft yaw/pitch
/// pair, in world coordinates: yaw 0 faces +Z (south) and is read from the
/// south, yaw 90 faces -X (west), and positive pitch tips the face downward.
///
/// This is Minecraft's own direction vector, NOT [huiLookDirection] — that
/// one negates X for the menu authoring frame, which does not apply to a
/// world-anchored hologram.
PVec3 glossDisplayNormal({
  required double yawDegrees,
  double pitchDegrees = 0,
}) {
  final double yaw = yawDegrees * math.pi / 180;
  final double pitch = pitchDegrees * math.pi / 180;
  final double cosPitch = math.cos(pitch);
  return PVec3(
    -cosPitch * math.sin(yaw),
    -math.sin(pitch),
    cosPitch * math.cos(yaw),
  );
}

/// The pose one billboard mode resolves to against one camera.
///
/// [yawDegrees] and [pitchDegrees] are the angles the face actually ends up
/// at; [tracksYaw] and [tracksPitch] say which of the two the client solves
/// per viewer instead of reading from the document, and are what the stage
/// admits it can only show for the camera it has.
final class HologramFacing {
  const HologramFacing({
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.tracksYaw,
    required this.tracksPitch,
  });

  final double yawDegrees;
  final double pitchDegrees;
  final bool tracksYaw;
  final bool tracksPitch;

  PVec3 get normal =>
      glossDisplayNormal(yawDegrees: yawDegrees, pitchDegrees: pitchDegrees);
}

/// Resolves [doc]'s billboard mode against [basis]: `CENTER` turns on both
/// axes, `VERTICAL` yaws only and keeps `pitch`, `HORIZONTAL` pitches only
/// and keeps `yaw`, `FIXED` turns on neither and is the only mode where both
/// document angles reach the screen.
///
/// An unknown mode string (which the plugin rejects outright — validation
/// already flags it) is treated as `CENTER` so the stage keeps drawing.
HologramFacing hologramFacing({
  required CameraBasis basis,
  required GlossHologramDoc doc,
}) {
  final List<double> position = doc.anchor.position;
  final PVec3 toCamera =
      (basis.position - PVec3(position[0], position[1], position[2]))
          .normalized;
  final double cameraYaw = toCamera.lengthSquared == 0
      ? doc.yaw
      : math.atan2(-toCamera.x, toCamera.z) * 180 / math.pi;
  final double cameraPitch = toCamera.lengthSquared == 0
      ? doc.pitch
      : -math.asin(toCamera.y.clamp(-1.0, 1.0)) * 180 / math.pi;
  final bool tracksYaw =
      doc.billboard != 'FIXED' && doc.billboard != 'HORIZONTAL';
  final bool tracksPitch =
      doc.billboard != 'FIXED' && doc.billboard != 'VERTICAL';
  return HologramFacing(
    yawDegrees: tracksYaw ? cameraYaw : doc.yaw,
    pitchDegrees: tracksPitch ? cameraPitch : doc.pitch,
    tracksYaw: tracksYaw,
    tracksPitch: tracksPitch,
  );
}

/// The drawn text plane as a css 2D matrix, normalised so that a face-on
/// plane is the identity.
///
/// The element is already sized in screen pixels per world block at the
/// anchor's depth, so this only has to say where the plane's own right and up
/// axes point on screen relative to that. `CENTER` therefore lands on
/// [identity] and the stage draws exactly what it drew before `billboard`
/// existed.
final class HologramPlaneTransform {
  const HologramPlaneTransform({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
  });

  /// `matrix(1, 0, 0, 1, 0, 0)`: the plane squarely facing the camera.
  static const HologramPlaneTransform identity = HologramPlaneTransform(
    a: 1,
    b: 0,
    c: 0,
    d: 1,
  );

  /// Screen delta per unit of the plane's own right axis.
  final double a;
  final double b;

  /// Screen delta per unit of the plane's own down axis (css y grows down).
  final double c;
  final double d;

  double get determinant => a * d - b * c;

  /// True when the camera is behind the face: the glyphs render mirrored,
  /// which is what a FIXED hologram really looks like from behind.
  bool get isMirrored => determinant < 0;

  /// How much of the face the camera actually sees, 1 square-on and 0 exactly
  /// edge-on.
  double get faceCoverage => determinant.abs().clamp(0.0, 1.0);

  /// Under a fiftieth of the face left: the stack collapses to a sliver and
  /// then to nothing. Not a limitation of the stage — an edge-on
  /// `TextDisplay` is invisible in game too — but the surface has to say so,
  /// because a blank stage otherwise reads as a broken document.
  bool get isEdgeOn => faceCoverage < 0.02;
}

/// Where the text plane lands on screen for [doc]'s billboard mode.
///
/// Read off [projectToScreen] as a finite difference over
/// [_planeProbeBlocks], so it is a first-order (affine) reading of a quad the
/// client draws with full perspective: correct in orientation, mirroring and
/// scale at the anchor, without per-pixel foreshortening across the face. A
/// probe that falls at or behind the camera gives [HologramPlaneTransform.identity]
/// rather than a garbage matrix.
HologramPlaneTransform hologramPlaneTransform({
  required CameraBasis basis,
  required GlossHologramDoc doc,
  required HologramBillboardPlacement placement,
  required double viewportWidth,
  required double viewportHeight,
  double perspectivePx = huiPreviewPerspectivePx,
}) {
  final List<double> position = doc.anchor.position;
  final PVec3 anchor = PVec3(position[0], position[1], position[2]);
  final HologramFacing facing = hologramFacing(basis: basis, doc: doc);
  final PVec3 normal = facing.normal;
  PVec3 right = normal.cross(PVec3.up);
  if (right.lengthSquared <= 1e-12) {
    // Straight up or straight down: the yaw alone still names a right axis,
    // and it is the one the roll-free basis converges to either side of the
    // pole.
    final double yaw = facing.yawDegrees * math.pi / 180;
    right = PVec3(-math.cos(yaw), 0, -math.sin(yaw));
  }
  right = right.normalized;
  final PVec3 up = right.cross(normal).normalized;

  ProjectedPoint? project(PVec3 point) => projectToScreen(
    basis: basis,
    point: point,
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    perspectivePx: perspectivePx,
  );

  final ProjectedPoint? origin = project(anchor);
  final ProjectedPoint? alongRight = project(
    anchor + right * _planeProbeBlocks,
  );
  final ProjectedPoint? alongUp = project(anchor + up * _planeProbeBlocks);
  if (origin == null || alongRight == null || alongUp == null) {
    return HologramPlaneTransform.identity;
  }

  final double unit = _planeProbeBlocks * placement.pxPerBlock;
  if (unit.abs() < 1e-9) return HologramPlaneTransform.identity;
  return HologramPlaneTransform(
    a: (alongRight.x - origin.x) / unit,
    b: (alongRight.y - origin.y) / unit,
    c: -(alongUp.x - origin.x) / unit,
    d: -(alongUp.y - origin.y) / unit,
  );
}

/// One clause for the stage readout: what the mode does, and what a single
/// camera cannot show about it.
///
/// The three tracking modes are solved here against the preview camera only.
/// In game the client re-solves them per viewer every frame, so two players
/// standing apart never see the same pose — a fixed frame can show one of
/// those poses, never the fact that they differ.
String hologramBillboardNote(String billboard) => switch (billboard) {
  'FIXED' => huiText(
    'billboard fixed · never turns; orbit behind it to read it mirrored',
  ),
  'VERTICAL' => huiText(
    'billboard vertical · yaws to each viewer, keeps its pitch; solved here '
    'for this camera only',
  ),
  'HORIZONTAL' => huiText(
    'billboard horizontal · pitches to each viewer, keeps its yaw; solved '
    'here for this camera only',
  ),
  'CENTER' => huiText(
    'billboard center · faces every viewer on both axes, so this camera '
    'stands in for all of them',
  ),
  _ => huiText(
    'billboard {billboard} is not a mode Gloss accepts; drawn as center',
    <String, Object?>{'billboard': billboard},
  ),
};

/// Every line rendered through the Gloss text pipeline at [nowMs], in
/// document order — index 0 is the TOP of the stack, exactly like the joined
/// `TextDisplay` string.
List<GlossLineRender> hologramRenderedLines(
  GlossHologramDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
}) => <GlossLineRender>[
  for (final String line in doc.lines)
    renderGlossLine(line, animations: animations, emoji: emoji, nowMs: nowMs),
];

/// True when any line plays an animation — the surface's ticker gate.
bool hologramIsAnimated(
  GlossHologramDoc doc,
  GlossAnimationResolver animations,
) {
  for (final String line in doc.lines) {
    if (renderGlossLine(line, animations: animations).isAnimated) return true;
  }
  return false;
}

/// The default orbit for a freshly opened hologram: pulled back far enough to
/// frame the stack and the grid, aimed at the middle of the line stack.
OrbitCamera hologramDefaultCamera(GlossHologramDoc doc) {
  final List<double> position = doc.anchor.position;
  final double stackHeight = doc.lines.length * glossHologramLineHeightBlocks;
  return OrbitCamera(
    target: PVec3(position[0], position[1] + stackHeight / 2, position[2]),
    yawDegrees: 180,
    pitchDegrees: -12,
    distance: 6,
  );
}

OrbitCamera reframeHologramCamera(
  OrbitCamera camera,
  PVec3 previousFocus,
  GlossHologramDoc doc,
) {
  final PVec3 nextFocus = hologramDefaultCamera(doc).target;
  return camera.copyWith(target: camera.target + nextFocus - previousFocus);
}
