library;

import '../model/particle_layer.dart';
import '../model/vec3.dart';
import 'validation.dart';

final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');
final RegExp _keyPattern = RegExp(r'^[a-z0-9._-]+:[a-z0-9/._-]+$');
final RegExp _colorPattern = RegExp(r'^#[0-9a-f]{6}$');

List<HuiIssue> validateParticleLayers(
  List<GlossParticleLayer> layers, {
  String path = 'particleLayers',
}) {
  final List<HuiIssue> issues = <HuiIssue>[];
  if (layers.length > glossParticleMaxLayers) {
    _error(
      issues,
      path,
      'Gloss accepts at most {maximum} particle layers on one render.',
      <String, Object?>{'maximum': glossParticleMaxLayers},
    );
  }

  final Set<String> ids = <String>{};
  for (int index = 0; index < layers.length; index++) {
    final GlossParticleLayer layer = layers[index];
    final String layerPath = '$path[$index]';
    final String id = _normalizedId(layer.id);
    if (id.isEmpty || id.length > 64 || !_idPattern.hasMatch(id)) {
      _error(
        issues,
        '$layerPath.id',
        'Particle layer ids must match [a-z0-9][a-z0-9._-]* and be at most 64 characters.',
      );
    } else if (!ids.add(id)) {
      _error(
        issues,
        '$layerPath.id',
        'Particle layer id "{id}" is duplicated.',
        <String, Object?>{'id': id},
      );
    }

    _target(issues, '$layerPath.target', layer.target);
    _geometry(issues, '$layerPath.geometry', layer.geometry);
    _placement(issues, '$layerPath.placement', layer.placement);
    _particle(issues, '$layerPath.particle', layer.particle);
    _emission(issues, '$layerPath.emission', layer.emission);
    _clamp(issues, '$layerPath.priority', layer.priority, -1000, 1000);
  }
  return issues;
}

void _target(List<HuiIssue> issues, String path, GlossParticleTarget target) {
  final String scope = _choice(
    issues,
    '$path.scope',
    target.scope,
    glossParticleTargetScopes,
    'target scope',
  );
  final String? name = _optionalId(
    issues,
    '$path.name',
    target.name,
    'Particle span names',
  );
  final String? component = _optionalId(
    issues,
    '$path.component',
    target.component,
    'Particle component ids',
  );
  if (target.line != null && target.line! < 1) {
    _error(
      issues,
      '$path.line',
      'Particle target lines are one-based and must be greater than zero.',
    );
  }
  if (scope == 'span' && name == null) {
    _error(
      issues,
      '$path.name',
      'A span target requires a particle span name.',
    );
  }
  if (scope == 'component' && component == null) {
    _error(
      issues,
      '$path.component',
      'A component target requires a component id.',
    );
  }
  if (scope == 'line' && target.line == null) {
    _error(
      issues,
      '$path.line',
      'A line target requires a one-based line number.',
    );
  }
}

void _geometry(
  List<HuiIssue> issues,
  String path,
  GlossParticleGeometry geometry,
) {
  final String type = _choice(
    issues,
    '$path.type',
    geometry.type,
    glossParticleGeometryTypes,
    'geometry type',
  );
  if (geometry.from != null) {
    _vector(issues, '$path.from', geometry.from!);
  }
  if (geometry.to != null) {
    _vector(issues, '$path.to', geometry.to!);
  }
  for (int index = 0; index < geometry.points.length; index++) {
    _vector(issues, '$path.points[$index]', geometry.points[index]);
  }
  _optionalRange(issues, '$path.width', geometry.width, 0, 128);
  _optionalRange(issues, '$path.height', geometry.height, 0, 128);
  _optionalRange(issues, '$path.depth', geometry.depth, 0, 128);
  _range(issues, '$path.padding', geometry.padding, 0, 16);
  _range(issues, '$path.spacing', geometry.spacing, 0.02, 16);
  if (type == 'line' && (geometry.from == null || geometry.to == null)) {
    _error(issues, path, 'Line geometry requires both from and to vectors.');
  }
  if (type == 'polyline' && geometry.points.length < 2) {
    _error(
      issues,
      '$path.points',
      'Polyline geometry requires at least two points.',
    );
  }
}

void _placement(
  List<HuiIssue> issues,
  String path,
  GlossParticlePlacement placement,
) {
  _choice(
    issues,
    '$path.layer',
    placement.layer,
    glossParticlePlacementLayers,
    'placement layer',
  );
  _range(issues, '$path.depth', placement.depth, 0, 16);
  _vector(issues, '$path.offset', placement.offset);
}

void _particle(List<HuiIssue> issues, String path, GlossParticleSpec particle) {
  final String key = particle.key.trim().toLowerCase();
  if (!_keyPattern.hasMatch(key)) {
    _error(
      issues,
      '$path.key',
      'Particle keys must be canonical namespaced keys such as minecraft:dust.',
    );
  }
  final bool dust = key == 'minecraft:dust';
  if (dust) {
    final String? color = particle.color;
    if (color == null || !_colorPattern.hasMatch(color.trim().toLowerCase())) {
      _error(
        issues,
        '$path.color',
        'Dust particle colors must be six-digit RGB values such as #00ff00.',
      );
    }
    _optionalRange(issues, '$path.size', particle.size, 0.01, 4);
    if (particle.size == null) {
      _error(issues, '$path.size', 'A dust particle requires a size.');
    }
    return;
  }
  if (particle.color != null) {
    _error(
      issues,
      '$path.color',
      'Particle color is only valid for minecraft:dust.',
    );
  }
  if (particle.size != null) {
    _error(
      issues,
      '$path.size',
      'Particle size is only valid for minecraft:dust.',
    );
  }
}

void _emission(
  List<HuiIssue> issues,
  String path,
  GlossParticleEmission emission,
) {
  _clamp(issues, '$path.intervalTicks', emission.intervalTicks, 1, 200);
  _choice(
    issues,
    '$path.pattern',
    emission.pattern,
    glossParticleEmissionPatterns,
    'emission pattern',
  );
  _clamp(issues, '$path.periodTicks', emission.periodTicks, 1, 72000);
}

String _choice(
  List<HuiIssue> issues,
  String path,
  String value,
  List<String> choices,
  String noun,
) {
  final String normalized = value.trim();
  for (final String choice in choices) {
    if (choice.toLowerCase() == normalized.toLowerCase()) return choice;
  }
  _error(issues, path, '{noun} must be one of {choices}.', <String, Object?>{
    'noun': noun,
    'choices': choices.join(', '),
  });
  return '';
}

String? _optionalId(
  List<HuiIssue> issues,
  String path,
  String? value,
  String noun,
) {
  if (value == null) return null;
  final String normalized = _normalizedId(value);
  if (normalized.isEmpty ||
      normalized.length > 64 ||
      !_idPattern.hasMatch(normalized)) {
    _error(
      issues,
      path,
      '{noun} must match [a-z0-9][a-z0-9._-]* and be at most 64 characters.',
      <String, Object?>{'noun': noun},
    );
    return null;
  }
  return normalized;
}

String _normalizedId(String value) => value.trim().toLowerCase();

void _vector(List<HuiIssue> issues, String path, Vec3 vector) {
  if (vector.x.isFinite && vector.y.isFinite && vector.z.isFinite) return;
  _error(issues, path, 'Particle vectors must contain three finite numbers.');
}

void _optionalRange(
  List<HuiIssue> issues,
  String path,
  double? value,
  double minimum,
  double maximum,
) {
  if (value == null) return;
  _range(issues, path, value, minimum, maximum);
}

void _range(
  List<HuiIssue> issues,
  String path,
  double value,
  double minimum,
  double maximum,
) {
  if (value.isFinite && value >= minimum && value <= maximum) return;
  _error(
    issues,
    path,
    'Particle values here must be finite and between {minimum} and {maximum}.',
    <String, Object?>{'minimum': minimum, 'maximum': maximum},
  );
}

void _clamp(
  List<HuiIssue> issues,
  String path,
  int value,
  int minimum,
  int maximum,
) {
  if (value >= minimum && value <= maximum) return;
  issues.add(
    HuiIssue(
      severity: HuiSeverity.warning,
      path: path,
      message:
          'Gloss clamps {value} to the supported {minimum}..{maximum} range.',
      messageArguments: <String, Object?>{
        'value': value,
        'minimum': minimum,
        'maximum': maximum,
      },
      fix: 'Choose a value inside the runtime range.',
    ),
  );
}

void _error(
  List<HuiIssue> issues,
  String path,
  String message, [
  Map<String, Object?> arguments = const <String, Object?>{},
]) {
  issues.add(
    HuiIssue(
      severity: HuiSeverity.error,
      path: path,
      message: message,
      messageArguments: arguments,
      fix: 'Correct the value before exporting.',
    ),
  );
}
