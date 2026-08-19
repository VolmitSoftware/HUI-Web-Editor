/// Validation for Gloss MOTD documents.
///
/// Errors are what `MotdDoc.java` rejects at parse: the revision range, a
/// document without entries, and an entry whose line count is outside
/// 1..`MAX_LINES_PER_ENTRY` (`MotdDoc.java:20-37`). The rest is what a ping
/// actually shows: `MotdService.handlePing` renders through `renderStatic`,
/// so `|animation.<id>|` references play (warn when dangling) while
/// PlaceholderAPI tokens stay literal — a ping has no viewer to expand them
/// for (`TextPipeline.render`: the placeholder stage requires a non-null
/// viewer).
library;

import '../model/gloss_doc.dart';
import '../model/gloss_motd.dart';
import 'gloss_text.dart';
import 'validation.dart';

/// The vanilla server list truncates rows client-side around this many
/// visible characters; longer lines risk an ellipsis. Client behavior, not a
/// plugin limit — guidance the same way the scoreboard's 40-character line
/// note is.
const int glossMotdMaxVisibleLineLength = 45;

List<HuiIssue> validateMotdDoc(
  GlossMotdDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
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

  if (doc.entries.isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.entries',
        message:
            'The document has no entries; Gloss rejects a MOTD without at '
            'least one.',
        fix: 'Add an entry with one or two lines.',
      ),
    );
  }

  for (int index = 0; index < doc.entries.length; index++) {
    final GlossMotdEntry entry = doc.entries[index];
    final String path = 'entries[$index]';
    if (entry.lines.isEmpty || entry.lines.length > glossMotdMaxLinesPerEntry) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.lines',
          message: entry.lines.isEmpty
              ? 'This entry has no lines; Gloss rejects the whole file — an '
                    'entry needs 1 to $glossMotdMaxLinesPerEntry.'
              : 'This entry has ${entry.lines.length} lines; Gloss rejects '
                    'the whole file past $glossMotdMaxLinesPerEntry.',
          fix: 'Give the entry one or two lines.',
        ),
      );
    }
    for (int line = 0; line < entry.lines.length; line++) {
      final String text = entry.lines[line];
      final String linePath = '$path.lines[$line]';
      final int visible = glossLineMaxVisibleLength(text, animations);
      if (visible > glossMotdMaxVisibleLineLength) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.warning,
            path: linePath,
            message:
                'This line shows $visible visible characters; the vanilla '
                'server list clips rows around '
                '$glossMotdMaxVisibleLineLength.',
            fix: 'Shorten the line.',
          ),
        );
      }
      for (final String reference in glossLineMissingAnimationRefs(
        text,
        animations,
      )) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.warning,
            path: linePath,
            message:
                '|$reference| names an animation document this workspace '
                'does not have; the text will show literally in the server '
                'list.',
            fix:
                'Create the animation document or pick an existing one from '
                'the reference picker.',
          ),
        );
      }
      final List<String> placeholders = renderGlossLine(
        text,
        animations: animations,
      ).placeholders;
      if (placeholders.isNotEmpty) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.info,
            path: linePath,
            message:
                '${placeholders.join(', ')} will stay literal: a server-list '
                'ping has no viewer, so PlaceholderAPI never runs for a '
                'MOTD.',
            fix: 'Remove the placeholder or accept the literal text.',
          ),
        );
      }
    }
  }

  final HuiIssue? metrics = glossMetricInfo(<String>[
    for (final GlossMotdEntry entry in doc.entries) ...entry.lines,
  ]);
  if (metrics != null) issues.add(metrics);

  return issues;
}
