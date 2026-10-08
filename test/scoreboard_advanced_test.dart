import 'dart:convert';

import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/logic/scoreboard_layout.dart';
import 'package:gloss_editor/logic/scoreboard_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/gloss_scoreboard.dart';
import 'package:gloss_editor/model/gloss_scoreboard_advanced.dart';
import 'package:gloss_editor/model/json_codec.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

const String _fixture = '''{
  "schemaVersion":2,"revision":7,"select":{"when":"true"},
  "presentation":{"title":"Base","lines":[{"section":"stats"}],
    "layout":{"custom":{"nested":[1,2]},"overflow":"truncate",
      "sections":{"stats":[{"text":"Health","id":"health","value":"20","custom":"row"}],"wrapper":[{"section":"stats"}]},
      "pages":[{"id":"one","lines":[{"section":"stats"}],"durationTicks":2,"custom":"page"},
               {"id":"two","title":"","lines":["Second"],"durationTicks":3}],
      "refresh":{"valueTicks":2,"custom":"refresh"}}},
  "variants":[{"id":"staff","when":"viewer.op","presentation":{"title":"Staff","lines":["Staff row"],"layout":{"custom":"variant"}}}],
  "objectives":{"custom":"objectives","belowName":{"title":"Health","value":"subject.health","custom":{"nested":true}}}
}''';

void main() {
  test('native objective completion offers the exact contract enums', () {
    for (final String slot in <String>['playerList', 'belowName']) {
      for (final MapEntry<String, List<String>> field in <String, List<String>>{
        'renderType': <String>['integer', 'hearts'],
        'format': <String>['number', 'blank', 'fixed', 'styled'],
        'conflict': <String>['yield', 'override'],
      }.entries) {
        final GlossJsonField schema =
            glossJsonFieldAt(glossScoreboardJsonSchema, <JsonPathStep>[
              const JsonPathStep.key('objectives'),
              JsonPathStep.key(slot),
              JsonPathStep.key(field.key),
            ])!;
        expect(
          schema.values.map(
            (GlossJsonValue value) => jsonDecode(value.literal),
          ),
          field.value,
        );
      }
    }
  });

  test('optional advanced settings remain omitted', () {
    expect(GlossScoreboardLayout.fromJson(null).toJson(), isEmpty);
    expect(GlossScoreboardObjectives.fromJson(null).toJson(), isEmpty);
    expect(
      GlossScoreboardObjective.fromJson(<String, Object?>{}).toJson(),
      isEmpty,
    );
  });

  test(
    'typed layout edits preserve nested extras and rename every reference',
    () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_fixture);
      final GlossScoreboardLayout layout = GlossScoreboardLayout.fromJson(
        doc.presentation.extras['layout'],
      );
      expect(
        layout.renameSection('stats', 'health', doc.presentation.lines),
        isTrue,
      );
      expect(layout.sections.keys, <String>['health', 'wrapper']);
      expect(layout.sections['wrapper']!.single.section, 'health');
      expect(layout.pages.first.lines.single.section, 'health');
      expect(doc.presentation.lines.single.section, 'health');
      expect(layout.sections['health']!.single.extras['custom'], 'row');
      layout.refresh.titleTicks = 5;
      doc.presentation.extras['layout'] = layout.toJson();
      final GlossScoreboardDoc restored = decodeGlossScoreboardDoc(
        encodeGlossScoreboardDoc(doc),
      );
      final GlossScoreboardLayout result = GlossScoreboardLayout.fromJson(
        restored.presentation.extras['layout'],
      );
      expect(result.extras, <String, Object?>{
        'custom': <String, Object?>{
          'nested': <int>[1, 2],
        },
      });
      expect(result.pages.first.extras['custom'], 'page');
      expect(result.refresh.extras['custom'], 'refresh');
      expect(result.refresh.titleTicks, 5);
      expect(result.refresh.valueTicks, 2);
      expect(result.refresh.textTicks, isNull);
      expect(validateScoreboardDoc(restored), isEmpty);
    },
  );

  test('section collisions do not change rows or section order', () {
    final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_fixture);
    final GlossScoreboardLayout layout = GlossScoreboardLayout.fromJson(
      doc.presentation.extras['layout'],
    );
    final Map<String, Object?> before = layout.toJson();
    expect(
      layout.renameSection('stats', 'wrapper', doc.presentation.lines),
      isFalse,
    );
    expect(
      layout.renameSection('missing', 'new', doc.presentation.lines),
      isFalse,
    );
    expect(layout.toJson(), before);
    expect(doc.presentation.lines.single.section, 'stats');
  });

  test('page order, durations and explicit blank titles drive preview', () {
    final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_fixture);
    final GlossScoreboardLayout layout = GlossScoreboardLayout.fromJson(
      doc.presentation.extras['layout'],
    );
    layout.pages.insert(0, layout.pages.removeAt(1));
    doc.presentation.extras['layout'] = layout.toJson();
    final GlossConditionContext viewer = GlossConditionContext();
    expect(glossResolveScoreboardLayout(doc.presentation, viewer, 0).title, '');
    expect(
      glossResolveScoreboardLayout(
        doc.presentation,
        viewer,
        100,
      ).lines.single.text,
      'Second',
    );
    expect(
      glossResolveScoreboardLayout(doc.presentation, viewer, 150).title,
      'Base',
    );
    layout.pages.first.show = false;
    layout.pages.last.show = false;
    doc.presentation.extras['layout'] = layout.toJson();
    expect(
      glossResolveScoreboardLayout(
        doc.presentation,
        viewer,
        150,
      ).lines.single.text,
      'Health',
    );
  });

  test('native edits preserve other slots and unknown nested properties', () {
    final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_fixture);
    final GlossScoreboardObjectives objectives =
        GlossScoreboardObjectives.fromJson(doc.extras['objectives']);
    objectives.playerList = GlossScoreboardObjective(
      renderType: 'hearts',
      conflict: 'override',
      refreshTicks: 1,
    );
    objectives.belowName!.subjects = 'subject.world == viewer.world';
    final Map<String, Object?> restored = GlossScoreboardObjectives.fromJson(
      objectives.toJson(),
    ).toJson();
    expect(restored['custom'], 'objectives');
    expect((restored['belowName'] as Map)['custom'], <String, Object?>{
      'nested': true,
    });
    expect((restored['playerList'] as Map)['conflict'], 'override');
    objectives.playerList = null;
    expect(objectives.toJson().containsKey('playerList'), isFalse);
    expect(objectives.belowName!.value, 'subject.health');
  });

  test('advanced variant and objective mutations undo and redo together', () {
    final Map<String, String> storage = <String, String>{};
    final EditorStore store = EditorStore(
      workspace: Workspace(
        read: (String key) => storage[key],
        write: (String key, String value) {
          storage[key] = value;
          return true;
        },
      ),
      autosaveDelay: Duration.zero,
    );
    addTearDown(store.dispose);
    store.importJson('advanced.json', _fixture);
    final Object? original = jsonDecode(store.exportJson());
    store.mutateScoreboard('advanced settings', (GlossScoreboardDoc doc) {
      final GlossScoreboardLayout layout = GlossScoreboardLayout.fromJson(
        doc.variants.single.presentation.extras['layout'],
      );
      layout.refresh.textTicks = 10;
      layout.pages.add(
        GlossScoreboardPage(
          id: 'staff',
          lines: <GlossScoreboardLine>[
            GlossScoreboardLine(text: 'Rotating staff'),
          ],
        ),
      );
      doc.variants.single.presentation.extras['layout'] = layout.toJson();
      final GlossScoreboardObjectives objectives =
          GlossScoreboardObjectives.fromJson(doc.extras['objectives']);
      objectives.belowName!.conflict = 'override';
      doc.extras['objectives'] = objectives.toJson();
    });
    final Object? edited = jsonDecode(store.exportJson());
    expect(edited, isNot(original));
    expect(
      store.scoreboardDoc!.presentation.toJson(),
      (original as Map)['presentation'],
    );
    expect(store.performUndo(), isTrue);
    expect(jsonDecode(store.exportJson()), original);
    expect(store.performRedo(), isTrue);
    expect(jsonDecode(store.exportJson()), edited);
  });

  test(
    'malformed raw settings remain importable without lossy typed edits',
    () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_fixture);
      for (final Object bad in <Object>[
        <String, Object?>{'pages': 'bad'},
        <String, Object?>{
          'refresh': <String, Object?>{'textTicks': 1.5},
        },
        <String, Object?>{
          'sections': <String, Object?>{'one': 'bad'},
        },
        <String, Object?>{
          'pages': <Object>[
            <String, Object?>{'id': 'one', 'title': 42},
          ],
        },
      ]) {
        doc.presentation.extras['layout'] = bad;
        expect(
          () => GlossScoreboardLayout.fromJson(bad),
          throwsA(isA<HuiFormatException>()),
        );
        expect(
          decodeGlossScoreboardDoc(
            encodeGlossScoreboardDoc(doc),
          ).presentation.extras['layout'],
          bad,
        );
        expect(
          validateScoreboardDoc(
            doc,
          ).where((HuiIssue issue) => issue.severity == HuiSeverity.error),
          isNotEmpty,
        );
      }
    },
  );

  test(
    'native objectives validate enums, expression syntax, conditions and cadence',
    () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_fixture);
      doc.extras['objectives'] = <String, Object?>{
        'playerList': <String, Object?>{
          'title': 42,
          'value': 'subject.health +',
          'renderType': 'text',
          'format': 'rainbow',
          'valueText': '{{ 1 + }}',
          'show': 42,
          'subjects': '5',
          'refreshTicks': 0,
          'conflict': 'merge',
        },
      };
      final Set<String> paths = validateScoreboardDoc(doc)
          .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
          .map((HuiIssue issue) => issue.path)
          .toSet();
      for (final String field in <String>[
        'title',
        'value',
        'renderType',
        'format',
        'show',
        'subjects',
        'refreshTicks',
        'conflict',
      ]) {
        expect(paths, contains(r'$.objectives.playerList.' + field));
      }
      expect(
        validateScoreboardDoc(doc).any(
          (HuiIssue issue) =>
              issue.path == r'$.objectives.playerList.valueText',
        ),
        isTrue,
      );
      doc.extras['objectives'] = <String, Object?>{
        'playerList': <String, Object?>{
          'value': 'subject.health',
          'renderType': 'HEARTS',
          'format': 'fixed',
          'valueText': '{{ subject.health }}',
          'show': true,
          'subjects': 'subject.world == viewer.world',
          'refreshTicks': 72000,
          'conflict': 'OVERRIDE',
        },
        'belowName': <String, Object?>{},
      };
      expect(validateScoreboardDoc(doc), isEmpty);
    },
  );

  test('native objective containers and refresh upper bound are checked', () {
    final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_fixture);
    doc.extras['objectives'] = false;
    expect(validateScoreboardDoc(doc).single.path, r'$.objectives');
    doc.extras['objectives'] = <String, Object?>{'belowName': 'bad'};
    expect(validateScoreboardDoc(doc).single.path, r'$.objectives.belowName');
    doc.extras['objectives'] = <String, Object?>{
      'belowName': <String, Object?>{'refreshTicks': 72001},
    };
    expect(
      validateScoreboardDoc(doc).single.path,
      r'$.objectives.belowName.refreshTicks',
    );
  });
}
