/// Validation for Gloss hologram documents.
///
/// Severity contract, matching the rest of the editor: an `error` is
/// something the plugin's parser or constructor would reject — the file will
/// not load in game (`HologramDoc.java:29-33`, `DocumentEnvelope.java`); a
/// `warning` loads but almost certainly is not what the author meant.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_hologram.dart';
import 'gloss_text.dart';
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
              '|$reference| names an animation document this workspace does '
              'not have; the text will show literally in game.',
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
