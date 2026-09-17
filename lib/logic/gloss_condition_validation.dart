/// The one condition check every conditional Gloss kind runs.
///
/// Scoreboards, tablists, surfaces and connection messages all compile a
/// `when` through `ConditionCompiler`, and all of them reject the same two
/// things: an expression that does not parse, and a constant one that is not
/// a boolean. Keeping the rule here means the four kinds cannot drift into
/// four slightly different sentences for the same mistake.
library;

import 'preview_expr.dart';
import 'validation.dart';

/// Issues for the condition [source] reported against [path].
List<HuiIssue> glossConditionIssues(String source, String path) {
  final List<HuiIssue> issues = <HuiIssue>[];
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
  return issues;
}

final class _EmptyConditionScope extends PExprScope {
  @override
  Object? call(String name, List<Object?> args) => null;

  @override
  Object? variable(String dottedName) => null;
}
