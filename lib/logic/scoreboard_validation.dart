/// Validation for conditional Gloss scoreboard documents.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_scoreboard.dart';
import 'gloss_text.dart';
import 'preview_expr.dart';
import 'validation.dart';

List<HuiIssue> validateScoreboardDoc(
  GlossScoreboardDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[];
  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  _validateCondition(doc.select.when, r'$.select.when', issues);
  _validatePresentation(
    doc.presentation,
    r'$.presentation',
    issues,
    animations,
    emoji,
  );

  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.variants.length; index++) {
    final GlossScoreboardVariant variant = doc.variants[index];
    final String path =
        r'$.variants['
        '$index]';
    final String normalizedId = variant.id.trim();
    if (normalizedId.isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message: 'A conditional variant id cannot be blank.',
          fix: 'Give the variant a stable id.',
        ),
      );
    } else if (!_validVariantId.hasMatch(normalizedId)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message:
              'Variant id "{id}" contains unsupported characters. Gloss accepts only letters, numbers, dots, hyphens and underscores.',
          messageArguments: <String, Object?>{'id': variant.id},
          fix: 'Use only letters, numbers, dots, hyphens and underscores.',
        ),
      );
    } else if (!ids.add(normalizedId)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message:
              'Variant id "{id}" is duplicated; priority ties use the id as the deterministic tiebreaker.',
          messageArguments: <String, Object?>{'id': variant.id},
          fix: 'Use a unique id.',
        ),
      );
    }
    _validateCondition(variant.when, '$path.when', issues);
    _validatePresentation(
      variant.presentation,
      '$path.presentation',
      issues,
      animations,
      emoji,
    );
  }

  final List<String> text = <String>[
    doc.presentation.title,
    ...doc.presentation.lines,
    for (final GlossScoreboardVariant variant in doc.variants) ...<String>[
      variant.presentation.title,
      ...variant.presentation.lines,
    ],
  ];
  final HuiIssue? metrics = glossMetricInfo(text);
  if (metrics != null) issues.add(metrics);
  return issues;
}

final RegExp _validVariantId = RegExp(r'^[A-Za-z0-9._-]+$');

void _validatePresentation(
  GlossScoreboardPresentation presentation,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
  GlossEmojiResolver emoji,
) {
  final int titleLength = glossTranslatedLength(
    presentation.title,
    animations,
    emoji: emoji,
  );
  if (titleLength > glossBoardMaxTitleLength) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '$path.title',
        message:
            'The rendered title is {titleLength} UTF-16 units; VolmLib caps it safely at {glossBoardMaxTitleLength}.',
        messageArguments: <String, Object?>{
          'titleLength': titleLength,
          'glossBoardMaxTitleLength': glossBoardMaxTitleLength,
        },
        fix: 'Shorten the title or use cheaper colour codes.',
      ),
    );
  }
  if (presentation.lines.length > glossBoardMaxLines) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '$path.lines',
        message:
            'The presentation has {length} lines; Gloss renders only the first {glossBoardMaxLines}.',
        messageArguments: <String, Object?>{
          'length': presentation.lines.length,
          'glossBoardMaxLines': glossBoardMaxLines,
        },
        fix: 'Trim the list to the visible line limit.',
      ),
    );
  }

  for (int index = 0; index < presentation.lines.length; index++) {
    final String line = presentation.lines[index];
    final String linePath = '$path.lines[$index]';
    final GlossScoreboardLineMeasure measure = measureGlossScoreboardLine(
      line,
      animations,
      emoji: emoji,
    );
    if (measure.truncated) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: linePath,
          message:
              'This rendered line uses {encodedLength} encoded characters; {deliveredVisibleLength} of {visibleLength} visible characters reach the client.',
          messageArguments: <String, Object?>{
            'encodedLength': measure.encodedLength,
            'deliveredVisibleLength': measure.deliveredVisibleLength,
            'visibleLength': measure.visibleLength,
          },
          fix: 'Shorten the line or remove formatting codes.',
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
          path: linePath,
          message:
              '|{reference}| names an animation document this workspace does not have; the text will show literally in game.',
          messageArguments: <String, Object?>{'reference': reference},
          fix: 'Create the animation document or select an existing one.',
        ),
      );
    }
  }
  for (final String reference in glossLineMissingAnimationRefs(
    presentation.title,
    animations,
  )) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '$path.title',
        message:
            '|{reference}| names an animation document this workspace does not have; the title will show literally in game.',
        messageArguments: <String, Object?>{'reference': reference},
        fix: 'Create the animation document or select an existing one.',
      ),
    );
  }
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: '$path.title', text: presentation.title),
      for (int index = 0; index < presentation.lines.length; index++)
        (path: '$path.lines[$index]', text: presentation.lines[index]),
    ]),
  );
}

void _validateCondition(String source, String path, List<HuiIssue> issues) {
  try {
    final PExpr expression = parsePreviewExpr(source);
    if (isConstantExpr(expression)) {
      final Object value = evalPreviewExpr(expression, _EmptyConditionScope());
      if (value is! bool) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.error,
            path: path,
            message: 'A condition must evaluate to true or false.',
            fix: 'Use a boolean comparison or boolean literal.',
          ),
        );
      }
    }
  } on PExprException catch (error) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message: 'Invalid condition: {error}',
        messageArguments: <String, Object?>{'error': error.message},
        fix: 'Correct the boolean expression.',
      ),
    );
  }
}

final class _EmptyConditionScope extends PExprScope {
  @override
  Object? call(String name, List<Object?> args) => null;

  @override
  Object? variable(String dottedName) => null;
}
