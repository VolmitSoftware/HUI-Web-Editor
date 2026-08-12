/// Geometry of the shell's rail / canvas / inspector split, and its persistence.
///
/// Deliberately pure: every clamp the splitters apply is decided here so it can
/// be unit-tested without a DOM. The live widths are CSS custom properties
/// (`--hui-rail-width`, `--hui-inspector-width`) written straight onto the
/// document root by the drag handler — a drag therefore never rebuilds the
/// widget tree, and only the released value comes back through this class.
///
/// ```dart
/// PaneLayout panes = PaneLayout.load();
/// panes = panes.withWidth(PaneSide.rail, 312, viewportWidth: 1440);
/// panes.persist();
/// ```
library;

import 'dart:convert';

import '../../services/storage_service.dart';

/// Which pane a splitter resizes. The splitter always sits between its pane and
/// the canvas, so the canvas is what pays for the change.
enum PaneSide { rail, inspector }

class PaneLayout {
  const PaneLayout({
    this.railWidth = defaultRailWidth,
    this.inspectorWidth = defaultInspectorWidth,
  });

  final double railWidth;
  final double inspectorWidth;

  /// Narrower than the 280/340 the editor shipped with: the canvas is the point
  /// of the app, and at 1280 this hands it back 60px.
  static const double defaultRailWidth = 240;
  static const double defaultInspectorWidth = 320;

  static const double minRailWidth = 200;
  static const double maxRailWidth = 420;
  static const double minInspectorWidth = 280;
  static const double maxInspectorWidth = 520;

  /// A drag stops growing a pane before the canvas drops below this. The stated
  /// min/max above are the hard range; this is the situational one.
  static const double minCanvasWidth = 420;

  /// Grab width of a splitter. Mirrors `--hui-splitter-width` in 02-shell.css;
  /// the pointer maths needs it because the handle occupies its own grid track.
  static const double handleWidth = 6;

  /// Arrow-key resize step. Shift uses the coarse one.
  static const double keyStep = 8;
  static const double keyStepCoarse = 40;

  static const String storageKey = 'holoui.panes.v1';

  static const PaneLayout defaults = PaneLayout();

  double widthOf(PaneSide side) =>
      side == PaneSide.rail ? railWidth : inspectorWidth;

  static double minOf(PaneSide side) =>
      side == PaneSide.rail ? minRailWidth : minInspectorWidth;

  static double maxOf(PaneSide side) =>
      side == PaneSide.rail ? maxRailWidth : maxInspectorWidth;

  static double defaultOf(PaneSide side) =>
      side == PaneSide.rail ? defaultRailWidth : defaultInspectorWidth;

  static PaneSide otherOf(PaneSide side) =>
      side == PaneSide.rail ? PaneSide.inspector : PaneSide.rail;

  /// The custom property the pane's grid track reads.
  static String variableOf(PaneSide side) =>
      side == PaneSide.rail ? '--hui-rail-width' : '--hui-inspector-width';

  /// Pane width implied by the splitter's left edge sitting at [edgeX] in
  /// viewport coordinates.
  ///
  /// `.hui-shell` is `position: fixed; inset: 0`, so the shell's left edge is
  /// x = 0 and its right edge is [viewportWidth].
  static double widthForEdge(
    PaneSide side,
    double edgeX,
    double viewportWidth,
  ) => side == PaneSide.rail ? edgeX : viewportWidth - edgeX - handleWidth;

  /// Clamps [raw] into the side's hard range, additionally refusing to squeeze
  /// the canvas below [minCanvasWidth] once [viewportWidth] is known.
  ///
  /// A [viewportWidth] of 0 means "not measurable" and only the hard range
  /// applies; a non-finite [raw] leaves the pane where it is.
  double clampWidth(PaneSide side, double raw, {double viewportWidth = 0}) {
    if (!raw.isFinite) return widthOf(side);
    final double low = minOf(side);
    double high = maxOf(side);
    if (viewportWidth > 0) {
      final double room =
          viewportWidth -
          widthOf(otherOf(side)) -
          minCanvasWidth -
          (handleWidth * 2);
      if (room < high) high = room;
    }
    if (high < low) high = low;
    if (raw < low) return low;
    if (raw > high) return high;
    return raw;
  }

  PaneLayout withWidth(PaneSide side, double raw, {double viewportWidth = 0}) {
    final double value = clampWidth(side, raw, viewportWidth: viewportWidth);
    return side == PaneSide.rail
        ? PaneLayout(railWidth: value, inspectorWidth: inspectorWidth)
        : PaneLayout(railWidth: railWidth, inspectorWidth: value);
  }

  PaneLayout nudged(PaneSide side, double delta, {double viewportWidth = 0}) =>
      withWidth(side, widthOf(side) + delta, viewportWidth: viewportWidth);

  /// Double-clicking a handle lands here.
  PaneLayout resetSide(PaneSide side) => withWidth(side, defaultOf(side));

  // --- persistence ----------------------------------------------------------

  String encode() => jsonEncode(<String, num>{
    'rail': railWidth.round(),
    'inspector': inspectorWidth.round(),
  });

  /// Never throws: a corrupt or foreign value degrades to [defaults] rather
  /// than leaving the user with no panes.
  static PaneLayout decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return defaults;
    }
    if (parsed is! Map<String, Object?>) return defaults;
    return defaults
        .withWidth(PaneSide.rail, _readWidth(parsed['rail'], defaultRailWidth))
        .withWidth(
          PaneSide.inspector,
          _readWidth(parsed['inspector'], defaultInspectorWidth),
        );
  }

  static PaneLayout load() => decode(StorageService.read(storageKey));

  /// False when the browser refused the write; the pane still moved, it just
  /// will not survive a reload.
  bool persist() => StorageService.write(storageKey, encode());

  static double _readWidth(Object? value, double fallback) {
    if (value is num) {
      final double parsed = value.toDouble();
      if (parsed.isFinite) return parsed;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is PaneLayout &&
      other.railWidth == railWidth &&
      other.inspectorWidth == inspectorWidth;

  @override
  int get hashCode => Object.hash(railWidth, inspectorWidth);

  @override
  String toString() =>
      'PaneLayout(rail: $railWidth, inspector: $inspectorWidth)';
}
