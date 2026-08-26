library;

import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_particle_preview.dart';
import '../../logic/gloss_particle_text.dart';
import '../../model/model.dart';

class GlossParticleOverlay extends StatelessWidget {
  const GlossParticleOverlay({
    required this.layers,
    required this.pixelsPerBlock,
    required this.tick,
    this.renderedText,
    this.textScale = 1,
    this.textOrigin = const GlossParticleRect(
      x: 0,
      y: 0,
      z: 0,
      width: 0,
      height: 0,
      depth: 0,
    ),
    this.scopeBounds = const <String, List<GlossParticleRect>>{},
    super.key,
  });

  final List<GlossParticleLayer> layers;
  final double pixelsPerBlock;
  final int tick;
  final GlossParticleTextRendered? renderedText;
  final double textScale;
  final GlossParticleRect textOrigin;
  final Map<String, List<GlossParticleRect>> scopeBounds;

  @override
  Widget build(BuildContext context) {
    if (layers.isEmpty) {
      return const dom.span(classes: 'hui-particle-overlay', <Widget>[]);
    }
    return dom.span(
      classes: 'hui-particle-overlay',
      attributes: const <String, String>{'aria-hidden': 'true'},
      <Widget>[
        for (final GlossParticleLayer layer in layers)
          for (final Vec3 point in _points(layer)) _dot(layer, point),
      ],
    );
  }

  List<Vec3> _points(GlossParticleLayer layer) {
    final List<GlossParticleRect> targets = _targets(layer);
    if (layer.target.scope != 'local' && targets.isEmpty) {
      return const <Vec3>[];
    }
    return glossSelectParticlePattern(
      glossSampleParticleGeometry(layer.geometry, targets, maximum: 512),
      layer.emission,
      tick,
    );
  }

  List<GlossParticleRect> _targets(GlossParticleLayer layer) {
    final String scope = layer.target.scope;
    final List<GlossParticleRect>? direct = scopeBounds[scope];
    if (direct != null) return direct;
    if (scope == 'local') return const <GlossParticleRect>[];
    final GlossParticleTextRendered? text = renderedText;
    if (text == null) return const <GlossParticleRect>[];
    final List<GlossParticleRect> local = switch (scope) {
      'projection' || 'component' || 'text' || 'label' => <GlossParticleRect>[
        glossParticleTextBounds(text.text, textScale),
      ],
      'line' => _lineTargets(text.text, layer.target.line),
      'span' => glossParticleSpanBounds(
        text,
        layer.target.name ?? '',
        textScale,
        perLetter:
            layer.geometry.type == 'letterBounds' ||
            layer.geometry.type == 'glyphOutline' ||
            layer.geometry.type == 'glyphFill',
      ),
      _ => const <GlossParticleRect>[],
    };
    return <GlossParticleRect>[
      for (final GlossParticleRect target in local)
        target.translate(textOrigin.x, textOrigin.y, textOrigin.z),
    ];
  }

  List<GlossParticleRect> _lineTargets(String text, int? oneBasedLine) {
    if (oneBasedLine == null || oneBasedLine < 1) {
      return const <GlossParticleRect>[];
    }
    final List<GlossParticleRect> lines = glossParticleLineBounds(
      text,
      textScale,
    );
    final int index = oneBasedLine - 1;
    return index < lines.length
        ? <GlossParticleRect>[lines[index]]
        : const <GlossParticleRect>[];
  }

  Widget _dot(GlossParticleLayer layer, Vec3 point) {
    final double size = math.max(
      2.4,
      math.min(8, (layer.particle.size ?? 1) * 3.4),
    );
    final double x =
        (point.x + layer.placement.offset.x) * pixelsPerBlock - size / 2;
    final double y =
        -(point.y + layer.placement.offset.y) * pixelsPerBlock - size / 2;
    return dom.span(
      classes:
          'hui-particle-dot is-${layer.placement.layer} is-${layer.emission.pattern}',
      styles: dom.Styles(
        raw: <String, String>{
          'left': 'calc(50% + ${x.toStringAsFixed(2)}px)',
          'top': 'calc(50% + ${y.toStringAsFixed(2)}px)',
          'width': '${size.toStringAsFixed(2)}px',
          'height': '${size.toStringAsFixed(2)}px',
          '--hui-particle-color': layer.particle.color ?? '#8bd5ff',
        },
      ),
      const <Widget>[],
    );
  }
}
