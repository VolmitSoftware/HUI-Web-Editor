library;

import '../model/gloss_damage_indicators.dart';
import '../model/gloss_doc.dart';
import 'validation.dart';

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

  if (!doc.damage.enabled && !doc.healing.enabled) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.damage.enabled',
        message:
            'Damage and healing indicators are both disabled, so the service stays idle.',
        fix: 'Enable at least one indicator type to show combat numbers.',
      ),
    );
  }

  final Set<String> worlds = <String>{};
  for (int index = 0; index < doc.filters.disabledWorlds.length; index++) {
    final String world = doc.filters.disabledWorlds[index];
    if (world.trim().isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: '\$.filters.disabledWorlds[$index]',
          message: 'Blank disabled-world entries are ignored.',
          fix: 'Remove the blank entry or enter a world folder name.',
        ),
      );
    } else if (!worlds.add(world)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.info,
          path: '\$.filters.disabledWorlds[$index]',
          message: 'The world "{world}" is listed more than once.',
          messageArguments: <String, Object?>{'world': world},
          fix: 'Keep one entry for each disabled world.',
        ),
      );
    }
  }
  return issues;
}

void _style(
  List<HuiIssue> issues,
  String path,
  GlossDamageIndicatorStyle style,
) {
  if (!style.format.contains(glossDamageAmountToken)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: '$path.format',
        message:
            'The format must contain {amount}; Gloss rejects this document without it.',
        fix: 'Insert {amount} where the formatted number should appear.',
      ),
    );
  }
  _range(issues, '$path.offset.x', style.offset.x, -32, 32);
  _range(issues, '$path.offset.y', style.offset.y, -32, 32);
  _range(issues, '$path.offset.z', style.offset.z, -32, 32);
  _range(
    issues,
    '$path.motion.horizontalSpeed',
    style.motion.horizontalSpeed,
    0,
    16,
  );
  _range(
    issues,
    '$path.motion.verticalSpeed',
    style.motion.verticalSpeed,
    -16,
    16,
  );
  _range(
    issues,
    '$path.motion.verticalAcceleration',
    style.motion.verticalAcceleration,
    -32,
    32,
  );
  _range(
    issues,
    '$path.motion.spinDegreesPerSecond',
    style.motion.spinDegreesPerSecond,
    -1440,
    1440,
  );
  _range(
    issues,
    '$path.presentation.startScale',
    style.presentation.startScale,
    0,
    16,
  );
  _range(
    issues,
    '$path.presentation.endScale',
    style.presentation.endScale,
    0,
    16,
  );
  _range(
    issues,
    '$path.presentation.fadeStartFraction',
    style.presentation.fadeStartFraction,
    0,
    1,
  );
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
