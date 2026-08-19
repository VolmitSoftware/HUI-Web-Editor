/// Hologram validation: errors are exactly what the Gloss parser or record
/// constructors reject; warnings load but misbehave.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/hologram_validation.dart';
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

GlossHologramDoc _valid() => decodeGlossHologramDoc('''
{
  "schemaVersion": 1,
  "revision": 1,
  "anchor": {"world": "world", "position": [0, 64, 0]},
  "lines": ["&fHello"]
}
''');

List<String> _errors(List<HuiIssue> issues) => <String>[
  for (final HuiIssue issue in issues)
    if (issue.severity == HuiSeverity.error) issue.path,
];

List<String> _warnings(List<HuiIssue> issues) => <String>[
  for (final HuiIssue issue in issues)
    if (issue.severity == HuiSeverity.warning) issue.path,
];

void main() {
  test('the baseline shape is clean', () {
    expect(validateHologramDoc(_valid()), isEmpty);
  });

  group('errors — what Gloss rejects', () {
    test('revision below 1 or past MAX_SAFE_REVISION', () {
      final GlossHologramDoc low = _valid()..revision = 0;
      expect(_errors(validateHologramDoc(low)), contains(r'$.revision'));
      final GlossHologramDoc high = _valid()
        ..revision = glossMaxSafeRevision + 1;
      expect(_errors(validateHologramDoc(high)), contains(r'$.revision'));
      final GlossHologramDoc max = _valid()..revision = glossMaxSafeRevision;
      expect(_errors(validateHologramDoc(max)), isEmpty);
    });

    test('a missing anchor object', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(
        '{"schemaVersion": 1, "revision": 1, "lines": []}',
      );
      expect(_errors(validateHologramDoc(doc)), contains(r'$.anchor'));
    });

    test('a blank world', () {
      final GlossHologramDoc doc = _valid()..anchor.world = '   ';
      expect(_errors(validateHologramDoc(doc)), contains(r'$.anchor.world'));
    });

    test('a position that is not three finite numbers', () {
      final GlossHologramDoc wrongLength = _valid()
        ..anchor.positionRaw = <num>[1, 2];
      expect(
        _errors(validateHologramDoc(wrongLength)),
        contains(r'$.anchor.position'),
      );
      final GlossHologramDoc notNumbers = _valid()
        ..anchor.positionRaw = <Object>['a', 'b', 'c'];
      expect(
        _errors(validateHologramDoc(notNumbers)),
        contains(r'$.anchor.position'),
      );
      final GlossHologramDoc notAList = _valid()
        ..anchor.positionRaw = 'origin';
      expect(
        _errors(validateHologramDoc(notAList)),
        contains(r'$.anchor.position'),
      );
      final GlossHologramDoc infinite = _valid()
        ..anchor.positionRaw = <num>[double.infinity, 0, 0];
      expect(
        _errors(validateHologramDoc(infinite)),
        contains(r'$.anchor.position'),
      );
    });
  });

  group('warnings — loads but misbehaves', () {
    test('no lines renders nothing', () {
      final GlossHologramDoc doc = _valid()..lines.clear();
      final List<HuiIssue> issues = validateHologramDoc(doc);
      expect(_errors(issues), isEmpty);
      expect(_warnings(issues), contains(r'$.lines'));
    });

    test('a dangling animation reference names its line', () {
      final GlossHologramDoc doc = _valid()
        ..lines.add('|animation.missing| here');
      final List<HuiIssue> issues = validateHologramDoc(doc);
      expect(_warnings(issues), contains('lines[1]'));
      expect(
        issues.any((HuiIssue issue) =>
            issue.message.contains('animation.missing')),
        isTrue,
      );
    });

    test('a satisfied animation reference is clean', () {
      final GlossHologramDoc doc = _valid()..lines.add('|animation.glow|');
      final List<HuiIssue> issues = validateHologramDoc(
        doc,
        animations: _Animations(<String, GlossAnimationDoc>{
          'glow': GlossAnimationDoc(frames: <String>['*']),
        }),
      );
      expect(issues, isEmpty);
    });
  });

  group('infos — worth knowing, not worth fixing', () {
    test('metric references are one note listing the keys', () {
      final GlossHologramDoc doc = _valid()
        ..lines.add('TPS |metric.react.tps|')
        ..lines.add('|metric.iris.chunks| chunks');
      final HuiIssue info = validateHologramDoc(doc).single;
      expect(info.severity, HuiSeverity.info);
      expect(info.path, r'$');
      expect(info.message, contains('react.tps'));
      expect(info.message, contains('iris.chunks'));
      expect(info.message, contains('integration bridge'));
    });
  });
}
