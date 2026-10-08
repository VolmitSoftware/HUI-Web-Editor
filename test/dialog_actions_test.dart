import 'package:gloss_editor/config/defaults.dart';
import 'package:gloss_editor/config/gloss_menu_json_schema.dart';
import 'package:gloss_editor/logic/action_document_validation.dart';
import 'package:gloss_editor/logic/dialog_action_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('native form and named calls preserve nested authoring fields', () {
    final HuiAction form = HuiAction.fromJson(<String, Object?>{
      'type': 'dialog',
      'title': 'Choose',
      'kind': 'notice',
      'inputs': <Object?>[
        <String, Object?>{
          'key': 'choice',
          'type': 'single_option',
          'initial': 'first',
          'options': <Object?>[
            <String, Object?>{'id': 'first', 'label': 'First'},
          ],
        },
      ],
      'buttons': <Object?>[
        <String, Object?>{
          'label': 'Accept',
          'actions': <Object?>[
            <String, Object?>{'type': 'call', 'action': 'save'},
          ],
        },
      ],
      'unsupported': <Object?>[
        <String, Object?>{'type': 'message', 'message': 'Use chat'},
      ],
    });
    expect(form.copy().toJson(), form.toJson());
    expect(validateDialogAction(form.toJson(), 'form'), isEmpty);
    expect(createDefaultAction('dialog').type, 'dialog');
    expect(createDefaultAction('call').type, 'call');
    expect(
      glossActionNode.variants['dialog']!.map((field) => field.key),
      containsAll(<String>['inputs', 'buttons', 'unsupported', 'onTimeout']),
    );
  });
  test('native forms reject invalid controls and native bounds', () {
    final List<String> paths = validateDialogAction(<String, Object?>{
      'kind': 'confirmation',
      'buttons': <Object?>[],
      'timeoutTicks': 0,
      'body': <Object?>[
        <String, Object?>{'width': 1025},
      ],
      'inputs': <Object?>[
        <String, Object?>{
          'key': 'same',
          'type': 'text',
          'initial': 'too long',
          'maxLength': 2,
        },
        <String, Object?>{
          'key': 'same',
          'type': 'number_range',
          'start': 0,
          'end': 10,
          'initial': 11,
          'step': -1,
        },
      ],
    }, 'form').map((issue) => issue.path).toList();
    expect(
      paths,
      containsAll(<String>[
        'form.buttons',
        'form.timeoutTicks',
        'form.body[0].width',
        'form.inputs[0].initial',
        'form.inputs[1].key',
        'form.inputs[1].initial',
        'form.inputs[1].step',
      ]),
    );
  });
  test(
    'named references validate cycles and unknown calls without flattening source',
    () {
      final Map<String, Object?> source = <String, Object?>{
        'actions': <String, Object?>{
          'save': <Object?>[
            <String, Object?>{'type': 'message', 'message': 'Saved'},
          ],
        },
        'slots': <String, Object?>{
          '0': <String, Object?>{
            'type': 'button',
            'actions': <Object?>[
              <String, Object?>{'type': 'call', 'action': 'save'},
            ],
          },
        },
      };
      expect(validateActionDocument(source), isEmpty);
      final HuiMenu menu = HuiMenu.fromJson(<String, Object?>{
        'components': <Object?>[],
        ...source,
      });
      expect(menu.copy().extras['actions'], source['actions']);
      source['actions'] = <String, Object?>{
        'save': <Object?>[
          <String, Object?>{'type': 'call', 'action': 'save'},
        ],
      };
      expect(
        validateActionDocument(
          source,
        ).any((issue) => issue.message.contains('cycle')),
        isTrue,
      );
      source['actions'] = <String, Object?>{};
      expect(
        validateActionDocument(
          source,
        ).any((issue) => issue.message.contains('does not exist')),
        isTrue,
      );
    },
  );
}
