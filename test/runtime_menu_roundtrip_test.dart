import 'dart:convert';

import 'package:gloss_editor/config/defaults.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/preview/action_log.dart';
import 'package:test/test.dart';

void main() {
  test('all runtime actions load, copy and retain nested authored values', () {
    final List<String> runtimeTypes = huiActionTypes
        .where((String type) => !huiEditorActionTypes.contains(type))
        .toList();
    expect(runtimeTypes, containsAll(<String>['surface', 'dialog', 'call']));
    for (final String type in runtimeTypes) {
      final Map<String, Object?> raw = <String, Object?>{
        'type': type,
        'trigger': 'shift_right_click',
        'show': 'player.online',
        'payload': <String, Object?>{
          'enabled': false,
          'count': 0,
          'actions': <Object?>[
            <String, Object?>{'type': 'message', 'message': 'Saved'},
          ],
        },
      };
      final HuiAction action = HuiAction.fromJson(raw);
      final HuiAction copied = action.copy();
      expect(action.toJson(), raw, reason: type);
      expect(copied.toJson(), raw, reason: type);
      (copied.extras['payload'] as Map<String, Object?>)['count'] = 9;
      expect((action.extras['payload'] as Map<String, Object?>)['count'], 0);
      copied.trigger = 'left_click';
      expect(copied.toJson()['trigger'], 'left_click');
      expect(loggedActionFrom(action), isA<LoggedRuntimeAction>());
    }
  });

  test('nested control flow survives editing the containing menu', () {
    final Map<String, Object?> sequence = <String, Object?>{
      'type': 'sequence',
      'steps': <Object?>[
        <String, Object?>{'type': 'delay', 'ticks': 20},
        <String, Object?>{
          'type': 'if',
          'condition': 'player.online',
          'then': <Object?>[
            <String, Object?>{'type': 'title', 'title': 'Welcome'},
          ],
          'else': <Object?>[
            <String, Object?>{'type': 'stop'},
          ],
        },
      ],
    };
    final HuiMenu menu = createDefaultMenu();
    menu.components.add(
      HuiComponent(
        'controls',
        Vec3.zero(),
        HuiButtonData(0.05, <HuiAction>[
          HuiAction.fromJson(sequence),
        ], HuiTextIcon('Run')),
      ),
    );
    final HuiMenu imported = decodeHuiMenu(encodeHuiMenu(menu));
    imported.components.last.offset.x = 2;
    final HuiMenu copied = cloneHuiMenu(imported);
    expect(
      (copied.components.last.data as HuiButtonData).actions.single.toJson(),
      sequence,
    );
  });

  test('list slider field and tabs load and survive layout edits', () {
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[
      <String, Object?>{
        'type': 'list',
        'var': 'entry',
        'source': 'server.players',
        'pageSize': 8,
        'flow': <String, Object?>{
          'columns': 2,
          'spacingX': 1.5,
          'spacingY': 0.5,
        },
        'template': <String, Object?>{
          'type': 'field',
          'var': 'answer',
          'prompt': 'chat',
          'label': 'Name',
          'initial': 'Guest',
        },
      },
      <String, Object?>{
        'type': 'slider',
        'var': 'volume',
        'min': 0,
        'max': 10,
        'step': 0.5,
        'width': 3,
        'label': 'Volume',
      },
      <String, Object?>{
        'type': 'field',
        'var': 'answer',
        'prompt': 'anvil',
        'label': 'Name',
        'initial': 'Guest',
      },
      <String, Object?>{
        'type': 'tabs',
        'var': 'page',
        'spacing': 2,
        'tabs': <Object?>[
          <String, Object?>{'id': 'home', 'label': 'Home'},
          <String, Object?>{'id': 'shop', 'label': 'Shop'},
        ],
      },
    ];
    final HuiMenu menu = createDefaultMenu();
    for (final Map<String, Object?> payload in payloads) {
      menu.components.add(
        HuiComponent(
          payload['type']! as String,
          Vec3.zero(),
          HuiComponentData.fromJson(payload),
        ),
      );
    }
    final HuiMenu imported = decodeHuiMenu(encodeHuiMenu(menu));
    for (int index = 0; index < payloads.length; index++) {
      final HuiComponent component = imported.componentById(
        payloads[index]['type']! as String,
      )!;
      component.offset.x = index.toDouble();
      expect(component.data.copy().toJson(), payloads[index]);
    }
    final Map<String, Object?> saved =
        jsonDecode(encodeHuiMenu(imported)) as Map<String, Object?>;
    expect(saved['components'], hasLength(menu.components.length));
    final HuiListData original =
        imported.componentById('list')!.data as HuiListData;
    final HuiListData copied = original.copy();
    copied.flow!['columns'] = 9;
    (copied.template! as HuiFieldData).initial = 'Changed';
    expect(original.flow!['columns'], 2);
    expect((original.template! as HuiFieldData).initial, 'Guest');
  });
}
