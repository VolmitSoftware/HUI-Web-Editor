/// Everything the pixel-space card editor does that does not need a `<canvas>`.
///
/// The surface in `lib/components/preview_card/` owns the DOM, the pointer
/// events and the paint; the mapping between screen and card pixels, the hit
/// model, and every write a gesture is allowed to make live here so they can be
/// exercised on the VM. Same split as [canvas_scene.dart](canvas_scene.dart) and
/// [multi_select.dart](multi_select.dart) hold for the component editor.
///
/// Coordinates follow the document's own convention throughout: card pixels,
/// origin at the card centre, `y` growing UPWARDS — exactly what
/// [PreviewCardScene] carries. Only [PreviewCardView] knows about screen pixels
/// and their downward `y`.
///
/// DOM-free: pure logic, runs on the VM under `dart test`.
library;

import 'dart:math' as math;

import '../model/preview_doc.dart';
import 'mc_text.dart';
import 'preview_card_scene.dart';
import 'preview_expr.dart';
import 'preview_sim.dart';

/// Advance of one Minecraft glyph in card pixels: a 5 px glyph plus its 1 px
/// gap.
///
/// The same number `huiGlyphAdvancePixels`
/// (`lib/components/render/icon_renderers.dart`) carries for the component
/// canvas, declared again here rather than imported because that file imports
/// `package:web` and this pass has to stay DOM-free. A label's real width is
/// measured against the loaded font by the painter and handed back in; this is
/// what the hit model falls back to before the first paint.
const int previewGlyphAdvancePx = 6;

/// `CardFramer`'s line box: the height one label occupies.
const int previewLabelLineHeightPx = 12;

/// Integer scale factors the surface zooms through.
///
/// Integers only, and never interpolated: the card is authored in whole pixels
/// and a fractional scale turns an 18 px well into a smeared 18.4 px one. The
/// stops thin out as they grow because a step from 12x to 13x is not worth a
/// notch of the wheel.
const List<int> previewZoomStops = <int>[1, 2, 3, 4, 6, 8, 12, 16];

/// Where a fresh surface starts: an 18 px well reads as a 72 px control, which
/// is about the size the same well occupies on a real Minecraft screen.
const int previewDefaultZoom = 4;

/// Shown when a drag is refused because the model would have to be rewritten as
/// a constant to accept it.
const String previewExpressionMoveHint =
    'This element is positioned by an expression - edit x/y in the inspector';

const String previewExpressionResizeHint =
    'This element is sized by an expression - edit it in the inspector';

/// A label has no authored extent at all: `PreviewElement.Label` carries no
/// size and the parser compiles none, so there is nothing for a handle to
/// write.
const String previewNoResizeHint = 'A label has no size to drag';

int previewClampZoom(int zoom) =>
    zoom.clamp(previewZoomStops.first, previewZoomStops.last).toInt();

/// The next stop above [zoom], or [zoom] itself at the top.
int previewZoomIn(int zoom) {
  for (final int stop in previewZoomStops) {
    if (stop > zoom) return stop;
  }
  return previewZoomStops.last;
}

int previewZoomOut(int zoom) {
  for (int i = previewZoomStops.length - 1; i >= 0; i--) {
    if (previewZoomStops[i] < zoom) return previewZoomStops[i];
  }
  return previewZoomStops.first;
}

// ---------------------------------------------------------------------------
// Screen mapping
// ---------------------------------------------------------------------------

/// The camera over the card: an integer scale plus a pan, in screen pixels.
///
/// Immutable, like [HuiViewport](viewport_math.dart): every gesture produces a
/// new one and the surface commits it, so a half-applied transform can never be
/// painted.
class PreviewCardView {
  const PreviewCardView({
    this.widthPx = 0,
    this.heightPx = 0,
    this.zoom = previewDefaultZoom,
    this.panX = 0,
    this.panY = 0,
  });

  /// CSS pixels of the drawing surface.
  final double widthPx;
  final double heightPx;

  final int zoom;

  /// Screen-pixel offset of the card origin from the centre of the surface.
  final double panX;
  final double panY;

  bool get hasArea => widthPx > 0 && heightPx > 0;

  double get originX => widthPx / 2 + panX;

  double get originY => heightPx / 2 + panY;

  double toScreenX(num cardX) => originX + cardX * zoom;

  double toScreenY(num cardY) => originY - cardY * zoom;

  double toCardX(double screenX) => (screenX - originX) / zoom;

  double toCardY(double screenY) => (originY - screenY) / zoom;

  PreviewCardView resized(double width, double height) =>
      PreviewCardView(
        widthPx: width,
        heightPx: height,
        zoom: zoom,
        panX: panX,
        panY: panY,
      );

  PreviewCardView pannedBy(double dxPx, double dyPx) => PreviewCardView(
        widthPx: widthPx,
        heightPx: heightPx,
        zoom: zoom,
        panX: panX + dxPx,
        panY: panY + dyPx,
      );

  PreviewCardView reset() =>
      PreviewCardView(widthPx: widthPx, heightPx: heightPx);

  /// Re-scales around a screen point, which stays over the same card pixel.
  /// Called with the pointer for a wheel zoom and with the centre of the
  /// surface for the toolbar buttons.
  PreviewCardView zoomedAt(
    int nextZoom, {
    required double screenX,
    required double screenY,
  }) {
    final int clamped = previewClampZoom(nextZoom);
    if (clamped == zoom) return this;
    final double cardX = toCardX(screenX);
    final double cardY = toCardY(screenY);
    return PreviewCardView(
      widthPx: widthPx,
      heightPx: heightPx,
      zoom: clamped,
      panX: screenX - cardX * clamped - widthPx / 2,
      panY: screenY + cardY * clamped - heightPx / 2,
    );
  }

  PreviewCardView zoomedAtCenter(int nextZoom) =>
      zoomedAt(nextZoom, screenX: widthPx / 2, screenY: heightPx / 2);

  /// Largest stop that fits [bounds] with [paddingPx] to spare, centred.
  /// A null or empty box leaves the camera at its default, which is what an
  /// empty document should show.
  PreviewCardView fittedTo(PreviewBox? bounds, {double paddingPx = 24}) {
    if (bounds == null || !hasArea) return reset();
    final double usableWidth = math.max(1, widthPx - paddingPx * 2);
    final double usableHeight = math.max(1, heightPx - paddingPx * 2);
    int best = previewZoomStops.first;
    for (final int stop in previewZoomStops) {
      if (bounds.width * stop <= usableWidth &&
          bounds.height * stop <= usableHeight) {
        best = stop;
      }
    }
    return PreviewCardView(
      widthPx: widthPx,
      heightPx: heightPx,
      zoom: best,
      panX: -bounds.centerX * best,
      panY: bounds.centerY * best,
    );
  }
}

// ---------------------------------------------------------------------------
// Boxes
// ---------------------------------------------------------------------------

/// An axis-aligned box in card pixels, `y` up.
class PreviewBox {
  const PreviewBox({
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
  });

  final double left;
  final double bottom;
  final double right;
  final double top;

  double get width => right - left;

  double get height => top - bottom;

  double get centerX => (left + right) / 2;

  double get centerY => (bottom + top) / 2;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= bottom && y <= top;

  PreviewBox inflate(double amount) => PreviewBox(
        left: left - amount,
        bottom: bottom - amount,
        right: right + amount,
        top: top + amount,
      );

  PreviewBox union(PreviewBox other) => PreviewBox(
        left: math.min(left, other.left),
        bottom: math.min(bottom, other.bottom),
        right: math.max(right, other.right),
        top: math.max(top, other.top),
      );
}

/// The drawn extent of one item.
///
/// [labelWidth] is the width the painter measured for a [CardLabel], in card
/// pixels; without it the run text is measured at [previewGlyphAdvancePx] per
/// glyph, which is the vanilla advance and close enough to click with before
/// the webfont has loaded. A label that resolved to nothing still gets one
/// glyph of width, so an author can always select it and fix the expression.
PreviewBox previewItemBox(CardItem item, {double? labelWidth}) {
  final double halfWidth;
  final double halfHeight;
  switch (item) {
    case CardPanel():
      halfWidth = item.width / 2;
      halfHeight = item.height / 2;
    case CardCell():
      halfWidth = item.size / 2;
      halfHeight = item.size / 2;
    case CardSlot():
      halfWidth = item.size / 2;
      halfHeight = item.size / 2;
    case CardLabel():
      final double measured = labelWidth ?? previewLabelWidth(item);
      halfWidth = math.max(measured, previewGlyphAdvancePx.toDouble()) / 2;
      halfHeight = previewLabelLineHeightPx / 2;
  }
  return PreviewBox(
    left: item.x - halfWidth,
    bottom: item.y - halfHeight,
    right: item.x + halfWidth,
    top: item.y + halfHeight,
  );
}

/// Nominal width of a label's runs, in card pixels. Minecraft widens every
/// GLYPH of a bold run by one pixel rather than the run as a whole, which is
/// the same rule the component canvas measures by.
double previewLabelWidth(CardLabel label) {
  double total = 0;
  for (final McSpan run in label.text) {
    total += run.text.runes.length *
        (previewGlyphAdvancePx + (run.bold ? 1 : 0));
  }
  return total;
}

/// Bounding box of everything drawn, or null for an empty scene.
PreviewBox? previewSceneBounds(
  PreviewCardScene scene, {
  List<double>? labelWidths,
}) {
  PreviewBox? bounds;
  for (int i = 0; i < scene.items.length; i++) {
    final PreviewBox box =
        previewItemBox(scene.items[i], labelWidth: _labelWidthAt(labelWidths, i));
    bounds = bounds == null ? box : bounds.union(box);
  }
  return bounds;
}

double? _labelWidthAt(List<double>? widths, int index) =>
    widths == null || index >= widths.length || widths[index] <= 0
        ? null
        : widths[index];

// ---------------------------------------------------------------------------
// Hit model
// ---------------------------------------------------------------------------

/// Item indices in paint order: ascending `z`, ties broken by emission order.
///
/// `List.sort` is not stable, so the index tiebreak is load-bearing — the card
/// chrome and a document panel both sit at z 1 and the chrome has to stay
/// behind.
List<int> previewPaintOrder(PreviewCardScene scene) {
  final List<int> order =
      List<int>.generate(scene.items.length, (int index) => index);
  order.sort((int a, int b) {
    final int byZ = scene.items[a].z.compareTo(scene.items[b].z);
    return byZ != 0 ? byZ : a.compareTo(b);
  });
  return order;
}

/// Which element emitted [itemIndex], or -1 for card chrome.
int previewElementIndexOf(PreviewCardScene scene, int itemIndex) =>
    itemIndex < 0 || itemIndex >= scene.sources.length
        ? -1
        : scene.sources[itemIndex];

/// Every item [elementIndex] emitted — one per `repeat` instance.
List<int> previewItemsForElement(PreviewCardScene scene, int elementIndex) =>
    <int>[
      for (int i = 0; i < scene.sources.length; i++)
        if (scene.sources[i] == elementIndex) i,
    ];

/// The topmost item under a card-space point, or null.
///
/// Card chrome is skipped unless [chrome] is set: the frame and the panel cover
/// the whole card, and clicking one of them means "nothing", not "select the
/// frame the framer drew".
int? previewHitTestItem(
  PreviewCardScene scene,
  double cardX,
  double cardY, {
  List<double>? labelWidths,
  bool chrome = false,
}) {
  final List<int> order = previewPaintOrder(scene);
  for (int i = order.length - 1; i >= 0; i--) {
    final int index = order[i];
    if (!chrome && previewElementIndexOf(scene, index) < 0) continue;
    final PreviewBox box = previewItemBox(
      scene.items[index],
      labelWidth: _labelWidthAt(labelWidths, index),
    );
    if (box.contains(cardX, cardY)) return index;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Writes
// ---------------------------------------------------------------------------

/// True when a field holds something the editor may overwrite: a JSON number,
/// or nothing at all (which means the format's own default). An expression
/// source is refused — silently replacing it with a constant would throw away
/// the author's work.
bool previewIsConstant(HuiRawExpr raw) => raw == null || raw is num;

/// A constant field as the integer the scene resolved it to. `Math.round` is
/// half-UP in the plugin, which is what [previewRound] reproduces, so an
/// authored `3.5` reads back as the 4 the canvas is actually showing.
int previewConstantInt(HuiRawExpr raw, {int fallback = 0}) =>
    raw is num ? previewRound(raw.toDouble()).toInt() : fallback;

class PreviewPoint {
  const PreviewPoint(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is PreviewPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PreviewPoint($x, $y)';
}

/// Why [element] cannot be dragged, or null when it can be.
String? previewMoveRefusal(HuiPreviewElement element) =>
    previewIsConstant(element.x) && previewIsConstant(element.y)
        ? null
        : previewExpressionMoveHint;

/// Where a drag of ([dxCard], [dyCard]) card pixels lands, measured from
/// [element]'s current position. This is the arrow-key path: each nudge is a
/// discrete step off wherever the element now is.
///
/// Snapping is to whole pixels and is not optional: the format has no
/// sub-pixel coordinate, so a fractional drag would be truncated on the way
/// into the JSON anyway.
PreviewPoint previewMoveTarget(
  HuiPreviewElement element, {
  required double dxCard,
  required double dyCard,
}) =>
    previewMoveFrom(
      PreviewPoint(previewConstantInt(element.x), previewConstantInt(element.y)),
      dxCard: dxCard,
      dyCard: dyCard,
    );

/// Where a drag of ([dxCard], [dyCard]) lands, measured from [start].
///
/// This is the pointer path, and [start] is the position captured at
/// pointer-DOWN: every frame of the gesture re-resolves the whole travel
/// against it, so rounding can never accumulate across a slow drag the way it
/// would if each frame moved the element by its own delta.
PreviewPoint previewMoveFrom(
  PreviewPoint start, {
  required double dxCard,
  required double dyCard,
}) =>
    PreviewPoint((start.x + dxCard).round(), (start.y + dyCard).round());

enum PreviewHandle { topLeft, topRight, bottomLeft, bottomRight }

/// One resize grip, in card pixels.
class PreviewHandleSpot {
  const PreviewHandleSpot(this.handle, this.x, this.y);

  final PreviewHandle handle;
  final double x;
  final double y;
}

List<PreviewHandleSpot> previewHandleSpots(PreviewBox box) =>
    <PreviewHandleSpot>[
      PreviewHandleSpot(PreviewHandle.topLeft, box.left, box.top),
      PreviewHandleSpot(PreviewHandle.topRight, box.right, box.top),
      PreviewHandleSpot(PreviewHandle.bottomLeft, box.left, box.bottom),
      PreviewHandleSpot(PreviewHandle.bottomRight, box.right, box.bottom),
    ];

/// The write one resize produces: the new centre plus whichever extent field
/// the element's type actually carries.
class PreviewResize {
  const PreviewResize({
    required this.x,
    required this.y,
    this.width,
    this.height,
    this.size,
  });

  final int x;
  final int y;

  /// Set for a `panel` only.
  final int? width;
  final int? height;

  /// Set for a `cell` or a `slot` only, which are square by construction.
  final int? size;
}

/// Why [element] cannot be resized, or null when it can be.
///
/// The position has to be constant too: a resize moves the centre to keep the
/// opposite corner pinned, so an expression-positioned element has nowhere to
/// write the result.
String? previewResizeRefusal(HuiPreviewElement element) {
  if (element.type == 'label') return previewNoResizeHint;
  if (!previewIsConstant(element.x) || !previewIsConstant(element.y)) {
    return previewExpressionMoveHint;
  }
  switch (element.type) {
    case 'panel':
      return element.width is num && element.height is num
          ? null
          : previewExpressionResizeHint;
    case 'cell':
    case 'slot':
      return element.size is num ? null : previewExpressionResizeHint;
    default:
      return previewNoResizeHint;
  }
}

/// Resolves a grip drag to a write, pinning the corner opposite [handle].
///
/// Null when the element refuses the gesture; the caller shows
/// [previewResizeRefusal] instead. [box] is the item's box as the scene built
/// it, so a repeat instance resizes from the instance the pointer grabbed.
PreviewResize? previewResizeTarget({
  required HuiPreviewElement element,
  required PreviewBox box,
  required PreviewHandle handle,
  required double cardX,
  required double cardY,
  int minSize = 1,
}) {
  if (previewResizeRefusal(element) != null) return null;
  final double anchorX = switch (handle) {
    PreviewHandle.topLeft || PreviewHandle.bottomLeft => box.right,
    PreviewHandle.topRight || PreviewHandle.bottomRight => box.left,
  };
  final double anchorY = switch (handle) {
    PreviewHandle.topLeft || PreviewHandle.topRight => box.bottom,
    PreviewHandle.bottomLeft || PreviewHandle.bottomRight => box.top,
  };
  final double signX = cardX >= anchorX ? 1 : -1;
  final double signY = cardY >= anchorY ? 1 : -1;
  final int spanX =
      math.max(minSize, (cardX - anchorX).abs().round()).toInt();
  final int spanY =
      math.max(minSize, (cardY - anchorY).abs().round()).toInt();

  if (element.type == 'panel') {
    return PreviewResize(
      x: (anchorX + signX * spanX / 2).round(),
      y: (anchorY + signY * spanY / 2).round(),
      width: spanX,
      height: spanY,
    );
  }
  // Square: the longer of the two drags wins, so the grip always follows the
  // pointer on at least one axis.
  final int span = math.max(spanX, spanY);
  return PreviewResize(
    x: (anchorX + signX * span / 2).round(),
    y: (anchorY + signY * span / 2).round(),
    size: span,
  );
}

// ---------------------------------------------------------------------------
// Simulation target
// ---------------------------------------------------------------------------

/// Whole-word match on any variable [PreviewSim.tick] moves. Built once: the
/// surface asks this question on every document revision.
final RegExp _previewTickVaryingPattern =
    RegExp('\\b(?:${previewTickVaryingVariables.join('|')})\\b');

/// True when anything in [doc] reads a variable the simulation clock moves —
/// which is to say, when running the clock would actually change the picture.
///
/// The scan is textual over the document's raw expression sources rather than
/// over parsed ASTs, and it is deliberately allowed to over-report: a message
/// key that happens to contain `lit`, or a literal string with the word `time`
/// in it, answers true and costs nothing but a clock that was going to run
/// anyway. It must never UNDER-report, which is why the name set lives beside
/// [PreviewSim.tick] under a drift test instead of being written out here.
///
/// Note that a name is only matched whole: `cookTimeTotal` and `brewTotal` are
/// fixed for a category and do not start the clock on their own.
bool previewDocIsAnimated(HuiPreviewDoc doc) {
  final HuiPreviewCard? card = doc.card;
  if (card != null &&
      (_readsClock(card.framed) ||
          _readsClock(card.title) ||
          _readsClock(card.accent))) {
    return true;
  }
  for (final HuiPreviewElement element in doc.elements) {
    if (_readsClock(element.x) ||
        _readsClock(element.y) ||
        _readsClock(element.z) ||
        _readsClock(element.width) ||
        _readsClock(element.height) ||
        _readsClock(element.size) ||
        _readsClock(element.color) ||
        _readsClock(element.wellColor) ||
        _readsClock(element.index) ||
        _readsClock(element.background) ||
        _readsClock(element.text) ||
        _readsClock(element.visible) ||
        _readsClock(element.repeat?.count)) {
      return true;
    }
  }
  return false;
}

bool _readsClock(Object? raw) =>
    raw is String && _previewTickVaryingPattern.hasMatch(raw);

/// The simulated category a document is obviously written against, from its own
/// match criteria.
///
/// A convenience, not a contract: the simulation panel lets an author pick any
/// category. It exists so opening a furnace document shows a running furnace
/// rather than an empty chest, which is the difference between a surface that
/// looks broken and one that looks right.
String previewAutoSimCategory(HuiPreviewDoc doc) {
  final String? special = doc.match.special;
  // A `special` document (the locked card) is drawn with no target at all.
  if (special != null && special.isNotEmpty) return 'statics';
  for (final String block in doc.match.blocks) {
    final String name = block.toUpperCase();
    if (name.contains('FURNACE') || name.contains('SMOKER')) return 'furnace';
    if (name.contains('BREWING')) return 'brewing';
    if (name.contains('BEEHIVE') || name.contains('BEE_NEST')) return 'beehive';
    if (name.contains('CAULDRON')) return 'cauldron';
    if (name.contains('JUKEBOX')) return 'jukebox';
    if (name.contains('ENDER_CHEST')) return 'enderChest';
  }
  if (doc.match.blocks.isNotEmpty) return 'chest';
  if (doc.match.entities.isNotEmpty) return 'entity';
  return 'statics';
}
