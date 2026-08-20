/// Validation for Gloss tablist documents.
///
/// `TablistDoc.java` rejects nothing beyond the envelope — it normalizes the
/// format keys silently (`copyFormats`) — so everything else here reports
/// what the tab screen will actually do: disabled halves whose content goes
/// unused, the blank-template reset, the missing-`default` fallback, and
/// dangling animation references (header, footer and list names all render
/// through the text pipeline per viewer, `TablistService.renderSafe`).
library;

import '../model/gloss_doc.dart';
import '../model/gloss_tablist.dart';
import 'gloss_text.dart';
import 'validation.dart';

List<HuiIssue> validateTablistDoc(
  GlossTablistDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[];

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) {
    issues.add(revisionIssue);
  }

  if (!doc.useHeaderFooter &&
      (doc.header.isNotEmpty || doc.footer.isNotEmpty)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.useHeaderFooter',
        message:
            'The header and footer are written but useHeaderFooter is off, '
            'so the tab screen never shows them.',
        fix: 'Turn useHeaderFooter on, or clear the texts.',
      ),
    );
  }

  if (!doc.groupListNames && doc.nameFormats.isNotEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.groupListNames',
        message:
            'Name formats are written but groupListNames is off, so every '
            'list name stays vanilla.',
        fix: 'Turn groupListNames on, or clear the formats.',
      ),
    );
  }

  final Map<String, String> effective = doc.effectiveNameFormats;
  final List<String> writtenKeys = doc.nameFormats.keys.toList();
  final List<String> effectiveKeys = effective.keys.toList();
  if (writtenKeys.length != effectiveKeys.length ||
      !_sameStrings(writtenKeys, effectiveKeys)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.nameFormats',
        message:
            'Gloss normalizes the format keys to '
            '[${effectiveKeys.join(', ')}] — trimmed, lowercased, blank '
            'keys dropped.',
        fix: 'Write the normalized keys to keep the file honest.',
      ),
    );
  }

  if (doc.groupListNames &&
      !effective.containsKey(glossTablistDefaultGroupKey)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.nameFormats',
        message:
            'No "default" entry: players in unlisted groups fall to the '
            'literal "\$player" fallback format.',
        fix: 'Add a "default" format to control the fallback.',
      ),
    );
  }

  for (final MapEntry<String, String> entry in effective.entries) {
    if (entry.value.trim().isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.info,
          path: r'$.nameFormats',
          message:
              'The "${entry.key}" format is blank, which RESETS matching '
              'players to their vanilla list name rather than applying an '
              'empty one.',
          fix: 'Give it a format, or keep the reset deliberately.',
        ),
      );
    }
  }

  void danglingRefs(String text, String path, String where) {
    for (final String reference in glossLineMissingAnimationRefs(
      text,
      animations,
    )) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: path,
          message:
              '|$reference| names an animation document this workspace does '
              'not have; the text will show literally in $where.',
          fix:
              'Create the animation document or pick an existing one from '
              'the reference picker.',
        ),
      );
    }
  }

  danglingRefs(doc.header, r'$.header', 'the tab header');
  danglingRefs(doc.footer, r'$.footer', 'the tab footer');
  for (final MapEntry<String, String> entry in effective.entries) {
    danglingRefs(entry.value, r'$.nameFormats', 'the "${entry.key}" list name');
  }

  final HuiIssue? metrics = glossMetricInfo(<String>[
    doc.header,
    doc.footer,
    ...doc.nameFormats.values,
  ]);
  if (metrics != null) issues.add(metrics);
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: r'$.header', text: doc.header),
      (path: r'$.footer', text: doc.footer),
      for (final MapEntry<String, String> entry in doc.nameFormats.entries)
        (path: r'$.nameFormats', text: entry.value),
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
