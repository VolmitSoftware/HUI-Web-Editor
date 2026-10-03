import '../model/gloss_presentation_variant.dart';
import 'gloss_show.dart';
import 'preview_expr.dart';
import 'validation.dart';

GlossPresentationVariant? resolvePresentationVariant(
  List<GlossPresentationVariant> variants, {
  PExprScope? scope,
  int nowMs = 0,
}) {
  GlossPresentationVariant? selected;
  for (final GlossPresentationVariant variant in variants) {
    if (glossShowMatches(variant.when, scope: scope, nowMs: nowMs) &&
        (selected == null ||
            variant.priority > selected.priority ||
            variant.priority == selected.priority &&
                variant.id.compareTo(selected.id) < 0)) {
      selected = variant;
    }
  }
  return selected;
}

List<HuiIssue> validatePresentationVariants(
  List<GlossPresentationVariant> variants,
) {
  final List<HuiIssue> issues = <HuiIssue>[];
  if (variants.length > 64) {
    issues.add(const HuiIssue(severity: HuiSeverity.error, path: r'$.variants', message: 'At most {maximum} variants are allowed.', messageArguments: <String, Object?>{'maximum': 64}));
  }
  final Set<String> ids = <String>{};
  for (final (int index, GlossPresentationVariant variant)
      in variants.indexed) {
    final String path = '\$.variants[$index]';
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(variant.id)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message:
              'Variant ids accept only letters, numbers, dots, hyphens and underscores.',
        ),
      );
    } else if (!ids.add(variant.id)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.id',
          message: 'Variant id "{id}" is duplicated.',
          messageArguments: <String, Object?>{'id': variant.id},
        ),
      );
    }
    issues.addAll(validateGlossShow(variant.when, path: '$path.when'));
    final HuiIssue? range = runtimeRangeIssue(
      '$path.priority',
      variant.priority,
      -1000,
      1000,
    );
    if (range != null) issues.add(range);
  }
  return issues;
}
