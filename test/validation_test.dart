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

HuiMenu _withAction(HuiAction action) => _menu(<HuiComponent>[
      _component(
        'a',
        HuiButtonData(0.05, <HuiAction>[action], HuiTextIcon('x')),
      ),
    ]);

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

    test('flags an unknown command source', () {
      expect(
        _has(validateHuiMenu(_withAction(HuiCommandAction('/a', 'console'))),
            HuiSeverity.warning, 'Unknown command source'),
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
            0.05,
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
  });
}
