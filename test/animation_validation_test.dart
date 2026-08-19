/// Animation validation: parse-rejects are errors, the silent interval clamp
/// is a warning that names the effective value.
library;

import 'package:gloss_editor/logic/animation_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossAnimationDoc _valid() => GlossAnimationDoc(
  mode: 'ascend',
  frameIntervalMs: 500,
  frames: <String>['&cA', '&aB'],
);

List<String> _paths(List<HuiIssue> issues, HuiSeverity severity) => <String>[
  for (final HuiIssue issue in issues)
    if (issue.severity == severity) issue.path,
];

void main() {
  test('a valid document is clean', () {
    expect(validateAnimationDoc(_valid()), isEmpty);
  });

  test('every shipped mode validates', () {
    for (final String mode in glossAnimationModes) {
      expect(validateAnimationDoc(_valid()..mode = mode), isEmpty,
          reason: mode);
    }
  });

  group('errors', () {
    test('revision out of range', () {
      expect(
        _paths(validateAnimationDoc(_valid()..revision = 0),
            HuiSeverity.error),
        contains(r'$.revision'),
      );
    });

    test('an unknown mode', () {
      final List<HuiIssue> issues = validateAnimationDoc(
        _valid()..mode = 'wobble',
      );
      expect(_paths(issues, HuiSeverity.error), contains(r'$.mode'));
      expect(
        issues.first.fix,
        contains('ascend, descend, ascend_descend, random'),
      );
    });

    test('a blank mode', () {
      expect(
        _paths(validateAnimationDoc(_valid()..mode = '  '), HuiSeverity.error),
        contains(r'$.mode'),
      );
    });

    test('mode is case-insensitive like requireMode', () {
      expect(validateAnimationDoc(_valid()..mode = 'DESCEND'), isEmpty);
    });

    test('an empty frame list', () {
      expect(
        _paths(
          validateAnimationDoc(_valid()..frames.clear()),
          HuiSeverity.error,
        ),
        contains(r'$.frames'),
      );
    });
  });

  group('the interval warning', () {
    test('below range names the 1 ms floor', () {
      final List<HuiIssue> issues = validateAnimationDoc(
        _valid()..frameIntervalMs = 0,
      );
      expect(_paths(issues, HuiSeverity.error), isEmpty);
      final HuiIssue warning = issues.single;
      expect(warning.severity, HuiSeverity.warning);
      expect(warning.path, r'$.frameIntervalMs');
      expect(warning.message, contains('silently'));
      expect(warning.message, contains('1 ms'));
    });

    test('above range names the 60000 ms ceiling', () {
      final HuiIssue warning = validateAnimationDoc(
        _valid()..frameIntervalMs = 90000,
      ).single;
      expect(warning.severity, HuiSeverity.warning);
      expect(warning.message, contains('60000 ms'));
    });

    test('the bounds themselves are clean', () {
      expect(validateAnimationDoc(_valid()..frameIntervalMs = 1), isEmpty);
      expect(validateAnimationDoc(_valid()..frameIntervalMs = 60000), isEmpty);
    });
  });
}
