library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('shared editor exposes every canonical particle layer group', () {
    final String source = File(
      'lib/components/inspector/particle_layers_editor.dart',
    ).readAsStringSync();

    for (final String field in <String>[
      'layer.id',
      'layer.target.scope',
      'layer.target.name',
      'layer.target.component',
      'layer.target.line',
      'geometry.type',
      'geometry.from',
      'geometry.to',
      'geometry.points',
      'geometry.width',
      'geometry.height',
      'geometry.depth',
      'geometry.padding',
      'geometry.spacing',
      'layer.placement.layer',
      'layer.placement.depth',
      'layer.placement.offset',
      'layer.particle.key',
      'layer.particle.color',
      'layer.particle.size',
      'layer.emission.pattern',
      'layer.emission.intervalTicks',
      'layer.emission.periodTicks',
      'layer.emission.seed',
      'layer.priority',
    ]) {
      expect(source, contains(field), reason: field);
    }
    expect(source, contains('<particles:name>text</particles>'));
    expect(source, contains('glossParticleTargetScopes'));
    expect(source, contains('glossParticleGeometryTypes'));
    expect(source, contains('glossParticlePlacementLayers'));
    expect(source, contains('glossParticleEmissionPatterns'));
  });

  test('in-game render inspectors mount shared particle controls', () {
    for (final String path in <String>[
      'lib/components/inspector/hologram_inspector.dart',
      'lib/components/inspector/menu_inspector.dart',
      'lib/components/inspector/bubble_inspector.dart',
      'lib/components/inspector/damage_indicator_inspector.dart',
      'lib/components/inspector/real_drop_inspector.dart',
      'lib/components/inspector/preview_match_editor.dart',
    ]) {
      final String source = File(path).readAsStringSync();
      expect(source, contains('ParticleLayersEditor('), reason: path);
      expect(source, contains('.particleLayers'), reason: path);
    }
  });

  test('panels inherit menu particles without separate controls', () {
    final String source = File(
      'lib/components/inspector/panel_inspector.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('ParticleLayersEditor')));
    expect(source, isNot(contains('particleLayers')));
  });
}
