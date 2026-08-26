library;

import 'dart:math' as math;

import '../model/model.dart';
import 'gloss_particle_text.dart';

const double glossParticleCharacterWidth = 0.1;
const double glossParticleLineHeight = 0.26;

final class GlossParticleRect {
  const GlossParticleRect({
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.height,
    required this.depth,
  });

  const GlossParticleRect.plane(double width, double height)
    : this(x: 0, y: 0, z: 0, width: width, height: height, depth: 0);

  final double x;
  final double y;
  final double z;
  final double width;
  final double height;
  final double depth;

  GlossParticleRect translate(double dx, double dy, double dz) =>
      GlossParticleRect(
        x: x + dx,
        y: y + dy,
        z: z + dz,
        width: width,
        height: height,
        depth: depth,
      );
}

GlossParticleRect glossParticleTextBounds(String rendered, double scale) =>
    _layout(rendered, scale).bounds;

List<GlossParticleRect> glossParticleLineBounds(String rendered, double scale) {
  final _GlossParticleTextLayout layout = _layout(rendered, scale);
  final int lineCount = math.max(1, _countLines(rendered));
  final double lineHeight = glossParticleLineHeight * _safeScale(scale);
  final List<GlossParticleRect> lines = <GlossParticleRect>[];
  for (int line = 0; line < lineCount; line++) {
    double minimumX = double.infinity;
    double maximumX = double.negativeInfinity;
    final double centerY = (lineCount - 1) * lineHeight / 2 - line * lineHeight;
    for (final _GlossParticleCell cell in layout.cells) {
      if ((cell.bounds.y - centerY).abs() > 1.0E-9) continue;
      minimumX = math.min(minimumX, cell.bounds.x - cell.bounds.width / 2);
      maximumX = math.max(maximumX, cell.bounds.x + cell.bounds.width / 2);
    }
    final double width = minimumX == double.infinity ? 0 : maximumX - minimumX;
    lines.add(
      GlossParticleRect(
        x: 0,
        y: centerY,
        z: 0,
        width: width,
        height: lineHeight,
        depth: 0,
      ),
    );
  }
  return List<GlossParticleRect>.unmodifiable(lines);
}

List<GlossParticleRect> glossParticleSpanBounds(
  GlossParticleTextRendered rendered,
  String spanName,
  double scale, {
  required bool perLetter,
}) {
  final List<GlossParticleTextSpan> spans = rendered.named(spanName);
  if (spans.isEmpty) return const <GlossParticleRect>[];
  final _GlossParticleTextLayout layout = _layout(rendered.text, scale);
  final List<GlossParticleRect> bounds = <GlossParticleRect>[];
  for (final GlossParticleTextSpan span in spans) {
    final List<_GlossParticleCell> cells = <_GlossParticleCell>[
      for (final _GlossParticleCell cell in layout.cells)
        if (cell.sourceIndex >= span.start && cell.sourceIndex < span.end) cell,
    ];
    if (perLetter) {
      bounds.addAll(<GlossParticleRect>[
        for (final _GlossParticleCell cell in cells) cell.bounds,
      ]);
    } else if (cells.isNotEmpty) {
      bounds.add(_unionCells(cells));
    }
  }
  return List<GlossParticleRect>.unmodifiable(bounds);
}

List<Vec3> glossSampleParticleGeometry(
  GlossParticleGeometry geometry,
  List<GlossParticleRect> targets, {
  int maximum = 512,
}) {
  final int limit = math.max(1, maximum);
  final List<Vec3> output = <Vec3>[];
  if (geometry.type == 'line') {
    final Vec3? from = geometry.from;
    final Vec3? to = geometry.to;
    if (from != null && to != null) {
      _addLine(output, from, to, geometry.spacing, limit, true);
    }
    return List<Vec3>.unmodifiable(output);
  }
  if (geometry.type == 'polyline') {
    for (
      int index = 1;
      index < geometry.points.length && output.length < limit;
      index++
    ) {
      _addLine(
        output,
        geometry.points[index - 1],
        geometry.points[index],
        geometry.spacing,
        limit,
        index == 1,
      );
    }
    return List<Vec3>.unmodifiable(output);
  }
  final List<GlossParticleRect> activeTargets = targets.isEmpty
      ? <GlossParticleRect>[
          GlossParticleRect(
            x: 0,
            y: 0,
            z: 0,
            width: geometry.width ?? 0,
            height: geometry.height ?? 0,
            depth: geometry.depth ?? 0,
          ),
        ]
      : targets;
  for (final GlossParticleRect target in activeTargets) {
    if (output.length >= limit) break;
    _sampleTarget(output, geometry, target, limit);
  }
  return List<Vec3>.unmodifiable(output);
}

List<Vec3> glossSelectParticlePattern(
  List<Vec3> samples,
  GlossParticleEmission emission,
  int tick,
) {
  if (samples.isEmpty || emission.pattern == 'steady') return samples;
  final int period = math.max(1, emission.periodTicks);
  final int phase = _floorMod(tick + emission.seed, period);
  return switch (emission.pattern) {
    'chase' || 'scan' => <Vec3>[
      samples[((phase * samples.length) ~/ period) % samples.length],
    ],
    'corners' => _corners(samples),
    'pulse' => phase * 2 < period ? samples : const <Vec3>[],
    'twinkle' => _twinkle(samples, emission.seed, tick),
    _ => samples,
  };
}

_GlossParticleTextLayout _layout(String rendered, double scale) {
  final double safeScale = _safeScale(scale);
  final double characterWidth = glossParticleCharacterWidth * safeScale;
  final double lineHeight = glossParticleLineHeight * safeScale;
  final List<_GlossParticleCellDraft> drafts = <_GlossParticleCellDraft>[];
  final List<int> lineWidths = <int>[];
  int line = 0;
  int column = 0;
  int index = 0;
  while (index < rendered.length) {
    final int value = rendered.codeUnitAt(index);
    if ((value == 0x00A7 || value == 0x26) &&
        index + 1 < rendered.length &&
        _isLegacyCode(rendered[index + 1])) {
      index += _legacyCodeLength(rendered, index);
      continue;
    }
    if (_isLineBreak(value)) {
      lineWidths.add(column);
      line++;
      column = 0;
      if (value == 0x0D &&
          index + 1 < rendered.length &&
          rendered.codeUnitAt(index + 1) == 0x0A) {
        index++;
      }
      index++;
      continue;
    }
    if (!_isIsoControl(value)) {
      drafts.add(
        _GlossParticleCellDraft(sourceIndex: index, line: line, column: column),
      );
      column++;
    }
    index++;
  }
  lineWidths.add(column);
  final int lineCount = lineWidths.length;
  final List<_GlossParticleCell> cells = <_GlossParticleCell>[];
  double maximumWidth = 0;
  for (final int width in lineWidths) {
    maximumWidth = math.max(maximumWidth, width * characterWidth);
  }
  for (final _GlossParticleCellDraft draft in drafts) {
    final double lineWidth = lineWidths[draft.line] * characterWidth;
    cells.add(
      _GlossParticleCell(
        sourceIndex: draft.sourceIndex,
        bounds: GlossParticleRect(
          x: -lineWidth / 2 + characterWidth * (draft.column + 0.5),
          y: (lineCount - 1) * lineHeight / 2 - draft.line * lineHeight,
          z: 0,
          width: characterWidth,
          height: lineHeight,
          depth: 0,
        ),
      ),
    );
  }
  return _GlossParticleTextLayout(
    cells: List<_GlossParticleCell>.unmodifiable(cells),
    bounds: GlossParticleRect.plane(maximumWidth, lineCount * lineHeight),
  );
}

double _safeScale(double scale) => scale.isFinite ? math.max(0, scale) : 1;

int _legacyCodeLength(String rendered, int index) {
  if (index + 13 < rendered.length &&
      rendered[index + 1].toLowerCase() == 'x') {
    return 14;
  }
  return 2;
}

bool _isLegacyCode(String value) =>
    '0123456789abcdefklmnorx'.contains(value.toLowerCase());

int _countLines(String rendered) {
  int count = 1;
  for (int index = 0; index < rendered.length; index++) {
    final int value = rendered.codeUnitAt(index);
    if (_isLineBreak(value)) {
      count++;
      if (value == 0x0D &&
          index + 1 < rendered.length &&
          rendered.codeUnitAt(index + 1) == 0x0A) {
        index++;
      }
    }
  }
  return count;
}

bool _isLineBreak(int value) =>
    value == 0x0A || value == 0x0D || value == 0x2028 || value == 0x2029;

bool _isIsoControl(int value) =>
    (value >= 0 && value <= 0x1F) || (value >= 0x7F && value <= 0x9F);

GlossParticleRect _unionCells(List<_GlossParticleCell> cells) {
  double minimumX = double.infinity;
  double minimumY = double.infinity;
  double maximumX = double.negativeInfinity;
  double maximumY = double.negativeInfinity;
  for (final _GlossParticleCell cell in cells) {
    minimumX = math.min(minimumX, cell.bounds.x - cell.bounds.width / 2);
    minimumY = math.min(minimumY, cell.bounds.y - cell.bounds.height / 2);
    maximumX = math.max(maximumX, cell.bounds.x + cell.bounds.width / 2);
    maximumY = math.max(maximumY, cell.bounds.y + cell.bounds.height / 2);
  }
  return GlossParticleRect(
    x: (minimumX + maximumX) / 2,
    y: (minimumY + maximumY) / 2,
    z: 0,
    width: maximumX - minimumX,
    height: maximumY - minimumY,
    depth: 0,
  );
}

void _sampleTarget(
  List<Vec3> output,
  GlossParticleGeometry geometry,
  GlossParticleRect target,
  int limit,
) {
  final double padding = geometry.padding;
  final GlossParticleRect expanded = GlossParticleRect(
    x: target.x,
    y: target.y,
    z: target.z,
    width: target.width + padding * 2,
    height: target.height + padding * 2,
    depth: target.depth + padding * 2,
  );
  switch (geometry.type) {
    case 'point':
      _add(output, Vec3(expanded.x, expanded.y, expanded.z), limit);
    case 'filledPlane' || 'glyphFill':
      _addPlane(output, expanded, geometry.spacing, limit);
    case 'cuboid':
      _addCuboid(output, expanded, geometry.spacing, limit);
    case 'letterBounds' || 'glyphOutline' || 'outline':
      _addOutline(output, expanded, geometry.spacing, limit);
  }
}

void _addPlane(
  List<Vec3> output,
  GlossParticleRect target,
  double spacing,
  int limit,
) {
  final double left = target.x - target.width / 2;
  final double bottom = target.y - target.height / 2;
  final int columns = _segments(target.width, spacing);
  final int rows = _segments(target.height, spacing);
  for (int row = 0; row <= rows && output.length < limit; row++) {
    final double y = bottom + target.height * row / rows;
    for (int column = 0; column <= columns && output.length < limit; column++) {
      final double x = left + target.width * column / columns;
      _add(output, Vec3(x, y, target.z), limit);
    }
  }
}

void _addOutline(
  List<Vec3> output,
  GlossParticleRect target,
  double spacing,
  int limit,
) {
  final double halfWidth = target.width / 2;
  final double halfHeight = target.height / 2;
  final Vec3 bottomLeft = Vec3(
    target.x - halfWidth,
    target.y - halfHeight,
    target.z,
  );
  final Vec3 bottomRight = Vec3(
    target.x + halfWidth,
    target.y - halfHeight,
    target.z,
  );
  final Vec3 topRight = Vec3(
    target.x + halfWidth,
    target.y + halfHeight,
    target.z,
  );
  final Vec3 topLeft = Vec3(
    target.x - halfWidth,
    target.y + halfHeight,
    target.z,
  );
  _addLine(output, bottomLeft, bottomRight, spacing, limit, true);
  _addLine(output, bottomRight, topRight, spacing, limit, false);
  _addLine(output, topRight, topLeft, spacing, limit, false);
  _addLine(output, topLeft, bottomLeft, spacing, limit, false);
}

void _addCuboid(
  List<Vec3> output,
  GlossParticleRect target,
  double spacing,
  int limit,
) {
  final double halfWidth = target.width / 2;
  final double halfHeight = target.height / 2;
  final double halfDepth = target.depth / 2;
  final List<Vec3> corners = <Vec3>[
    Vec3(target.x - halfWidth, target.y - halfHeight, target.z - halfDepth),
    Vec3(target.x + halfWidth, target.y - halfHeight, target.z - halfDepth),
    Vec3(target.x + halfWidth, target.y + halfHeight, target.z - halfDepth),
    Vec3(target.x - halfWidth, target.y + halfHeight, target.z - halfDepth),
    Vec3(target.x - halfWidth, target.y - halfHeight, target.z + halfDepth),
    Vec3(target.x + halfWidth, target.y - halfHeight, target.z + halfDepth),
    Vec3(target.x + halfWidth, target.y + halfHeight, target.z + halfDepth),
    Vec3(target.x - halfWidth, target.y + halfHeight, target.z + halfDepth),
  ];
  const List<List<int>> edges = <List<int>>[
    <int>[0, 1],
    <int>[1, 2],
    <int>[2, 3],
    <int>[3, 0],
    <int>[4, 5],
    <int>[5, 6],
    <int>[6, 7],
    <int>[7, 4],
    <int>[0, 4],
    <int>[1, 5],
    <int>[2, 6],
    <int>[3, 7],
  ];
  for (int index = 0; index < edges.length && output.length < limit; index++) {
    final List<int> edge = edges[index];
    _addLine(
      output,
      corners[edge[0]],
      corners[edge[1]],
      spacing,
      limit,
      index == 0,
    );
  }
}

void _addLine(
  List<Vec3> output,
  Vec3 from,
  Vec3 to,
  double spacing,
  int limit,
  bool includeStart,
) {
  final double dx = to.x - from.x;
  final double dy = to.y - from.y;
  final double dz = to.z - from.z;
  final double length = math.sqrt(dx * dx + dy * dy + dz * dz);
  final int segments = _segments(length, spacing);
  final int start = includeStart ? 0 : 1;
  for (int index = start; index <= segments && output.length < limit; index++) {
    final double progress = index / segments;
    _add(
      output,
      Vec3(
        from.x + dx * progress,
        from.y + dy * progress,
        from.z + dz * progress,
      ),
      limit,
    );
  }
}

int _segments(double length, double spacing) =>
    math.max(1, (length / spacing).ceil());

void _add(List<Vec3> output, Vec3 point, int limit) {
  if (output.length < limit) output.add(point);
}

List<Vec3> _corners(List<Vec3> samples) {
  if (samples.length <= 4) return samples;
  final int last = samples.length - 1;
  return <Vec3>[
    samples[0],
    samples[last ~/ 3],
    samples[last * 2 ~/ 3],
    samples[last],
  ];
}

List<Vec3> _twinkle(List<Vec3> samples, int seed, int tick) {
  final int count = math.max(1, samples.length ~/ 8);
  final List<Vec3> selected = <Vec3>[];
  int state = (seed ^ tick * 0x9E3779B9) & 0xFFFFFFFF;
  for (int index = 0; index < count; index++) {
    state ^= state >> 12;
    state = (state ^ ((state << 25) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    state ^= state >> 27;
    selected.add(samples[_floorMod(state, samples.length)]);
  }
  return List<Vec3>.unmodifiable(selected);
}

int _floorMod(int value, int modulus) =>
    ((value % modulus) + modulus) % modulus;

final class _GlossParticleTextLayout {
  const _GlossParticleTextLayout({required this.cells, required this.bounds});

  final List<_GlossParticleCell> cells;
  final GlossParticleRect bounds;
}

final class _GlossParticleCellDraft {
  const _GlossParticleCellDraft({
    required this.sourceIndex,
    required this.line,
    required this.column,
  });

  final int sourceIndex;
  final int line;
  final int column;
}

final class _GlossParticleCell {
  const _GlossParticleCell({required this.sourceIndex, required this.bounds});

  final int sourceIndex;
  final GlossParticleRect bounds;
}
