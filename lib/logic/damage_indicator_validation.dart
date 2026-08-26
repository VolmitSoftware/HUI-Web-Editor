library;

import '../model/gloss_damage_indicators.dart';
import '../model/gloss_doc.dart';
import 'gloss_particle_text.dart';
import 'preview_expr.dart';
import 'particle_layer_validation.dart';
import 'validation.dart';

final RegExp _validVariantId = RegExp(r'^[A-Za-z0-9._-]+$');

List<HuiIssue> validateDamageIndicatorsDoc(GlossDamageIndicatorsDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[];
  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  _range(issues, r'$.limits.maxPerSecond', doc.limits.maxPerSecond, 1, 1000);
  _range(issues, r'$.limits.lifetimeMs', doc.limits.lifetimeMs, 250, 30000);
  _range(issues, r'$.limits.minimumDelta', doc.limits.minimumDelta, 0, 1000);
  _range(issues, r'$.limits.decimals', doc.limits.decimals, 0, 4);
  _style(issues, r'$.damage', doc.damage);
  _style(issues, r'$.healing', doc.healing);
  _condition(issues, r'$.audience.when', doc.audience.when);
  return issues;
}

void _style(
  List<HuiIssue> issues,
  String path,
  GlossDamageIndicatorStyle style,
) {
  _condition(issues, '$path.when', style.when);
  _presentation(issues, '$path.presentation', style.presentation);
  final Set<String> ids = <String>{};
  for (int index = 0; index < style.variants.length; index++) {
    final GlossDamageIndicatorVariant variant = style.variants[index];
    final String variantPath = '$path.variants[$index]';
    final String id = variant.id.trim();
    if (id.isEmpty) {
      _error(issues, '$variantPath.id', 'Variant ids must not be blank.');
    } else if (!_validVariantId.hasMatch(id)) {
      _error(
        issues,
        '$variantPath.id',
        'Variant ids accept only letters, numbers, dots, hyphens and underscores.',
      );
    } else if (!ids.add(id)) {
      _error(issues, '$variantPath.id', 'Variant id "{id}" is duplicated.', {
        'id': id,
      });
    }
    _condition(issues, '$variantPath.when', variant.when);
    _presentation(issues, '$variantPath.presentation', variant.presentation);
  }
}

void _presentation(
  List<HuiIssue> issues,
  String path,
  GlossDamageIndicatorPresentation presentation,
) {
  if (!presentation.format.contains(glossDamageAmountToken)) {
    _error(
      issues,
      '$path.format',
      'The format must contain {amount}; Gloss rejects this document without it.',
    );
  }
  final String? particleSpanError = glossParticleTextSyntaxError(
    presentation.format,
  );
  if (particleSpanError != null) {
    _error(
      issues,
      '$path.format',
      'Invalid particle text span: {error}',
      <String, Object?>{'error': particleSpanError},
    );
  }
  _range(issues, '$path.offset.x', presentation.offset.x, -32, 32);
  _range(issues, '$path.offset.y', presentation.offset.y, -32, 32);
  _range(issues, '$path.offset.z', presentation.offset.z, -32, 32);
  _range(
    issues,
    '$path.motion.horizontalSpeed',
    presentation.motion.horizontalSpeed,
    0,
    16,
  );
  _range(
    issues,
    '$path.motion.verticalSpeed',
    presentation.motion.verticalSpeed,
    -16,
    16,
  );
  _range(
    issues,
    '$path.motion.verticalAcceleration',
    presentation.motion.verticalAcceleration,
    -32,
    32,
  );
  _range(
    issues,
    '$path.motion.spinDegreesPerSecond',
    presentation.motion.spinDegreesPerSecond,
    -1440,
    1440,
  );
  _range(
    issues,
    '$path.transform.startScale',
    presentation.transform.startScale,
    0,
    16,
  );
  _range(
    issues,
    '$path.transform.endScale',
    presentation.transform.endScale,
    0,
    16,
  );
  _range(
    issues,
    '$path.transform.fadeStartFraction',
    presentation.transform.fadeStartFraction,
    0,
    1,
  );
  issues.addAll(
    validateParticleLayers(
      presentation.particleLayers,
      path: '$path.particleLayers',
    ),
  );
}

void _condition(List<HuiIssue> issues, String path, String source) {
  try {
    final PExpr expression = parsePreviewExpr(source);
    if (isConstantExpr(expression)) {
      final Object value = evalPreviewExpr(expression, _EmptyScope());
      if (value is! bool) {
        _error(issues, path, 'A condition must evaluate to true or false.');
      }
    }
  } on PExprException catch (error) {
    _error(issues, path, 'Invalid condition: {error}', <String, Object?>{
      'error': error.message,
    });
  }
}

void _range(
  List<HuiIssue> issues,
  String path,
  num value,
  num minimum,
  num maximum,
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

final class _EmptyScope extends PExprScope {
  @override
  Object? call(String name, List<Object?> args) => null;

  @override
  Object? variable(String dottedName) => null;
}
