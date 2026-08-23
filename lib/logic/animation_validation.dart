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

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) {
    issues.add(revisionIssue);
  }

  if (doc.normalizedMode == null) {
    if (doc.mode.trim().isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: r'$.mode',
          message:
              'The mode is missing; Gloss rejects an animation without one.',
          fix: "Use one of: {join}.",
          fixArguments: <String, Object?>{
            'join': glossAnimationModes.join(', '),
          },
        ),
      );
    } else {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: r'$.mode',
          message:
              '"{mode}" is not an animation mode; Gloss rejects the whole file.',
          messageArguments: <String, Object?>{'mode': doc.mode},
          fix: "Use one of: {join}.",
          fixArguments: <String, Object?>{
            'join': glossAnimationModes.join(', '),
          },
        ),
      );
    }
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
            "{frameIntervalMs} ms is outside 1..60000. Gloss loads the file but silently plays it at {effectiveFrameIntervalMs} ms.",
        messageArguments: <String, Object?>{
          'frameIntervalMs': doc.frameIntervalMs,
          'effectiveFrameIntervalMs': doc.effectiveFrameIntervalMs,
        },
        fix: 'Write the interval you actually want, between 1 and 60000.',
      ),
    );
  }

  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      for (int index = 0; index < doc.frames.length; index++)
        (path: 'frames[$index]', text: doc.frames[index]),
    ]),
  );

  return issues;
}
