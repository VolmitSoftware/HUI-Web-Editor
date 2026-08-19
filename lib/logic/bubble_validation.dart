/// Validation for Gloss bubble-style documents.
///
/// `BubbleStyleDoc.java` rejects almost nothing: beyond the envelope, only a
/// present-but-malformed `offset` kills the file (the strict `[x, y, z]`
/// Vector adapter). The three numeric fields clamp SILENTLY
/// (`BubbleStyleDoc.java:26-28`), so out-of-range values are warnings that
/// name the effective value, per the wave-1 convention. The select notes
/// mirror `BubbleStyles.resolveStyleId` and `Select.cleanStrings`.
library;

import '../model/gloss_bubble_style.dart';
import '../model/gloss_doc.dart';
import 'validation.dart';

List<HuiIssue> validateBubbleStyleDoc(GlossBubbleStyleDoc doc) {
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

  if (!doc.offsetIsValidTriple) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.offset',
        message:
            'The offset must be exactly three finite numbers [x, y, z]; '
            'Gloss rejects anything else. Leaving the key out entirely is '
            'fine — the plugin then uses [0, 1, 0].',
        fix: 'Write the offset as [x, y, z].',
      ),
    );
  }

  void clampWarning(String key, int written, int effective, int min, int max) {
    if (written == effective) return;
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '\$.$key',
        message:
            '$written is outside $min..$max. Gloss loads the file but '
            'silently runs $effective.',
        fix: 'Write the value you actually want, between $min and $max.',
      ),
    );
  }

  clampWarning(
    'wordWrapChars',
    doc.wordWrapChars,
    doc.effectiveWordWrapChars,
    glossBubbleMinWordWrapChars,
    glossBubbleMaxWordWrapChars,
  );
  clampWarning(
    'lineStaggerTicks',
    doc.lineStaggerTicks,
    doc.effectiveLineStaggerTicks,
    glossBubbleMinLineStaggerTicks,
    glossBubbleMaxLineStaggerTicks,
  );
  clampWarning(
    'maxAliveMs',
    doc.maxAliveMs,
    doc.effectiveMaxAliveMs,
    glossBubbleMinMaxAliveMs,
    glossBubbleMaxMaxAliveMs,
  );

  final GlossBubbleSelect? select = doc.select;
  if (select == null) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.select',
        message:
            'No select rule: this style never auto-matches. Players reach '
            'it only by explicit choice (needing '
            '$glossBubbleStylePermissionPrefix<id>), or as the fallback '
            'when the file is named "$glossBubbleDefaultStyleId".',
        fix: 'Add a select rule to auto-apply it by world or group.',
      ),
    );
  } else {
    if (select.worlds.length != select.effectiveWorlds.length) {
      issues.add(
        const HuiIssue(
          severity: HuiSeverity.info,
          path: r'$.select.worlds',
          message:
              'Blank world entries are silently dropped; the rest are '
              'trimmed.',
          fix: 'Remove the empty entries to keep the file honest.',
        ),
      );
    }
    if (select.groups.length != select.effectiveGroups.length ||
        !_sameStrings(select.groups, select.effectiveGroups)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.info,
          path: r'$.select.groups',
          message:
              'Gloss normalizes the groups to '
              '[${select.effectiveGroups.join(', ')}] — trimmed, lowercased, '
              'blanks dropped.',
          fix: 'Write the normalized names to keep the file honest.',
        ),
      );
    }
    if (select.effectiveWorlds.isEmpty && select.effectiveGroups.isEmpty) {
      issues.add(
        const HuiIssue(
          severity: HuiSeverity.info,
          path: r'$.select',
          message:
              'A select with no worlds and no groups matches every player '
              'in every world — only its priority separates it from other '
              'auto-matching styles.',
          fix: 'Constrain it, or lean on priority deliberately.',
        ),
      );
    }
  }

  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: r'$.prefix', text: doc.prefix),
    ]),
  );

  return issues;
}

bool _sameStrings(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (int index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
