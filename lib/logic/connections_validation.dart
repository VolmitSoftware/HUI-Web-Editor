/// Validation for Gloss connection-message documents.
///
/// Errors are what `ConnectionsDoc.java` refuses at parse: the revision range,
/// an audience outside `AUDIENCES`, and a variant whose condition is blank or
/// does not compile. The rest is what a standalone server actually does with
/// the file: `audience` and the proxy's `switch` block are read and ignored
/// because one server is the whole network, and the text renders per
/// recipient, so `{{ subject.name }}` is the connecting player and
/// `{{ viewer.name }}` is the reader.
library;

import '../model/gloss_connections.dart';
import '../model/gloss_doc.dart';
import 'gloss_condition_validation.dart';
import 'gloss_show.dart';
import 'gloss_text.dart';
import 'validation.dart';

/// What a connection message reads: `ConnectionsService.render` builds a
/// scope around the recipient and the connecting player, so the text sees
/// `viewer.*` and `subject.*` exactly as a condition does.
const GlossTextExpressionSamples glossConnectionsSamples =
    GlossTextExpressionSamples(values: glossScopedSampleValues);

/// The tablist's own substitution token. A connection message never runs it,
/// so a line that carries it ships a literal `$player` to chat.
const String glossConnectionsForeignToken = r'$player';

List<HuiIssue> validateConnectionsDoc(
  GlossConnectionsDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[
    ...validateGlossShow(doc.extras['show']),
  ];

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  for (final String key in glossConnectionsSectionKeys) {
    _validateSection(doc.section(key), r'$.' + key, issues, animations);
  }

  final HuiIssue? metrics = glossMetricInfo(<String>[
    for (final String key in glossConnectionsSectionKeys)
      if (doc.section(key).present) ...<String>[
        doc.section(key).presentation.text,
        for (final GlossConnectionsVariant variant in doc.section(key).variants)
          variant.presentation.text,
      ],
  ]);
  if (metrics != null) issues.add(metrics);

  return issues;
}

void _validateSection(
  GlossConnectionsSection section,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  // An absent block is Section.DISABLED: it broadcasts nothing, so there is
  // nothing in it to be wrong.
  if (!section.present) return;

  issues.addAll(validateGlossShow(section.extras['show'], path: '$path.show'));
  _validateAudience(section.audience, '$path.audience', issues);
  _validateText(
    section.presentation.text,
    '$path.presentation.text',
    issues,
    animations,
    required: section.enabled,
  );

  for (int index = 0; index < section.variants.length; index++) {
    final GlossConnectionsVariant variant = section.variants[index];
    final String variantPath = '$path.variants[$index]';
    if (variant.when.trim().isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$variantPath.when',
          message:
              'A connection-message variant needs a condition; Gloss refuses '
              'the whole file when one is blank.',
          fix: 'Give the variant a condition, or delete it.',
        ),
      );
    } else {
      issues.addAll(glossConditionIssues(variant.when, '$variantPath.when'));
    }
    _validateText(
      variant.presentation.text,
      '$variantPath.presentation.text',
      issues,
      animations,
      required: section.enabled,
    );
  }
}

void _validateAudience(String audience, String path, List<HuiIssue> issues) {
  if (!glossConnectionsAudiences.contains(audience)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Audience "{audience}" is not one of {allowed}; Gloss refuses the '
            'whole file.',
        messageArguments: <String, Object?>{
          'audience': audience,
          'allowed': glossConnectionsAudiences.join(', '),
        },
        fix: 'Use network or server.',
      ),
    );
  }
  // A listed spelling is not worth an issue on every document: the server
  // ignores it either way, and the field's own help says so once.
}

void _validateText(
  String text,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations, {
  required bool required,
}) {
  if (text.trim().isEmpty) {
    if (required) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: path,
          message:
              'This message is on with no text, so every connection sends a '
              'blank line to chat.',
          fix: 'Write the line, or turn the message off.',
        ),
      );
    }
    return;
  }
  if (text.contains(glossConnectionsForeignToken)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: path,
        message:
            r'$player is a tab-list token. A connection message renders per '
            r'recipient, so write {{ subject.name }} for the connecting '
            r'player and {{ viewer.name }} for the reader.',
        fix: r'Replace $player with {{ subject.name }}.',
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
        path: path,
        message:
            '|{reference}| names an animation document this workspace does not have; the text will show literally in the {surface}.',
        messageArguments: <String, Object?>{
          'reference': reference,
          'surface': 'chat line',
        },
        fix: 'Create the animation document or select an existing one.',
      ),
    );
  }
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: path, text: text),
    ], expressionSamples: glossConnectionsSamples),
  );
}
