/// Bubble-style validation: the strict-offset rejection as an error, the
/// silent clamps as warnings naming the effective value, and the select
/// notes.
library;

import 'package:gloss_editor/logic/bubble_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossBubbleStyleDoc _clean() => decodeGlossBubbleStyleDoc('''
{
  "schemaVersion": 1,
  "revision": 1,
  "prefix": "&7",
  "offset": [0.0, 1.0, 0.0],
  "wordWrapChars": 32,
  "lineStaggerTicks": 5,
  "maxAliveMs": 5000,
  "flyAway": true,
  "followPlayer": true,
  "hideOwn": true,
  "select": {"worlds": ["world"], "groups": [], "priority": 0}
}
''');

void main() {
  test('a clean selected style validates clean', () {
    expect(validateBubbleStyleDoc(_clean()), isEmpty);
  });

  test('an out-of-range revision is an error', () {
    final GlossBubbleStyleDoc doc = _clean()..revision = 0;
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.revision');
  });

  test('a malformed present offset is an error; an absent one is not', () {
    final GlossBubbleStyleDoc bad = _clean()..offsetRaw = <num>[1, 2];
    final List<HuiIssue> issues = validateBubbleStyleDoc(bad);
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.offset');

    final GlossBubbleStyleDoc absent = _clean()..offsetRaw = null;
    expect(validateBubbleStyleDoc(absent), isEmpty);
  });

  test('each silent clamp warns with the effective value', () {
    final GlossBubbleStyleDoc doc = _clean()
      ..wordWrapChars = 4
      ..lineStaggerTicks = 99
      ..maxAliveMs = 100;
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(issues, hasLength(3));
    expect(
      issues.every((HuiIssue issue) => issue.severity == HuiSeverity.warning),
      isTrue,
    );
    expect(
      issues.map((HuiIssue issue) => issue.path),
      containsAll(<String>[
        r'$.wordWrapChars',
        r'$.lineStaggerTicks',
        r'$.maxAliveMs',
      ]),
    );
    expect(
      issues
          .firstWhere((HuiIssue issue) => issue.path == r'$.wordWrapChars')
          .message,
      contains('silently runs 8'),
    );
    expect(
      issues
          .firstWhere((HuiIssue issue) => issue.path == r'$.maxAliveMs')
          .message,
      contains('silently runs 500'),
    );
  });

  test('no select is an info naming the explicit-choice path', () {
    final GlossBubbleStyleDoc doc = _clean()..select = null;
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.message, contains('never auto-matches'));
    expect(issues.single.message, contains('gloss.bubbles.style.'));
  });

  test('blank select entries and normalization are infos', () {
    final GlossBubbleStyleDoc doc = _clean();
    doc.select!.worlds.add('  ');
    doc.select!.groups.addAll(<String>['VIP', '']);
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(
      issues.map((HuiIssue issue) => issue.path),
      containsAll(<String>[r'$.select.worlds', r'$.select.groups']),
    );
    expect(
      issues.every((HuiIssue issue) => issue.severity == HuiSeverity.info),
      isTrue,
    );
  });

  test('a select with nothing to match is an everything-matcher info', () {
    final GlossBubbleStyleDoc doc = _clean();
    doc.select!.worlds.clear();
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.message, contains('every player'));
  });
}
