import 'dart:convert';

import 'package:gloss_editor/logic/canvas_scene.dart' show CanvasOverlap;
import 'package:gloss_editor/logic/gloss_text.dart'
    show GlossEmojiEntry, GlossEmojiResolver;
import 'package:gloss_editor/logic/hui_geometry.dart' show HuiRect;
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/catalogs.dart';
import 'package:test/test.dart';

final class _Emoji implements GlossEmojiResolver {
  const _Emoji();

  @override
  List<GlossEmojiEntry> get entries => const <GlossEmojiEntry>[
    GlossEmojiEntry(id: 'heart', trigger: '<3', glyph: '❤', enabled: true),
  ];
}

const _Emoji _emoji = _Emoji();

HuiMenu _menu(List<HuiComponent> components) =>
    HuiMenu(offset: Vec3(0, 1.7, 2.5), components: components);

HuiComponent _component(String id, HuiComponentData data) =>
    HuiComponent(id, Vec3(0, 0, 0), data);

HuiMenu _withIcon(HuiIcon? icon) =>
    _menu(<HuiComponent>[_component('a', HuiDecorationData(icon))]);

HuiMenu _withAction(HuiAction action) => _menu(<HuiComponent>[
  _component('a', HuiButtonData(1, <HuiAction>[action], HuiTextIcon('x'))),
]);

/// A one-button menu carrying [actionJson] verbatim, decoded rather than
/// constructed so absent-key tracking is exercised the way an import does it.
HuiMenu _decodedWithAction(String actionJson) => decodeHuiMenu(
  '{"offset":[0,1.7,2.5],"components":[{"id":"a",'
  '"offset":[0,0,0],"data":{"type":"button","highlightModifier":1,'
  '"icon":{"type":"text","text":"x"},"actions":[$actionJson]}}]}',
);

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
) => issues.where(
  (HuiIssue i) => i.severity == severity && i.message.contains(fragment),
);

bool _has(List<HuiIssue> issues, HuiSeverity severity, Pattern fragment) =>
    _matching(issues, severity, fragment).isNotEmpty;

void main() {
  group('component ids', () {
    test('flags duplicate ids as warnings', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _component('dup', HuiDecorationData(HuiTextIcon('a'))),
          _component('dup', HuiDecorationData(HuiTextIcon('b'))),
        ]),
      );
      expect(
        _has(issues, HuiSeverity.warning, 'Duplicate component id'),
        isTrue,
      );
      expect(
        _matching(
          issues,
          HuiSeverity.warning,
          'Duplicate component id',
        ).single.path,
        'components[1].id',
      );
    });

    test('flags an empty id', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _component('', HuiDecorationData(HuiTextIcon('a'))),
        ]),
      );
      expect(_has(issues, HuiSeverity.warning, 'no id'), isTrue);
    });

    test('flags characters outside [A-Za-z0-9_.-]', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _component('bad id!', HuiDecorationData(HuiTextIcon('a'))),
        ]),
      );
      expect(_has(issues, HuiSeverity.warning, 'invalid characters'), isTrue);
    });

    test('flags ids longer than 64 characters', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _component('a' * 65, HuiDecorationData(HuiTextIcon('a'))),
        ]),
      );
      expect(_has(issues, HuiSeverity.warning, 'longer than 64'), isTrue);
    });

    test('accepts a clean id', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _component('shop.buy-1_x', HuiDecorationData(HuiTextIcon('a'))),
        ]),
      );
      expect(issues, isEmpty);
    });
  });

  group('command actions', () {
    test('flags a missing command as an error', () {
      expect(
        _has(
          validateHuiMenu(_withAction(HuiCommandAction('  ', 'player'))),
          HuiSeverity.error,
          'Command is empty',
        ),
        isTrue,
      );
    });

    test('reports placeholders in commands as info', () {
      expect(
        _has(
          validateHuiMenu(
            _withAction(HuiCommandAction('/pay %player_name%', 'player')),
          ),
          HuiSeverity.info,
          'not expanded in commands',
        ),
        isTrue,
      );
    });

    test('flags a command source that is neither player nor server', () {
      expect(
        _has(
          validateHuiMenu(_withAction(HuiCommandAction('/a', 'console'))),
          HuiSeverity.warning,
          'not recognized',
        ),
        isTrue,
      );
    });
  });

  group('sound actions', () {
    test('flags an uppercase sound key as an error', () {
      expect(
        _has(
          validateHuiMenu(
            _withAction(HuiSoundAction('UI.BUTTON.CLICK', 'master', 1, 1)),
          ),
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
            _withAction(HuiSoundAction('ui button click', 'master', 1, 1)),
          ),
          HuiSeverity.error,
          'invalid characters',
        ),
        isTrue,
      );
    });

    test('flags an empty sound key as an error', () {
      expect(
        _has(
          validateHuiMenu(_withAction(HuiSoundAction('', 'master', 1, 1))),
          HuiSeverity.error,
          'Sound key is empty',
        ),
        isTrue,
      );
    });

    test('a missing sound source is silent: the plugin defaults it', () {
      expect(
        validateHuiMenu(
          _withAction(HuiSoundAction('ui.button.click', '', 1, 1)),
        ),
        isEmpty,
      );
    });

    test('warns that an unknown sound source falls back to master', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withAction(HuiSoundAction('ui.button.click', 'sfx', 1, 1)),
      );
      expect(_has(issues, HuiSeverity.warning, 'Sound source'), isTrue);
      expect(
        _matching(issues, HuiSeverity.warning, 'Sound source').single.message,
        contains('master'),
      );
    });

    test('warns on a sound missing from the catalog', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withAction(HuiSoundAction('ui.nope', 'master', 1, 1)),
        knownSounds: <String>{'ui.button.click'},
      );
      expect(
        _has(issues, HuiSeverity.warning, 'not in the sound catalog'),
        isTrue,
      );
    });

    test('accepts a namespaced sound present in the catalog', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withAction(
          HuiSoundAction('minecraft:ui.button.click', 'master', 1, 1),
        ),
        knownSounds: <String>{'ui.button.click'},
      );
      expect(issues, isEmpty);
    });

    test('warns on zero volume and zero pitch', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withAction(HuiSoundAction('ui.button.click', 'master', 0, 0)),
      );
      expect(_has(issues, HuiSeverity.warning, 'Volume 0'), isTrue);
      expect(_has(issues, HuiSeverity.warning, 'Pitch 0'), isTrue);
    });

    test('reports a pitch outside 0.5-2.0 as info', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withAction(HuiSoundAction('ui.button.click', 'master', 1, 3)),
      );
      expect(_has(issues, HuiSeverity.info, 'outside the 0.5-2.0'), isTrue);
    });
  });

  group('item icons', () {
    test('flags an uppercase material key as an error', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiItemIcon('STONE', 1, 0))),
          HuiSeverity.error,
          'lowercase',
        ),
        isTrue,
      );
    });

    test('flags an empty material key as an error', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiItemIcon('', 1, 0))),
          HuiSeverity.error,
          'Material key is empty',
        ),
        isTrue,
      );
    });

    test('warns on a material missing from the catalog', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiItemIcon('unobtainium', 1, 0)),
        knownMaterials: <String>{'stone'},
      );
      expect(
        _has(issues, HuiSeverity.warning, 'not in the material catalog'),
        isTrue,
      );
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
      expect(
        _has(issues, HuiSeverity.warning, 'Unknown item provider'),
        isTrue,
      );
      expect(
        _matching(
          issues,
          HuiSeverity.warning,
          'Unknown item provider',
        ).single.path,
        'components[0].data.icon.provider',
      );
    });

    test('provider lookup is case-insensitive and trims whitespace', () {
      expect(
        validateHuiMenu(
          _withIcon(HuiCustomItemIcon('  ItemsAdder  ', 'myitems:ruby', 1)),
        ),
        isEmpty,
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
      expect(
        _has(issues, HuiSeverity.info, 'not in the custom item catalog'),
        isTrue,
      );
      expect(
        issues.where((HuiIssue i) => i.severity == HuiSeverity.error),
        isEmpty,
      );
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
      final HuiIssue issue = _matching(
        validateHuiMenu(_withIcon(HuiAnimatedImageIcon(<String>[], 2))),
        HuiSeverity.error,
        'no frames',
      ).single;
      expect(issue.message, contains('missing-icon placeholder'));
      expect(issue.message, isNot(contains('throws')));
    });

    test('accepts speed zero because runtime treats it as every tick', () {
      expect(
        validateHuiMenu(
          _withIcon(HuiAnimatedImageIcon(<String>['a.png'], 0)),
        ).where((HuiIssue issue) => issue.path.endsWith('.speed')),
        isEmpty,
      );
    });

    test('validates every frame path', () {
      expect(
        _has(
          validateHuiMenu(
            _withIcon(HuiAnimatedImageIcon(<String>['../a.png'], 2)),
          ),
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
          _has(
            validateHuiMenu(_withIcon(HuiTextImageIcon(path))),
            HuiSeverity.error,
            'Image path',
          ),
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
        _has(
          validateHuiMenu(_withIcon(HuiTextImageIcon(''))),
          HuiSeverity.error,
          'Image path is empty',
        ),
        isTrue,
      );
    });

    test('reports a path missing from the image library as info', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiTextImageIcon('logo.png')),
        knownImagePaths: <String>{'other.png'},
      );
      expect(
        _has(issues, HuiSeverity.info, 'not in the image library'),
        isTrue,
      );
    });
  });

  group('text icons', () {
    test('accepts &n and &k legacy codes', () {
      expect(validateHuiMenu(_withIcon(HuiTextIcon('&nHello'))), isEmpty);
      expect(validateHuiMenu(_withIcon(HuiTextIcon('&kHello'))), isEmpty);
    });

    test('reports placeholders in text as info', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiTextIcon('Hi %player_name%'))),
          HuiSeverity.info,
          'PlaceholderAPI',
        ),
        isTrue,
      );
    });

    test('validates placeholder refresh range', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiTextIcon('Hi', null, -1))),
          HuiSeverity.error,
          'between 0 and 1200',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiTextIcon('Hi', null, 1201))),
          HuiSeverity.error,
          'between 0 and 1200',
        ),
        isTrue,
      );
      expect(validateHuiMenu(_withIcon(HuiTextIcon('Hi', null, 0))), isEmpty);
    });

    test('explains when a placeholder is intentionally frozen', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiTextIcon('Hi %player_name%', null, 0))),
          HuiSeverity.info,
          'then frozen',
        ),
        isTrue,
      );
    });
  });

  group('components and menu root', () {
    test('warns when a highlightModifier falls outside 0..1', () {
      expect(
        _has(
          validateHuiMenu(
            _menu(<HuiComponent>[
              _component(
                'a',
                HuiButtonData(2, const <HuiAction>[], HuiTextIcon('x')),
              ),
            ]),
          ),
          HuiSeverity.warning,
          'highlightModifier',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(
            _menu(<HuiComponent>[
              _component(
                'a',
                HuiButtonData(-1, const <HuiAction>[], HuiTextIcon('x')),
              ),
            ]),
          ),
          HuiSeverity.warning,
          'highlightModifier',
        ),
        isTrue,
      );
    });

    test('rejects non-positive custom hitbox dimensions', () {
      final HuiButtonData width = HuiButtonData(
        0.05,
        const <HuiAction>[],
        HuiTextIcon('x'),
        HuiHitbox(0, 1),
      );
      final HuiButtonData height = HuiButtonData(
        0.05,
        const <HuiAction>[],
        HuiTextIcon('x'),
        HuiHitbox(1, -0.5),
      );

      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[_component('w', width)])),
          HuiSeverity.error,
          'width must be',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[_component('h', height)])),
          HuiSeverity.error,
          'height must be',
        ),
        isTrue,
      );
    });

    test('accepts positive custom hitbox dimensions', () {
      final HuiButtonData data = HuiButtonData(
        0.05,
        const <HuiAction>[],
        HuiTextIcon('x'),
        HuiHitbox(1.25, 0.35),
      );
      expect(
        validateHuiMenu(_menu(<HuiComponent>[_component('a', data)])),
        isEmpty,
      );
    });

    test('accepts an offset-only detached hitbox', () {
      final HuiButtonData data = HuiButtonData(
        0.05,
        const <HuiAction>[],
        HuiTextIcon('x'),
        HuiHitbox(null, null, Vec3(0.5, -0.25, 0.75), HuiHitboxAnchor.menu),
      );
      expect(
        validateHuiMenu(_menu(<HuiComponent>[_component('a', data)])),
        isEmpty,
      );
    });

    test('rejects a partial custom size and non-finite offset', () {
      final HuiButtonData data = HuiButtonData(
        0.05,
        const <HuiAction>[],
        HuiTextIcon('x'),
        HuiHitbox(1, null, Vec3(double.nan, 0, 0)),
      );
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[_component('a', data)]),
      );
      expect(_has(issues, HuiSeverity.error, 'supplied together'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'finite numbers'), isTrue);
    });

    test('warns when an icon is null', () {
      expect(
        _has(
          validateHuiMenu(_withIcon(null)),
          HuiSeverity.warning,
          'missing-icon placeholder',
        ),
        isTrue,
      );
    });

    test('errors when a toggle condition or expected value is empty', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _component(
            'a',
            HuiToggleData(
              0.05,
              '',
              '',
              const <HuiAction>[],
              const <HuiAction>[],
              HuiTextIcon('on'),
              HuiTextIcon('off'),
            ),
          ),
        ]),
      );
      expect(_has(issues, HuiSeverity.error, 'condition is empty'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'expectedValue is empty'), isTrue);
    });

    test('warns when maxDistance falls outside [0, 6e7]', () {
      final HuiMenu menu = _menu(const <HuiComponent>[])..maxDistance = -1;
      expect(
        _has(validateHuiMenu(menu), HuiSeverity.warning, 'maxDistance'),
        isTrue,
      );
      menu.maxDistance = 7e7;
      expect(
        _has(validateHuiMenu(menu), HuiSeverity.warning, 'maxDistance'),
        isTrue,
      );
      menu.maxDistance = 8;
      expect(
        _has(validateHuiMenu(menu), HuiSeverity.warning, 'maxDistance'),
        isFalse,
      );
    });

    test('rejects non-finite exported menu and action numbers', () {
      final HuiMenu menu =
          _menu(<HuiComponent>[
              _component(
                'a',
                HuiButtonData(double.nan, <HuiAction>[
                  HuiSoundAction(
                    'ui.button.click',
                    'master',
                    double.infinity,
                    double.nan,
                  ),
                ], HuiTextIcon('x')),
              )..offset = Vec3(double.infinity, 0, 0),
            ])
            ..offset = Vec3(0, double.nan, 0)
            ..maxDistance = double.infinity;
      final List<HuiIssue> issues = validateHuiMenu(menu);

      expect(_has(issues, HuiSeverity.error, 'Menu offset'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'Component offset'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'maxDistance'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'highlightModifier'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'Volume'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'Pitch'), isTrue);
    });

    test('carries the owning component id on nested issues', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _component(
            'buy',
            HuiButtonData(0.05, <HuiAction>[
              HuiCommandAction('', 'player'),
            ], HuiTextIcon('x')),
          ),
        ]),
      );
      final HuiIssue issue = _matching(
        issues,
        HuiSeverity.error,
        'Command is empty',
      ).single;
      expect(issue.componentId, 'buy');
      expect(issue.path, 'components[0].data.actions[0].command');
    });

    test('warns when the menu has no components at all', () {
      expect(
        _has(
          validateHuiMenu(_menu(const <HuiComponent>[])),
          HuiSeverity.warning,
          'no components',
        ),
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

      final List<HuiIssue> missingList = validateHuiMenu(
        decodeHuiMenu('{"offset":[0,1.7,2.5]}'),
      );
      expect(_has(missingList, HuiSeverity.info, 'no components list'), isTrue);
    });

    test('a repaired document reports no defaulted-key notes', () {
      final HuiMenu menu = decodeHuiMenu(
        encodeHuiMenu(
          decodeHuiMenu(
            '{"components":[{"id":"a","data":{"type":"decoration",'
            '"icon":{"type":"text","text":"hi"}}}]}',
          ),
        ),
      );
      expect(
        validateHuiMenu(
          menu,
        ).where((HuiIssue i) => i.severity == HuiSeverity.info),
        isEmpty,
      );
    });

    test('a canonical valid menu produces no issues', () {
      final HuiMenu menu = _menu(<HuiComponent>[
        _component('title', HuiDecorationData(HuiTextIcon('&6&lStore'))),
        _component(
          'buy',
          HuiButtonData(1, <HuiAction>[
            HuiCommandAction('/warp shop', 'player'),
            HuiSoundAction('ui.button.click', 'master', 1, 1),
          ], HuiItemIcon('emerald', 3, 0)),
        ),
      ]);
      expect(validateHuiMenu(menu), isEmpty);
    });

    test('the typical 0.05 modifier is valid', () {
      final HuiMenu menu = _menu(<HuiComponent>[
        _component('title', HuiDecorationData(HuiTextIcon('&6&lStore'))),
        _component(
          'buy',
          HuiButtonData(0.05, <HuiAction>[
            HuiCommandAction('/warp shop', 'player'),
          ], HuiItemIcon('emerald', 3, 0)),
        ),
      ]);
      expect(validateHuiMenu(menu), isEmpty);
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
      final HuiIssue issue = _matching(
        issues,
        HuiSeverity.warning,
        'Hitbox overlaps',
      ).single;
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
        validateHuiMenu(
          three,
          overlaps: const <CanvasOverlap>[],
        ).map((HuiIssue i) => i.toString()),
        validateHuiMenu(three).map((HuiIssue i) => i.toString()),
      );
    });

    test('a pair naming a component the menu no longer has is skipped', () {
      expect(
        validateHuiMenu(
          three,
          overlaps: <CanvasOverlap>[_overlap('a', 'gone')],
        ),
        isEmpty,
      );
    });
  });

  group('wide text hitboxes', () {
    test('a clickable text line of 16 characters is reported as info', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
          _button('a', icon: HuiTextIcon('0123456789abcdef')),
        ]),
      );
      final HuiIssue issue = _matching(
        issues,
        HuiSeverity.info,
        'character count',
      ).single;
      expect(issue.message, contains('16 characters'));
      expect(issue.message, contains('1.75'));
      expect(issue.path, 'components[0].data.icon.text');
    });

    test('15 characters stays below the threshold', () {
      expect(
        _has(
          validateHuiMenu(
            _menu(<HuiComponent>[
              _button('a', icon: HuiTextIcon('0123456789abcde')),
            ]),
          ),
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
          validateHuiMenu(
            _menu(<HuiComponent>[
              _button('a', icon: HuiTextIcon('&6&lVillage Store')),
            ]),
          ),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
      );
    });

    test('only the widest line counts, and lines are measured separately', () {
      expect(
        _has(
          validateHuiMenu(
            _menu(<HuiComponent>[
              _button('a', icon: HuiTextIcon('short\nshort too')),
            ]),
          ),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
      );
      expect(
        _has(
          validateHuiMenu(
            _menu(<HuiComponent>[
              _button('a', icon: HuiTextIcon('short\n0123456789abcdef')),
            ]),
          ),
          HuiSeverity.info,
          'character count',
        ),
        isTrue,
      );
    });

    test('the emoji glyph is measured, not the token that spells it', () {
      // TextMenuIcon renders through TextPipeline.menuText, so the plane is
      // sized on the substituted string: 15 visible characters, not the 21
      // the field holds.
      final HuiTextIcon icon = HuiTextIcon('0123456789ab:heart:');
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[_button('a', icon: icon)])),
          HuiSeverity.info,
          'character count',
        ),
        isTrue,
        reason: 'unsubstituted, the token itself is 19 characters',
      );
      expect(
        _has(
          validateHuiMenu(
            _menu(<HuiComponent>[_button('a', icon: icon)]),
            emoji: _emoji,
          ),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
        reason: 'substituted it is 13 characters',
      );
    });

    test('bracket hex does not count towards the width', () {
      expect(
        _has(
          validateHuiMenu(
            _menu(<HuiComponent>[
              _button('a', icon: HuiTextIcon('[ff8800]Village Store')),
            ]),
          ),
          HuiSeverity.info,
          'character count',
        ),
        isFalse,
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
      final List<HuiIssue> issues = validateHuiMenu(
        _menu(<HuiComponent>[
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
        ]),
      );
      expect(
        _matching(
          issues,
          HuiSeverity.info,
          'character count',
        ).map((HuiIssue i) => i.path),
        <String>[
          'components[0].data.trueIcon.text',
          'components[0].data.falseIcon.text',
        ],
      );
    });
  });

  group('command source', () {
    test('an omitted source is silent: the command runs as the player', () {
      expect(validateHuiMenu(_withCommand('/warp shop')), isEmpty);
    });

    test('a blank source reads the same way as an omitted one', () {
      expect(validateHuiMenu(_withCommand('/a', source: '')), isEmpty);
    });

    test('an explicit server source is silent', () {
      expect(validateHuiMenu(_withCommand('/a', source: 'server')), isEmpty);
    });

    test('an explicit player source is silent', () {
      expect(validateHuiMenu(_withCommand('/a', source: 'player')), isEmpty);
    });

    test('an unrecognised source reports the player fallback', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withCommand('/a', source: 'console'),
      );
      expect(_has(issues, HuiSeverity.warning, 'not recognized'), isTrue);
      expect(
        _matching(issues, HuiSeverity.warning, 'not recognized').single.message,
        contains('player default'),
      );
    });

    test('canonical imported enum spellings are not flagged', () {
      for (final String source in <String>['player', 'server']) {
        expect(validateHuiMenu(_withCommand('/a', source: source)), isEmpty);
      }
    });

    test('an action built in the editor is never flagged', () {
      expect(
        validateHuiMenu(_withAction(HuiCommandAction('/a', 'server'))),
        isEmpty,
      );
    });

    test('re-importing the export leaves nothing to report', () {
      final HuiMenu repaired = decodeHuiMenu(encodeHuiMenu(_withCommand('/a')));
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

    test('back, close, and move are always player-only', () {
      for (final String command in <String>[
        'holoui back',
        '/holoui close',
        '/holoui move',
        '/holoui back ignored args',
      ]) {
        expect(
          _has(
            validateHuiMenu(_withCommand(command, source: 'server')),
            HuiSeverity.warning,
            'only works for a player',
          ),
          isTrue,
          reason: command,
        );
      }
    });

    test('move resolves through every retired flat-tree root alias', () {
      for (final String root in <String>[
        'holoui',
        'holo',
        'hui',
        'holou',
        'hu',
      ]) {
        expect(huiPlayerOnlySubcommand('/$root move'), 'move', reason: root);
      }
    });

    test('the merged tree resolves under gloss menu, never at the root', () {
      for (final String root in <String>['gloss', 'gl', 'glo', 'gg']) {
        expect(
          huiPlayerOnlySubcommand('/$root menu move'),
          'move',
          reason: root,
        );
        expect(
          huiPlayerOnlySubcommand('/$root menus close'),
          'close',
          reason: '$root + the menus alias',
        );
        // The merged plugin has no root-level move/close/back/open.
        expect(huiPlayerOnlySubcommand('/$root move'), isNull, reason: root);
      }
      expect(
        huiPlayerOnlyCommandLabel('/gloss menu open shop'),
        'gloss menu open',
      );
      expect(huiPlayerOnlySubcommand('/gloss menu open *'), isNull);
      expect(huiPlayerOnlySubcommand('/gloss menu open'), isNull);
      expect(huiPlayerOnlySubcommand('/gloss menu list'), isNull);
    });

    test('gloss menu close from the console warns like the old tree did', () {
      final HuiIssue issue = _matching(
        validateHuiMenu(
          _withCommand('/gloss menu close', source: 'server'),
        ),
        HuiSeverity.warning,
        'only works for a player',
      ).single;
      expect(issue.message, contains('gloss menu close'));
    });

    test('the root aliases resolve the same command', () {
      for (final String root in <String>['holo', 'hui', 'holou', 'hu']) {
        expect(
          _has(
            validateHuiMenu(_withCommand('/$root close', source: 'server')),
            HuiSeverity.warning,
            'only works for a player',
          ),
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
          _has(
            validateHuiMenu(_withCommand(command, source: 'server')),
            HuiSeverity.warning,
            'only works for a player',
          ),
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
        '/holoui move',
      ]) {
        expect(
          _has(
            validateHuiMenu(_withCommand(command, source: 'player')),
            HuiSeverity.warning,
            'only works for a player',
          ),
          isFalse,
          reason: command,
        );
      }
    });

    test('open without a menu id lists menus and works from the console', () {
      // `open` defaults its argument to `*` and returns through `list(sender)`
      // before the player check, so this one really does work headless.
      for (final String command in <String>['/holoui open', '/holoui open *']) {
        expect(
          _has(
            validateHuiMenu(_withCommand(command, source: 'server')),
            HuiSeverity.warning,
            'only works for a player',
          ),
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
          _has(
            validateHuiMenu(_withCommand(command, source: 'server')),
            HuiSeverity.warning,
            'only works for a player',
          ),
          isFalse,
          reason: command,
        );
      }
    });
  });

  group('retired /holoui root', () {
    test('any retired alias warns and names the /gloss spelling', () {
      for (final String root in <String>[
        'holoui',
        'holo',
        'hui',
        'holou',
        'hu',
      ]) {
        final HuiIssue issue = _matching(
          validateHuiMenu(_withCommand('/$root close')),
          HuiSeverity.warning,
          'retired /holoui root',
        ).single;
        expect(issue.path, endsWith('.command'), reason: root);
        expect(issue.fix, contains('gloss menu close'), reason: root);
      }
    });

    test('known old subcommands map under gloss menu, arguments kept', () {
      expect(
        huiRetiredCommandReplacement('/holoui open shops/main'),
        'gloss menu open shops/main',
      );
      expect(huiRetiredCommandReplacement('holoui move'), 'gloss menu move');
      expect(
        huiRetiredCommandReplacement('/holoui item export'),
        'gloss item export',
        reason: 'non-menu subcommands move to the /gloss root',
      );
      expect(huiRetiredCommandReplacement('/holoui'), 'gloss');
      expect(huiRetiredCommandReplacement('/gloss menu close'), isNull);
      expect(huiRetiredCommandReplacement('/warp shop'), isNull);
    });

    test('the reachability set keeps accepting both trees — imports never '
        'hard-fail', () {
      // A retired-root command yields WARNINGS only, never an error.
      expect(
        validateHuiMenu(_withCommand('/holoui close', source: 'player'))
            .where((HuiIssue issue) => issue.severity == HuiSeverity.error),
        isEmpty,
      );
      // And the player-only recognition still fires for the old tree.
      expect(
        _has(
          validateHuiMenu(_withCommand('/holoui close', source: 'server')),
          HuiSeverity.warning,
          'only works for a player',
        ),
        isTrue,
      );
    });

    test('the merged spelling never draws the retired warning', () {
      expect(
        _has(
          validateHuiMenu(_withCommand('/gloss menu close')),
          HuiSeverity.warning,
          'retired /holoui root',
        ),
        isFalse,
      );
    });

    test('an absent source is not flagged: it runs as the player', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withCommand('/holoui open shop'),
      );
      expect(
        _has(issues, HuiSeverity.warning, 'only works for a player'),
        isFalse,
      );
      // Only the retired-root warning remains for the old spelling.
      expect(
        issues.single.message,
        contains('retired /holoui root'),
      );
    });

    test('an unrecognised source keeps its fallback warning instead', () {
      final List<HuiIssue> issues = validateHuiMenu(
        _withCommand('/holoui close', source: 'console'),
      );
      expect(
        _has(issues, HuiSeverity.warning, 'only works for a player'),
        isFalse,
      );
      expect(_has(issues, HuiSeverity.warning, 'not recognized'), isTrue);
    });
  });

  group('ignored menu keys', () {
    test('a menu "name" key is reported as info', () {
      final HuiMenu menu = _menu(<HuiComponent>[_button('a')])
        ..extras['name'] = 'Village Store';
      final HuiIssue issue = _matching(
        validateHuiMenu(menu),
        HuiSeverity.info,
        'file base name',
      ).single;
      expect(issue.path, 'name');
      expect(issue.componentId, isNull);
    });

    test('the key survives the export it is reported against', () {
      final HuiMenu menu = _menu(<HuiComponent>[_button('a')])
        ..extras['name'] = 'Village Store';
      expect(encodeHuiMenu(menu), contains('"name": "Village Store"'));
      expect(
        _has(
          validateHuiMenu(decodeHuiMenu(encodeHuiMenu(menu))),
          HuiSeverity.info,
          'file base name',
        ),
        isTrue,
      );
    });

    test('a menu without the key is silent', () {
      expect(
        _has(
          validateHuiMenu(_menu(<HuiComponent>[_button('a')])),
          HuiSeverity.info,
          'file base name',
        ),
        isFalse,
      );
    });
  });

  group('native navigation actions', () {
    test('push and replace require a target', () {
      for (final String mode in <String>['push', 'replace']) {
        expect(
          _has(
            validateHuiMenu(_withAction(HuiNavigateAction('', mode))),
            HuiSeverity.error,
            'require a target',
          ),
          isTrue,
          reason: mode,
        );
      }
    });

    test('back home and close do not require a target', () {
      for (final String mode in <String>['back', 'home', 'close']) {
        expect(
          validateHuiMenu(_withAction(HuiNavigateAction('', mode))),
          isEmpty,
          reason: mode,
        );
      }
    });

    test('navigation warns when a later action matches the same click', () {
      final HuiMenu menu = _withAction(HuiNavigateAction('next', 'push'));
      final HuiButtonData data = menu.components.single.data as HuiButtonData;
      data.actions.add(HuiSoundAction('ui.button.click', 'master', 1, 1));

      expect(
        _has(validateHuiMenu(menu), HuiSeverity.warning, 'same click trigger'),
        isTrue,
      );
    });

    test(
      'navigation on another exact trigger does not shadow later actions',
      () {
        final HuiMenu menu = _withAction(
          HuiNavigateAction('next', 'push', 'right_click'),
        );
        final HuiButtonData data = menu.components.single.data as HuiButtonData;
        data.actions.add(
          HuiSoundAction('ui.button.click', 'master', 1, 1, 'left_click'),
        );

        expect(
          _has(
            validateHuiMenu(menu),
            HuiSeverity.warning,
            'same click trigger',
          ),
          isFalse,
        );
      },
    );

    test('unknown click triggers are rejected', () {
      expect(
        _has(
          validateHuiMenu(
            _withAction(HuiMessageAction('Hello', 'middle_click')),
          ),
          HuiSeverity.error,
          'not recognized',
        ),
        isTrue,
      );
    });

    test('file-system traversal is rejected as a target id', () {
      expect(
        _has(
          validateHuiMenu(_withAction(HuiNavigateAction('../secret', 'push'))),
          HuiSeverity.error,
          'traversal segment',
        ),
        isTrue,
      );
    });

    test('nested canonical menu ids are valid navigation targets', () {
      expect(
        validateHuiMenu(
          _withAction(HuiNavigateAction('shops/tools/Confirm', 'push')),
        ),
        isEmpty,
      );
    });
  });

  group('icon display style', () {
    test('accepts the complete supported style range', () {
      final HuiIconStyle style = HuiIconStyle(
        billboard: 'vertical',
        shadow: true,
        seeThrough: true,
        textAlignment: 'left',
        backgroundArgb: '#80000000',
        textOpacity: 127,
        lineWidth: 100,
        blockLight: 4,
        skyLight: 15,
        viewRange: 2,
        shadowRadius: 0.5,
        shadowStrength: 0.75,
        cullingWidth: 4,
        cullingHeight: 3,
        glowColor: '#FFFF0000',
        scaleX: 2,
        scaleY: 0.5,
        scaleZ: 1.5,
      );
      expect(validateHuiMenu(_withIcon(HuiTextIcon('styled', style))), isEmpty);
    });

    test('rejects malformed colors, unpaired light and unsafe scale', () {
      final HuiIconStyle style = HuiIconStyle(
        backgroundArgb: '#123456',
        blockLight: 15,
        scaleX: 0,
      );
      final List<HuiIssue> issues = validateHuiMenu(
        _withIcon(HuiTextIcon('styled', style)),
      );
      expect(_has(issues, HuiSeverity.error, 'eight hexadecimal'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'supplied together'), isTrue);
      expect(_has(issues, HuiSeverity.error, 'finite and between'), isTrue);
    });
  });

  group('entity icons', () {
    test('accepts supported living entities and dimensions', () {
      expect(
        validateHuiMenu(_withIcon(HuiEntityIcon('minecraft:parrot', 0.5, 0.9))),
        isEmpty,
      );
    });

    test('rejects unsafe types and invalid dimensions', () {
      final List<HuiIssue> unsafe = validateHuiMenu(
        _withIcon(HuiEntityIcon('minecraft:item', 1, 1)),
      );
      final List<HuiIssue> dimensions = validateHuiMenu(
        _withIcon(HuiEntityIcon('minecraft:parrot', 0, 65)),
      );

      expect(_has(unsafe, HuiSeverity.error, 'spawnable living'), isTrue);
      expect(_has(dimensions, HuiSeverity.error, 'greater than 0'), isTrue);
      expect(_has(dimensions, HuiSeverity.error, 'at most 64'), isTrue);
    });

    test('matches Bukkit key parsing and the implicit minecraft namespace', () {
      expect(
        validateHuiMenu(_withIcon(HuiEntityIcon('parrot', 0.5, 0.9))),
        isEmpty,
      );
      expect(
        _has(
          validateHuiMenu(
            _withIcon(HuiEntityIcon('MINECRAFT:PARROT', 0.5, 0.9)),
          ),
          HuiSeverity.error,
          'must be lowercase',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(
            _withIcon(HuiEntityIcon(' minecraft:parrot ', 0.5, 0.9)),
          ),
          HuiSeverity.error,
          'surrounding whitespace',
        ),
        isTrue,
      );
    });

    test('rejects display style on an entity icon', () {
      final HuiEntityIcon icon = HuiEntityIcon('minecraft:parrot');
      icon.extras['style'] = HuiIconStyle().toJson();

      expect(
        _has(
          validateHuiMenu(_withIcon(icon)),
          HuiSeverity.error,
          'do not accept display-entity style',
        ),
        isTrue,
      );
    });
  });

  group('block icons', () {
    test('accepts implicit and explicit Minecraft block ids', () {
      expect(
        validateHuiMenu(_withIcon(HuiBlockIcon('minecraft:stone'))),
        isEmpty,
      );
      expect(validateHuiMenu(_withIcon(HuiBlockIcon('stone'))), isEmpty);
      expect(
        _has(
          validateHuiMenu(_withIcon(HuiBlockIcon('minecraft:diamond_sword'))),
          HuiSeverity.error,
          'not a block',
        ),
        isTrue,
      );
    });
  });

  group('typed interaction actions', () {
    test('message requires visible content', () {
      expect(
        _has(
          validateHuiMenu(_withAction(HuiMessageAction('   '))),
          HuiSeverity.error,
          'Message is empty',
        ),
        isTrue,
      );
    });

    test('message reports click and insertion tags stripped by runtime', () {
      expect(
        _has(
          validateHuiMenu(
            _withAction(
              HuiMessageAction(
                '<click:open_url:https://example.com>Open</click>',
              ),
            ),
          ),
          HuiSeverity.warning,
          'stripped by the runtime',
        ),
        isTrue,
      );
    });

    test('teleport requires an explicit world key and finite pose', () {
      expect(
        _has(
          validateHuiMenu(
            _withAction(HuiTeleportAction('world', 0, 64, 0, 0, 0)),
          ),
          HuiSeverity.error,
          'namespace:key',
        ),
        isTrue,
      );
      expect(
        _has(
          validateHuiMenu(
            _withAction(
              HuiTeleportAction('minecraft:overworld', double.nan, 64, 0, 0, 0),
            ),
          ),
          HuiSeverity.error,
          'finite number',
        ),
        isTrue,
      );
      expect(
        validateHuiMenu(
          _withAction(
            HuiTeleportAction('minecraft:overworld', 1, 64, -2, 90, 0),
          ),
        ),
        isEmpty,
      );
    });

    test('connect rejects whitespace and plugin-message injection', () {
      for (final String server in <String>[
        'bad server',
        'lobby\nConnect\nevil',
      ]) {
        expect(
          _has(
            validateHuiMenu(_withAction(HuiConnectAction(server))),
            HuiSeverity.error,
            'Proxy server name',
          ),
          isTrue,
          reason: server,
        );
      }
      expect(
        validateHuiMenu(_withAction(HuiConnectAction('lobby-1'))),
        isEmpty,
      );
    });
  });
}
