/// Scoreboard validation: render-cap and truncation warnings, dangling
/// animation references, and the silent-normalization notes.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/scoreboard_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

final class _Animations implements GlossAnimationResolver {
  _Animations(this.docs);

  final Map<String, GlossAnimationDoc> docs;

  @override
  List<String> get ids => docs.keys.toList()..sort();

  @override
  GlossAnimationDoc? byId(String id) => docs[id];
}

GlossScoreboardDoc _valid() => GlossScoreboardDoc(
  title: '&d&lGloss',
  lines: <String>['&fWelcome!'],
);

List<String> _paths(List<HuiIssue> issues, HuiSeverity severity) => <String>[
  for (final HuiIssue issue in issues)
    if (issue.severity == severity) issue.path,
];

void main() {
  test('the shipped default shape is clean', () {
    expect(validateScoreboardDoc(_valid()), isEmpty);
  });

  test('revision out of range is the one hard error', () {
    expect(
      _paths(validateScoreboardDoc(_valid()..revision = 0), HuiSeverity.error),
      contains(r'$.revision'),
    );
  });

  group('render-cap warnings', () {
    test('more than 15 lines warns once at the list', () {
      final GlossScoreboardDoc doc = _valid()
        ..lines = <String>[for (int i = 0; i < 16; i++) 'line $i'];
      final List<HuiIssue> issues = validateScoreboardDoc(doc);
      expect(_paths(issues, HuiSeverity.warning), contains(r'$.lines'));
      expect(issues.single.message, contains('first 15'));
    });

    test('exactly 15 lines is clean', () {
      final GlossScoreboardDoc doc = _valid()
        ..lines = <String>[for (int i = 0; i < 15; i++) 'line $i'];
      expect(validateScoreboardDoc(doc), isEmpty);
    });

    test('a line past 40 visible characters names its index', () {
      final GlossScoreboardDoc doc = _valid()
        ..lines = <String>['ok', '&a${'x' * 41}'];
      final HuiIssue warning = validateScoreboardDoc(doc).single;
      expect(warning.path, 'lines[1]');
      expect(warning.message, contains('41 visible'));
    });

    test('colour codes do not count toward the 40 visible characters', () {
      final GlossScoreboardDoc doc = _valid()
        ..lines = <String>['&a&l&n[FF0000]${'x' * 40}'];
      expect(validateScoreboardDoc(doc), isEmpty);
    });

    test('an animated line measures its longest frame', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'long': GlossAnimationDoc(frames: <String>['ok', 'y' * 41]),
      });
      final GlossScoreboardDoc doc = _valid()
        ..lines = <String>['|animation.long|'];
      expect(
        _paths(
          validateScoreboardDoc(doc, animations: animations),
          HuiSeverity.warning,
        ),
        contains('lines[0]'),
      );
    });
  });

  group('title truncation', () {
    test('counts colour codes the way BoardService does', () {
      // 18 visible + [RRGGBB] costing 14 = 32 rendered: exactly at the cap.
      final GlossScoreboardDoc atCap = _valid()
        ..title = '[FF00AA]${'x' * 18}';
      expect(validateScoreboardDoc(atCap), isEmpty);
      final GlossScoreboardDoc over = _valid()
        ..title = '[FF00AA]${'x' * 19}';
      final HuiIssue warning = validateScoreboardDoc(over).single;
      expect(warning.path, r'$.title');
      expect(warning.message, contains('33 characters'));
    });
  });

  group('animation references', () {
    test('a dangling reference in a line warns at that line', () {
      final GlossScoreboardDoc doc = _valid()
        ..lines = <String>['|animation.gone|'];
      final HuiIssue warning = validateScoreboardDoc(doc).single;
      expect(warning.path, 'lines[0]');
      expect(warning.message, contains('animation.gone'));
    });

    test('a dangling reference in the title warns at the title', () {
      final GlossScoreboardDoc doc = _valid()..title = '|animation.gone|';
      expect(
        _paths(validateScoreboardDoc(doc), HuiSeverity.warning),
        contains(r'$.title'),
      );
    });

    test('a satisfied reference is clean', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'ok': GlossAnimationDoc(frames: <String>['*']),
      });
      final GlossScoreboardDoc doc = _valid()
        ..lines = <String>['|animation.ok|'];
      expect(validateScoreboardDoc(doc, animations: animations), isEmpty);
    });
  });

  group('normalization notes', () {
    test('a permission the server will rewrite gets an info note', () {
      final GlossScoreboardDoc doc = _valid()..permission = ' VIP ';
      final HuiIssue info = validateScoreboardDoc(doc).single;
      expect(info.severity, HuiSeverity.info);
      expect(info.path, r'$.permission');
      expect(info.message, contains('"vip"'));
    });

    test('groups the server will rewrite get an info note', () {
      final GlossScoreboardDoc doc = _valid()
        ..groups = <String>['VIP', 'vip', ''];
      final HuiIssue info = validateScoreboardDoc(doc).single;
      expect(info.severity, HuiSeverity.info);
      expect(info.path, r'$.groups');
      expect(info.message, contains('[vip]'));
    });

    test('already-normalized values stay silent', () {
      final GlossScoreboardDoc doc = _valid()
        ..permission = 'vip'
        ..groups = <String>['vip', 'mvp'];
      expect(validateScoreboardDoc(doc), isEmpty);
    });
  });
}
