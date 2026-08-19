import 'dart:io';

import 'package:gloss_editor/config/editing.dart';
import 'package:test/test.dart';

/// Matches a top-level `const double huiX = ...;` declaration.
RegExp _declaration(String name) =>
    RegExp('^const\\s+double\\s+$name\\s*=', multiLine: true);

List<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList(growable: false);

void main() {
  group('editing step constants', () {
    test('nudge steps carry the values the shortcut sheet documents', () {
      expect(huiNudgeStep, 0.05);
      expect(huiNudgeStepLarge, 0.25);
    });

    test('the coarse nudge is a whole multiple of the fine one', () {
      const double ratio = huiNudgeStepLarge / huiNudgeStep;
      expect(ratio, closeTo(ratio.roundToDouble(), 1e-9));
    });

    test('depth step reorders the draw without moving anything measurable', () {
      expect(huiDepthStep, 0.01);
      expect(huiDepthStep, lessThan(huiNudgeStep));
    });
  });

  group('one home per step', () {
    // The regression this guards is the one that produced the item: the same
    // value declared in two files under two names, which then drift. Anything
    // that needs a step imports `config/editing.dart`.
    for (final String name in <String>[
      'huiNudgeStep',
      'huiNudgeStepLarge',
      'huiDepthStep',
    ]) {
      test('$name is declared exactly once under lib/', () {
        final List<String> declaring = <String>[
          for (final File file in _libDartFiles())
            if (_declaration(name).hasMatch(file.readAsStringSync())) file.path,
        ];
        expect(
          declaring,
          <String>['lib/config/editing.dart'],
          reason: '$name must have exactly one home; found in $declaring',
        );
      });
    }

    test('no file re-declares a step under an alias', () {
      final List<String> offenders = <String>[
        for (final File file in _libDartFiles())
          for (final String alias in <String>[
            'huiNudgeStepCoarse',
            'huiZOrderStep',
          ])
            if (_declaration(alias).hasMatch(file.readAsStringSync()))
              '${file.path}:$alias',
      ];
      expect(offenders, isEmpty);
    });
  });
}
