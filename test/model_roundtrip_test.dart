import 'dart:convert';

import 'package:holoui_editor/model/model.dart';
import 'package:test/test.dart';

/// Verbatim from report-holoui.md section 1.7 (the code-correct canonical
/// example). Raw string: the embedded `\n` must reach the parser as a JSON
/// escape, not as a Dart newline.
const String canonicalJson = r'''
{
  "offset": [0, 1.7, 2.5],
  "lockPosition": false,
  "followPlayer": true,
  "maxDistance": 8,
  "closeOnDeath": true,
  "closeOnTeleport": true,
  "components": [
    {
      "id": "title",
      "offset": [0, 0.85, 0],
      "data": { "type": "decoration",
                "icon": { "type": "text", "text": "&6&lVillage Store\n&7Click to buy" } }
    },
    {
      "id": "buy",
      "offset": [0, 0, 0],
      "data": { "type": "button",
                "highlightModifier": 0.05,
                "icon": { "type": "item", "item": "emerald", "count": 3, "customModelValue": 0 },
                "actions": [
                  { "type": "command", "source": "player", "command": "/warp shop" },
                  { "type": "sound", "sound": "ui.button.click", "source": "master", "volume": 1, "pitch": 1 }
                ] }
    },
    {
      "id": "logo",
      "offset": [-1.2, 0.2, 0],
      "data": { "type": "decoration",
                "icon": { "type": "animatedTextImage", "source": ["spin/0.png", "spin/1.png"], "speed": 3 } }
    },
    {
      "id": "fly",
      "offset": [1.2, 0.2, 0],
      "data": { "type": "toggle",
                "highlightModifier": 0.05,
                "condition": "%essentials_fly%",
                "expectedValue": "true",
                "trueIcon":  { "type": "textImage", "path": "fly_on.png" },
                "falseIcon": { "type": "textImage", "path": "fly_off.png" },
                "trueActions":  [{ "type": "command", "source": "player", "command": "/fly on" }],
                "falseActions": [{ "type": "command", "source": "player", "command": "/fly off" }] }
    }
  ]
}
''';

/// Exact expected output of [encodeHuiMenu] for [canonicalJson].
const String canonicalGolden = r'''{
  "offset": [0, 1.7, 2.5],
  "lockPosition": false,
  "followPlayer": true,
  "maxDistance": 8,
  "closeOnDeath": true,
  "closeOnTeleport": true,
  "components": [
    {
      "id": "title",
      "offset": [0, 0.85, 0],
      "data": {
        "type": "decoration",
        "icon": {
          "type": "text",
          "text": "&6&lVillage Store\n&7Click to buy"
        }
      }
    },
    {
      "id": "buy",
      "offset": [0, 0, 0],
      "data": {
        "type": "button",
        "highlightModifier": 0.05,
        "icon": {
          "type": "item",
          "item": "emerald",
          "count": 3,
          "customModelValue": 0
        },
        "actions": [
          {
            "type": "command",
            "source": "player",
            "command": "/warp shop"
          },
          {
            "type": "sound",
            "sound": "ui.button.click",
            "source": "master",
            "volume": 1,
            "pitch": 1
          }
        ]
      }
    },
    {
      "id": "logo",
      "offset": [-1.2, 0.2, 0],
      "data": {
        "type": "decoration",
        "icon": {
          "type": "animatedTextImage",
          "source": [
            "spin/0.png",
            "spin/1.png"
          ],
          "speed": 3
        }
      }
    },
    {
      "id": "fly",
      "offset": [1.2, 0.2, 0],
      "data": {
        "type": "toggle",
        "highlightModifier": 0.05,
        "condition": "%essentials_fly%",
        "expectedValue": "true",
        "trueIcon": {
          "type": "textImage",
          "path": "fly_on.png"
        },
        "falseIcon": {
          "type": "textImage",
          "path": "fly_off.png"
        },
        "trueActions": [
          {
            "type": "command",
            "source": "player",
            "command": "/fly on"
          }
        ],
        "falseActions": [
          {
            "type": "command",
            "source": "player",
            "command": "/fly off"
          }
        ]
      }
    }
  ]
}''';

void main() {
  group('canonical example', () {
    test('decodes every root field', () {
      final HuiMenu menu = decodeHuiMenu(canonicalJson);
      expect(menu.offset, Vec3(0, 1.7, 2.5));
      expect(menu.lockPosition, isFalse);
      expect(menu.followPlayer, isTrue);
      expect(menu.maxDistance, 8.0);
      expect(menu.closeOnDeath, isTrue);
      expect(menu.closeOnTeleport, isTrue);
      expect(menu.components.length, 4);
      expect(
        menu.components.map((HuiComponent c) => c.id).toList(),
        <String>['title', 'buy', 'logo', 'fly'],
      );
    });

    test('decodes every component payload', () {
      final HuiMenu menu = decodeHuiMenu(canonicalJson);

      final HuiDecorationData title =
          menu.components[0].data as HuiDecorationData;
      final HuiTextIcon titleIcon = title.icon! as HuiTextIcon;
      expect(titleIcon.text, '&6&lVillage Store\n&7Click to buy');
      expect(menu.components[0].offset, Vec3(0, 0.85, 0));

      final HuiButtonData buy = menu.components[1].data as HuiButtonData;
      expect(buy.highlightModifier, 0.05);
      final HuiItemIcon buyIcon = buy.icon! as HuiItemIcon;
      expect(buyIcon.item, 'emerald');
      expect(buyIcon.count, 3);
      expect(buyIcon.customModelValue, 0);
      expect(buy.actions.length, 2);
      final HuiCommandAction warp = buy.actions[0] as HuiCommandAction;
      expect(warp.command, '/warp shop');
      expect(warp.source, 'player');
      final HuiSoundAction click = buy.actions[1] as HuiSoundAction;
      expect(click.sound, 'ui.button.click');
      expect(click.source, 'master');
      expect(click.volume, 1.0);
      expect(click.pitch, 1.0);

      final HuiDecorationData logo =
          menu.components[2].data as HuiDecorationData;
      final HuiAnimatedImageIcon anim = logo.icon! as HuiAnimatedImageIcon;
      expect(anim.source, <String>['spin/0.png', 'spin/1.png']);
      expect(anim.speed, 3);

      final HuiToggleData fly = menu.components[3].data as HuiToggleData;
      expect(fly.highlightModifier, 0.05);
      expect(fly.condition, '%essentials_fly%');
      expect(fly.expectedValue, 'true');
      expect((fly.trueIcon! as HuiTextImageIcon).path, 'fly_on.png');
      expect((fly.falseIcon! as HuiTextImageIcon).path, 'fly_off.png');
      expect((fly.trueActions.single as HuiCommandAction).command, '/fly on');
      expect((fly.falseActions.single as HuiCommandAction).command, '/fly off');
    });

    test('encodes to the golden pretty form', () {
      expect(encodeHuiMenu(decodeHuiMenu(canonicalJson)), canonicalGolden);
    });

    test('golden re-decodes to an identical document', () {
      final HuiMenu once = decodeHuiMenu(canonicalJson);
      final HuiMenu twice = decodeHuiMenu(encodeHuiMenu(once));
      expect(encodeHuiMenu(twice), encodeHuiMenu(once));
    });

    test('preserves component declaration order through a round trip', () {
      final HuiMenu menu = decodeHuiMenu(canonicalJson);
      menu.components.insert(
        1,
        HuiComponent('inserted', Vec3(1, 1, 1), HuiDecorationData()),
      );
      final HuiMenu again = decodeHuiMenu(encodeHuiMenu(menu));
      expect(
        again.components.map((HuiComponent c) => c.id).toList(),
        <String>['title', 'inserted', 'buy', 'logo', 'fly'],
      );
    });
  });

  group('lenient import', () {
    test('coerces a single component object into a list', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":{"id":"solo","offset":[0,0,0],'
        '"data":{"type":"decoration"}}}',
      );
      expect(menu.components.length, 1);
      expect(menu.components.single.id, 'solo');
    });

    test('coerces a single action object into a list', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button","actions":{"type":"command",'
        '"command":"say hi","source":"server"}}}]}',
      );
      final HuiButtonData data = menu.components.single.data as HuiButtonData;
      expect(data.actions.length, 1);
      expect((data.actions.single as HuiCommandAction).command, 'say hi');
    });

    test('coerces a single animated source string into a list', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"decoration","icon":'
        '{"type":"animatedTextImage","source":"a.png","speed":2}}}]}',
      );
      final HuiDecorationData data =
          menu.components.single.data as HuiDecorationData;
      final HuiAnimatedImageIcon icon = data.icon! as HuiAnimatedImageIcon;
      expect(icon.source, <String>['a.png']);
      expect(encodeHuiMenu(menu), contains('"source": [\n            "a.png"'));
    });

    test('applies Java zero-values for every missing field', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button"}},{"id":"b","offset":[0,0,0],'
        '"data":{"type":"toggle"}},{"id":"c","offset":[0,0,0],'
        '"data":{"type":"decoration","icon":{"type":"item","item":"stone"}}}]}',
      );
      expect(menu.lockPosition, isFalse);
      expect(menu.followPlayer, isFalse);
      expect(menu.closeOnDeath, isFalse);
      expect(menu.closeOnTeleport, isFalse);
      expect(menu.maxDistance, isNull);

      final HuiButtonData button = menu.components[0].data as HuiButtonData;
      expect(button.highlightModifier, 0.0);
      expect(button.actions, isEmpty);
      expect(button.icon, isNull);

      final HuiToggleData toggle = menu.components[1].data as HuiToggleData;
      expect(toggle.highlightModifier, 0.0);
      expect(toggle.condition, '');
      expect(toggle.expectedValue, '');
      expect(toggle.trueActions, isEmpty);
      expect(toggle.falseActions, isEmpty);
      expect(toggle.trueIcon, isNull);
      expect(toggle.falseIcon, isNull);

      final HuiDecorationData deco = menu.components[2].data as HuiDecorationData;
      final HuiItemIcon item = deco.icon! as HuiItemIcon;
      expect(item.count, 0);
      expect(item.customModelValue, 0);
    });

    test('a missing root offset defaults to the origin instead of throwing', () {
      final HuiMenu menu = decodeHuiMenu('{"components":[]}');
      expect(menu.offset, Vec3(0, 0, 0));
      expect(menu.components, isEmpty);
    });

    test('defaulted hard-required keys are recorded for validation', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"components":[{"id":"a","data":{"type":"decoration"}}]}',
      );
      expect(menu.absentKeys, contains('offset'));
      expect(menu.absentKeys, isNot(contains('components')));
      expect(menu.components.single.absentKeys, contains('offset'));

      final HuiMenu whole = decodeHuiMenu('{"offset":[0,1.7,2.5]}');
      expect(whole.absentKeys, contains('components'));
      expect(whole.absentKeys, isNot(contains('offset')));

      // The repaired document carries both keys, so a re-decode is clean.
      expect(decodeHuiMenu(encodeHuiMenu(menu)).absentKeys, isEmpty);
    });
  });

  group('extras preservation', () {
    test('unknown keys survive a round trip at every level', () {
      const String source = '{"offset":[0,0,0],"weirdRoot":{"a":1},'
          '"components":[{"id":"a","offset":[0,0,0],"nickname":"x",'
          '"data":{"type":"button","note":7,"icon":'
          '{"type":"text","text":"hi","tint":"red"},'
          '"actions":[{"type":"sound","sound":"ui.button.click",'
          '"source":"master","volume":1,"pitch":1,"delay":5}]}}]}';
      final String out = encodeHuiMenu(decodeHuiMenu(source));
      final Map<String, dynamic> tree =
          jsonDecode(out) as Map<String, dynamic>;

      expect(tree['weirdRoot'], <String, dynamic>{'a': 1});
      final Map<String, dynamic> component =
          (tree['components'] as List<dynamic>).single as Map<String, dynamic>;
      expect(component['nickname'], 'x');
      final Map<String, dynamic> data =
          component['data'] as Map<String, dynamic>;
      expect(data['note'], 7);
      expect((data['icon'] as Map<String, dynamic>)['tint'], 'red');
      expect(
        ((data['actions'] as List<dynamic>).single
            as Map<String, dynamic>)['delay'],
        5,
      );
    });

    test('known keys win over an extras collision', () {
      final HuiTextIcon icon = HuiTextIcon('real')
        ..extras = <String, dynamic>{'text': 'fake', 'other': 1};
      final Map<String, dynamic> json = icon.toJson();
      expect(json['text'], 'real');
      expect(json['other'], 1);
    });

    test('extras are deep copied, not aliased', () {
      final HuiMenu menu = decodeHuiMenu('{"offset":[0,0,0],"components":[],'
          '"nested":{"list":[1,2]}}');
      final HuiMenu clone = cloneHuiMenu(menu);
      (clone.extras['nested'] as Map<String, dynamic>)['list'] =
          <int>[9];
      expect(
        (menu.extras['nested'] as Map<String, dynamic>)['list'],
        <int>[1, 2],
      );
    });

    test('the root id key is parsed then dropped, never re-emitted', () {
      final String out = encodeHuiMenu(
        decodeHuiMenu('{"id":"dropped","offset":[0,0,0],"components":[]}'),
      );
      expect(jsonDecode(out) as Map<String, dynamic>, isNot(contains('id')));
    });
  });

  group('customModelValue', () {
    test('reads and writes the customModelValue key', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"decoration","icon":{"type":"item",'
        '"item":"diamond_sword","count":1,"customModelValue":42}}}]}',
      );
      final HuiDecorationData data =
          menu.components.single.data as HuiDecorationData;
      expect((data.icon! as HuiItemIcon).customModelValue, 42);
      expect(encodeHuiMenu(menu), contains('"customModelValue": 42'));
    });

    test('the stale customModelData key migrates onto customModelValue', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"decoration","icon":{"type":"item",'
        '"item":"diamond_sword","customModelData":9}}}]}',
      );
      final HuiDecorationData data =
          menu.components.single.data as HuiDecorationData;
      final HuiItemIcon icon = data.icon! as HuiItemIcon;
      expect(icon.customModelValue, 9);
      expect(icon.extras, isNot(contains('customModelData')));
      final String out = encodeHuiMenu(menu);
      expect(out, contains('"customModelValue": 9'));
      expect(out, isNot(contains('customModelData')));
    });

    test('an explicit customModelValue wins over customModelData', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"decoration","icon":{"type":"item",'
        '"item":"diamond_sword","customModelValue":3,"customModelData":9}}}]}',
      );
      final HuiDecorationData data =
          menu.components.single.data as HuiDecorationData;
      expect((data.icon! as HuiItemIcon).customModelValue, 3);
    });
  });

  group('stale schema keys', () {
    test('an animated icon authored with path migrates onto source', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"decoration","icon":{"type":"animatedTextImage",'
        '"path":["a.png","b.png"],"speed":3}}}]}',
      );
      final HuiDecorationData data =
          menu.components.single.data as HuiDecorationData;
      final HuiAnimatedImageIcon icon = data.icon! as HuiAnimatedImageIcon;
      expect(icon.source, <String>['a.png', 'b.png']);
      expect(icon.speed, 3);
      final String out = encodeHuiMenu(menu);
      expect(out, contains('"a.png"'));
      expect(out, isNot(contains('"path"')));
    });

    test('a command action without a source imports as server', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button","actions":[{"type":"command",'
        '"command":"/x"}]}}]}',
      );
      final HuiButtonData data = menu.components.single.data as HuiButtonData;
      expect((data.actions.single as HuiCommandAction).source, 'server');
      expect(encodeHuiMenu(menu), contains('"source": "server"'));
    });

    test('an unknown command source is kept for validation to flag', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button","actions":[{"type":"command",'
        '"command":"/x","source":"console"}]}}]}',
      );
      final HuiButtonData data = menu.components.single.data as HuiButtonData;
      expect((data.actions.single as HuiCommandAction).source, 'console');
    });
  });

  group('strict export', () {
    test('omits maxDistance when unlimited and emits it when set', () {
      final HuiMenu menu = HuiMenu(offset: Vec3(0, 1.7, 2.5));
      expect(encodeHuiMenu(menu), isNot(contains('maxDistance')));
      menu.maxDistance = 16;
      expect(encodeHuiMenu(menu), contains('"maxDistance": 16'));
    });

    test('always emits sound volume, pitch and source', () {
      final HuiMenu menu = HuiMenu(
        offset: Vec3(0, 0, 0),
        components: <HuiComponent>[
          HuiComponent(
            'a',
            Vec3(0, 0, 0),
            HuiButtonData(0, <HuiAction>[HuiSoundAction()], null),
          ),
        ],
      );
      final String out = encodeHuiMenu(menu);
      expect(out, contains('"volume": 1'));
      expect(out, contains('"pitch": 1'));
      expect(out, contains('"source": "master"'));
      expect(out, contains('"sound": "ui.button.click"'));
    });

    test('writes vectors as inline three-number arrays', () {
      final HuiMenu menu = HuiMenu(offset: Vec3(1, -2.5, 0));
      expect(encodeHuiMenu(menu), contains('"offset": [1, -2.5, 0]'));
    });

    test('emits integral numbers without a trailing .0', () {
      final HuiMenu menu = HuiMenu(
        offset: Vec3(0, 0, 0),
        components: <HuiComponent>[
          HuiComponent(
            'a',
            Vec3(0, 0, 0),
            HuiButtonData(1, const <HuiAction>[], null),
          ),
        ],
      );
      expect(encodeHuiMenu(menu), contains('"highlightModifier": 1'));
    });
  });

  group('hard errors', () {
    test('throws on invalid JSON', () {
      expect(
        () => decodeHuiMenu('{ not json'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('throws when the root is not an object', () {
      expect(() => decodeHuiMenu('[1,2]'), throwsA(isA<HuiFormatException>()));
    });

    test('throws on a missing component data type', () {
      expect(
        () => decodeHuiMenu('{"offset":[0,0,0],"components":[{"id":"a",'
            '"offset":[0,0,0],"data":{}}]}'),
        throwsA(
          isA<HuiFormatException>()
              .having((HuiFormatException e) => e.message, 'message',
                  contains('Missing type'))
              .having((HuiFormatException e) => e.path, 'path',
                  'components[0].data'),
        ),
      );
    });

    test('throws on an unknown component data type', () {
      expect(
        () => decodeHuiMenu('{"offset":[0,0,0],"components":[{"id":"a",'
            '"offset":[0,0,0],"data":{"type":"widget"}}]}'),
        throwsA(
          isA<HuiFormatException>().having(
            (HuiFormatException e) => e.message,
            'message',
            contains('Unknown type: widget'),
          ),
        ),
      );
    });

    test('throws on an unknown icon type', () {
      expect(
        () => decodeHuiMenu('{"offset":[0,0,0],"components":[{"id":"a",'
            '"offset":[0,0,0],"data":{"type":"decoration",'
            '"icon":{"type":"fontImage","path":"a.png"}}}]}'),
        throwsA(
          isA<HuiFormatException>()
              .having((HuiFormatException e) => e.message, 'message',
                  contains('Unknown type: fontImage'))
              .having((HuiFormatException e) => e.path, 'path',
                  'components[0].data.icon'),
        ),
      );
    });

    test('throws on an unknown action type', () {
      expect(
        () => decodeHuiMenu('{"offset":[0,0,0],"components":[{"id":"a",'
            '"offset":[0,0,0],"data":{"type":"button","actions":'
            '[{"type":"teleport"}]}}]}'),
        throwsA(
          isA<HuiFormatException>().having(
            (HuiFormatException e) => e.path,
            'path',
            'components[0].data.actions[0]',
          ),
        ),
      );
    });

    test('throws when a vector does not have exactly three numbers', () {
      expect(
        () => decodeHuiMenu('{"offset":[0,1],"components":[]}'),
        throwsA(
          isA<HuiFormatException>()
              .having((HuiFormatException e) => e.path, 'path', 'offset'),
        ),
      );
    });
  });

  group('copies', () {
    test('cloneHuiMenu produces an independent document', () {
      final HuiMenu menu = decodeHuiMenu(canonicalJson);
      final HuiMenu clone = cloneHuiMenu(menu);
      expect(encodeHuiMenu(clone), encodeHuiMenu(menu));

      clone.offset.x = 99;
      clone.components.removeLast();
      (clone.components[0].data as HuiDecorationData).icon =
          HuiTextIcon('changed');

      expect(menu.offset.x, 0);
      expect(menu.components.length, 4);
      expect(
        ((menu.components[0].data as HuiDecorationData).icon! as HuiTextIcon)
            .text,
        '&6&lVillage Store\n&7Click to buy',
      );
    });

    test('copy() is deep on every node type', () {
      final HuiComponent component = HuiComponent(
        'a',
        Vec3(1, 2, 3),
        HuiToggleData(
          0.05,
          'c',
          'v',
          <HuiAction>[HuiCommandAction('/a', 'player')],
          <HuiAction>[HuiSoundAction('ui.button.click', 'master', 1, 1)],
          HuiAnimatedImageIcon(<String>['a.png'], 2),
          HuiItemIcon('stone', 1, 0),
        ),
      );
      final HuiComponent copy = component.copy();
      final HuiToggleData copied = copy.data as HuiToggleData;
      copy.offset.y = 9;
      copied.trueActions.clear();
      (copied.trueIcon! as HuiAnimatedImageIcon).source.add('b.png');

      final HuiToggleData original = component.data as HuiToggleData;
      expect(component.offset.y, 2);
      expect(original.trueActions.length, 1);
      expect((original.trueIcon! as HuiAnimatedImageIcon).source.length, 1);
    });
  });
}
