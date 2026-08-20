/// Validation for Gloss bubble-style documents.
///
/// `BubbleStyleDoc.java` rejects almost nothing: beyond the envelope, only a
/// present-but-malformed `offset` kills the file (the strict `[x, y, z]`
/// Vector adapter). The two numeric fields clamp SILENTLY
/// (`BubbleStyleDoc.java:26-28`), so out-of-range values are warnings that
/// name the effective value, per the wave-1 convention. The select notes
/// mirror `BubbleStyles.resolveStyleId` and `Select.cleanStrings`.
library;

import '../model/gloss_bubble_style.dart';
import '../model/gloss_doc.dart';
import 'bubble_motion.dart';
import 'preview_expr.dart';
import 'validation.dart';

List<HuiIssue> validateBubbleStyleDoc(GlossBubbleStyleDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[];

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) {
    issues.add(revisionIssue);
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
    'maxAliveMs',
    doc.maxAliveMs,
    doc.effectiveMaxAliveMs,
    glossBubbleMinMaxAliveMs,
    glossBubbleMaxMaxAliveMs,
  );

  issues.addAll(_validateMotion(doc.motion));
  issues.addAll(_validateShimmer(doc));

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

List<HuiIssue> _validateShimmer(GlossBubbleStyleDoc doc) {
  final GlossBubbleShimmer shimmer = doc.shimmer;
  final List<HuiIssue> issues = <HuiIssue>[];
  if (!shimmer.colorIsValid) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.shimmer.color',
        message:
            'Shimmer color must be exactly #RRGGBB; Gloss rejects the '
            'whole bubble style otherwise.',
        fix: 'Choose a six-digit RGB color such as #ffffff.',
      ),
    );
  }
  void clampWarning(
    String key,
    int written,
    int effective,
    int minimum,
    int maximum,
  ) {
    if (written == effective) return;
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '\$.shimmer.$key',
        message:
            '$written is outside $minimum..$maximum. Gloss loads the file '
            'but silently runs $effective.',
        fix: 'Write the bounded value the server will actually use.',
      ),
    );
  }

  clampWarning(
    'width',
    shimmer.width,
    shimmer.effectiveWidth,
    glossBubbleMinShimmerWidth,
    glossBubbleMaxShimmerWidth,
  );
  clampWarning(
    'durationMs',
    shimmer.durationMs,
    shimmer.effectiveDurationMs,
    glossBubbleMinShimmerDurationMs,
    glossBubbleMaxShimmerDurationMs,
  );
  clampWarning(
    'spawnDelayMs',
    shimmer.spawnDelayMs,
    shimmer.effectiveSpawnDelayMs,
    0,
    glossBubbleMaxShimmerOffsetMs,
  );
  clampWarning(
    'flyAwayLeadMs',
    shimmer.flyAwayLeadMs,
    shimmer.effectiveFlyAwayLeadMs,
    0,
    glossBubbleMaxShimmerOffsetMs,
  );

  if (!shimmer.spawn && !shimmer.flyAway) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.shimmer',
        message: 'Both shimmer passes are disabled; the bubble stays unlit.',
        fix: 'Enable the spawn or fly-away pass to show a shimmer.',
      ),
    );
  }
  if (shimmer.spawn &&
      shimmer.effectiveSpawnDelayMs >= doc.effectiveMaxAliveMs) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.shimmer.spawnDelayMs',
        message:
            'The spawn shimmer starts after this bubble expires, so players '
            'will not see it.',
        fix: 'Use a delay shorter than maxAliveMs.',
      ),
    );
  }
  if (shimmer.flyAway && shimmer.effectiveFlyAwayLeadMs == 0) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.shimmer.flyAwayLeadMs',
        message:
            'The fly-away shimmer starts exactly at expiry and cannot be '
            'seen.',
        fix: 'Use a positive lead, normally at least durationMs.',
      ),
    );
  } else if (shimmer.flyAway &&
      shimmer.effectiveFlyAwayLeadMs < shimmer.effectiveDurationMs) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.shimmer.flyAwayLeadMs',
        message:
            'The fly-away shimmer reaches expiry before completing its '
            'left-to-right sweep.',
        fix: 'Use flyAwayLeadMs greater than or equal to durationMs.',
      ),
    );
  }
  return issues;
}

const Set<String> _motionFunctions = <String>{
  'clamp',
  'lerp',
  'min',
  'max',
  'floor',
  'ceil',
  'round',
  'abs',
  'mod',
  'sin',
  'cos',
  'pow',
  'smoothstep',
  'rgb',
  'argb',
  'alpha',
  'mix',
  'palette',
  'select',
  'number',
  'bar',
  'hex',
  'str',
  'fixed',
  'plain',
  'readable',
};

List<HuiIssue> _validateMotion(GlossBubbleMotion motion) {
  final List<HuiIssue> issues = <HuiIssue>[];
  final List<({String path, String source, double min, double max})> leaves =
      <({String path, String source, double min, double max})>[
        (
          path: r'$.motion.translation.x',
          source: motion.translation.x,
          min: glossBubbleMotionMinTranslation,
          max: glossBubbleMotionMaxTranslation,
        ),
        (
          path: r'$.motion.translation.y',
          source: motion.translation.y,
          min: glossBubbleMotionMinTranslation,
          max: glossBubbleMotionMaxTranslation,
        ),
        (
          path: r'$.motion.translation.z',
          source: motion.translation.z,
          min: glossBubbleMotionMinTranslation,
          max: glossBubbleMotionMaxTranslation,
        ),
        (
          path: r'$.motion.scale.x',
          source: motion.scale.x,
          min: glossBubbleMotionMinScale,
          max: glossBubbleMotionMaxScale,
        ),
        (
          path: r'$.motion.scale.y',
          source: motion.scale.y,
          min: glossBubbleMotionMinScale,
          max: glossBubbleMotionMaxScale,
        ),
        (
          path: r'$.motion.scale.z',
          source: motion.scale.z,
          min: glossBubbleMotionMinScale,
          max: glossBubbleMotionMaxScale,
        ),
        (
          path: r'$.motion.rotation.x',
          source: motion.rotation.x,
          min: double.negativeInfinity,
          max: double.infinity,
        ),
        (
          path: r'$.motion.rotation.y',
          source: motion.rotation.y,
          min: double.negativeInfinity,
          max: double.infinity,
        ),
        (
          path: r'$.motion.rotation.z',
          source: motion.rotation.z,
          min: double.negativeInfinity,
          max: double.infinity,
        ),
        (
          path: r'$.motion.opacity',
          source: motion.opacity,
          min: glossBubbleMotionMinOpacity,
          max: glossBubbleMotionMaxOpacity,
        ),
      ];
  for (final ({String path, String source, double min, double max}) leaf
      in leaves) {
    if (leaf.source.length > glossBubbleMotionMaxExpressionLength) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: leaf.path,
          message:
              'The expression is ${leaf.source.length} characters; Gloss '
              'rejects motion expressions longer than '
              '$glossBubbleMotionMaxExpressionLength.',
          fix: 'Shorten the expression.',
        ),
      );
      continue;
    }
    final PExpr expression;
    try {
      expression = parsePreviewExpr(leaf.source);
    } on PExprException catch (failure) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: leaf.path,
          message: failure.message,
          fix: 'Write a valid numeric motion expression.',
        ),
      );
      continue;
    }
    final Set<String> variables = <String>{};
    final Set<String> functions = <String>{};
    _collectMotionNames(expression, variables, functions);
    final List<String> unknownVariables =
        variables
            .where((String name) => !glossBubbleMotionVariables.contains(name))
            .toList()
          ..sort();
    final List<String> unknownFunctions =
        functions
            .where((String name) => !_motionFunctions.contains(name))
            .toList()
          ..sort();
    if (unknownVariables.isNotEmpty || unknownFunctions.isNotEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: leaf.path,
          message: <String>[
            if (unknownVariables.isNotEmpty)
              'Unknown variables: ${unknownVariables.join(', ')}.',
            if (unknownFunctions.isNotEmpty)
              'Unknown functions: ${unknownFunctions.join(', ')}.',
          ].join(' '),
          fix: 'Use the bubble lifetime variables and shared math functions.',
        ),
      );
      continue;
    }

    bool warned = false;
    for (final double t in const <double>[0, 0.25, 0.5, 0.75, 1]) {
      final double value;
      try {
        value = evaluateGlossBubbleMotionSource(
          leaf.source,
          GlossBubbleMotionContext(
            t: t,
            ageMs: 5000 * t,
            lifetimeMs: 5000,
            stackIndex: 0,
            stackCount: 1,
            lineCount: 1,
            stackY: 1.12,
            seed: 0.5,
          ),
        );
      } on PExprException catch (failure) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.error,
            path: leaf.path,
            message: '${failure.message} at t=$t.',
            fix: 'Make the expression numeric and finite across its lifetime.',
          ),
        );
        warned = true;
        break;
      }
      if (value < leaf.min || value > leaf.max) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.warning,
            path: leaf.path,
            message:
                'At t=$t this evaluates to $value; Gloss clamps it into '
                '${leaf.min}..${leaf.max}.',
            fix: 'Clamp the expression explicitly if that bound is intended.',
          ),
        );
        warned = true;
        break;
      }
    }
    if (warned) continue;
  }
  return issues;
}

void _collectMotionNames(
  PExpr expression,
  Set<String> variables,
  Set<String> functions,
) {
  switch (expression) {
    case PVar(name: final String name):
      variables.add(name);
    case PCall(name: final String name, args: final List<PExpr> args):
      functions.add(name);
      for (final PExpr argument in args) {
        _collectMotionNames(argument, variables, functions);
      }
    case PList(items: final List<PExpr> items):
      for (final PExpr item in items) {
        _collectMotionNames(item, variables, functions);
      }
    case PUnary(operand: final PExpr operand):
      _collectMotionNames(operand, variables, functions);
    case PBinary(left: final PExpr left, right: final PExpr right):
      _collectMotionNames(left, variables, functions);
      _collectMotionNames(right, variables, functions);
    case PTernary(
      condition: final PExpr condition,
      ifTrue: final PExpr ifTrue,
      ifFalse: final PExpr ifFalse,
    ):
      _collectMotionNames(condition, variables, functions);
      _collectMotionNames(ifTrue, variables, functions);
      _collectMotionNames(ifFalse, variables, functions);
    case PNum():
    case PStr():
    case PBool():
      break;
  }
}

bool _sameStrings(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (int index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
