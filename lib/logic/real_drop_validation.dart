library;

import '../model/gloss_doc.dart';
import '../model/gloss_real_drops.dart';
import 'real_drop_script.dart';
import 'validation.dart';

List<HuiIssue> validateRealDropSettingsDoc(GlossRealDropSettingsDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[];
  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  _range(
    issues,
    r'$.limits.updateIntervalTicks',
    doc.limits.updateIntervalTicks,
    1,
    20,
  );
  _range(
    issues,
    r'$.limits.settledPollIntervalTicks',
    doc.limits.settledPollIntervalTicks,
    2,
    200,
  );
  _range(
    issues,
    r'$.limits.maxVisualsPerStack',
    doc.limits.maxVisualsPerStack,
    1,
    5,
  );
  _range(
    issues,
    r'$.limits.maxVisualsPerChunk',
    doc.limits.maxVisualsPerChunk,
    8,
    1024,
  );
  _range(issues, r'$.limits.viewRange', doc.limits.viewRange, 4, 128);
  _range(issues, r'$.limits.spread', doc.limits.spread, 0, 1);
  _range(issues, r'$.scale.defaultScale', doc.scale.defaultScale, 0.05, 2);
  _range(issues, r'$.scale.flatItems', doc.scale.flatItems, 0.05, 2);
  _range(issues, r'$.scale.thinBlocks', doc.scale.thinBlocks, 0.05, 2);
  _range(
    issues,
    r'$.motion.speedMultiplier',
    doc.motion.speedMultiplier,
    0.1,
    4,
  );
  _range(
    issues,
    r'$.motion.degreesPerSecondX',
    doc.motion.degreesPerSecondX,
    -1440,
    1440,
  );
  _range(
    issues,
    r'$.motion.degreesPerSecondY',
    doc.motion.degreesPerSecondY,
    -1440,
    1440,
  );
  _range(
    issues,
    r'$.motion.degreesPerSecondZ',
    doc.motion.degreesPerSecondZ,
    -1440,
    1440,
  );
  _range(issues, r'$.motion.variance', doc.motion.variance, 0, 1);
  _range(
    issues,
    r'$.motion.velocityInfluence',
    doc.motion.velocityInfluence,
    0,
    4,
  );
  _range(
    issues,
    r'$.motion.submergedSpinMultiplier',
    doc.motion.submergedSpinMultiplier,
    0,
    1,
  );
  _range(
    issues,
    r'$.motion.groundRollMultiplier',
    doc.motion.groundRollMultiplier,
    0,
    4,
  );
  _range(issues, r'$.landing.tiltDegrees', doc.landing.tiltDegrees, 0, 45);
  _range(
    issues,
    r'$.landing.transitionTicks',
    doc.landing.transitionTicks,
    0,
    20,
  );
  _range(issues, r'$.landing.faceAttraction', doc.landing.faceAttraction, 0, 1);
  _range(
    issues,
    r'$.landing.movingFaceAttraction',
    doc.landing.movingFaceAttraction,
    0,
    1,
  );
  _range(
    issues,
    r'$.landing.alignmentDegrees',
    doc.landing.alignmentDegrees,
    0.05,
    10,
  );
  _range(
    issues,
    r'$.landing.settleDelayTicks',
    doc.landing.settleDelayTicks,
    0,
    100,
  );
  _choice(issues, r'$.landing.mode', doc.landing.mode, const <String>{
    'NATURAL',
    'FLAT',
    'UPRIGHT',
  });
  _range(issues, r'$.labels.yOffset', doc.labels.yOffset, 0, 4);
  _range(issues, r'$.labels.scale', doc.labels.scale, 0.1, 4);
  _range(issues, r'$.labels.viewRange', doc.labels.viewRange, 4, 128);
  _choice(issues, r'$.labels.billboard', doc.labels.billboard, const <String>{
    'CENTER',
    'FIXED',
    'HORIZONTAL',
    'VERTICAL',
  });
  _range(issues, r'$.labels.backgroundRed', doc.labels.backgroundRed, 0, 255);
  _range(
    issues,
    r'$.labels.backgroundGreen',
    doc.labels.backgroundGreen,
    0,
    255,
  );
  _range(issues, r'$.labels.backgroundBlue', doc.labels.backgroundBlue, 0, 255);
  _range(
    issues,
    r'$.labels.backgroundAlpha',
    doc.labels.backgroundAlpha,
    0,
    255,
  );
  _physics(issues, doc.physics);
  _script(issues, doc.script);
  return issues;
}

/// The physics block's four clamps. Warnings, like every other clamp in this
/// file: the server silently pins an out-of-range number at load rather than
/// refusing the document, so the file is still valid and the author is only
/// told the value will not survive.
void _physics(List<HuiIssue> issues, GlossRealDropPhysics? physics) {
  if (physics == null) return;
  _range(
    issues,
    r'$.physics.gravityMultiplier',
    physics.gravityMultiplier,
    0,
    4,
  );
  _range(issues, r'$.physics.bounce', physics.bounce, 0, 0.9);
  _range(issues, r'$.physics.waterBuoyancy', physics.waterBuoyancy, 0, 1);
  _range(issues, r'$.physics.waterDrag', physics.waterDrag, 0, 1);
}

/// Every expression in the script block, compiled and type-checked the way the
/// server does at load.
///
/// These are errors, not warnings, and they are raised whether or not
/// `script.enabled` is set: a problem in any expression refuses the whole
/// document, so a broken expression behind a switch that is off still means the
/// file will not load. The message is the server's own, so the console line an
/// operator would see and the line the inspector shows are the same sentence.
void _script(List<HuiIssue> issues, GlossRealDropScript? script) {
  if (script == null) return;
  for (final RealDropScriptIssue issue in RealDropScriptPlan.compile(
    script,
  ).issues) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: issue.path,
        message: issue.message,
        fix: 'Gloss refuses the whole document until this expression parses.',
      ),
    );
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
      message: 'Gloss clamps this value to $minimum..$maximum at load time.',
      fix: 'Choose a value inside the supported range.',
    ),
  );
}

void _choice(
  List<HuiIssue> issues,
  String path,
  String value,
  Set<String> allowed,
) {
  if (allowed.contains(value.toUpperCase())) return;
  issues.add(
    HuiIssue(
      severity: HuiSeverity.warning,
      path: path,
      message: 'Gloss does not recognize "$value" and uses ${allowed.first}.',
      fix: 'Choose ${allowed.join(', ')}.',
    ),
  );
}
