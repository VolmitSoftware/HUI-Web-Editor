/// Validation for Gloss animation documents.
///
/// Errors are what `AnimationDoc.java` rejects at parse (revision range, an
/// unknown or blank mode, an empty frame list). The interval is the one field
/// the plugin fixes SILENTLY — clamped into 1..60000 without a log line
/// (`AnimationDoc.java:20`) — so an out-of-range value is a warning that
/// names the effective clamped value instead of an error.
library;

import '../model/gloss_animation.dart';
import '../model/gloss_doc.dart';
import 'validation.dart';

List<HuiIssue> validateAnimationDoc(GlossAnimationDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[];

  if (!glossRevisionInRange(doc.revision)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.revision',
        message:
            'Revision ${doc.revision} is outside 1..9007199254740991, so '
            'Gloss rejects the whole file.',
        fix:
            'The revision is server-owned; leave it at the value the server '
            'wrote, or 1 for a new document.',
      ),
    );
  }

  if (doc.normalizedMode == null) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.mode',
        message: doc.mode.trim().isEmpty
            ? 'The mode is missing; Gloss rejects an animation without one.'
            : '"${doc.mode}" is not an animation mode; Gloss rejects the '
                  'whole file.',
        fix: 'Use one of: ${glossAnimationModes.join(', ')}.',
      ),
    );
  }

  if (doc.frames.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.frames',
        message:
            'The animation has no frames; Gloss rejects an empty frame '
            'list.',
        fix: 'Add at least one frame of text.',
      ),
    );
  }

  if (doc.frameIntervalMs != doc.effectiveFrameIntervalMs) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.frameIntervalMs',
        message:
            '${doc.frameIntervalMs} ms is outside 1..60000. Gloss loads the '
            'file but silently plays it at '
            '${doc.effectiveFrameIntervalMs} ms.',
        fix: 'Write the interval you actually want, between 1 and 60000.',
      ),
    );
  }

  return issues;
}
