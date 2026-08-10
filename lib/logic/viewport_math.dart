/// Pure viewport transform math for the HoloUI canvas.
///
/// World frame: Minecraft block space as authored in a menu file.
/// `x` grows to the player's right, `y` grows UP (0 = the player's feet),
/// `z` is depth away from the camera and is not part of the 2-D mapping.
///
/// Screen frame: CSS pixels measured from the canvas element's top-left,
/// `y` growing DOWN. Every mapping here therefore flips the y axis.
///
/// Nothing in this library touches the DOM or the model layer; it is imported
/// by tests and by the canvas renderer alike.
library;

import 'dart:math' as math;

/// Hard zoom range. `zoom` is a unitless multiplier applied on top of
/// [HuiViewport.basePixelsPerBlock].
const double huiMinZoom = 0.2;
const double huiMaxZoom = 20.0;

/// CSS pixels per block at `zoom == 1`. A default menu spans roughly two
/// blocks, so this shows a comfortable working area on a typical canvas.
const double huiDefaultPixelsPerBlock = 120.0;

/// Wheel curve: `factor = exp(-deltaY * sensitivity)` (anim-al's shadowbox
/// viewport uses the same constant, so the feel matches across the two apps).
const double huiWheelZoomSensitivity = 0.0015;

/// `WheelEvent.deltaMode == 1` reports lines; this converts a line to pixels.
const double huiWheelLinePixels = 16.0;

/// How far the world point under the canvas centre may travel from the world
/// origin, in blocks. Keeps the menu from being panned into nowhere.
const double huiPanLimitBlocks = 256.0;

/// Guard against divide-by-zero when the canvas has not been laid out yet.
const double _minPixelsPerBlock = 1e-6;

/// A point in screen space: CSS pixels from the canvas top-left, y down.
class ScreenPoint {
  final double x;
  final double y;

  const ScreenPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is ScreenPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ScreenPoint($x, $y)';
}

/// A point in world space: blocks, y up.
class WorldPoint {
  final double x;
  final double y;

  const WorldPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is WorldPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'WorldPoint($x, $y)';
}

/// An axis-aligned world-space rectangle expressed by its edges, y up.
class WorldBounds {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const WorldBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  double get width => maxX - minX;

  double get height => maxY - minY;

  double get centerX => (minX + maxX) / 2;

  double get centerY => (minY + maxY) / 2;

  WorldBounds expand(double blocks) => WorldBounds(
    minX: minX - blocks,
    minY: minY - blocks,
    maxX: maxX + blocks,
    maxY: maxY + blocks,
  );

  WorldBounds union(WorldBounds other) => WorldBounds(
    minX: math.min(minX, other.minX),
    minY: math.min(minY, other.minY),
    maxX: math.max(maxX, other.maxX),
    maxY: math.max(maxY, other.maxY),
  );

  @override
  bool operator ==(Object other) =>
      other is WorldBounds &&
      other.minX == minX &&
      other.minY == minY &&
      other.maxX == maxX &&
      other.maxY == maxY;

  @override
  int get hashCode => Object.hash(minX, minY, maxX, maxY);

  @override
  String toString() => 'WorldBounds($minX, $minY, $maxX, $maxY)';
}

/// Zoom + pan of the canvas. Pan is stored in CSS pixels relative to the canvas
/// centre, matching the anchor-preserving zoom formula below.
class CanvasTransform {
  final double zoom;
  final double panX;
  final double panY;

  const CanvasTransform({this.zoom = 1.0, this.panX = 0.0, this.panY = 0.0});

  static const CanvasTransform identity = CanvasTransform();

  CanvasTransform copyWith({double? zoom, double? panX, double? panY}) =>
      CanvasTransform(
        zoom: zoom ?? this.zoom,
        panX: panX ?? this.panX,
        panY: panY ?? this.panY,
      );

  /// Translate by a screen-pixel delta (drag-to-pan).
  CanvasTransform panBy(double dx, double dy) =>
      CanvasTransform(zoom: zoom, panX: panX + dx, panY: panY + dy);

  /// Clamp zoom into [minZoom]..[maxZoom] and pan into +/- the given limits.
  CanvasTransform clamp({
    double minZoom = huiMinZoom,
    double maxZoom = huiMaxZoom,
    double maxPanX = double.infinity,
    double maxPanY = double.infinity,
  }) => CanvasTransform(
    zoom: clampZoom(zoom, minZoom: minZoom, maxZoom: maxZoom),
    panX: _clampAbs(panX, maxPanX),
    panY: _clampAbs(panY, maxPanY),
  );

  /// Zoom so that the world point currently under ([anchorX], [anchorY]) stays
  /// under it. Anchor coordinates are CSS pixels relative to the canvas CENTRE
  /// (`clientX - rect.left - rect.width / 2`), y down.
  CanvasTransform zoomAtPoint({
    required double requestedZoom,
    required double anchorX,
    required double anchorY,
    double minZoom = huiMinZoom,
    double maxZoom = huiMaxZoom,
    double maxPanX = double.infinity,
    double maxPanY = double.infinity,
  }) {
    final double oldZoom = clampZoom(zoom, minZoom: minZoom, maxZoom: maxZoom);
    final double nextZoom = clampZoom(
      requestedZoom,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    if (oldZoom <= 0) {
      return CanvasTransform(zoom: nextZoom, panX: panX, panY: panY).clamp(
        minZoom: minZoom,
        maxZoom: maxZoom,
        maxPanX: maxPanX,
        maxPanY: maxPanY,
      );
    }
    final double ratio = nextZoom / oldZoom;
    return CanvasTransform(
      zoom: nextZoom,
      panX: anchorX - (anchorX - panX) * ratio,
      panY: anchorY - (anchorY - panY) * ratio,
    ).clamp(
      minZoom: minZoom,
      maxZoom: maxZoom,
      maxPanX: maxPanX,
      maxPanY: maxPanY,
    );
  }

  /// Multiply the current zoom, keeping the anchor stationary.
  CanvasTransform zoomByAtPoint({
    required double factor,
    required double anchorX,
    required double anchorY,
    double minZoom = huiMinZoom,
    double maxZoom = huiMaxZoom,
    double maxPanX = double.infinity,
    double maxPanY = double.infinity,
  }) => zoomAtPoint(
    requestedZoom: zoom * factor,
    anchorX: anchorX,
    anchorY: anchorY,
    minZoom: minZoom,
    maxZoom: maxZoom,
    maxPanX: maxPanX,
    maxPanY: maxPanY,
  );

  @override
  bool operator ==(Object other) =>
      other is CanvasTransform &&
      other.zoom == zoom &&
      other.panX == panX &&
      other.panY == panY;

  @override
  int get hashCode => Object.hash(zoom, panX, panY);

  @override
  String toString() => 'CanvasTransform(zoom: $zoom, panX: $panX, panY: $panY)';
}

double clampZoom(
  double zoom, {
  double minZoom = huiMinZoom,
  double maxZoom = huiMaxZoom,
}) {
  if (zoom.isNaN) {
    return minZoom;
  }
  return math.min(math.max(zoom, minZoom), maxZoom);
}

double _clampAbs(double value, double limit) {
  if (value.isNaN) {
    return 0;
  }
  if (!limit.isFinite) {
    return value;
  }
  final double bound = limit.abs();
  return math.min(math.max(value, -bound), bound);
}

/// Exponential wheel curve with `WheelEvent.deltaMode` normalisation.
/// Pass the raw `deltaY`; a negative delta (scroll up) zooms in.
double wheelZoomFactor(
  double deltaY, {
  int deltaMode = 0,
  double linePixels = huiWheelLinePixels,
  double pagePixels = 800.0,
  double sensitivity = huiWheelZoomSensitivity,
}) {
  double delta = deltaY;
  if (deltaMode == 1) {
    delta *= linePixels;
  } else if (deltaMode == 2) {
    delta *= pagePixels;
  }
  return math.exp(-delta * sensitivity);
}

/// Maps block space to canvas pixels honouring zoom, pan and device pixel
/// ratio. Immutable: every mutating helper returns a new viewport.
class HuiViewport {
  /// CSS pixel size of the canvas element.
  final double widthPx;
  final double heightPx;

  /// `window.devicePixelRatio` used to size the canvas backing store.
  final double devicePixelRatio;

  /// CSS pixels per block at `zoom == 1`.
  final double basePixelsPerBlock;

  final CanvasTransform transform;

  const HuiViewport({
    required this.widthPx,
    required this.heightPx,
    this.devicePixelRatio = 1.0,
    this.basePixelsPerBlock = huiDefaultPixelsPerBlock,
    this.transform = CanvasTransform.identity,
  });

  double get zoom => transform.zoom;

  /// CSS pixels per block at the current zoom.
  double get pixelsPerBlock {
    final double value = basePixelsPerBlock * transform.zoom;
    return value.isFinite && value > _minPixelsPerBlock
        ? value
        : _minPixelsPerBlock;
  }

  /// Backing-store pixels per block (use when drawing without `ctx.scale`).
  double get devicePixelsPerBlock => pixelsPerBlock * devicePixelRatio;

  /// Backing store size: assign these to `canvas.width` / `canvas.height`.
  double get backingWidthPx => widthPx * devicePixelRatio;

  double get backingHeightPx => heightPx * devicePixelRatio;

  /// Screen position of world x = 0 / y = 0.
  double get originX => widthPx / 2 + transform.panX;

  double get originY => heightPx / 2 + transform.panY;

  double worldToScreenX(double blockX) => originX + blockX * pixelsPerBlock;

  double worldToScreenY(double blockY) => originY - blockY * pixelsPerBlock;

  ScreenPoint worldToScreen(double blockX, double blockY) =>
      ScreenPoint(worldToScreenX(blockX), worldToScreenY(blockY));

  /// Same as [worldToScreen] but in backing-store pixels.
  ScreenPoint worldToDevice(double blockX, double blockY) => ScreenPoint(
    worldToScreenX(blockX) * devicePixelRatio,
    worldToScreenY(blockY) * devicePixelRatio,
  );

  double screenToWorldX(double screenX) => (screenX - originX) / pixelsPerBlock;

  double screenToWorldY(double screenY) => (originY - screenY) / pixelsPerBlock;

  WorldPoint screenToWorld(double screenX, double screenY) =>
      WorldPoint(screenToWorldX(screenX), screenToWorldY(screenY));

  double blocksToPixels(double blocks) => blocks * pixelsPerBlock;

  double pixelsToBlocks(double pixels) => pixels / pixelsPerBlock;

  /// World rectangle currently covered by the canvas (grid culling).
  WorldBounds get visibleWorld => WorldBounds(
    minX: screenToWorldX(0),
    minY: screenToWorldY(heightPx),
    maxX: screenToWorldX(widthPx),
    maxY: screenToWorldY(0),
  );

  /// Pan limit in CSS pixels for the current zoom.
  double get maxPanPixels => huiPanLimitBlocks * pixelsPerBlock;

  HuiViewport withTransform(CanvasTransform next) => HuiViewport(
    widthPx: widthPx,
    heightPx: heightPx,
    devicePixelRatio: devicePixelRatio,
    basePixelsPerBlock: basePixelsPerBlock,
    transform: next,
  );

  HuiViewport resized({
    required double widthPx,
    required double heightPx,
    double? devicePixelRatio,
  }) => HuiViewport(
    widthPx: widthPx,
    heightPx: heightPx,
    devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    basePixelsPerBlock: basePixelsPerBlock,
    transform: transform,
  );

  HuiViewport panByPixels(double dx, double dy) => withTransform(
    transform.panBy(dx, dy).clamp(maxPanX: maxPanPixels, maxPanY: maxPanPixels),
  );

  /// Zoom keeping the world point under a canvas-local pixel stationary.
  /// [screenX] / [screenY] are CSS pixels from the canvas top-left.
  HuiViewport zoomAtScreenPoint({
    required double requestedZoom,
    required double screenX,
    required double screenY,
  }) {
    final CanvasTransform next = transform.zoomAtPoint(
      requestedZoom: requestedZoom,
      anchorX: screenX - widthPx / 2,
      anchorY: screenY - heightPx / 2,
    );
    return withTransform(
      next.clamp(
        maxPanX: huiPanLimitBlocks * basePixelsPerBlock * next.zoom,
        maxPanY: huiPanLimitBlocks * basePixelsPerBlock * next.zoom,
      ),
    );
  }

  HuiViewport zoomByAtScreenPoint({
    required double factor,
    required double screenX,
    required double screenY,
  }) => zoomAtScreenPoint(
    requestedZoom: transform.zoom * factor,
    screenX: screenX,
    screenY: screenY,
  );

  /// Zoom about the canvas centre (toolbar buttons, keyboard `+` / `-`).
  HuiViewport zoomAtCenter(double requestedZoom) => zoomAtScreenPoint(
    requestedZoom: requestedZoom,
    screenX: widthPx / 2,
    screenY: heightPx / 2,
  );

  HuiViewport zoomByAtCenter(double factor) =>
      zoomAtCenter(transform.zoom * factor);

  /// Fit [bounds] into the canvas with [paddingPx] of breathing room and centre
  /// it. Degenerate (zero-size) bounds keep the current zoom.
  HuiViewport zoomToFit(WorldBounds bounds, {double paddingPx = 32}) {
    final double availableWidth = math.max(
      widthPx - paddingPx * 2,
      _minPixelsPerBlock,
    );
    final double availableHeight = math.max(
      heightPx - paddingPx * 2,
      _minPixelsPerBlock,
    );
    final double base = basePixelsPerBlock > 0
        ? basePixelsPerBlock
        : huiDefaultPixelsPerBlock;
    double target = transform.zoom;
    if (bounds.width > 0 && bounds.height > 0) {
      target = math.min(
        availableWidth / (bounds.width * base),
        availableHeight / (bounds.height * base),
      );
    } else if (bounds.width > 0) {
      target = availableWidth / (bounds.width * base);
    } else if (bounds.height > 0) {
      target = availableHeight / (bounds.height * base);
    }
    final double nextZoom = clampZoom(target);
    final double scale = base * nextZoom;
    return withTransform(
      CanvasTransform(
        zoom: nextZoom,
        panX: -bounds.centerX * scale,
        panY: bounds.centerY * scale,
      ).clamp(
        maxPanX: huiPanLimitBlocks * scale,
        maxPanY: huiPanLimitBlocks * scale,
      ),
    );
  }

  /// Centre a world point without changing the zoom.
  HuiViewport centerOn(double blockX, double blockY) => withTransform(
    CanvasTransform(
      zoom: transform.zoom,
      panX: -blockX * pixelsPerBlock,
      panY: blockY * pixelsPerBlock,
    ).clamp(maxPanX: maxPanPixels, maxPanY: maxPanPixels),
  );

  HuiViewport reset() => withTransform(CanvasTransform.identity);

  @override
  bool operator ==(Object other) =>
      other is HuiViewport &&
      other.widthPx == widthPx &&
      other.heightPx == heightPx &&
      other.devicePixelRatio == devicePixelRatio &&
      other.basePixelsPerBlock == basePixelsPerBlock &&
      other.transform == transform;

  @override
  int get hashCode => Object.hash(
    widthPx,
    heightPx,
    devicePixelRatio,
    basePixelsPerBlock,
    transform,
  );

  @override
  String toString() =>
      'HuiViewport(${widthPx}x$heightPx @${devicePixelRatio}x, $transform)';
}
