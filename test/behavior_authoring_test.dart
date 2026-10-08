import 'package:gloss_editor/config/defaults.dart';
import 'package:gloss_editor/logic/behavior_action_validation.dart';
import 'package:gloss_editor/logic/behavior_validation.dart';
import 'package:gloss_editor/model/behavior_authoring.dart';
import 'package:gloss_editor/model/gloss_behavior.dart';
import 'package:gloss_editor/model/gloss_doc.dart';
import 'package:gloss_editor/model/hui_actions.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:test/test.dart';

void main() {
  test(
    'behavior calls are rejected in every supported continuation without rewriting source',
    () {
      final Map<String, Object?> call = <String, Object?>{
        'type': 'call',
        'action': 'saved',
        'future': <String, Object?>{'preserve': true},
      };
      final List<Object?> calls = <Object?>[call];
      final List<Map<String, Object?>> raw = <Map<String, Object?>>[
        call,
        <String, Object?>{'type': 'sequence', 'steps': calls, 'onSkip': calls},
        <String, Object?>{'type': 'repeat', 'times': 1, 'steps': calls},
        for (final String type in <String>['if', 'chance', 'cooldown'])
          <String, Object?>{
            ...createDefaultAction(type).toJson(),
            'then': calls,
            'else': calls,
          },
        <String, Object?>{
          'type': 'parallel',
          'branches': <Object?>[calls],
        },
        <String, Object?>{
          'type': 'switch',
          'on': "'saved'",
          'cases': <String, Object?>{'saved': calls},
          'default': calls,
        },
        <String, Object?>{'type': 'prompt', 'then': calls},
        <String, Object?>{
          'type': 'dialog',
          'unsupported': calls,
          'onTimeout': calls,
          'buttons': <Object?>[
            <String, Object?>{'actions': calls},
          ],
          'exitButton': <String, Object?>{'actions': calls},
        },
        <String, Object?>{'type': 'emit', 'name': 'saved', 'args': call},
      ];
      final GlossBehaviorDoc doc = GlossBehaviorDoc.fromJson(<String, Object?>{
        'schemaVersion': 2,
        'on': <Object?>[
          <String, Object?>{'trigger': 'join', 'do': raw},
        ],
      });
      final Map<String, Object?> baseline = doc.toJson();
      expect(
        validateBehaviorDoc(doc)
            .where(
              (issue) =>
                  issue.message ==
                  'Named action calls are not supported in behaviors.',
            )
            .map((issue) => issue.path),
        <String>[
          r'$.on[0].do[0].type',
          r'$.on[0].do[1].steps[0].type',
          r'$.on[0].do[1].onSkip[0].type',
          r'$.on[0].do[2].steps[0].type',
          for (int index = 3; index <= 5; index++) ...<String>[
            '\$.on[0].do[$index].then[0].type',
            '\$.on[0].do[$index].else[0].type',
          ],
          r'$.on[0].do[6].branches[0][0].type',
          r'$.on[0].do[7].cases.saved[0].type',
          r'$.on[0].do[7].default[0].type',
          r'$.on[0].do[8].then[0].type',
          r'$.on[0].do[9].unsupported[0].type',
          r'$.on[0].do[9].onTimeout[0].type',
          r'$.on[0].do[9].buttons[0].actions[0].type',
          r'$.on[0].do[9].exitButton.actions[0].type',
        ],
      );
      expect(doc.toJson(), baseline);
      final List<Map<String, Object?>> edited = HuiActionSourceList.read(raw)!
          .edit(
            (List<HuiAction> actions) =>
                actions.add(createDefaultAction('message')),
          );
      expect(edited.take(raw.length).toList(), raw);
    },
  );

  test(
    'single-field edits preserve absent defaults, malformed untouched fields and nested extras',
    () {
      final List<Map<String, Object?>> raw = <Map<String, Object?>>[
        <String, Object?>{
          'type': 'sound',
          'sound': 'ui.button.click',
          'volume': 'bad',
          'future': <String, Object?>{'nested': 1},
        },
        <String, Object?>{'type': 'command', 'command': 'help'},
      ];
      final HuiActionSourceList source = HuiActionSourceList.read(raw)!;
      final List<Map<String, Object?>> output = source.edit((
        List<HuiAction> actions,
      ) {
        actions[1] = (actions[1] as HuiCommandAction).copy()..command = 'list';
      });
      expect(output.first, raw.first);
      expect(output.last, <String, Object?>{
        'type': 'command',
        'command': 'list',
      });
      expect(raw.last['command'], 'help');
    },
  );
  test(
    'action reorder, duplicate entries, insert and deletion retain original shapes',
    () {
      final List<Map<String, Object?>> raw = <Map<String, Object?>>[
        <String, Object?>{'type': 'message', 'message': 'a', 'future': 1},
        <String, Object?>{'type': 'message', 'message': 'a'},
      ];
      expect(
        HuiActionSourceList.read(raw)!.edit(
          (List<HuiAction> actions) => actions.insert(0, actions.removeAt(1)),
        ),
        raw.reversed.toList(),
      );
      final List<Map<String, Object?>> added = HuiActionSourceList.read(raw)!
          .edit(
            (List<HuiAction> actions) =>
                actions.add(createDefaultAction('delay')),
          );
      expect(added.take(2).toList(), raw);
      expect(added.last, <String, Object?>{'type': 'delay', 'ticks': 20});
      expect(
        HuiActionSourceList.read(
          raw,
        )!.edit((List<HuiAction> actions) => actions.removeAt(0)),
        <Map<String, Object?>>[raw.last],
      );
    },
  );
  test('unknown and malformed action shapes are preserved for code repair', () {
    for (final Object? raw in <Object?>[
      'bad',
      <Object?>[null],
      <Object?>[
        <String, Object?>{'type': 'future'},
      ],
    ]) {
      expect(HuiActionSourceList.read(raw), isNull);
    }
    final List<Object?> raw = <Object?>[
      <String, Object?>{'type': 'sequence', 'steps': 'bad', 'future': 5},
    ];
    expect(
      HuiActionSourceList.read(raw)!.edit((List<HuiAction> actions) {}),
      raw,
    );
  });
  test(
    'nested actions edit in place without normalizing siblings or sequence cues',
    () {
      final Map<String, Object?> raw = <String, Object?>{
        'type': 'sequence',
        'future': true,
        'steps': <Object?>[
          <String, Object?>{
            'type': 'command',
            'command': 'help',
            'atTicks': 20,
          },
          <String, Object?>{'type': 'sound', 'sound': 'bell'},
        ],
      };
      final List<Map<String, Object?>> output =
          HuiActionSourceList.read(<Object?>[raw])!.edit((
            List<HuiAction> actions,
          ) {
            final HuiRuntimeAction next = (actions.single as HuiRuntimeAction)
                .copy();
            next.extras['steps'] =
                HuiActionSourceList.read(next.extras['steps'])!.edit((
                  List<HuiAction> steps,
                ) {
                  steps[0] = (steps[0] as HuiCommandAction).copy()
                    ..command = 'list';
                });
            actions[0] = next;
          });
      expect(output.single['future'], true);
      expect(output.single['steps'], <Object?>[
        <String, Object?>{'type': 'command', 'command': 'list', 'atTicks': 20},
        <String, Object?>{'type': 'sound', 'sound': 'bell'},
      ]);
    },
  );
  test(
    'state defaults preserve authored coercions and extensions until explicitly edited',
    () {
      for (final (String type, Object? value, Object expected)
          in <(String, Object?, Object)>[
            ('number', '12.5', 12.5),
            ('number', true, 1),
            ('number', null, 0),
            ('boolean', 'yes', true),
            ('boolean', 0, false),
            ('boolean', null, false),
            ('string', null, ''),
            ('string', 3, '3'),
          ]) {
        final Map<String, Object?> raw = <String, Object?>{
          'scope': 'player',
          'type': type,
          'default': value,
          'future': 4,
        };
        final BehaviorStateDeclaration state = BehaviorStateDeclaration.read(
          raw,
        )!;
        expect(state.resolvedDefault, expected);
        expect(state.toJson(), raw);
      }
      final BehaviorStateDeclaration omitted = BehaviorStateDeclaration(
        scope: 'world',
        type: 'boolean',
      );
      expect(omitted.toJson().containsKey('default'), false);
      expect(
        BehaviorStateDeclaration.read(<String, Object?>{
          'scope': true,
          'type': 'number',
        }),
        isNull,
      );
    },
  );
  test(
    'invalid numeric and boolean state defaults report the authored field',
    () {
      final GlossBehaviorDoc doc = GlossBehaviorDoc(
        state: <String, Object?>{
          'counter': <String, Object?>{
            'scope': 'player',
            'type': 'number',
            'default': 'bad',
          },
          'flag': <String, Object?>{
            'scope': 'global',
            'type': 'boolean',
            'default': 'bad',
          },
        },
      );
      expect(
        validateBehaviorDoc(doc).map((issue) => issue.path),
        containsAll(<String>[
          r'$.state.counter.default',
          r'$.state.flag.default',
        ]),
      );
    },
  );
  test(
    'authored flow defaults obey backend validation, including arbitrary value expressions',
    () {
      for (final String type in <String>[
        'sequence',
        'parallel',
        'repeat',
        'if',
        'switch',
        'chance',
        'delay',
        'cooldown',
        'setState',
        'addState',
        'clearState',
        'emit',
        'stop',
      ]) {
        expect(
          behaviorActionIssues(<Object?>[
            createDefaultAction(type).toJson(),
          ], r'$.do'),
          isEmpty,
          reason: type,
        );
      }
    },
  );
  test('flow limits and nested branches validate their actual paths', () {
    final List<Map<String, Object?>> raw = <Map<String, Object?>>[
      <String, Object?>{'type': 'repeat', 'times': 1025, 'steps': <Object?>[]},
      <String, Object?>{
        'type': 'sequence',
        'steps': <Object?>[
          <String, Object?>{'type': 'delay', 'ticks': 0, 'atTicks': -1},
        ],
      },
      <String, Object?>{'type': 'chance', 'percent': 101},
      <String, Object?>{
        'type': 'switch',
        'on': "'value'",
        'cases': <String, Object?>{'x': 'bad'},
      },
    ];
    expect(
      behaviorActionIssues(raw, r'$.do').map((issue) => issue.path),
      containsAll(<String>[
        r'$.do[0].times',
        r'$.do[1].steps[0].ticks',
        r'$.do[1].steps[0].atTicks',
        r'$.do[2].percent',
        r'$.do[3].cases.x',
      ]),
    );
  });
  test(
    'behavior action and state changes share undo without losing raw source',
    () {
      final EditorStore store = EditorStore();
      store.importJson(
        'behavior.json',
        '{"schemaVersion":2,"on":[{"trigger":"join","do":[{"type":"command","command":"help"}]}],"state":{"flag":{"scope":"player","type":"boolean","future":1}}}',
      );
      final Map<String, Object?> baseline =
          (store.glossDoc! as GlossBehaviorDoc).toJson();
      store.mutateGloss('edit action', (GlossDoc raw) {
        final GlossBehaviorDoc doc = raw as GlossBehaviorDoc;
        doc.on.single.actions = HuiActionSourceList.read(doc.on.single.actions)!
            .edit(
              (List<HuiAction> actions) =>
                  (actions.single as HuiCommandAction).command = 'list',
            );
      });
      expect(store.performUndo(), true);
      expect((store.glossDoc! as GlossBehaviorDoc).toJson(), baseline);
      expect(store.performRedo(), true);
      expect(
        (store.glossDoc! as GlossBehaviorDoc).on.single.actions.single
            .containsKey('source'),
        false,
      );
    },
  );
}
