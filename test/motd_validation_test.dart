/// MOTD validation: the `MotdDoc.java` parse rejections as errors, the
/// renderStatic realities (animations play, placeholders never expand) as
/// warnings and infos.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/motd_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossMotdDoc _doc(List<List<String>> entries, {int revision = 1}) =>
    GlossMotdDoc(
      revision: revision,
      entries: <GlossMotdEntry>[
        for (final List<String> lines in entries)
          GlossMotdEntry(lines: List<String>.of(lines)),
      ],
    );

final class _OneAnimation implements GlossAnimationResolver {
  _OneAnimation(this.id);

  final String id;

  @override
  List<String> get ids => <String>[id];

  @override
  GlossAnimationDoc? byId(String wanted) =>
      wanted == id ? GlossAnimationDoc(frames: <String>['&cGloss']) : null;
}

void main() {
  test('the shipped default validates clean', () {
    expect(
      validateMotdDoc(
        _doc(<List<String>>[
          <String>['&dA glossy server'],
        ]),
      ),
      isEmpty,
    );
  });

  test('an out-of-range revision is an error', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['a'],
      ], revision: 0),
    );
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.revision');
  });

  test('no entries is an error — the plugin rejects the file', () {
    final List<HuiIssue> issues = validateMotdDoc(_doc(<List<String>>[]));
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.entries');
  });

  test('an entry with zero or three lines is an error', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>[],
        <String>['a', 'b', 'c'],
        <String>['fine'],
      ]),
    );
    expect(issues, hasLength(2));
    expect(issues[0].path, 'entries[0].lines');
    expect(issues[0].severity, HuiSeverity.error);
    expect(issues[1].path, 'entries[1].lines');
    expect(issues[1].message, contains('3 lines'));
  });

  test('a long line warns with the visible character count', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['&d${'x' * 60}'],
      ]),
    );
    expect(issues.single.severity, HuiSeverity.warning);
    expect(issues.single.message, contains('60 visible characters'));
  });

  test('a dangling animation reference warns; a resolvable one is clean', () {
    final GlossMotdDoc doc = _doc(<List<String>>[
      <String>['|animation.rainbow|'],
    ]);
    final List<HuiIssue> dangling = validateMotdDoc(doc);
    expect(dangling.single.severity, HuiSeverity.warning);
    expect(dangling.single.message, contains('animation.rainbow'));
    expect(validateMotdDoc(doc, animations: _OneAnimation('rainbow')), isEmpty);
  });

  test('a placeholder is an info — a ping has no viewer', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['&7Hi %player_name%'],
      ]),
    );
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.message, contains('%player_name%'));
    expect(issues.single.message, contains('no viewer'));
  });

  test('metric references are one info listing the keys', () {
    final List<HuiIssue> issues = validateMotdDoc(
      _doc(<List<String>>[
        <String>['&7TPS |metric.react.tps|', '|metric.iris.chunks|'],
      ]),
    );
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.path, r'$');
    expect(issues.single.message, contains('react.tps'));
    expect(issues.single.message, contains('iris.chunks'));
  });
}
