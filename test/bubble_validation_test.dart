library;

import 'package:gloss_editor/logic/bubble_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossBubbleStyleDoc _clean() => decodeGlossBubbleStyleDoc('''
{
  "schemaVersion": 2,
  "revision": 1,
  "prefix": "&7",
  "offset": [0.0, 1.0, 0.0],
  "wordWrapChars": 32,
  "maxAliveMs": 5000,
  "motion": {
    "translation": {
      "x": "0",
      "y": "10 * pow(clamp((ageMs - lifetimeMs + 2000) / 2000, 0, 1), 16)",
      "z": "0"
    },
    "scale": {"x": "1", "y": "1", "z": "1"},
    "rotation": {"x": "0", "y": "0", "z": "0"},
    "opacity": "1"
  },
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
    final HuiIssue issue = validateBubbleStyleDoc(doc).single;
    expect(issue.severity, HuiSeverity.error);
    expect(issue.path, r'$.revision');
  });

  test('a malformed present offset is an error; an absent one is not', () {
    final GlossBubbleStyleDoc bad = _clean()..offsetRaw = <num>[1, 2];
    expect(validateBubbleStyleDoc(bad).single.path, r'$.offset');
    final GlossBubbleStyleDoc absent = _clean()..offsetRaw = null;
    expect(validateBubbleStyleDoc(absent), isEmpty);
  });

  test('numeric document clamps warn with the effective value', () {
    final GlossBubbleStyleDoc doc = _clean()
      ..wordWrapChars = 4
      ..maxAliveMs = 100;
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(issues, hasLength(2));
    expect(issues.map((HuiIssue issue) => issue.path), <String>[
      r'$.wordWrapChars',
      r'$.maxAliveMs',
    ]);
    expect(issues.first.message, contains('silently runs 8'));
    expect(issues.last.message, contains('silently runs 500'));
  });

  test('invalid and clamped shimmer values mirror runtime diagnostics', () {
    final GlossBubbleStyleDoc doc = _clean();
    doc.shimmer.color = 'white';
    doc.shimmer.width = 99;
    doc.shimmer.durationMs = 1;
    doc.shimmer.spawnDelayMs = -1;
    doc.shimmer.flyAwayLeadMs = 999999;
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(
      issues.map((HuiIssue issue) => issue.path),
      containsAll(<String>[
        r'$.shimmer.color',
        r'$.shimmer.width',
        r'$.shimmer.durationMs',
        r'$.shimmer.spawnDelayMs',
        r'$.shimmer.flyAwayLeadMs',
      ]),
    );
    expect(
      issues
          .firstWhere((HuiIssue issue) => issue.path == r'$.shimmer.color')
          .severity,
      HuiSeverity.error,
    );
  });

  test('shimmer warns when a configured pass cannot complete visibly', () {
    final GlossBubbleStyleDoc doc = _clean();
    doc.shimmer.spawnDelayMs = doc.effectiveMaxAliveMs;
    // The departure cycle is opt-in now, so it has to be asked for before its
    // lead can be diagnosed.
    doc.shimmer.flyAway = true;
    doc.shimmer.flyAwayLeadMs = 0;
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(
      issues.map((HuiIssue issue) => issue.path),
      containsAll(<String>[
        r'$.shimmer.spawnDelayMs',
        r'$.shimmer.flyAwayLeadMs',
      ]),
    );
  });

  test('invalid, unknown, and overlong motion expressions are errors', () {
    final GlossBubbleStyleDoc doc = _clean();
    doc.motion.translation.x = 'missing + 1';
    doc.motion.translation.y = 'smoothstep(1, 1, t)';
    doc.motion.translation.z = '1' * 513;
    doc.motion.scale.x = 'mystery(t)';
    final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      hasLength(4),
    );
    expect(
      issues.map((HuiIssue issue) => issue.path),
      containsAll(<String>[
        r'$.motion.translation.x',
        r'$.motion.translation.y',
        r'$.motion.translation.z',
        r'$.motion.scale.x',
      ]),
    );
    expect(
      issues
          .firstWhere(
            (HuiIssue issue) => issue.path == r'$.motion.translation.y',
          )
          .message,
      contains('smoothstep edges must differ'),
    );
  });

  test(
    'runtime-clamped motion values warn while rotations may exceed a turn',
    () {
      final GlossBubbleStyleDoc doc = _clean();
      doc.motion.translation.x = '100';
      doc.motion.scale.y = '-1';
      doc.motion.opacity = '2';
      doc.motion.rotation.z = '9000 * t';
      final List<HuiIssue> issues = validateBubbleStyleDoc(doc);
      expect(
        issues.where((HuiIssue issue) => issue.severity == HuiSeverity.warning),
        hasLength(3),
      );
      expect(
        issues.any((HuiIssue issue) => issue.path == r'$.motion.rotation.z'),
        isFalse,
      );
    },
  );

  test('no select explains explicit choice and default-name fallback', () {
    final GlossBubbleStyleDoc doc = _clean()..select = null;
    final HuiIssue issue = validateBubbleStyleDoc(doc).single;
    expect(issue.severity, HuiSeverity.info);
    expect(issue.message, contains('gloss.bubbles.style.'));
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
  });

  test('a select with no constraints matches every player', () {
    final GlossBubbleStyleDoc doc = _clean();
    doc.select!.worlds.clear();
    final HuiIssue issue = validateBubbleStyleDoc(doc).single;
    expect(issue.severity, HuiSeverity.info);
    expect(issue.message, contains('every player'));
  });
}
