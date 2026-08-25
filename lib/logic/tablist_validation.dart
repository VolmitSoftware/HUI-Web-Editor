/// Validation for conditional Gloss tablist documents.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_tablist.dart';
import 'gloss_text.dart';
import 'preview_expr.dart';
import 'validation.dart';

List<HuiIssue> validateTablistDoc(
  GlossTablistDoc doc, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
}) {
  final List<HuiIssue> issues = <HuiIssue>[];
  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) issues.add(revisionIssue);

  _validateHeaderFooterPresentation(
    doc.headerFooter.presentation,
    r'$.headerFooter.presentation',
    issues,
    animations,
  );
  _validateHeaderFooterVariants(doc, issues, animations);
  _validateListNamePresentation(
    doc.listNames.presentation,
    r'$.listNames.presentation',
    issues,
    animations,
  );
  _validateListNameVariants(doc, issues, animations);

  final List<String> allText = <String>[
    doc.headerFooter.presentation.header,
    doc.headerFooter.presentation.footer,
    doc.listNames.presentation.format,
    for (final GlossTablistHeaderFooterVariant variant
        in doc.headerFooter.variants) ...<String>[
      variant.presentation.header,
      variant.presentation.footer,
    ],
    for (final GlossTablistListNameVariant variant in doc.listNames.variants)
      variant.presentation.format,
  ];
  final HuiIssue? metrics = glossMetricInfo(allText);
  if (metrics != null) issues.add(metrics);
  return issues;
}

void _validateHeaderFooterVariants(
  GlossTablistDoc doc,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.headerFooter.variants.length; index++) {
    final GlossTablistHeaderFooterVariant variant =
        doc.headerFooter.variants[index];
    final String path =
        r'$.headerFooter.variants['
        '$index]';
    _validateVariantIdentity(variant.id, '$path.id', ids, issues);
    _validateCondition(variant.when, '$path.when', issues);
    _validateHeaderFooterPresentation(
      variant.presentation,
      '$path.presentation',
      issues,
      animations,
    );
  }
}

void _validateListNameVariants(
  GlossTablistDoc doc,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.listNames.variants.length; index++) {
    final GlossTablistListNameVariant variant = doc.listNames.variants[index];
    final String path =
        r'$.listNames.variants['
        '$index]';
    _validateVariantIdentity(variant.id, '$path.id', ids, issues);
    _validateCondition(variant.when, '$path.when', issues);
    _validateListNamePresentation(
      variant.presentation,
      '$path.presentation',
      issues,
      animations,
    );
  }
}

void _validateVariantIdentity(
  String id,
  String path,
  Set<String> ids,
  List<HuiIssue> issues,
) {
  final String normalizedId = id.trim();
  if (normalizedId.isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message: 'A conditional variant id cannot be blank.',
        fix: 'Give the variant a stable id.',
      ),
    );
  } else if (!_validVariantId.hasMatch(normalizedId)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Variant id "{id}" contains unsupported characters. Gloss accepts only letters, numbers, dots, hyphens and underscores.',
        messageArguments: <String, Object?>{'id': id},
        fix: 'Use only letters, numbers, dots, hyphens and underscores.',
      ),
    );
  } else if (!ids.add(normalizedId)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        message:
            'Variant id "{id}" is duplicated; priority ties use the id as the deterministic tiebreaker.',
        messageArguments: <String, Object?>{'id': id},
        fix: 'Use a unique id within this section.',
      ),
    );
  }
}

final RegExp _validVariantId = RegExp(r'^[A-Za-z0-9._-]+$');

void _validateHeaderFooterPresentation(
  GlossTablistHeaderFooterPresentation presentation,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  _danglingRefs(
    presentation.header,
    '$path.header',
    'header',
    issues,
    animations,
  );
  _danglingRefs(
    presentation.footer,
    '$path.footer',
    'footer',
    issues,
    animations,
  );
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: '$path.header', text: presentation.header),
      (path: '$path.footer', text: presentation.footer),
    ]),
  );
}

void _validateListNamePresentation(
  GlossTablistListNamePresentation presentation,
  String path,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
  if (presentation.format.trim().isEmpty) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.info,
        path: '$path.format',
        message:
            'A blank list-name format resets matching players to their vanilla list name.',
        fix: 'Keep the reset deliberately or enter a format.',
      ),
    );
  }
  _danglingRefs(
    presentation.format,
    '$path.format',
    'list name',
    issues,
    animations,
  );
  issues.addAll(
    glossTextExpressionIssues(<({String path, String text})>[
      (path: '$path.format', text: presentation.format),
    ]),
  );
}

void _danglingRefs(
  String text,
  String path,
  String surface,
  List<HuiIssue> issues,
  GlossAnimationResolver animations,
) {
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
          'surface': surface,
        },
        fix: 'Create the animation document or select an existing one.',
      ),
    );
  }
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
