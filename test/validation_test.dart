import 'dart:convert';

import 'package:holoui_editor/logic/canvas_scene.dart' show CanvasOverlap;
import 'package:holoui_editor/logic/hui_geometry.dart' show HuiRect;
import 'package:holoui_editor/logic/validation.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/services/catalogs.dart';
import 'package:test/test.dart';

HuiMenu _menu(List<HuiComponent> components) =>
    HuiMenu(offset: Vec3(0, 1.7, 2.5), components: components);

HuiComponent _component(String id, HuiComponentData data) =>
    HuiComponent(id, Vec3(0, 0, 0), data);

HuiMenu _withIcon(HuiIcon? icon) =>
    _menu(<HuiComponent>[_component('a', HuiDecorationData(icon))]);

/// highlightModifier 1 keeps the override note (its own group below) out of
/// every unrelated action assertion.
HuiMenu _withAction(HuiAction action) => _menu(<HuiComponent>[
      _component(
        'a',
        HuiButtonData(1, <HuiAction>[action], HuiTextIcon('x')),
      ),
    ]);

/// A one-button menu carrying [actionJson] verbatim, decoded rather than
/// constructed so absent-key tracking is exercised the way an import does it.
HuiMenu _decodedWithAction(String actionJson) =>
    decodeHuiMenu('{"offset":[0,1.7,2.5],"components":[{"id":"a",'
        '"offset":[0,0,0],"data":{"type":"button","highlightModifier":1,'
        '"icon":{"type":"text","text":"x"},"actions":[$actionJson]}}]}');

HuiMenu _withCommand(String command, {String? source}) => _decodedWithAction(
      '{"type":"command","command":${jsonEncode(command)}'
      '${source == null ? '' : ',"source":${jsonEncode(source)}'}}',
    );

HuiComponent _button(String id, {double modifier = 1, HuiIcon? icon}) =>
    _component(
      id,
      HuiButtonData(modifier, const <HuiAction>[], icon ?? HuiTextIcon('x')),
    );

CanvasOverlap _overlap(String first, String second) => CanvasOverlap(
      firstId: first,
      secondId: second,
      region: const HuiRect(x: 0, y: 0, w: 0.1, h: 0.1),
    );

Iterable<HuiIssue> _matching(
  List<HuiIssue> issues,
  HuiSeverity severity,
  Pattern fragment,
) =>
    issues.where((HuiIssue i) =>
        i.severity == severity && i.message.contains(fragment));

bool _has(List<HuiIssue> issues, HuiSeverity severity, Pattern fragment) =>
    _matching(issues, severity, fragment).isNotEmpty;

void main() {
  group('component ids', () {
    test('flags duplicate ids as warnings', () {
      final List<HuiIssue> issues = validateHuiMenu(_menu(<HuiComponent>[
        _component('dup', HuiDecorationData(HuiTextIcon('a'))),
        _component('dup', HuiDecorationData(HuiTextIcon('b'))),
      ]));
      expect(_has(issues, HuiSeverity.warning, 'Duplicate component id'), isTrue);
      expect(
        _matching(issues, HuiSeverity.warning, 'Duplicate component id')
            .single
            .path,
        'components[1].id',
      );
    });

    test('flags an empty id', () {
      final List<HuiIssue> issues =
          validateHuiMenu(_menu(<HuiComponent>[
        _component('', HuiDecorationData(HuiTextIcon('a'))),
      ]));
      expect(_has(issues, HuiSeverity.warning, 'no id'), isTrue);
    });

    test('flags characters outside [A-Za-z0-9_.-]', () {
      final List<HuiIssue> issues =
          validateHuiMenu(_menu(<HuiComponent>[
        _component('bad id!', HuiDecorationData(HuiTextIcon('a'))),
      ]));
      expect(_has(issues, HuiSeverity.warning, 'invalid characters'), isTrue);
    });

    test('flags ids longer than 64 characters', () {
      final List<HuiIssue> issues =
          validateHuiMenu(_menu(<HuiComponent>[
        _component('a' * 65, HuiDecorationData(HuiTextIcon('a'))),
      ]));
      expect(_has(issues, HuiSeverity.warning, 'longer than 64'), isTrue);
    });

    test('accepts a clean id', () {
      final List<HuiIssue> issues =
          validateHuiMenu(_menu(<HuiComponent>[
        _component('shop.buy-1_x', HuiDecorationData(HuiTextIcon('a'))),
      ]));
      expect(issues, isEmpty);
    });
  });

  group('command actions', () {
    test('flags a missing command as an error', () {
      expect(
        _has(validateHuiMenu(_withAction(HuiCommandAction('  ', 'player'))),
            HuiSeverity.error, 'Command is empty'),
        isTrue,
      );
    });

    test('reports placeholders in commands as info', () {
      expect(
        _has(
          validateHuiMenu(
              _withAction(HuiCommandAction('/pay %player_name%', 'player'))),
          HuiSeverity.info,
          'not expanded in commands',
        ),
        isTrue,
      );
    });

    test('flags a command source that is neither player nor server', () {
      expect(
        _has(validateHuiMenu(_withAction(HuiCommandAction('/a', 'console'))),
            HuiSeverity.warning, 'not one of the two spellings'),
        isTrue,
      );
    });
  });

  group('sound actions', () {
    test('flags an uppercase sound key as an error', () {
      expect(
        _has(
          validateHuiMenu(
              _withAction(HuiSoundAction('UI.BUTTON.CLICK', 'master', 1, 1))),
          HuiSeverity.error,
          'lowercase',
        ),
        isTrue,
      );
    });

    test('flags invalid sound key characters as an error', () {
      expect(
        _has(
          validateHuiMenu(
              _withAction(HuiSoundAction('ui button click', 'master', 1, 1))),
          HuiSeverity.error,
          'invalid characters',
        ),
        isTrue,
      );
    });

    test('flags an empty sound key as an error', () {
      expect(
        _has(validateHuiMenu(_withAction(HuiSoundAction('', 'master', 1, 1))),
            HuiSeverity.error, 'Sound key is empty'),
        isTrue,
      );
    });

    test('flags a missing or unknown sound source as an error', () {
      expect(
        _has(
          validateHuiMenu(
              _withAction(HuiSoundAction('ui.button.click', '', 1, 1))),
          HuiSeverity.error,
          'Sound source',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(
              _withAction(HuiSoundAction('ui.button.click', 'sfx', 1, 1))),
          HuiSeverity.error,
          'Sound source',
        ),
        isTrue,
      );
    });

    test('warns on a sound missing from the catalog', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withAction(HuiSoundAction('ui.nope', 'master', 1, 1)),
        knownSounds: <String>{'ui.button.click'},
      );
      expect(_has(issues, HuiSeverity.warning, 'not in the sound catalog'),
          isTrue);
    });

    test('accepts a namespaced sound present in the catalog', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withAction(
            HuiSoundAction('minecraft:ui.button.click', 'master', 1, 1)),
        knownSounds: <String>{'ui.button.click'},
      );
      expect(issues, isEmpty);
    });

    test('warns on zero volume and zero pitch', () {
      final List<HuiIssue> issues = validateHuiMenu(
          _withAction(HuiSoundAction('ui.button.click', 'master', 0, 0)));
      expect(_has(issues, HuiSeverity.warning, 'Volume 0'), isTrue);
      expect(_has(issues, HuiSeverity.warning, 'Pitch 0'), isTrue);
    });

    test('reports a pitch outside 0.5-2.0 as info', () {
      final List<HuiIssue> issues = validateHuiMenu(
          _withAction(HuiSoundAction('ui.button.click', 'master', 1, 3)));
      expect(_has(issues, HuiSeverity.info, 'outside the 0.5-2.0'), isTrue);
    });
  });

  group('item icons', () {
    test('flags an uppercase material key as an error', () {
      expect(
        _has(validateHuiMenu(_withIcon(HuiItemIcon('STONE', 1, 0))),
            HuiSeverity.error, 'lowercase'),
        isTrue,
      );
    });

    test('flags an empty material key as an error', () {
      expect(
        _has(validateHuiMenu(_withIcon(HuiItemIcon('', 1, 0))),
            HuiSeverity.error, 'Material key is empty'),
        isTrue,
      );
    });

    test('warns on a material missing from the catalog', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiItemIcon('unobtainium', 1, 0)),
        knownMaterials: <String>{'stone'},
      );
      expect(_has(issues, HuiSeverity.warning, 'not in the material catalog'),
          isTrue);
    });
  });

  group('custom item icons', () {
    final HuiCustomItemCatalog catalog = HuiCustomItemCatalog.parse(
      '{"providers":["itemsadder"],"items":[{"provider":"itemsadder",'
      '"id":"myitems:ruby","material":"diamond"}]}',
    )!;

    test('flags a blank id as an error', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiCustomItemIcon('itemsadder', '  ', 1))),
          HuiSeverity.error,
          'Custom item id is empty',
        ),
        isTrue,
      );
    });

    test('accepts any id under a known provider or auto', () {
      for (final String provider in <String>['auto', 'itemsadder', '']) {
        expect(
          validateHuiMenu(
            _withIcon(HuiCustomItemIcon(provider, 'anything:at:all', 1)),
          ),
          isEmpty,
          reason: provider,
        );
      }
    });

    test('warns on a provider the plugin has no adapter for', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiCustomItemIcon('itemsadder2', 'myitems:ruby', 1)),
      );
      expect(_has(issues, HuiSeverity.warning, 'Unknown item provider'), isTrue);
      expect(
        _matching(issues, HuiSeverity.warning, 'Unknown item provider')
            .single
            .path,
        'components[0].data.icon.provider',
      );
    });

    test('warns on a provider id that only differs in case', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiCustomItemIcon('ItemsAdder', 'myitems:ruby', 1)),
      );
      expect(_has(issues, HuiSeverity.warning, 'Unknown item provider'), isTrue);
      expect(
        _matching(issues, HuiSeverity.warning, 'Unknown item provider')
            .single
            .fix,
        contains('itemsadder'),
      );
    });

    test('warns on padded ids, which never match verbatim', () {
      expect(
        _has(
          validateHuiMenu(
            _withIcon(HuiCustomItemIcon('oraxen', ' ruby_sword', 1)),
          ),
          HuiSeverity.warning,
          'whitespace',
        ),
        isTrue,
      );
    });

    test('warns on a count outside 1-99', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiCustomItemIcon('auto', 'ruby', 0))),
          HuiSeverity.warning,
          'count',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiCustomItemIcon('auto', 'ruby', 100))),
          HuiSeverity.warning,
          'count',
        ),
        isTrue,
      );
      expect(
        validateHuiMenu(_withIcon(HuiCustomItemIcon('auto', 'ruby', 99))),
        isEmpty,
      );
    });

    test('an id missing from the catalog is info, never an error', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiCustomItemIcon('itemsadder', 'myitems:sapphire', 1)),
        customItems: catalog,
      );
      expect(_has(issues, HuiSeverity.info, 'not in the custom item catalog'),
          isTrue);
      expect(issues.where((HuiIssue i) => i.severity == HuiSeverity.error),
          isEmpty);
    });

    test('an id present in the catalog raises nothing', () {
      expect(
        validateHuiMenu(
          _withIcon(HuiCustomItemIcon('itemsadder', 'myitems:ruby', 1)),
          customItems: catalog,
        ),
        isEmpty,
      );
      expect(
        validateHuiMenu(
          _withIcon(HuiCustomItemIcon('auto', 'myitems:ruby', 1)),
          customItems: catalog,
        ),
        isEmpty,
      );
    });

    test('without a catalog an unknown id raises nothing', () {
      expect(
        validateHuiMenu(
          _withIcon(HuiCustomItemIcon('itemsadder', 'myitems:sapphire', 1)),
        ),
        isEmpty,
      );
      expect(
        validateHuiMenu(
          _withIcon(HuiCustomItemIcon('itemsadder', 'myitems:sapphire', 1)),
          customItems: HuiCustomItemCatalog.empty(),
        ),
        isEmpty,
      );
    });
  });

  group('animated icons', () {
    test('flags an empty source list as an error', () {
      expect(
        _has(
            validateHuiMenu(
                _withIcon(HuiAnimatedImageIcon(<String>[], 2))),
            HuiSeverity.error,
            'no frames'),
        isTrue,
      );
    });

    test('flags speed below 1 as an error', () {
      expect(
        _has(
          validateHuiMenu(
              _withIcon(HuiAnimatedImageIcon(<String>['a.png'], 0))),
          HuiSeverity.error,
          'every tick',
        ),
        isTrue,
      );
    });

    test('validates every frame path', () {
      expect(
        _has(
          validateHuiMenu(
              _withIcon(HuiAnimatedImageIcon(<String>['../a.png'], 2))),
          HuiSeverity.error,
          'must not contain',
        ),
        isTrue,
      );
    });
  });

  group('image paths', () {
    test('flags a leading slash, colon, dot-dot and backslash as errors', () {
      for (final String path in <String>[
        '/a.png',
        'C:/a.png',
        '../a.png',
        r'dir\a.png',
      ]) {
        expect(
          _has(validateHuiMenu(_withIcon(HuiTextImageIcon(path))),
              HuiSeverity.error, 'Image path'),
          isTrue,
          reason: path,
        );
      }
    });

    test('flags paths longer than 256 characters', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiTextImageIcon('${'a' * 253}.png'))),
          HuiSeverity.error,
          'longer than 256',
        ),
        isTrue,
      );
    });

    test('flags an empty image path', () {
      expect(
        _has(validateHuiMenu(_withIcon(HuiTextImageIcon(''))),
            HuiSeverity.error, 'Image path is empty'),
        isTrue,
      );
    });

    test('reports a path missing from the image library as info', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiTextImageIcon('logo.png')),
        knownImagePaths: <String>{'other.png'},
      );
      expect(_has(issues, HuiSeverity.info, 'not in the image library'), isTrue);
    });
  });

  group('text icons', () {
    test('warns about the broken &n and &k legacy codes', () {
      expect(
        _has(validateHuiMenu(_withIcon(HuiTextIcon('&nHello'))),
            HuiSeverity.warning, 'render literally'),
        isTrue,
      );
      expect(
        _has(validateHuiMenu(_withIcon(HuiTextIcon('&kHello'))),
            HuiSeverity.warning, 'render literally'),
        isTrue,
      );
      expect(
        _has(validateHuiMenu(_withIcon(HuiTextIcon('&lHello'))),
            HuiSeverity.warning, 'render literally'),
        isFalse,
      );
    });

    test('reports placeholders in text as info', () {
      expect(
        _has(validateHuiMenu(_withIcon(HuiTextIcon('Hi %player_name%'))),
            HuiSeverity.info, 'PlaceholderAPI'),
        isTrue,
      );
    });
  });

  group('components and menu root', () {
    test('warns when a highlightModifier falls outside 0..1', () {
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[
            _component('a', HuiButtonData(2, const <HuiAction>[], HuiTextIcon('x'))),
          ])),
          HuiSeverity.warning,
          'highlightModifier',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[
            _component(
                'a', HuiButtonData(-1, const <HuiAction>[], HuiTextIcon('x'))),
          ])),
          HuiSeverity.warning,
          'highlightModifier',
        ),
        isTrue,
      );
    });

    test('warns when an icon is null', () {
      expect(
        _has(validateHuiMenu(_withIcon(null)), HuiSeverity.warning,
            'missing-icon placeholder'),
        isTrue,
      );
    });

    test('errors when a toggle condition or expected value is empty', () {
      final List<HuiIssue> issues = validateHuiMenu(_menu(<HuiComponent>[
        _component(
          'a',
          HuiToggleData(0.05, '', '', const <HuiAction>[], const <HuiAction>[],
              HuiTextIcon('on'), HuiTextIcon('off')),
        ),
      ]));
      expect(_has(issues, HuiSeverity.error, 'condition is empty'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'expectedValue is empty'), isTrue);
    });

    test('warns when maxDistance falls outside [0, 6e7]', () {
      final HuiMenu menu = _menu(const <HuiComponent>[])..maxDistance = -1;
      expect(_has(validateHuiMenu(menu), HuiSeverity.warning, 'maxDistance'),
          isTrue);
      menu.maxDistance = 7e7;
      expect(_has(validateHuiMenu(menu), HuiSeverity.warning, 'maxDistance'),
          isTrue);
      menu.maxDistance = 8;
      expect(_has(validateHuiMenu(menu), HuiSeverity.warning, 'maxDistance'),
          isFalse);
    });

    test('carries the owning component id on nested issues', () {
      final List<HuiIssue> issues = validateHuiMenu(_menu(<HuiComponent>[
        _component(
          'buy',
          HuiButtonData(
              0.05, <HuiAction>[HuiCommandAction('', 'player')], HuiTextIcon('x')),
        ),
      ]));
      final HuiIssue issue =
          _matching(issues, HuiSeverity.error, 'Command is empty').single;
      expect(issue.componentId, 'buy');
      expect(issue.path, 'components[0].data.actions[0].command');
    });

    test('warns when the menu has no components at all', () {
      expect(
        _has(validateHuiMenu(_menu(const <HuiComponent>[])),
            HuiSeverity.warning, 'no components'),
        isTrue,
      );
    });

    test('reports offsets and components the imported file never had', () {
      final HuiMenu menu = decodeHuiMenu(
        '{"components":[{"id":"a","data":{"type":"decoration",'
        '"icon":{"type":"text","text":"hi"}}}]}',
      );
      final List<HuiIssue> issues = validateHuiMenu(menu);
      expect(_has(issues, HuiSeverity.info, 'no menu offset'), isTrue);
      expect(
        _matching(issues, HuiSeverity.info, 'no menu offset').single.path,
        'offset',
      );
      expect(_has(issues, HuiSeverity.info, 'no offset'), isTrue);
      expect(
        _matching(issues, HuiSeverity.info, 'no offset').single.path,
        'components[0].offset',
      );

      final List<HuiIssue> missingList =
          validateHuiMenu(decodeHuiMenu('{"offset":[0,1.7,2.5]}'));
      expect(_has(missingList, HuiSeverity.info, 'no components list'), isTrue);
    });

    test('a repaired document reports no defaulted-key notes', () {
      final HuiMenu menu = decodeHuiMenu(encodeHuiMenu(decodeHuiMenu(
        '{"components":[{"id":"a","data":{"type":"decoration",'
        '"icon":{"type":"text","text":"hi"}}}]}',
      )));
      expect(
        validateHuiMenu(menu)
            .where((HuiIssue i) => i.severity == HuiSeverity.info),
        isEmpty,
      );
    });

    test('a canonical valid menu produces no issues', () {
      final HuiMenu menu = _menu(<HuiComponent>[
        _component('title', HuiDecorationData(HuiTextIcon('&6&lStore'))),
        _component(
          'buy',
          HuiButtonData(
            1,
            <HuiAction>[
              HuiCommandAction('/warp shop', 'player'),
              HuiSoundAction('ui.button.click', 'master', 1, 1),
            ],
            HuiItemIcon('emerald', 3, 0),
          ),
        ),
      ]);
      expect(validateHuiMenu(menu), isEmpty);
    });

    test('the same menu at the typical 0.05 modifier adds only the note', () {
      final HuiMenu menu = _menu(<HuiComponent>[
        _component('title', HuiDecorationData(HuiTextIcon('&6&lStore'))),
        _component(
          'buy',
          HuiButtonData(
            0.05,
            <HuiAction>[HuiCommandAction('/warp shop', 'player')],
            HuiItemIcon('emerald', 3, 0),
          ),
        ),
      ]);
      final List<HuiIssue> issues = validateHuiMenu(menu);
      expect(issues, hasLength(1));
      expect(issues.single.severity, HuiSeverity.info);
      expect(issues.single.path, 'components[1].data.highlightModifier');
    });
  });

  group('overlapping hitboxes', () {
    final HuiMenu three = _menu(<HuiComponent>[
      _button('a'),
      _button('b'),
      _button('c'),
    ]);

    test('an overlapping pair is a warning naming both components', () {
      final List<HuiIssue> issues = validateHuiMenu(
        three,
        overlaps: <CanvasOverlap>[_overlap('a', 'b')],
      );
      final HuiIssue issue =
          _matching(issues, HuiSeverity.warning, 'Hitbox overlaps').single;
      expect(issue.message, contains('"b"'));
      expect(issue.componentId, 'a');
      expect(issue.path, 'components[0]');
      expect(issue.fix, isNotNull);
    });

    test('the path indexes the first component of the pair', () {
      final List<HuiIssue> issues = validateHuiMenu(
        three,
        overlaps: <CanvasOverlap>[_overlap('b', 'c')],
      );
      expect(
        _matching(issues, HuiSeverity.warning, 'Hitbox overlaps').single.path,
        'components[1]',
      );
    });

    test('a three-way overlap reports all three pairs', () {
      final List<HuiIssue> issues = validateHuiMenu(
        three,
        overlaps: <CanvasOverlap>[
          _overlap('a', 'b'),
          _overlap('a', 'c'),
          _overlap('b', 'c'),
        ],
      );
      expect(
        _matching(issues, HuiSeverity.warning, 'Hitbox overlaps'),
        hasLength(3),
      );
    });

    test('no overlaps leaves the issue list exactly as it was', () {
      expect(validateHuiMenu(three), isEmpty);
      expect(
        validateHuiMenu(three, overlaps: const <CanvasOverlap>[]).map(
          (HuiIssue i) => i.toString(),
        ),
        validateHuiMenu(three).map((HuiIssue i) => i.toString()),
      );
    });

    test('a pair naming a component the menu no longer has is skipped', () {
      expect(
        validateHuiMenu(three, overlaps: <CanvasOverlap>[_overlap('a', 'gone')]),
        isEmpty,
      );
    });
  });

  group('wide text hitboxes', () {
    test('a clickable text line of 16 characters is reported as info', () {
      final List<HuiIssue> issues = validateHuiMenu(_menu(<HuiComponent>[
        _button('a', icon: HuiTextIcon('0123456789abcdef')),
      ]));
      final HuiIssue issue =
          _matching(issues, HuiSeverity.info, 'character count').single;
      expect(issue.message, contains('16 characters'));
      expect(issue.message, contains('1.75'));
      expect(issue.path, 'components[0].data.icon.text');
    });

    test('15 characters stays below the threshold', () {
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[
            _button('a', icon: HuiTextIcon('0123456789abcde')),
          ])),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
      );
    });

    test('formatting codes do not count towards the width', () {
      // TextUtils.content() is the rendered string, so &6&l is not in the
      // plane width even though the raw field is 20 characters.
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[
            _button('a', icon: HuiTextIcon('&6&lVillage Store')),
          ])),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
      );
    });

    test('only the widest line counts, and lines are measured separately', () {
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[
            _button('a', icon: HuiTextIcon('short\nshort too')),
          ])),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
      );
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[
            _button('a', icon: HuiTextIcon('short\n0123456789abcdef')),
          ])),
          HuiSeverity.info,
          'character count',
        ),
        isTrue,
      );
    });

    test('a decoration is never reported: it has no hitbox at all', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiTextIcon('0123456789abcdefghij'))),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
      );
    });

    test('both toggle icons are measured', () {
      final List<HuiIssue> issues = validateHuiMenu(_menu(<HuiComponent>[
        _component(
          'a',
          HuiToggleData(
            1,
            '%c%',
            'true',
            const <HuiAction>[],
            const <HuiAction>[],
            HuiTextIcon('0123456789abcdef'),
            HuiTextIcon('0123456789abcdefgh'),
          ),
        ),
      ]));
      expect(
        _matching(issues, HuiSeverity.info, 'character count')
            .map((HuiIssue i) => i.path),
        <String>[
          'components[0].data.trueIcon.text',
          'components[0].data.falseIcon.text',
        ],
      );
    });
  });

  group('highlightModifier override', () {
    test('a clickable with a modifier other than 1 is reported once', () {
      final List<HuiIssue> issues = validateHuiMenu(_menu(<HuiComponent>[
        _button('a', modifier: 0.05),
      ]));
      final HuiIssue issue =
          _matching(issues, HuiSeverity.info, 'first hover tick').single;
      expect(issue.path, 'components[0].data.highlightModifier');
      expect(issue.componentId, 'a');
    });

    test('twenty offenders still produce exactly one issue', () {
      final List<HuiComponent> components = <HuiComponent>[
        for (int i = 0; i < 20; i++) _button('b$i', modifier: 0.05),
      ];
      final List<HuiIssue> issues = validateHuiMenu(_menu(components));
      final HuiIssue issue =
          _matching(issues, HuiSeverity.info, 'first hover tick').single;
      expect(issue.path, 'components[0].data.highlightModifier');
    });

    test('the note points at the first offender, not the first clickable', () {
      final List<HuiIssue> issues = validateHuiMenu(_menu(<HuiComponent>[
        _button('a'),
        _button('b', modifier: 0.2),
        _button('c', modifier: 0.3),
      ]));
      expect(
        _matching(issues, HuiSeverity.info, 'first hover tick').single.path,
        'components[1].data.highlightModifier',
      );
    });

    test('a modifier of exactly 1 already matches the snap', () {
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[_button('a')])),
          HuiSeverity.info,
          'first hover tick',
        ),
        isFalse,
      );
    });

    test('a toggle counts, a decoration does not', () {
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[
            _component(
              'a',
              HuiToggleData(0.05, '%c%', 'true', const <HuiAction>[],
                  const <HuiAction>[], HuiTextIcon('on'), HuiTextIcon('off')),
            ),
          ])),
          HuiSeverity.info,
          'first hover tick',
        ),
        isTrue,
      );
      expect(
        _has(validateHuiMenu(_withIcon(HuiTextIcon('x'))), HuiSeverity.info,
            'first hover tick'),
        isFalse,
      );
    });
  });

  group('command source', () {
    test('an omitted source is a warning: the command runs as the console', () {
      final List<HuiIssue> issues =
          validateHuiMenu(_withCommand('/warp shop'));
      final HuiIssue issue =
          _matching(issues, HuiSeverity.warning, 'no source').single;
      expect(issue.path, 'components[0].data.actions[0].source');
      expect(issue.componentId, 'a');
      expect(issue.message, contains('console'));
    });

    test('a blank source reads the same way as an omitted one', () {
      expect(
        _has(validateHuiMenu(_withCommand('/a', source: '')),
            HuiSeverity.warning, 'no source'),
        isTrue,
      );
    });

    test('an explicit server source is silent', () {
      expect(validateHuiMenu(_withCommand('/a', source: 'server')), isEmpty);
    });

    test('an explicit player source is silent', () {
      expect(validateHuiMenu(_withCommand('/a', source: 'player')), isEmpty);
    });

    test('an unrecognised source is a Gson-version warning, not this one', () {
      final List<HuiIssue> issues =
          validateHuiMenu(_withCommand('/a', source: 'console'));
      expect(
        _has(issues, HuiSeverity.warning, 'not one of the two spellings'),
        isTrue,
      );
      expect(_has(issues, HuiSeverity.warning, 'no source'), isFalse);
    });

    test('the unrecognised-source warning does not assert console dispatch',
        () {
      // HoloUi shades no Gson and registers no enum adapter, so "PLAYER"
      // resolves to the player on Gson >= 2.10 and to null (console) on 2.8.x.
      final HuiIssue issue = _matching(
        validateHuiMenu(_withCommand('/a', source: 'PLAYER')),
        HuiSeverity.warning,
        'not one of the two spellings',
      ).single;
      expect(issue.message, contains('Gson'));
    });

    test('an action built in the editor is never flagged', () {
      expect(
        _has(validateHuiMenu(_withAction(HuiCommandAction('/a', 'server'))),
            HuiSeverity.warning, 'no source'),
        isFalse,
      );
    });

    test('re-importing the repaired export clears the note', () {
      final HuiMenu repaired =
          decodeHuiMenu(encodeHuiMenu(_withCommand('/a')));
      expect(validateHuiMenu(repaired), isEmpty);
    });
  });

  group('player-only holoui subcommands', () {
    test('open with a menu id from the console is a silent no-op', () {
      final HuiIssue issue = _matching(
        validateHuiMenu(_withCommand('/holoui open shop', source: 'server')),
        HuiSeverity.warning,
        'only works for a player',
      ).single;
      expect(issue.path, 'components[0].data.actions[0].source');
      expect(issue.componentId, 'a');
      expect(issue.message, contains('holoui open'));
      expect(issue.fix, contains('player'));
    });

    test('back and close are always player-only', () {
      for (final String command in <String>[
        'holoui back',
        '/holoui close',
        '/holoui back ignored args',
      ]) {
        expect(
          _has(validateHuiMenu(_withCommand(command, source: 'server')),
              HuiSeverity.warning, 'only works for a player'),
          isTrue,
          reason: command,
        );
      }
    });

    test('the root aliases resolve the same command', () {
      for (final String root in <String>['holo', 'hui', 'holou', 'hu']) {
        expect(
          _has(validateHuiMenu(_withCommand('/$root close', source: 'server')),
              HuiSeverity.warning, 'only works for a player'),
          isTrue,
          reason: root,
        );
      }
    });

    test('leading whitespace and casing do not hide it', () {
      for (final String command in <String>[
        '/   holoui   open   shop',
        '/HoloUI Open shop',
        '  holoui close',
      ]) {
        expect(
          _has(validateHuiMenu(_withCommand(command, source: 'server')),
              HuiSeverity.warning, 'only works for a player'),
          isTrue,
          reason: command,
        );
      }
    });

    test('a player source is exactly what the fix asks for', () {
      for (final String command in <String>[
        '/holoui open shop',
        '/holoui back',
        '/holoui close',
      ]) {
        expect(
          _has(validateHuiMenu(_withCommand(command, source: 'player')),
              HuiSeverity.warning, 'only works for a player'),
          isFalse,
          reason: command,
        );
      }
    });

    test('open without a menu id lists menus and works from the console', () {
      // `open` defaults its argument to `*` and returns through `list(sender)`
      // before the player check, so this one really does work headless.
      for (final String command in <String>[
        '/holoui open',
        '/holoui open *',
      ]) {
        expect(
          _has(validateHuiMenu(_withCommand(command, source: 'server')),
              HuiSeverity.warning, 'only works for a player'),
          isFalse,
          reason: command,
        );
      }
    });

    test('other subcommands and unrelated commands are left alone', () {
      for (final String command in <String>[
        '/holoui list',
        '/holouiopen shop',
        '/pay bob holoui open shop',
        '/broadcast holoui close',
        '/say open',
      ]) {
        expect(
          _has(validateHuiMenu(_withCommand(command, source: 'server')),
              HuiSeverity.warning, 'only works for a player'),
          isFalse,
          reason: command,
        );
      }
    });

    test('an absent source produces this warning and not the generic one', () {
      final List<HuiIssue> issues =
          validateHuiMenu(_withCommand('/holoui open shop'));
      final HuiIssue issue = _matching(
              issues, HuiSeverity.warning, 'only works for a player')
          .single;
      expect(issue.message, contains('no source'));
      expect(
        issues.where((HuiIssue i) => i.path.endsWith('.source')),
        hasLength(1),
      );
    });

    test('an unrecognised source keeps its Gson warning instead', () {
      // "PLAYER" may well resolve to the player, so claiming a no-op would be
      // a lie; only server and absent are certainly console.
      final List<HuiIssue> issues =
          validateHuiMenu(_withCommand('/holoui close', source: 'PLAYER'));
      expect(_has(issues, HuiSeverity.warning, 'only works for a player'),
          isFalse);
      expect(_has(issues, HuiSeverity.warning, 'not one of the two spellings'),
          isTrue);
    });
  });

  group('ignored menu keys', () {
    test('a menu "name" key is reported as info', () {
      final HuiMenu menu = _menu(<HuiComponent>[_button('a')])
        ..extras['name'] = 'Village Store';
      final HuiIssue issue =
          _matching(validateHuiMenu(menu), HuiSeverity.info, 'file base name')
              .single;
      expect(issue.path, 'name');
      expect(issue.componentId, isNull);
    });

    test('the key survives the export it is reported against', () {
      final HuiMenu menu = _menu(<HuiComponent>[_button('a')])
        ..extras['name'] = 'Village Store';
      expect(encodeHuiMenu(menu), contains('"name": "Village Store"'));
      expect(
        _has(validateHuiMenu(decodeHuiMenu(encodeHuiMenu(menu))),
            HuiSeverity.info, 'file base name'),
        isTrue,
      );
    });

    test('a menu without the key is silent', () {
      expect(
        _has(validateHuiMenu(_menu(<HuiComponent>[_button('a')])),
            HuiSeverity.info, 'file base name'),
        isFalse,
      );
    });
  });
}
