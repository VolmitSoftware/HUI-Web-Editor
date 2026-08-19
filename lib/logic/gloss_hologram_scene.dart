/// DOM-free scene math for the hologram surface.
///
/// What the stage draws is what Gloss spawns: ONE unscaled `TextDisplay` at
/// the anchor with `Billboard.CENTER`, no shadow, not see-through and the
/// default background (`HologramService.configureDisplay`,
/// `HologramService.java:213-222`), holding every line joined with `\n`
/// (`PersistentHologram.refreshViewerText`, `PersistentHologram.java:414-420`).
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
/// which is exactly what `projectToScreen` returns.
library;

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
