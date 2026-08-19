/// The 3D layout pass: menu transforms, display billboards and collision planes.
library;

import 'package:gloss_editor/logic/canvas_scene.dart';
import 'package:gloss_editor/logic/hui_geometry.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/preview/preview_scene.dart';
import 'package:gloss_editor/preview/preview_types.dart';
import 'package:gloss_editor/preview/projection.dart';
import 'package:test/test.dart';

import 'projection_test.dart' show expectVec;

HuiComponent _button(
  String id,
  Vec3 offset, {
  double highlight = 0.05,
  String billboard = 'fixed',
}) => HuiComponent(
  id,
  offset,
  HuiButtonData(
    highlight,
    <HuiAction>[],
    HuiTextIcon('Play', HuiIconStyle(billboard: billboard)),
  ),
);

HuiComponent _decoration(String id, Vec3 offset, [String text = 'Title']) =>
    HuiComponent(id, offset, HuiDecorationData(HuiTextIcon(text)));

HuiMenu _menu({
  Vec3? offset,
  List<HuiComponent>? components,
  bool followPlayer = false,
}) => HuiMenu(
  offset: offset ?? Vec3.zero(),
  followPlayer: followPlayer,
  components: components ?? <HuiComponent>[],
);

PreviewScene _scene(
  HuiMenu menu, {
  double uiScale = 1,
  PVec3 openFeet = PVec3.zero,
  double openYawDeg = 0,
  double? facingYawDeg,
  PVec3? anchorFeet,
  double pitchDeg = 0,
  double rollDeg = 0,
  bool trueRender = false,
}) => buildPreviewScene(
  menu: menu,
  uiScale: uiScale,
  openFeet: openFeet,
  openYawDeg: openYawDeg,
  facingYawDeg: facingYawDeg ?? openYawDeg,
  anchorFeet: anchorFeet,
  pitchDeg: pitchDeg,
  rollDeg: rollDeg,
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
    test(
      'rotates about the vertical axis through the PLAYER, not the centre',
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
        expectVec(
          scene.quads.single.anchor,
          const PVec3(4, 0, 0),
          epsilon: 1e-9,
        );
      },
    );

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
      expectVec(scene.center, feet + const PVec3(0, 1, -3), epsilon: 1e-9);
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

    test('fixed quads use the menu yaw', () {
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 0, 3)),
            _decoration('b', Vec3(1, 0, 3)),
          ],
        ),
        openYawDeg: 137.5,
      );
      expect(scene.facingYawDeg, 137.5);
      for (final PreviewQuad quad in scene.quads) {
        // The outward face points back down the player's line of sight.
        expectVec(
          quad.fixedPlane.normal,
          -huiLookDirection(yawDegrees: 137.5),
          epsilon: 1e-12,
        );
      }
    });

    test('changing the menu yaw moves and turns a fixed quad', () {
      final HuiMenu menu = _menu(
        components: <HuiComponent>[_button('a', Vec3(0, 0, 3))],
      );
      final PreviewScene at0 = _scene(menu, openYawDeg: 0);
      final PreviewScene at90 = _scene(menu, openYawDeg: 90);
      expect(at0.quads.single.anchor == at90.quads.single.anchor, isFalse);
      expect(
        at0.quads.single.fixedPlane.normal,
        isNot(at90.quads.single.fixedPlane.normal),
      );
    });
  });

  group('billboard orientation', () {
    test('fixed preserves the full menu transform as the viewer moves', () {
      final PreviewQuad quad = _scene(
        _menu(components: <HuiComponent>[_button('a', Vec3(0, 1.5, 3))]),
        openYawDeg: 32,
        pitchDeg: 18,
        rollDeg: -11,
      ).quads.single;
      final PlaneAim fromFront = aimQuadPlane(quad, const PVec3(0, 1.5, -5));
      final PlaneAim fromSide = aimQuadPlane(quad, const PVec3(9, 1.5, 3));
      expectVec(fromFront.normal, quad.fixedPlane.normal);
      expectVec(fromFront.right, quad.fixedPlane.right);
      expectVec(fromSide.normal, quad.fixedPlane.normal);
      expectVec(fromSide.up, quad.fixedPlane.up);
    });

    test('vertical faces the viewer in yaw while keeping world up', () {
      final PreviewQuad quad = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 1.5, 3), billboard: 'vertical'),
          ],
        ),
        openYawDeg: 40,
        pitchDeg: 20,
        rollDeg: 15,
      ).quads.single;
      const PVec3 eye = PVec3(7, 8, -2);
      final PlaneAim aimed = aimQuadPlane(quad, eye);
      final PVec3 horizontal = PVec3(
        eye.x - quad.planeCenter.x,
        0,
        eye.z - quad.planeCenter.z,
      ).normalized;
      expectVec(aimed.normal, horizontal);
      expectVec(aimed.up, PVec3.up);
      expect(aimed.right.y, closeTo(0, 1e-12));
    });

    test('horizontal preserves menu right and pitches toward the viewer', () {
      final PreviewQuad quad = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 1.5, 3), billboard: 'horizontal'),
          ],
        ),
        openYawDeg: 35,
        pitchDeg: 12,
        rollDeg: -7,
      ).quads.single;
      const PVec3 eye = PVec3(5, 7, -4);
      final PlaneAim aimed = aimQuadPlane(quad, eye);
      final PVec3 expectedNormal =
          (eye -
                  quad.planeCenter -
                  quad.fixedPlane.right *
                      (eye - quad.planeCenter).dot(quad.fixedPlane.right))
              .normalized;
      expectVec(aimed.right, quad.fixedPlane.right);
      expectVec(aimed.normal, expectedNormal);
      expect(aimed.up.dot(aimed.right), closeTo(0, 1e-12));
    });

    test('center fully faces the viewer', () {
      final PreviewQuad quad = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 1.5, 3), billboard: 'center'),
          ],
        ),
        openYawDeg: 75,
      ).quads.single;
      const PVec3 eye = PVec3(6, 5, -3);
      final PlaneAim aimed = aimQuadPlane(quad, eye);
      expectVec(aimed.normal, (eye - quad.planeCenter).normalized);
    });

    test('the visual and click plane apply the same billboard basis', () {
      final PreviewQuad quad = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 1.5, 3), billboard: 'center'),
          ],
        ),
      ).quads.single;
      const PVec3 eye = PVec3(6, 5, -3);
      final PlaneAim hitbox = aimQuadPlane(quad, eye);
      final PlaneAim visual = aimQuadVisual(quad, quad.planeCenter, eye);
      expectVec(visual.normal, hitbox.normal);
      expectVec(visual.right, hitbox.right);
      expectVec(visual.up, hitbox.up);
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

    test('the drawn quad and plane carry the true-render drop together', () {
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
      expect(flat.planeCenter.y, closeTo(0, 1e-12));
      expect(biased.planeCenter.y, closeTo(-huiTextTrueRenderBias, 1e-12));
      expect(biased.planeCenter.y, closeTo(biased.visualCenter.y, 1e-12));
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
        facingYawDeg: 0,
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
      expect(scene.clickables.map((PreviewQuad q) => q.id).toList(), <String>[
        'btn',
      ]);
    });

    test('clickables keep declaration order for equal-distance ties', () {
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('one', Vec3(0, 0, 0)),
            _decoration('deco', Vec3(0, 1, 0)),
            _button('two', Vec3(1, 0, 0)),
          ],
        ),
      );
      expect(scene.clickables.map((PreviewQuad q) => q.id).toList(), <String>[
        'one',
        'two',
      ]);
      expect(scene.quads.map((PreviewQuad q) => q.id).toList(), <String>[
        'one',
        'deco',
        'two',
      ]);
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
              HuiToggleData(
                2.5,
                '',
                '',
                <HuiAction>[],
                <HuiAction>[],
                HuiTextIcon('on'),
                HuiTextIcon('off'),
              ),
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
    test('a moved anchor translates the whole menu rigidly', () {
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
        facingYawDeg: 45,
        anchorFeet: still.anchorFeet + const PVec3(5, 0, -2),
      );
      expectVec(
        walked.center,
        still.center + const PVec3(5, 0, -2),
        epsilon: 1e-9,
      );
      for (final PreviewQuad quad in still.quads) {
        expectVec(
          walked.byId(quad.id)!.anchor,
          quad.anchor + const PVec3(5, 0, -2),
          epsilon: 1e-9,
        );
        expectVec(
          walked.byId(quad.id)!.fixedPlane.normal,
          quad.fixedPlane.normal,
        );
      }
    });

    test('the pivot is the CURRENT player position, not the open one', () {
      final PreviewScene scene = _scene(
        _menu(
          offset: Vec3(0, 0, 4),
          followPlayer: true,
          components: <HuiComponent>[_button('a', Vec3(0, 0, 0))],
        ),
        openYawDeg: 90,
        facingYawDeg: 90,
        anchorFeet: const PVec3(20, 0, 20),
      );
      expectVec(scene.anchorFeet, const PVec3(20, 0, 20), epsilon: 1e-9);
      expectVec(
        scene.quads.single.anchor,
        const PVec3(24, 0, 20),
        epsilon: 1e-9,
      );
      expectVec(scene.center, const PVec3(24, 0, 20), epsilon: 1e-9);
    });

    test('keeps the open pose but turns with the current player yaw', () {
      final HuiMenu menu = _menu(
        offset: Vec3(0, 0, 4),
        followPlayer: true,
        components: <HuiComponent>[_button('a', Vec3(1, 0, 0))],
      );
      final PreviewScene scene = _scene(
        menu,
        openFeet: const PVec3(2, 0, 3),
        openYawDeg: 20,
        anchorFeet: const PVec3(8, 0, 9),
        facingYawDeg: 90,
      );
      expect(scene.openYawDeg, 20);
      expect(scene.facingYawDeg, 90);
      expectVec(scene.center, const PVec3(12, 0, 9), epsilon: 1e-9);
      expectVec(
        scene.quads.single.fixedPlane.normal,
        -huiLookDirection(yawDegrees: 90),
        epsilon: 1e-9,
      );
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
      expectVec(
        scene.lift(0, 0, 2),
        feet + const PVec3(2, 0, 0),
        epsilon: 1e-9,
      );
      expectVec(
        scene.lift(0, 3, 0),
        feet + const PVec3(0, 3, 0),
        epsilon: 1e-9,
      );
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
      expectVec(
        scene.liftDirection(const PVec3(0, 0, 1)),
        const PVec3(1, 0, 0),
        epsilon: 1e-9,
      );
      expectVec(
        scene.liftDirection(const PVec3(0, 1, 0)),
        const PVec3(0, 1, 0),
        epsilon: 1e-9,
      );
    });
  });

  group('hoveredClickableIds', () {
    // One call is a whole geometry tick: apply each icon's billboard rule,
    // then test the look ray against every clickable.
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
      final PVec3 eye = PVec3(0, scene.quads.first.planeCenter.y, -1);
      final LookRay ray = LookRay.normalized(eye, const PVec3(0, 0, 1));
      expect(hoveredClickableIds(scene: scene, ray: ray, eye: eye), <String>[
        'back',
        'front',
      ]);
    });

    test('reports the nearest event-time click target', () {
      final PreviewScene scene = overlapping();
      final PVec3 eye = PVec3(0, scene.quads.first.planeCenter.y, -1);
      final LookRay ray = LookRay.normalized(eye, const PVec3(0, 0, 1));

      expect(nearestClickableId(scene: scene, ray: ray, eye: eye), 'front');
    });

    test('never reports a decoration', () {
      final PreviewScene scene = overlapping();
      final PVec3 eye = PVec3(0, scene.quads.first.planeCenter.y, -1);
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

    test('a center billboard resolves a glancing hit from the side', () {
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('a', Vec3(0, 0, 3), billboard: 'center'),
          ],
        ),
      );
      final PVec3 anchor = scene.quads.single.planeCenter;
      const PVec3 eye = PVec3(6, 0, 3);
      final LookRay ray = LookRay.normalized(eye, anchor - eye);
      expect(hoveredClickableIds(scene: scene, ray: ray, eye: eye), <String>[
        'a',
      ]);
    });
  });

  group('edges', () {
    test('an empty menu produces an empty scene', () {
      final PreviewScene scene = _scene(_menu());
      expect(scene.quads, isEmpty);
      expect(scene.clickables, isEmpty);
      expect(scene.byId('nope'), isNull);
    });

    test('duplicate ids keep only the first quad', () {
      final PreviewScene scene = _scene(
        _menu(
          components: <HuiComponent>[
            _button('dup', Vec3(0, 0, 0)),
            _button('dup', Vec3(1, 0, 0)),
          ],
        ),
      );
      expect(scene.quads.length, 1);
      expectVec(scene.byId('dup')!.anchor, PVec3.zero);
    });
  });
}
