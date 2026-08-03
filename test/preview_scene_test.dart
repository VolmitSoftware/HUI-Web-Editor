/// The 3D layout pass: where each component's quad and collision plane land in
/// the world, and what is frozen at open versus recomputed every tick.
library;

import 'package:holoui_editor/logic/canvas_scene.dart';
import 'package:holoui_editor/logic/hui_geometry.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/preview/preview_scene.dart';
import 'package:holoui_editor/preview/preview_types.dart';
import 'package:holoui_editor/preview/projection.dart';
import 'package:test/test.dart';

import 'projection_test.dart' show expectVec;

HuiComponent _button(String id, Vec3 offset, {double highlight = 0.05}) =>
    HuiComponent(
      id,
      offset,
      HuiButtonData(highlight, <HuiAction>[], HuiTextIcon('Play')),
    );

HuiComponent _decoration(String id, Vec3 offset, [String text = 'Title']) =>
    HuiComponent(id, offset, HuiDecorationData(HuiTextIcon(text)));

HuiMenu _menu({
  Vec3? offset,
  List<HuiComponent>? components,
  bool followPlayer = false,
}) =>
    HuiMenu(
      offset: offset ?? Vec3.zero(),
      followPlayer: followPlayer,
      components: components ?? <HuiComponent>[],
    );

PreviewScene _scene(
  HuiMenu menu, {
  double uiScale = 1,
  PVec3 openFeet = PVec3.zero,
  double openYawDeg = 0,
  PVec3? currentCenter,
  bool trueRender = false,
}) =>
    buildPreviewScene(
      menu: menu,
      uiScale: uiScale,
      openFeet: openFeet,
      openYawDeg: openYawDeg,
      currentCenter: currentCenter,
      trueRender: trueRender,
    );

void main() {
  group('anchoring', () {
    test('a zero-offset component sits exactly at the feet', () {
      // `MenuSession.java:73` hangs the centre off `player.getLocation()`,
      // which is the feet, not the eyes.
      const PVec3 feet = PVec3(10, 64, -3);
      final PreviewScene scene = _scene(
        _menu(components: <HuiComponent>[_button('a', Vec3(0, 0, 0))]),
        openFeet: feet,
      );
      expectVec(scene.quads.single.anchor, feet);
      expectVec(scene.center, feet);
      expectVec(scene.anchorFeet, feet);
    });

    test('the menu offset is NOT scaled but component offsets are', () {
      // `HuiSettings.java:60-66`: uiScale multiplies the component offset
      // (`MenuComponent.java:54`) and nothing else.
      final PreviewScene scene = _scene(
        _menu(
          offset: Vec3(0, 1.5, 3),
          components: <HuiComponent>[_button('a', Vec3(1, 0.5, 0))],
        ),
        uiScale: 2,
      );
      expectVec(scene.center, const PVec3(0, 1.5, 3));
      expectVec(scene.quads.single.anchor, const PVec3(2, 2.5, 3));
    });

    test('uiScale 1 leaves both offsets alone', () {
      final PreviewScene scene = _scene(
        _menu(
          offset: Vec3(0, 1.5, 3),
          components: <HuiComponent>[_button('a', Vec3(1, 0.5, 0))],
        ),
      );
      expectVec(scene.quads.single.anchor, const PVec3(1, 2, 3));
    });

    test('the json frame is the authoring frame: no second X mirror', () {
      // `MenuSession.java:70` multiplies by (-1, 1, 1) so that json +x means
      // the player's RIGHT. The preview frame is defined that way already.
      final PreviewScene scene = _scene(
        _menu(components: <HuiComponent>[_button('a', Vec3(2, 0, 0))]),
      );
      expect(scene.quads.single.anchor.x, closeTo(2, 1e-12));
    });
  });

  group('open yaw', () {
    test('rotates about the vertical axis through the PLAYER, not the centre',
        () {
      // `MenuComponent.java:142-144` pivots on the player's eye location; a
      // centre-pivot would leave this component where it started.
      final PreviewScene scene = _scene(
        _menu(
          offset: Vec3(0, 0, 4),
          components: <HuiComponent>[_button('a', Vec3(0, 0, 0))],
        ),
        openYawDeg: 90,
      );
      expectVec(scene.quads.single.anchor, const PVec3(4, 0, 0), epsilon: 1e-9);
    });

    test('the pivot follows the player, keeping the layout rigid', () {
      const PVec3 feet = PVec3(-7, 64, 12);
      final PreviewScene scene = _scene(
        _menu(
          offset: Vec3(0, 1, 3),
          components: <HuiComponent>[_button('a', Vec3(1, 0, 0))],
        ),
        openFeet: feet,
        openYawDeg: 180,
      );
      // Yaw 180 turns the player around: forward becomes -z, right becomes -x.
      // `center` is where the menu draws; `sessionCenter` is the runtime's raw
      // pre-rotation `centerPoint`, and at this yaw the two disagree.
      expectVec(scene.center, feet + const PVec3(0, 1, -3), epsilon: 1e-9);
      expectVec(scene.sessionCenter, feet + const PVec3(0, 1, 3));
      expectVec(
        scene.quads.single.anchor,
        feet + const PVec3(-1, 1, -3),
        epsilon: 1e-9,
      );
    });

    test('component spread rotates with the open yaw, spacing preserved', () {
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('l', Vec3(-1, 0, 3)),
            _button('r', Vec3(1, 0, 3)),
          ],
        ),
        openYawDeg: 90,
      );
      expect(
        scene.byId('l')!.anchor.distanceTo(scene.byId('r')!.anchor),
        closeTo(2, 1e-9),
      );
      // Facing +x, the left button is now the one further along +z.
      expect(scene.byId('l')!.anchor.z, closeTo(1, 1e-9));
      expect(scene.byId('r')!.anchor.z, closeTo(-1, 1e-9));
    });

    test('quad facing is the open yaw, frozen on every quad', () {
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 0, 3)),
            _decoration('b', Vec3(1, 0, 3)),
          ],
        ),
        openYawDeg: 137.5,
      );
      for (final PreviewQuad quad in scene.quads) {
        expect(quad.facingYawDeg, 137.5);
        // The outward face points back down the player's line of sight.
        expectVec(
          quad.normal,
          -huiLookDirection(yawDegrees: 137.5),
          epsilon: 1e-12,
        );
      }
    });

    test('changing the open yaw is the ONLY thing that moves a quad', () {
      final HuiMenu menu =
          _menu(components: <HuiComponent>[_button('a', Vec3(0, 0, 3))]);
      final PreviewScene at0 = _scene(menu, openYawDeg: 0);
      final PreviewScene at90 = _scene(menu, openYawDeg: 90);
      expect(at0.quads.single.anchor == at90.quads.single.anchor, isFalse);
      expect(at0.quads.single.facingYawDeg, isNot(at90.quads.single.facingYawDeg));
    });
  });

  group('frozen quads versus re-aimed planes', () {
    // The contrast this whole preview exists to show: the plane chases the eye
    // every tick (`ClickableComponent.java:60-62`), the quad never moves.
    final PreviewScene scene = _scene(
      _menu(components: <HuiComponent>[_button('a', Vec3(0, 1.5, 3))]),
      openYawDeg: 0,
    );
    final PreviewQuad quad = scene.quads.single;

    test('the scene takes no camera at all — quads cannot follow one', () {
      final PreviewScene again = _scene(
        _menu(components: <HuiComponent>[_button('a', Vec3(0, 1.5, 3))]),
        openYawDeg: 0,
      );
      expectVec(again.quads.single.anchor, quad.anchor);
      expect(again.quads.single.facingYawDeg, quad.facingYawDeg);
    });

    test('a moving eye re-aims the plane while the quad stays put', () {
      final PVec3 fromFront = aimQuadPlane(quad, const PVec3(0, 1.5, -5)).normal;
      final PVec3 fromSide = aimQuadPlane(quad, const PVec3(9, 1.5, 3)).normal;
      expectVec(fromFront, const PVec3(0, 0, -1), epsilon: 1e-9);
      expectVec(fromSide, const PVec3(1, 0, 0), epsilon: 1e-9);
      // ... and the quad is untouched by either call.
      expectVec(quad.anchor, const PVec3(0, 1.5, 3));
      expect(quad.facingYawDeg, 0);
    });
  });

  group('plane and visual geometry come from the 2D scene', () {
    test('a text plane is chars x lineHeight / 2 wide, lines tall', () {
      // `TextMenuIcon.java:66-72` with lineHeight 0.21875 at uiScale 1.
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            HuiComponent(
              'a',
              Vec3(0, 0, 0),
              HuiButtonData(0.05, <HuiAction>[], HuiTextIcon('Play\nQuit')),
            ),
          ],
        ),
      );
      final PreviewQuad quad = scene.quads.single;
      expect(quad.planeWidth, closeTo(4 * huiLineHeight / 2, 1e-12));
      expect(quad.planeHeight, closeTo(2 * huiLineHeight, 1e-12));
    });

    test('an item plane is 0.75 square and drops 0.05 below the anchor', () {
      // `ItemMenuIcon.java:74-77`.
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            HuiComponent(
              'a',
              Vec3(0, 2, 0),
              HuiButtonData(0.05, <HuiAction>[], HuiItemIcon('stone')),
            ),
          ],
        ),
        uiScale: 2,
      );
      final PreviewQuad quad = scene.quads.single;
      expect(quad.planeWidth, closeTo(huiItemSize * 2, 1e-12));
      expect(quad.planeHeight, closeTo(huiItemSize * 2, 1e-12));
      expectVec(quad.anchor, const PVec3(0, 4, 0));
      expectVec(
        quad.planeCenter,
        const PVec3(0, 4 - huiItemHitboxDrop * 2, 0),
        epsilon: 1e-12,
      );
    });

    test('the plane centre rotates with the quad, keeping its local drop', () {
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            HuiComponent(
              'a',
              Vec3(0, 0, 3),
              HuiButtonData(0.05, <HuiAction>[], HuiItemIcon('stone')),
            ),
          ],
        ),
        openYawDeg: 90,
      );
      final PreviewQuad quad = scene.quads.single;
      expectVec(quad.anchor, const PVec3(3, 0, 0), epsilon: 1e-9);
      expectVec(
        quad.planeCenter,
        const PVec3(3, -huiItemHitboxDrop, 0),
        epsilon: 1e-9,
      );
    });

    test('the drawn quad carries the true-render drop when asked', () {
      final HuiMenu menu = _menu(
        components: <HuiComponent>[
          HuiComponent(
            'a',
            Vec3(0, 0, 0),
            HuiDecorationData(HuiTextIcon('Hi')),
          ),
        ],
      );
      final PreviewQuad flat = _scene(menu).quads.single;
      final PreviewQuad biased = _scene(menu, trueRender: true).quads.single;
      expect(flat.visualCenter.y, closeTo(0, 1e-12));
      expect(biased.visualCenter.y, closeTo(-huiTextTrueRenderBias, 1e-12));
      // The collision plane never moves with the drawing.
      expect(flat.planeCenter.y, closeTo(biased.planeCenter.y, 1e-12));
    });

    test('reuses the supplied canvas scene rather than rebuilding it', () {
      final HuiMenu menu = _menu(
        components: <HuiComponent>[_button('a', Vec3(1, 0, 0))],
      );
      final CanvasScene canvas = buildCanvasScene(
        menu: menu,
        uiScale: 2,
        trueRender: false,
        togglePreview: (String _) => true,
        textCache: McTextCache(),
      );
      final PreviewScene scene = buildPreviewScene(
        menu: menu,
        uiScale: 2,
        openFeet: PVec3.zero,
        openYawDeg: 0,
        canvas: canvas,
      );
      expect(identical(scene.canvas, canvas), isTrue);
      expect(identical(scene.quads.single.item, canvas.items.single), isTrue);
    });
  });

  group('clickability', () {
    test('decorations get no plane and never appear in clickables', () {
      // `MenuComponent.java:62-67`: decorations tick but are not clickable.
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _decoration('deco', Vec3(0, 1, 0)),
            _button('btn', Vec3(0, 0, 0)),
          ],
        ),
      );
      expect(scene.byId('deco')!.clickable, isFalse);
      expect(scene.byId('btn')!.clickable, isTrue);
      expect(
        scene.clickables.map((PreviewQuad q) => q.id).toList(),
        <String>['btn'],
      );
    });

    test('clickables keep declaration order — the click dispatch order', () {
      // `SessionHolder.java:145-159` fires every hovered clickable in order.
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('one', Vec3(0, 0, 0)),
            _decoration('deco', Vec3(0, 1, 0)),
            _button('two', Vec3(1, 0, 0)),
          ],
        ),
      );
      expect(
        scene.clickables.map((PreviewQuad q) => q.id).toList(),
        <String>['one', 'two'],
      );
      expect(scene.quads.map((PreviewQuad q) => q.id).toList(),
          <String>['one', 'deco', 'two']);
    });

    test('the highlight modifier is carried through unclamped', () {
      // Gson writes the record field directly; the API's 0..1 clamp
      // (`HoloComponent.java:33`) never sees a parsed value.
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 0, 0), highlight: 3),
            HuiComponent(
              'toggle',
              Vec3(1, 0, 0),
              HuiToggleData(2.5, '', '', <HuiAction>[], <HuiAction>[],
                  HuiTextIcon('on'), HuiTextIcon('off')),
            ),
          ],
        ),
      );
      expect(scene.byId('a')!.highlightModifier, 3);
      expect(scene.byId('toggle')!.highlightModifier, 2.5);
      expect(scene.byId('toggle')!.clickable, isTrue);
    });

    test('decorations report a zero highlight modifier', () {
      final PreviewScene scene = _scene(
        _menu(components: <HuiComponent>[_decoration('d', Vec3(0, 0, 0))]),
      );
      expect(scene.byId('d')!.highlightModifier, 0);
    });
  });

  group('followPlayer', () {
    test('a moved centre translates the whole menu rigidly', () {
      // `MenuSession.java:103-109` re-derives every location from the new
      // centre and re-applies the SAME frozen initialY.
      final HuiMenu menu = _menu(
        offset: Vec3(0, 1.5, 3),
        followPlayer: true,
        components: <HuiComponent>[
          _button('a', Vec3(-1, 0, 0)),
          _button('b', Vec3(1, 0, 0)),
        ],
      );
      final PreviewScene still = _scene(menu, openYawDeg: 45);
      final PreviewScene walked = _scene(
        menu,
        openYawDeg: 45,
        currentCenter: still.sessionCenter + const PVec3(5, 0, -2),
      );
      expectVec(walked.center, still.center + const PVec3(5, 0, -2),
          epsilon: 1e-9);
      for (final PreviewQuad quad in still.quads) {
        expectVec(
          walked.byId(quad.id)!.anchor,
          quad.anchor + const PVec3(5, 0, -2),
          epsilon: 1e-9,
        );
        // Facing is frozen at open; walking never re-aims it.
        expect(walked.byId(quad.id)!.facingYawDeg, quad.facingYawDeg);
      }
    });

    test('the pivot is the CURRENT player position, not the open one', () {
      // The runtime pivots on `player.getEyeLocation()` at the moment of the
      // move, so the derived feet must come off the current centre.
      final PreviewScene scene = _scene(
        _menu(
          offset: Vec3(0, 0, 4),
          followPlayer: true,
          components: <HuiComponent>[_button('a', Vec3(0, 0, 0))],
        ),
        openYawDeg: 90,
        // The player walked to (20, 0, 20); the runtime's centre is their feet
        // plus the UNROTATED menu offset.
        currentCenter: const PVec3(20, 0, 24),
      );
      expectVec(scene.anchorFeet, const PVec3(20, 0, 20), epsilon: 1e-9);
      expectVec(scene.quads.single.anchor, const PVec3(24, 0, 20),
          epsilon: 1e-9);
      expectVec(scene.center, const PVec3(24, 0, 20), epsilon: 1e-9);
    });
  });

  group('lifting canvas coordinates into the world', () {
    test('lift applies the frozen rotation and the feet translation', () {
      const PVec3 feet = PVec3(3, 64, 7);
      final PreviewScene scene = _scene(
        _menu(components: <HuiComponent>[_button('a', Vec3(0, 0, 0))]),
        openFeet: feet,
        openYawDeg: 90,
      );
      expectVec(scene.lift(0, 0, 2), feet + const PVec3(2, 0, 0),
          epsilon: 1e-9);
      expectVec(scene.lift(0, 3, 0), feet + const PVec3(0, 3, 0),
          epsilon: 1e-9);
    });

    test('a quad anchor is exactly the lift of its canvas anchor', () {
      final PreviewScene scene = _scene(
        _menu(
          offset: Vec3(0.5, 1.25, 2),
          components: <HuiComponent>[_button('a', Vec3(1, -0.5, 0.25))],
        ),
        uiScale: 1.5,
        openFeet: const PVec3(-2, 3, 9),
        openYawDeg: 210,
      );
      final CanvasItem item = scene.canvas.items.single;
      expectVec(
        scene.quads.single.anchor,
        scene.lift(item.anchor.x, item.anchor.y, item.depth),
        epsilon: 1e-12,
      );
    });

    test('liftDirection rotates without translating', () {
      final PreviewScene scene = _scene(
        _menu(components: <HuiComponent>[_button('a', Vec3(0, 0, 0))]),
        openFeet: const PVec3(100, 5, -20),
        openYawDeg: 90,
      );
      expectVec(scene.liftDirection(const PVec3(0, 0, 1)),
          const PVec3(1, 0, 0), epsilon: 1e-9);
      expectVec(scene.liftDirection(const PVec3(0, 1, 0)),
          const PVec3(0, 1, 0), epsilon: 1e-9);
    });
  });

  group('hoveredClickableIds', () {
    // One call is a whole tick of `ClickableComponent.onTick`: re-aim every
    // plane at the eye, then test the look ray against each.
    PreviewScene overlapping() => _scene(
          _menu(
            components: <HuiComponent>[
              _button('back', Vec3(0, 0, 3)),
              _decoration('deco', Vec3(0, 0, 3)),
              _button('front', Vec3(0, 0, 2.9)),
            ],
          ),
          openFeet: const PVec3(0, 0, 0),
        );

    test('reports every hit clickable in declaration order', () {
      final PreviewScene scene = overlapping();
      const PVec3 eye = PVec3(0, 0, -1);
      final LookRay ray = LookRay.normalized(eye, const PVec3(0, 0, 1));
      expect(
        hoveredClickableIds(scene: scene, ray: ray, eye: eye),
        <String>['back', 'front'],
      );
    });

    test('never reports a decoration', () {
      final PreviewScene scene = overlapping();
      const PVec3 eye = PVec3(0, 0, -1);
      final LookRay ray = LookRay.normalized(eye, const PVec3(0, 0, 1));
      expect(
        hoveredClickableIds(scene: scene, ray: ray, eye: eye),
        isNot(contains('deco')),
      );
    });

    test('a ray aimed away from the menu hovers nothing', () {
      final PreviewScene scene = overlapping();
      const PVec3 eye = PVec3(0, 0, -1);
      final LookRay ray = LookRay.normalized(eye, const PVec3(0, 0, -1));
      expect(hoveredClickableIds(scene: scene, ray: ray, eye: eye), isEmpty);
    });

    test('planes re-aim, so a glancing eye still resolves a hit', () {
      // Standing to the side, the plane turns to face the eye and the ray meets
      // it square on — a fixed-normal plane would be edge-on and miss.
      final PreviewScene scene = _scene(
        _menu(components: <HuiComponent>[_button('a', Vec3(0, 0, 3))]),
      );
      final PVec3 anchor = scene.quads.single.planeCenter;
      const PVec3 eye = PVec3(6, 0, 3);
      final LookRay ray = LookRay.normalized(eye, anchor - eye);
      expect(
        hoveredClickableIds(scene: scene, ray: ray, eye: eye),
        <String>['a'],
      );
    });
  });

  group('edges', () {
    test('an empty menu produces an empty scene', () {
      final PreviewScene scene = _scene(_menu());
      expect(scene.quads, isEmpty);
      expect(scene.clickables, isEmpty);
      expect(scene.byId('nope'), isNull);
    });

    test('duplicate ids keep both quads; byId resolves the first', () {
      // The plugin renders both but only registers the first
      // (`MenuSession.java:79` putIfAbsent).
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('dup', Vec3(0, 0, 0)),
            _button('dup', Vec3(1, 0, 0)),
          ],
        ),
      );
      expect(scene.quads.length, 2);
      expectVec(scene.byId('dup')!.anchor, PVec3.zero);
    });
  });
}
