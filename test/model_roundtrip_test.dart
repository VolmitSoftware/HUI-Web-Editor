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
      expect(menu.components.map((HuiComponent c) => c.id).toList(), <String>[
        'title',
        'buy',
        'logo',
        'fly',
      ]);
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
      expect(buy.hitbox, isNull);
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
      expect(again.components.map((HuiComponent c) => c.id).toList(), <String>[
        'title',
        'inserted',
        'buy',
        'logo',
        'fly',
      ]);
    });
  });

  group('button hitbox', () {
    test('round-trips explicit dimensions', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button","highlightModifier":0.05,'
        '"hitbox":{"width":1.25,"height":0.35},"actions":[]}}]}',
      );
      final HuiButtonData button = menu.components.single.data as HuiButtonData;
      expect(button.hitbox!.width, 1.25);
      expect(button.hitbox!.height, 0.35);

      final String encoded = encodeHuiMenu(menu);
      expect(encoded, contains('"hitbox": {'));
      expect(encoded, contains('"width": 1.25'));
      expect(encoded, contains('"height": 0.35'));
    });

    test('round-trips detached offset-only geometry', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[1,2,3],'
        '"data":{"type":"button","highlightModifier":0.05,'
        '"hitbox":{"offset":[0.5,-0.25,0.75],"anchor":"menu"},'
        '"actions":[]}}]}',
      );
      final HuiHitbox hitbox =
          (menu.components.single.data as HuiButtonData).hitbox!;
      expect(hitbox.width, isNull);
      expect(hitbox.height, isNull);
      expect(hitbox.offset, Vec3(0.5, -0.25, 0.75));
      expect(hitbox.anchor, HuiHitboxAnchor.menu);

      final String encoded = encodeHuiMenu(menu);
      expect(encoded, contains('"offset": [0.5, -0.25, 0.75]'));
      expect(encoded, contains('"anchor": "menu"'));
      expect(encoded, isNot(contains('"width"')));
      expect(encoded, isNot(contains('"height"')));
    });

    test('omitted hitbox remains automatic and stays omitted', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button","actions":[]}}]}',
      );
      final HuiButtonData button = menu.components.single.data as HuiButtonData;
      expect(button.hitbox, isNull);
      expect(encodeHuiMenu(menu), isNot(contains('"hitbox"')));
    });

    test('copy owns independent hitbox geometry', () {
      final HuiButtonData original = HuiButtonData(
        0.05,
        <HuiAction>[],
        HuiTextIcon('Play'),
        HuiHitbox(1.25, 0.35, Vec3(0.5, -0.25, 0.75), HuiHitboxAnchor.menu),
      );
      final HuiButtonData copy = original.copy();
      copy.hitbox!.width = 2;
      copy.hitbox!.offset.x = 4;

      expect(original.hitbox!.width, 1.25);
      expect(original.hitbox!.offset.x, 0.5);
      expect(copy.hitbox!.width, 2);
      expect(copy.hitbox!.anchor, HuiHitboxAnchor.menu);
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

      final HuiDecorationData deco =
          menu.components[2].data as HuiDecorationData;
      final HuiItemIcon item = deco.icon! as HuiItemIcon;
      expect(item.count, 0);
      expect(item.customModelValue, 0);
    });

    test(
      'a missing root offset defaults to the origin instead of throwing',
      () {
        final HuiMenu menu = decodeHuiMenu('{"components":[]}');
        expect(menu.offset, Vec3(0, 0, 0));
        expect(menu.components, isEmpty);
      },
    );

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
      const String source =
          '{"offset":[0,0,0],"weirdRoot":{"a":1},'
          '"components":[{"id":"a","offset":[0,0,0],"nickname":"x",'
          '"data":{"type":"button","note":7,"icon":'
          '{"type":"text","text":"hi","tint":"red"},'
          '"actions":[{"type":"sound","sound":"ui.button.click",'
          '"source":"master","volume":1,"pitch":1,"delay":5}]}}]}';
      final String out = encodeHuiMenu(decodeHuiMenu(source));
      final Map<String, dynamic> tree = jsonDecode(out) as Map<String, dynamic>;

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
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[],'
        '"nested":{"list":[1,2]}}',
      );
      final HuiMenu clone = cloneHuiMenu(menu);
      (clone.extras['nested'] as Map<String, dynamic>)['list'] = <int>[9];
      expect((menu.extras['nested'] as Map<String, dynamic>)['list'], <int>[
        1,
        2,
      ]);
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

  group('customItem icon', () {
    String iconJson(String icon) =>
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"decoration","icon":$icon}}]}';

    HuiCustomItemIcon iconOf(HuiMenu menu) =>
        (menu.components.single.data as HuiDecorationData).icon!
            as HuiCustomItemIcon;

    test('is an authorable icon type', () {
      expect(huiIconTypes, contains('customItem'));
    });

    test('reads provider, item and count', () {
      final HuiCustomItemIcon icon = iconOf(
        decodeHuiMenu(
          iconJson(
            '{"type":"customItem","provider":"itemsadder",'
            '"item":"myitems:ruby","count":4}',
          ),
        ),
      );
      expect(icon.provider, 'itemsadder');
      expect(icon.item, 'myitems:ruby');
      expect(icon.count, 4);
      expect(icon.type, 'customItem');
    });

    test(
      'normalizes provider case and surrounding whitespace like runtime',
      () {
        final HuiMenu menu = decodeHuiMenu(
          iconJson(
            '{"type":"customItem","provider":"  ItemsAdder  ",'
            '"item":"myitems:ruby"}',
          ),
        );
        final HuiCustomItemIcon icon = iconOf(menu);
        expect(icon.provider, 'itemsadder');
        expect(encodeHuiMenu(menu), contains('"provider": "itemsadder"'));
      },
    );

    test('preserves the case of an id the provider defines uppercase', () {
      final HuiCustomItemIcon icon = iconOf(
        decodeHuiMenu(
          iconJson(
            '{"type":"customItem","provider":"mmoitems","item":"SWORD:CUTLASS"}',
          ),
        ),
      );
      expect(icon.item, 'SWORD:CUTLASS');
      expect(
        encodeHuiMenu(
          decodeHuiMenu(
            iconJson(
              '{"type":"customItem","provider":"mmoitems","item":"SWORD:CUTLASS"}',
            ),
          ),
        ),
        contains('"item": "SWORD:CUTLASS"'),
      );
    });

    test('a missing or blank provider defaults to auto', () {
      expect(
        iconOf(
          decodeHuiMenu(iconJson('{"type":"customItem","item":"ruby"}')),
        ).provider,
        'auto',
      );
      expect(
        iconOf(
          decodeHuiMenu(
            iconJson('{"type":"customItem","provider":"  ","item":"ruby"}'),
          ),
        ).provider,
        'auto',
      );
    });

    test('a missing or zero count coerces to 1, like the plugin', () {
      expect(
        iconOf(
          decodeHuiMenu(iconJson('{"type":"customItem","item":"ruby"}')),
        ).count,
        1,
      );
      expect(
        iconOf(
          decodeHuiMenu(
            iconJson('{"type":"customItem","item":"ruby","count":0}'),
          ),
        ).count,
        1,
      );
      expect(
        iconOf(
          decodeHuiMenu(
            iconJson('{"type":"customItem","item":"ruby","count":-3}'),
          ),
        ).count,
        1,
      );
    });

    test('exports the keys in the contract order', () {
      final String out = encodeHuiMenu(
        decodeHuiMenu(
          iconJson(
            '{"type":"customItem","count":2,"item":"ruby",'
            '"provider":"oraxen"}',
          ),
        ),
      );
      expect(
        out,
        contains(
          '"icon": {\n'
          '          "type": "customItem",\n'
          '          "provider": "oraxen",\n'
          '          "item": "ruby",\n'
          '          "count": 2\n'
          '        }',
        ),
      );
    });

    test('unknown keys survive a round trip', () {
      final HuiMenu menu = decodeHuiMenu(
        iconJson(
          '{"type":"customItem","provider":"nexo","item":"ruby",'
          '"lore":["a","b"],"note":{"x":1}}',
        ),
      );
      expect(iconOf(menu).extras.keys, <String>['lore', 'note']);
      final String out = encodeHuiMenu(menu);
      expect(out, contains('"lore"'));
      expect(out, contains('"note"'));
      expect(
        decodeHuiMenu(out).components.single.data,
        isA<HuiDecorationData>(),
      );
    });

    test('re-decoding an export is a fixed point', () {
      final String first = encodeHuiMenu(
        decodeHuiMenu(
          iconJson(
            '{"type":"customItem","provider":"slimefun","item":"MAGIC_WORKBENCH",'
            '"count":16,"extra":true}',
          ),
        ),
      );
      expect(encodeHuiMenu(decodeHuiMenu(first)), first);
    });

    test('copy() shares nothing with the original', () {
      final HuiCustomItemIcon icon =
          HuiCustomItemIcon('itemsadder', 'myitems:ruby', 2)
            ..extras = <String, dynamic>{
              'nested': <String, dynamic>{'a': 1},
            };
      final HuiCustomItemIcon copy = icon.copy();
      copy.item = 'other';
      (copy.extras['nested'] as Map<String, dynamic>)['a'] = 2;
      expect(icon.item, 'myitems:ruby');
      expect((icon.extras['nested'] as Map<String, dynamic>)['a'], 1);
    });
  });

  group('legacy keys', () {
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

    test('a command action without a source imports as player', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button","actions":[{"type":"command",'
        '"command":"/x"}]}}]}',
      );
      final HuiButtonData data = menu.components.single.data as HuiButtonData;
      expect((data.actions.single as HuiCommandAction).source, 'player');
      expect(encodeHuiMenu(menu), contains('"source": "player"'));
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

  group('action defaults on import', () {
    HuiCommandAction onlyCommand(HuiMenu menu) =>
        (menu.components.single.data as HuiButtonData).actions.single
            as HuiCommandAction;

    HuiSoundAction onlySound(HuiMenu menu) =>
        (menu.components.single.data as HuiButtonData).actions.single
            as HuiSoundAction;

    String document(String action) =>
        '{"offset":[0,0,0],"components":[{"id":"a","offset":[0,0,0],'
        '"data":{"type":"button","actions":[$action]}}]}';

    test('an absent or blank command source reads as the player default', () {
      expect(
        onlyCommand(
          decodeHuiMenu(document('{"type":"command","command":"/x"}')),
        ).source,
        'player',
      );
      expect(
        onlyCommand(
          decodeHuiMenu(
            document('{"type":"command","command":"/x","source":""}'),
          ),
        ).source,
        'player',
      );
    });

    test('an explicit command source survives verbatim', () {
      for (final String source in <String>['player', 'server', 'console']) {
        expect(
          onlyCommand(
            decodeHuiMenu(
              document('{"type":"command","command":"/x","source":"$source"}'),
            ),
          ).source,
          source,
          reason: source,
        );
      }
    });

    test('Java command enum names import as canonical JSON spellings', () {
      expect(
        onlyCommand(
          decodeHuiMenu(
            document('{"type":"command","command":"/x","source":"PLAYER"}'),
          ),
        ).source,
        'player',
      );
      expect(
        onlyCommand(
          decodeHuiMenu(
            document('{"type":"command","command":"/x","source":"GLOBAL"}'),
          ),
        ).source,
        'server',
      );
    });

    test('an omitted source exports the same file as an explicit player', () {
      final String absent = encodeHuiMenu(
        decodeHuiMenu(document('{"type":"command","command":"/x"}')),
      );
      final String explicit = encodeHuiMenu(
        decodeHuiMenu(
          document('{"type":"command","command":"/x","source":"player"}'),
        ),
      );
      expect(absent, explicit);
    });

    test('absent sound keys read as master, volume 1 and pitch 1', () {
      final HuiSoundAction sound = onlySound(
        decodeHuiMenu(document('{"type":"sound","sound":"ui.button.click"}')),
      );
      expect(sound.source, 'master');
      expect(sound.volume, 1);
      expect(sound.pitch, 1);
    });

    test('an explicit zero volume or pitch is preserved', () {
      final HuiSoundAction sound = onlySound(
        decodeHuiMenu(
          document(
            '{"type":"sound","sound":"ui.button.click","source":"music",'
            '"volume":0,"pitch":0}',
          ),
        ),
      );
      expect(sound.source, 'music');
      expect(sound.volume, 0);
      expect(sound.pitch, 0);
    });

    test('Java sound enum names import as canonical lowercase spellings', () {
      final HuiSoundAction sound = onlySound(
        decodeHuiMenu(
          document(
            '{"type":"sound","sound":"ui.button.click","source":"MUSIC"}',
          ),
        ),
      );
      expect(sound.source, 'music');
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
        () => decodeHuiMenu(
          '{"offset":[0,0,0],"components":[{"id":"a",'
          '"offset":[0,0,0],"data":{}}]}',
        ),
        throwsA(
          isA<HuiFormatException>()
              .having(
                (HuiFormatException e) => e.message,
                'message',
                contains('Missing type'),
              )
              .having(
                (HuiFormatException e) => e.path,
                'path',
                'components[0].data',
              ),
        ),
      );
    });

    test('throws on an unknown component data type', () {
      expect(
        () => decodeHuiMenu(
          '{"offset":[0,0,0],"components":[{"id":"a",'
          '"offset":[0,0,0],"data":{"type":"widget"}}]}',
        ),
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
        () => decodeHuiMenu(
          '{"offset":[0,0,0],"components":[{"id":"a",'
          '"offset":[0,0,0],"data":{"type":"decoration",'
          '"icon":{"type":"fontImage","path":"a.png"}}}]}',
        ),
        throwsA(
          isA<HuiFormatException>()
              .having(
                (HuiFormatException e) => e.message,
                'message',
                contains('Unknown type: fontImage'),
              )
              .having(
                (HuiFormatException e) => e.path,
                'path',
                'components[0].data.icon',
              ),
        ),
      );
    });

    test('the unknown-type message says the whole file fails to load', () {
      for (final String type in <String>['fontImage', 'itemStack']) {
        expect(
          () => decodeHuiMenu(
            '{"offset":[0,0,0],"components":[{"id":"a",'
            '"offset":[0,0,0],"data":{"type":"decoration",'
            '"icon":{"type":"$type"}}}]}',
          ),
          throwsA(
            isA<HuiFormatException>().having(
              (HuiFormatException e) => e.message,
              'message',
              allOf(<Matcher>[contains(type), contains('whole menu file')]),
            ),
          ),
          reason: type,
        );
      }
    });

    test('throws on an unknown action type', () {
      expect(
        () => decodeHuiMenu(
          '{"offset":[0,0,0],"components":[{"id":"a",'
          '"offset":[0,0,0],"data":{"type":"button","actions":'
          '[{"type":"teleport"}]}}]}',
        ),
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
          isA<HuiFormatException>().having(
            (HuiFormatException e) => e.path,
            'path',
            'offset',
          ),
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
      (clone.components[0].data as HuiDecorationData).icon = HuiTextIcon(
        'changed',
      );

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
