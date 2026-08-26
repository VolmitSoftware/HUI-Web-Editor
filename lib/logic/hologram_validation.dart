/// Validation for Gloss hologram documents.
///
/// Severity contract, matching the rest of the editor: an `error` is
/// something the plugin's parser or constructor would reject — the file will
/// not load in game (`HologramDoc.java:35-44`, `DocumentEnvelope.java`); a
/// `warning` loads but almost certainly is not what the author meant.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_hologram.dart';
import 'gloss_text.dart';
import 'gloss_particle_text.dart';
import 'particle_layer_validation.dart';
import 'validation.dart';

List<HuiIssue> validateHologramDoc(
  GlossHologramDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[];

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) {
    issues.add(revisionIssue);
  }
  issues.addAll(
    validateParticleLayers(doc.particleLayers, path: r'$.particleLayers'),
  );

  if (!doc.scale.isFinite ||
      doc.scale < glossHologramMinScale ||
      doc.scale > glossHologramMaxScale) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.scale',
        message: 'Scale must be between 0.05 and 16.',
        fix: 'Scale must be between 0.05 and 16.',
      ),
    );
  }

  if (!doc.anchorPresent) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.anchor',
        message:
            'The anchor object is missing; Gloss rejects a hologram without '
            'one.',
        fix: 'Add "anchor": {"world": ..., "position": [x, y, z]}.',
      ),
    );
  } else {
    if (doc.anchor.world.trim().isEmpty) {
      issues.add(
        const HuiIssue(
          severity: HuiSeverity.error,
          path: r'$.anchor.world',
          message:
              'The anchor world is empty; Gloss rejects a hologram without '
              'one.',
          fix: 'Name the world the hologram stands in, e.g. "world".',
        ),
      );
    }
    if (!doc.anchor.positionIsValidTriple) {
      issues.add(
        const HuiIssue(
          severity: HuiSeverity.error,
          path: r'$.anchor.position',
          message:
              'The anchor position must be exactly three finite numbers '
              '[x, y, z]; Gloss rejects anything else.',
          fix: 'Write the position as [x, y, z].',
        ),
      );
    }
  }

  if (!glossHologramBillboards.contains(doc.billboard)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.billboard',
        message:
            "\"{billboard}\" is not a billboard mode; Gloss rejects the whole file unless it is one of {join}.",
        messageArguments: <String, Object?>{
          'billboard': doc.billboard,
          'join': glossHologramBillboards.join(', '),
        },
        fix: 'Pick CENTER, VERTICAL, HORIZONTAL or FIXED.',
      ),
    );
  }

  issues.addAll(
    <HuiIssue?>[
      _angleIssue(r'$.yaw', 'yaw', doc.yaw, glossHologramMaxYawDegrees),
      _angleIssue(r'$.pitch', 'pitch', doc.pitch, glossHologramMaxPitchDegrees),
    ].whereType<HuiIssue>(),
  );

  if (doc.billboard == 'CENTER' && (doc.yaw != 0 || doc.pitch != 0)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.billboard',
        message:
            'CENTER turns on both axes, so this yaw and pitch never reach '
            'the screen: every viewer sees the hologram square-on anyway.',
        fix:
            'Switch to FIXED to use both angles, VERTICAL to keep the pitch, '
            'or HORIZONTAL to keep the yaw.',
      ),
    );
  }

  if (doc.lines.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.lines',
        message:
            'The hologram has no lines. Gloss accepts the file but renders '
            'nothing at the anchor.',
        fix: 'Add at least one line of text.',
      ),
    );
  }

  final String? particleSpanError = glossParticleTextSyntaxError(
    doc.lines.join('\n'),
  );
  if (particleSpanError != null) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.lines',
        message: 'Invalid particle text span: {error}',
        messageArguments: <String, Object?>{'error': particleSpanError},
        fix: 'Correct the value before exporting.',
      ),
    );
  }

  for (int index = 0; index < doc.lines.length; index++) {
    for (final String reference in glossLineMissingAnimationRefs(
      doc.lines[index],
      animations,
    )) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: 'lines[$index]',
          message:
              "|{reference}| names an animation document this workspace does not have; the text will show literally in game.",
          messageArguments: <String, Object?>{'reference': reference},
          fix:
              'Create the animation document or pick an existing one from '
              'the reference picker.',
        ),
      );
    }
  }

  final HuiIssue? metrics = glossMetricInfo(doc.lines);
  if (metrics != null) issues.add(metrics);
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      for (int index = 0; index < doc.lines.length; index++)
        (path: 'lines[$index]', text: doc.lines[index]),
    ]),
  );

  return issues;
}

/// An angle the plugin's constructor would throw on: `HologramDoc.requireAngle`
/// demands a finite value within the axis limit (`HologramDoc.java:84-92`).
HuiIssue? _angleIssue(String path, String axis, double value, double limit) {
  if (value.isFinite && value.abs() <= limit) return null;
  return HuiIssue(
    severity: HuiSeverity.error,
    path: path,
    message:
        "A {axis} of {value} is out of range; Gloss rejects the whole file unless it is between -{limit} and {limit2} degrees.",
    messageArguments: <String, Object?>{
      'axis': axis,
      'value': value,
      'limit': limit,
      'limit2': limit,
    },
    fix: "Use a {axis} between -{toInt} and {toInt2}.",
    fixArguments: <String, Object?>{
      'axis': axis,
      'toInt': limit.toInt(),
      'toInt2': limit.toInt(),
    },
  );
}
