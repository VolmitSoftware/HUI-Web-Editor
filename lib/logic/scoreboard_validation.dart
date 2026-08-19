/// Validation for Gloss scoreboard documents.
///
/// `BoardDoc.java` rejects almost nothing — it normalizes silently — so the
/// only error here is the envelope's revision range. Everything else is a
/// warning about what the server will actually show: the 15-line render cap
/// and 32-character title truncation live in `BoardService.java:40-41`, the
/// 40-character line guidance is the vanilla sidebar's classic limit, and
/// the normalization notes surface what `normalizePermission` /
/// `normalizeGroups` will quietly rewrite.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_scoreboard.dart';
import 'gloss_text.dart';
import 'validation.dart';

/// Vanilla's classic sidebar line width; longer lines risk client-side
/// truncation on the versions Gloss targets.
const int glossBoardMaxLineLength = 40;

List<HuiIssue> validateScoreboardDoc(
  GlossScoreboardDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
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

  final int titleLength = glossTranslatedLength(
    doc.title,
    animations,
    emoji: emoji,
  );
  if (titleLength > glossBoardMaxTitleLength) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.title',
        message:
            'The rendered title is $titleLength characters; Gloss cuts it at '
            '$glossBoardMaxTitleLength — colour codes count, and a [RRGGBB] '
            'tag costs 14.',
        fix: 'Shorten the title or use cheaper colour codes.',
      ),
    );
  }

  if (doc.lines.length > glossBoardMaxLines) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.lines',
        message:
            'The board has ${doc.lines.length} lines; Gloss renders only the '
            'first $glossBoardMaxLines.',
        fix: 'Trim the list — everything past line $glossBoardMaxLines is '
            'invisible in game.',
      ),
    );
  }

  for (int index = 0; index < doc.lines.length; index++) {
    final String line = doc.lines[index];
    final int visible = glossLineMaxVisibleLength(
      line,
      animations,
      emoji: emoji,
    );
    if (visible > glossBoardMaxLineLength) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: 'lines[$index]',
          message:
              'This line shows $visible visible characters; the vanilla '
              'sidebar clips past $glossBoardMaxLineLength.',
          fix: 'Shorten the line.',
        ),
      );
    }
    for (final String reference in glossLineMissingAnimationRefs(
      line,
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

  for (final String reference in glossLineMissingAnimationRefs(
    doc.title,
    animations,
  )) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.title',
        message:
            '|$reference| names an animation document this workspace does '
            'not have; the title will show it literally in game.',
        fix:
            'Create the animation document or pick an existing one from the '
            'reference picker.',
      ),
    );
  }

  if (doc.permission != doc.effectivePermission) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.permission',
        message:
            'Gloss normalizes "${doc.permission}" to '
            '"${doc.effectivePermission}" (trimmed, lowercased; blank means '
            'default).',
        fix: 'Write the normalized form to keep the file honest.',
      ),
    );
  }

  if (doc.groups.length != doc.effectiveGroups.length ||
      !_sameStrings(doc.groups, doc.effectiveGroups)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.groups',
        message:
            'Gloss normalizes the groups to '
            '[${doc.effectiveGroups.join(', ')}] — trimmed, lowercased, '
            'blanks dropped, duplicates removed.',
        fix: 'Write the normalized names to keep the file honest.',
      ),
    );
  }

  return issues;
}

bool _sameStrings(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (int index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
