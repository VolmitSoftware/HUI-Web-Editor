import 'dart:convert';

import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/logic/scoreboard_layout.dart';
import 'package:gloss_editor/logic/scoreboard_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/gloss_scoreboard.dart';
import 'package:test/test.dart';

void main() {
  test(
    'editing and copying labels preserve row metadata and advanced documents',
    () {
      final GlossScoreboardDoc document = decodeGlossScoreboardDoc('''
      {"schemaVersion":2,"revision":9,"select":{"when":"true"},"presentation":{
       "title":"","lines":[{"id":"balance","text":"Balance","value":"100","format":"fixed","show":"viewer.op"},{"section":"account","show":false}],
       "layout":{"sections":{"account":["A"]},"pages":[{"id":"first","lines":[{"section":"account"}]}],"refresh":{"valueTicks":2}}},
       "objectives":{"belowName":{"title":"Health","value":"subject.health"}},"variants":[]}
      ''');
      final GlossScoreboardDoc edited = document.copy();
      edited.presentation.lines.first.text = 'Credits';
      final GlossScoreboardDoc restored = decodeGlossScoreboardDoc(
        encodeGlossScoreboardDoc(edited),
      );
      final GlossScoreboardLine row = restored.presentation.lines.first;
      expect(row.text, 'Credits');
      expect(row.id, 'balance');
      expect(row.value, '100');
      expect(row.format, 'fixed');
      expect(row.show, 'viewer.op');
      expect(restored.presentation.lines.last.section, 'account');
      expect(restored.presentation.lines.last.show, false);
      expect(
        restored.presentation.extras['layout'],
        document.presentation.extras['layout'],
      );
      expect(restored.extras['objectives'], document.extras['objectives']);
      expect(document.presentation.lines.first.text, 'Balance');
      expect(restored.revision, 9);
    },
  );

  test('plain strings stay strings and objects keep their shape', () {
    final GlossScoreboardPresentation presentation =
        GlossScoreboardPresentation.fromJson(<String, Object?>{
          'lines': <Object>[
            'One',
            <String, Object?>{'text': 'Two', 'value': '2'},
          ],
        }, r'$.presentation');
    expect(presentation.toJson()['lines'], <Object>[
      'One',
      <String, Object?>{'text': 'Two', 'value': '2'},
    ]);
  });

  test('sections and conditional pages use the same viewer context', () {
    final GlossScoreboardPresentation authored =
        GlossScoreboardPresentation.fromJson(
          jsonDecode('''
      {"title":"Base","lines":["Fallback"],"layout":{"sections":{"account":[{"text":"Staff","show":"viewer.op"},"Always"]},
       "pages":[{"id":"first","title":"First","durationTicks":2,"show":"viewer.op","lines":[{"section":"account"}]},
                {"id":"second","durationTicks":3,"show":"viewer.op","lines":["Second"]}]}}
      '''),
          r'$.presentation',
        );
    final GlossConditionContext staff = GlossConditionContext(
      variables: <String, Object?>{'viewer.op': true},
    );
    final GlossConditionContext guest = GlossConditionContext(
      variables: <String, Object?>{'viewer.op': false},
    );
    final GlossScoreboardPresentation first = glossResolveScoreboardLayout(
      authored,
      staff,
      0,
    );
    expect(first.title, 'First');
    expect(first.lines.map((GlossScoreboardLine row) => row.text), <String>[
      'Staff',
      'Always',
    ]);
    final GlossScoreboardPresentation second = glossResolveScoreboardLayout(
      authored,
      staff,
      100,
    );
    expect(second.title, 'Base');
    expect(second.lines.single.text, 'Second');
    expect(
      glossResolveScoreboardLayout(authored, guest, 100).lines.single.text,
      'Fallback',
    );
  });

  test('a false section reference hides its whole section', () {
    final GlossScoreboardPresentation authored =
        GlossScoreboardPresentation.fromJson(
          jsonDecode('''
      {"lines":[{"section":"account","show":false},"Visible"],"layout":{"sections":{"account":["Hidden"]}}}
      '''),
          r'$.presentation',
        );
    expect(
      glossResolveScoreboardLayout(
        authored,
        GlossConditionContext(),
        0,
      ).lines.single.text,
      'Visible',
    );
  });

  test(
    'invalid section cycles and page rows report errors without breaking preview',
    () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc('''
      {"schemaVersion":2,"revision":1,"select":{},"presentation":{"lines":[{"section":"loop"}],
       "layout":{"sections":{"loop":[{"section":"loop"}]},"pages":[{"id":"one","lines":[{"show":42},"Valid"]}]}} ,"variants":[]}
      ''');
      final List<HuiIssue> issues = validateScoreboardDoc(doc);
      expect(
        issues.any((HuiIssue issue) => issue.message.contains('refers back')),
        isTrue,
      );
      expect(
        issues.any((HuiIssue issue) => issue.message.contains('valid row')),
        isTrue,
      );
      expect(
        glossResolveScoreboardLayout(
          doc.presentation,
          GlossConditionContext(),
          0,
        ).lines.single.text,
        'Valid',
      );
    },
  );

  test(
    'fixed, styled and blank values override the presentation number policy',
    () {
      expect(
        glossScoreboardValue(GlossScoreboardLine(value: '100'), 0, true),
        '100',
      );
      expect(
        glossScoreboardValue(
          GlossScoreboardLine(format: 'styled', value: '&c'),
          2,
          true,
        ),
        '&c13',
      );
      expect(
        glossScoreboardValue(GlossScoreboardLine(format: 'blank'), 0, false),
        isNull,
      );
      expect(
        glossScoreboardValue(GlossScoreboardLine(format: 'number'), 0, true),
        '15',
      );
      expect(glossScoreboardValue(GlossScoreboardLine(), 0, true), isNull);
    },
  );
}
