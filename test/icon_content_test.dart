/// Sprite cache keys.
///
/// The 3D preview rasterizes each icon once per distinct appearance and blits
/// the result, so the key has to change for every input the renderers read and
/// for nothing else. Two structurally identical decorations must share a key —
/// that is the whole point of the cache.
library;

import 'package:gloss_editor/logic/canvas_scene.dart';
import 'package:gloss_editor/logic/icon_content.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/image_library.dart';
import 'package:test/test.dart';

CanvasScene _scene(
  List<HuiComponent> components, {
  int animationTicks = 0,
  ImageLibrary? images,
}) => buildCanvasScene(
  menu: HuiMenu(offset: Vec3(0, 1.7, 2.5), components: components),
  uiScale: 1,
  trueRender: false,
  togglePreview: (String _) => true,
  textCache: McTextCache(),
  images: images,
  animationTicks: animationTicks,
);

/// Two 4x4 frames the scene builder will accept. Pixel grids stay undecoded on
/// the VM, which is fine: the key is keyed on the path, not the bitmap.
ImageLibrary _frames() {
  final ImageLibrary library = ImageLibrary();
  library.replaceAll(<StoredImage>[
    for (final String path in <String>['one.png', 'two.png'])
      StoredImage(
        path: path,
        dataUri:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
        width: 1,
        height: 1,
      ),
  ]);
  return library;
}

HuiComponent _text(String id, String text) =>
    HuiComponent(id, Vec3(0, 0, 0), HuiDecorationData(HuiTextIcon(text)));

String _key(
  CanvasScene scene,
  String id, {
  double pxPerBlock = 64,
  double uiScale = 1,
  int obfuscationTick = 0,
}) => spriteCacheKey(
  scene.byId(id)!,
  pxPerBlock: pxPerBlock,
  uiScale: uiScale,
  obfuscationTick: obfuscationTick,
);

void main() {
  group('spriteCacheKey', () {
    test('is stable for the same item across rebuilds', () {
      final String first = _key(
        _scene(<HuiComponent>[_text('a', '&aHi')]),
        'a',
      );
      final String second = _key(
        _scene(<HuiComponent>[_text('a', '&aHi')]),
        'a',
      );
      expect(first, second);
    });

    test('two identical icons share one key so they share one sprite', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', '&aHi'),
        _text('b', '&aHi'),
      ]);
      expect(_key(scene, 'a'), _key(scene, 'b'));
    });

    test('changes when the raw text changes', () {
      final String before = _key(
        _scene(<HuiComponent>[_text('a', '&aHi')]),
        'a',
      );
      final String after = _key(
        _scene(<HuiComponent>[_text('a', '&aHo')]),
        'a',
      );
      expect(before, isNot(after));
    });

    test('changes when only the colour code changes', () {
      final String green = _key(
        _scene(<HuiComponent>[_text('a', '&aHi')]),
        'a',
      );
      final String red = _key(_scene(<HuiComponent>[_text('a', '&cHi')]), 'a');
      expect(green, isNot(red));
    });

    test('changes with the requested pixels per block', () {
      final CanvasScene scene = _scene(<HuiComponent>[_text('a', 'Hi')]);
      expect(
        _key(scene, 'a', pxPerBlock: 64),
        isNot(_key(scene, 'a', pxPerBlock: 128)),
      );
    });

    test('changes with uiScale', () {
      final CanvasScene scene = _scene(<HuiComponent>[_text('a', 'Hi')]);
      expect(_key(scene, 'a', uiScale: 1), isNot(_key(scene, 'a', uiScale: 2)));
    });

    test('ignores the obfuscation tick for plain text', () {
      final CanvasScene scene = _scene(<HuiComponent>[_text('a', 'Hi')]);
      expect(
        _key(scene, 'a', obfuscationTick: 0),
        _key(scene, 'a', obfuscationTick: 7),
      );
    });

    test('follows the obfuscation tick when a span is obfuscated', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', '<obfuscated>Hi'),
      ]);
      expect(
        _key(scene, 'a', obfuscationTick: 0),
        isNot(_key(scene, 'a', obfuscationTick: 1)),
      );
    });

    test('follows the animation frame and wraps with it', () {
      final ImageLibrary images = _frames();
      HuiComponent build() => HuiComponent(
        'a',
        Vec3(0, 0, 0),
        HuiDecorationData(
          HuiAnimatedImageIcon(<String>['one.png', 'two.png'], 2),
        ),
      );
      String at(int ticks) => _key(
        _scene(<HuiComponent>[build()], animationTicks: ticks, images: images),
        'a',
      );
      expect(at(0), isNot(at(2)));
      expect(at(0), at(4));
    });

    test('a repeated frame path reuses its sprite', () {
      final ImageLibrary images = _frames();
      HuiComponent build() => HuiComponent(
        'a',
        Vec3(0, 0, 0),
        HuiDecorationData(
          HuiAnimatedImageIcon(<String>['one.png', 'two.png', 'one.png'], 2),
        ),
      );
      String at(int ticks) => _key(
        _scene(<HuiComponent>[build()], animationTicks: ticks, images: images),
        'a',
      );
      expect(at(0), at(4));
      expect(at(0), isNot(at(2)));
    });

    test('a sub-minimum speed previews at the runtime minimum', () {
      final ImageLibrary images = _frames();
      HuiComponent build() => HuiComponent(
        'a',
        Vec3(0, 0, 0),
        HuiDecorationData(
          HuiAnimatedImageIcon(<String>['one.png', 'two.png'], 1),
        ),
      );
      String at(int ticks) => _key(
        _scene(<HuiComponent>[build()], animationTicks: ticks, images: images),
        'a',
      );
      expect(at(0), at(1));
      expect(at(0), isNot(at(2)));
    });

    test('separates the two sides of a toggle', () {
      final HuiMenu menu = HuiMenu(
        components: <HuiComponent>[
          HuiComponent(
            'a',
            Vec3(0, 0, 0),
            HuiToggleData(
              1,
              '%papi%',
              'true',
              <HuiAction>[],
              <HuiAction>[],
              HuiTextIcon('&aOn'),
              HuiTextIcon('&cOff'),
            ),
          ),
        ],
      );
      CanvasScene sceneFor(bool showsTrue) => buildCanvasScene(
        menu: menu,
        uiScale: 1,
        trueRender: false,
        togglePreview: (String _) => showsTrue,
        textCache: McTextCache(),
      );
      expect(_key(sceneFor(true), 'a'), isNot(_key(sceneFor(false), 'a')));
    });

    test('separates item keys, counts and kinds', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        HuiComponent(
          'stone',
          Vec3(0, 0, 0),
          HuiDecorationData(HuiItemIcon('stone', 1, 0)),
        ),
        HuiComponent(
          'dirt',
          Vec3(1, 0, 0),
          HuiDecorationData(HuiItemIcon('dirt', 1, 0)),
        ),
        HuiComponent(
          'stack',
          Vec3(2, 0, 0),
          HuiDecorationData(HuiItemIcon('stone', 8, 0)),
        ),
        HuiComponent(
          'custom',
          Vec3(3, 0, 0),
          HuiDecorationData(HuiCustomItemIcon('oraxen', 'stone', 1)),
        ),
      ]);
      final Set<String> keys = <String>{
        _key(scene, 'stone'),
        _key(scene, 'dirt'),
        _key(scene, 'stack'),
        _key(scene, 'custom'),
      };
      expect(keys.length, 4);
    });

    test('separates two heads by the name each one draws', () {
      // Every head draws one generic sprite, so the authored name is the only
      // thing that can tell two of them apart.
      final CanvasScene scene = _scene(<HuiComponent>[
        HuiComponent(
          'notch',
          Vec3(0, 0, 0),
          HuiDecorationData(HuiPlayerHeadIcon('Notch')),
        ),
        HuiComponent(
          'viewer',
          Vec3(1, 0, 0),
          HuiDecorationData(HuiPlayerHeadIcon('%player_name%')),
        ),
        HuiComponent(
          'same',
          Vec3(2, 0, 0),
          HuiDecorationData(HuiPlayerHeadIcon('Notch')),
        ),
        HuiComponent(
          'item',
          Vec3(3, 0, 0),
          HuiDecorationData(HuiItemIcon('Notch', 1, 0)),
        ),
      ]);
      expect(_key(scene, 'notch'), _key(scene, 'same'));
      expect(_key(scene, 'notch'), isNot(_key(scene, 'viewer')));
      // The kind leads the key, so a head never shares an item's bitmap.
      expect(_key(scene, 'notch'), isNot(_key(scene, 'item')));
    });

    test('a missing icon keys the same everywhere', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        HuiComponent('a', Vec3(0, 0, 0), HuiDecorationData(HuiTextImageIcon())),
        HuiComponent('b', Vec3(1, 0, 0), HuiDecorationData(HuiTextImageIcon())),
      ]);
      expect(_key(scene, 'a'), _key(scene, 'b'));
    });
  });
}
