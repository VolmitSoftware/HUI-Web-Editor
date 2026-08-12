import 'package:holoui_editor/logic/hui_geometry.dart';
import 'package:holoui_editor/logic/viewport_math.dart';
import 'package:holoui_editor/model/hui_component.dart';
import 'package:holoui_editor/model/vec3.dart';
import 'package:test/test.dart';

const double _epsilon = 1e-12;

HuiComponent _component(double x, double y, [double z = 0]) =>
    HuiComponent('probe', Vec3(x, y, z), HuiDecorationData());

void main() {
  group('constants', () {
    test('match the plugin metrics', () {
      // MenuIcon.NAMETAG_SIZE = 1/16F * 3.5F
      expect(huiLineHeight, 0.21875);
      // Full-block glyph: 8 px + 1 px spacing at 1/40 blocks per pixel.
      expect(huiCharCell, 0.225);
      expect(huiItemSize, 0.75);
    });
  });

  group('HuiRect', () {
    test('x/y are the centre and the edges follow y-up', () {
      const HuiRect r = HuiRect(x: 1, y: 2, w: 4, h: 6);
      expect(r.left, -1.0);
      expect(r.right, 3.0);
      expect(r.bottom, -1.0);
      expect(r.top, 5.0);
      expect(r.halfWidth, 2.0);
      expect(r.halfHeight, 3.0);
    });

    test('contains uses inclusive edges', () {
      const HuiRect r = HuiRect(x: 0, y: 0, w: 2, h: 1);
      expect(r.contains(0, 0), isTrue);
      expect(r.contains(1, 0.5), isTrue);
      expect(r.contains(1.001, 0), isFalse);
      expect(r.contains(0, -0.51), isFalse);
    });

    test('overlaps is exclusive so touching edges do not collide', () {
      const HuiRect a = HuiRect(x: 0, y: 0, w: 2, h: 2);
      const HuiRect b = HuiRect(x: 1.5, y: 0, w: 2, h: 2);
      const HuiRect c = HuiRect(x: 2, y: 0, w: 2, h: 2);
      const HuiRect d = HuiRect(x: 0, y: 5, w: 2, h: 2);
      expect(a.overlaps(b), isTrue);
      expect(b.overlaps(a), isTrue);
      expect(a.overlaps(c), isFalse);
      expect(a.overlaps(d), isFalse);
    });

    test('translate, inflate and union', () {
      const HuiRect a = HuiRect(x: 0, y: 0, w: 2, h: 2);
      expect(a.translate(1, -1), const HuiRect(x: 1, y: -1, w: 2, h: 2));
      expect(a.inflate(0.5), const HuiRect(x: 0, y: 0, w: 3, h: 3));
      const HuiRect b = HuiRect(x: 4, y: 4, w: 2, h: 2);
      final HuiRect u = a.union(b);
      expect(u.left, -1.0);
      expect(u.right, 5.0);
      expect(u.bottom, -1.0);
      expect(u.top, 5.0);
    });

    test('exposes viewport bounds for fit-to-content', () {
      const HuiRect a = HuiRect(x: 1, y: 1, w: 2, h: 2);
      const WorldBounds expected = WorldBounds(
        minX: 0,
        minY: 0,
        maxX: 2,
        maxY: 2,
      );
      expect(a.bounds, expected);
    });
  });

  group('hitboxAt - text', () {
    test(
      '3 lines x 10 chars at uiScale 1 matches the collision plane table',
      () {
        const IconShape shape = IconShape.text(lines: 3, maxLineChars: 10);
        final HuiRect box = hitboxAt(
          anchorX: 0,
          anchorY: 0,
          uiScale: 1,
          shape: shape,
        );
        expect(box.w, closeTo(10 * huiLineHeight / 2, _epsilon));
        expect(box.w, closeTo(1.09375, _epsilon));
        expect(box.h, closeTo(3 * huiLineHeight, _epsilon));
        expect(box.h, closeTo(0.65625, _epsilon));
        expect(box.x, 0.0);
        expect(box.y, closeTo(-huiTextTrueRenderBias, _epsilon));
      },
    );

    test('scales width, height and the anchor by uiScale 2.5', () {
      const IconShape shape = IconShape.text(lines: 3, maxLineChars: 10);
      final HuiRect box = hitboxAt(
        anchorX: 1,
        anchorY: 2,
        uiScale: 2.5,
        shape: shape,
      );
      expect(box.w, closeTo(2.734375, _epsilon));
      expect(box.h, closeTo(1.640625, _epsilon));
      expect(box.x, 1.0);
      expect(box.y, closeTo(2 - huiTextTrueRenderBias * 2.5, _epsilon));
    });

    test('stays centred on the visible text regardless of line count', () {
      for (final int lines in <int>[1, 2, 5]) {
        final HuiRect box = hitboxAt(
          anchorX: -0.5,
          anchorY: 0.85,
          uiScale: 1,
          shape: IconShape.text(lines: lines, maxLineChars: 4),
        );
        expect(box.x, -0.5);
        expect(box.y, closeTo(0.85 - huiTextTrueRenderBias, _epsilon));
        expect(box.h, closeTo(lines * huiLineHeight, _epsilon));
      }
    });
  });

  group('hitboxAt - image', () {
    test('height uses (rows - 1) line heights', () {
      const IconShape shape = IconShape.image(rows: 8, columns: 8);
      final HuiRect box = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: shape,
      );
      expect(box.w, closeTo(0.875, _epsilon));
      expect(box.h, closeTo(7 * huiLineHeight, _epsilon));
      expect(box.h, closeTo(1.53125, _epsilon));
      expect(box.y, closeTo(-huiTextTrueRenderBias, _epsilon));
    });

    test('scales with uiScale 2.5', () {
      const IconShape shape = IconShape.image(rows: 8, columns: 8);
      final HuiRect box = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 2.5,
        shape: shape,
      );
      expect(box.w, closeTo(2.1875, _epsilon));
      expect(box.h, closeTo(3.828125, _epsilon));
    });

    test('a single row is exactly zero-height in game', () {
      final HuiRect box = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.image(rows: 1, columns: 4),
      );
      expect(box.h, 0.0);
    });

    test('the missing-icon placeholder is an 8x8 image shape', () {
      const IconShape missing = IconShape.missing();
      expect(missing.lines, 8);
      expect(missing.maxLineChars, 8);
      expect(missing.isItem, isFalse);
      final HuiRect box = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: missing,
      );
      expect(box.w, closeTo(0.875, _epsilon));
      expect(box.h, closeTo(1.53125, _epsilon));
    });
  });

  group('hitboxAt - item', () {
    test('is a 0.75 square dropped 0.05 below the anchor at uiScale 1', () {
      final HuiRect box = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.item(),
      );
      expect(box.w, 0.75);
      expect(box.h, 0.75);
      expect(box.x, 0.0);
      expect(box.y, closeTo(-0.05, _epsilon));
    });

    test('scales the square and the drop at uiScale 2.5', () {
      final HuiRect box = hitboxAt(
        anchorX: 2,
        anchorY: 1,
        uiScale: 2.5,
        shape: const IconShape.item(count: 4, isBlockItem: true),
      );
      expect(box.w, closeTo(1.875, _epsilon));
      expect(box.h, closeTo(1.875, _epsilon));
      expect(box.x, 2.0);
      expect(box.y, closeTo(1 - 0.125, _epsilon));
    });

    test('ignores line counts', () {
      final HuiRect a = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.item(),
      );
      final HuiRect b = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.item(count: 64),
      );
      expect(a, b);
    });
  });

  group('visualBoundsAt', () {
    test('preview mode centres text on the anchor', () {
      final HuiRect box = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.text(lines: 3, maxLineChars: 10),
      );
      expect(box.y, 0.0);
      expect(box.h, closeTo(3 * huiLineHeight, _epsilon));
      expect(box.w, closeTo(10 * huiTextCharWidth, _epsilon));
      expect(box.w, closeTo(1.5, _epsilon));
    });

    test('true render drops the text stack 0.325 blocks per uiScale', () {
      const IconShape shape = IconShape.text(lines: 3, maxLineChars: 10);
      final HuiRect one = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: shape,
        trueRender: true,
      );
      expect(one.y, closeTo(-0.325, _epsilon));
      final HuiRect scaled = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 2.5,
        shape: shape,
        trueRender: true,
      );
      expect(scaled.y, closeTo(-0.8125, _epsilon));
      expect(huiTextTrueRenderBias, 0.325);
    });

    test('images render one char cell per source pixel', () {
      final HuiRect box = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.image(rows: 8, columns: 8),
      );
      expect(box.w, closeTo(8 * huiCharCell, _epsilon));
      expect(box.w, closeTo(1.8, _epsilon));
      expect(box.h, closeTo(8 * huiLineHeight, _epsilon));
      expect(box.h, closeTo(1.75, _epsilon));
    });

    test('images share the text true-render bias', () {
      final HuiRect box = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 2,
        shape: const IconShape.image(rows: 4, columns: 4),
        trueRender: true,
      );
      expect(box.y, closeTo(-0.65, _epsilon));
    });

    test('items are a 0.75 square on the anchor in preview mode', () {
      final HuiRect box = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 2,
        shape: const IconShape.item(),
      );
      expect(box.w, 1.5);
      expect(box.h, 1.5);
      expect(box.y, 0.0);
    });

    test('true render applies the item display offsets', () {
      final HuiRect single = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.item(),
        trueRender: true,
      );
      expect(single.y, closeTo(-(0.21875 + 1.09), _epsilon));

      final HuiRect stacked = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.item(count: 12),
        trueRender: true,
      );
      expect(stacked.y, closeTo(-(0.21875 + 1.0), _epsilon));

      final HuiRect block = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.item(isBlockItem: true),
        trueRender: true,
      );
      // Block-like items are teleported by ItemMenuIcon.rotate on spawn, which
      // drops the nametag term the spawn location carried.
      expect(block.y, closeTo(-0.95, _epsilon));

      final HuiRect scaled = visualBoundsAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 2.5,
        shape: const IconShape.item(),
        trueRender: true,
      );
      expect(scaled.y, closeTo(-(0.21875 + 1.09) * 2.5, _epsilon));
    });

    test('itemTrueRenderBias matches the visual bounds it drives', () {
      expect(
        itemTrueRenderBias(count: 1, isBlockItem: false),
        closeTo(1.30875, _epsilon),
      );
      expect(
        itemTrueRenderBias(count: 2, isBlockItem: false),
        closeTo(1.21875, _epsilon),
      );
      expect(
        itemTrueRenderBias(count: 1, isBlockItem: true),
        closeTo(0.95, _epsilon),
      );
      expect(
        itemTrueRenderBias(count: 12, isBlockItem: true),
        closeTo(0.95, _epsilon),
      );
    });

    test('entity footprint grows upward from its feet anchor', () {
      final HuiRect visual = visualBoundsAt(
        anchorX: 2,
        anchorY: 3,
        uiScale: 2,
        shape: const IconShape.entity(width: 0.5, height: 0.9),
        trueRender: true,
      );
      final HuiRect hitbox = hitboxAt(
        anchorX: 2,
        anchorY: 3,
        uiScale: 2,
        shape: const IconShape.entity(width: 0.5, height: 0.9),
      );

      expect(visual, const HuiRect(x: 2, y: 3.9, w: 1, h: 1.8));
      expect(hitbox, visual);
      expect(visual.bottom, closeTo(3, _epsilon));
    });
  });

  group('text line layout', () {
    test('preview lines are centred on the anchor, top line first', () {
      expect(
        textLineCenterY(anchorY: 0, uiScale: 1, lineIndex: 0, lineCount: 3),
        closeTo(huiLineHeight, _epsilon),
      );
      expect(
        textLineCenterY(anchorY: 0, uiScale: 1, lineIndex: 1, lineCount: 3),
        closeTo(0, _epsilon),
      );
      expect(
        textLineCenterY(anchorY: 0, uiScale: 1, lineIndex: 2, lineCount: 3),
        closeTo(-huiLineHeight, _epsilon),
      );
      expect(
        textLineCenterY(anchorY: 0, uiScale: 1, lineIndex: 0, lineCount: 2),
        closeTo(huiLineHeight / 2, _epsilon),
      );
    });

    test('true render shifts every line by the stack bias', () {
      const double bias = huiTextTrueRenderBias;
      for (int i = 0; i < 3; i++) {
        final double preview = textLineCenterY(
          anchorY: 0.5,
          uiScale: 2,
          lineIndex: i,
          lineCount: 3,
        );
        final double real = textLineCenterY(
          anchorY: 0.5,
          uiScale: 2,
          lineIndex: i,
          lineCount: 3,
          trueRender: true,
        );
        expect(real, closeTo(preview - bias * 2, _epsilon));
      }
    });

    test('line spacing is the scaled nametag size', () {
      final double a = textLineCenterY(
        anchorY: 0,
        uiScale: 2.5,
        lineIndex: 0,
        lineCount: 4,
      );
      final double b = textLineCenterY(
        anchorY: 0,
        uiScale: 2.5,
        lineIndex: 1,
        lineCount: 4,
      );
      expect(a - b, closeTo(huiLineHeight * 2.5, _epsilon));
    });
  });

  group('item count label', () {
    test('sits below the anchor by the nametag size plus 0.37', () {
      expect(
        itemCountLabelY(anchorY: 0, uiScale: 1),
        closeTo(-(huiLineHeight + huiItemCountLabelOffset), _epsilon),
      );
      expect(
        itemCountLabelY(anchorY: 1, uiScale: 2),
        closeTo(1 - (huiLineHeight + huiItemCountLabelOffset) * 2, _epsilon),
      );
    });
  });

  group('component anchoring', () {
    test('the component offset is multiplied by uiScale', () {
      final HuiComponent c = _component(0.4, 0.85, -0.2);
      final WorldPoint one = anchorFor(component: c, uiScale: 1);
      expect(one.x, closeTo(0.4, _epsilon));
      expect(one.y, closeTo(0.85, _epsilon));
      final WorldPoint scaled = anchorFor(component: c, uiScale: 2.5);
      expect(scaled.x, closeTo(1.0, _epsilon));
      expect(scaled.y, closeTo(2.125, _epsilon));
      expect(depthFor(component: c, uiScale: 2.5), closeTo(-0.5, _epsilon));
    });

    test('the menu offset is added without being scaled', () {
      final HuiComponent c = _component(1, 1, 1);
      final Vec3 menu = Vec3(0, 1.7, 2.5);
      final WorldPoint anchor = anchorFor(
        component: c,
        uiScale: 2,
        menuOffset: menu,
      );
      expect(anchor.x, closeTo(2, _epsilon));
      expect(anchor.y, closeTo(3.7, _epsilon));
      expect(
        depthFor(component: c, uiScale: 2, menuOffset: menu),
        closeTo(4.5, _epsilon),
      );
    });

    test('hitboxFor lands the table values on the scaled anchor', () {
      final HuiComponent c = _component(1, 2);
      final HuiRect box = hitboxFor(
        component: c,
        uiScale: 2.5,
        shape: const IconShape.text(lines: 3, maxLineChars: 10),
      );
      expect(box.x, closeTo(2.5, _epsilon));
      expect(box.y, closeTo(5 - huiTextTrueRenderBias * 2.5, _epsilon));
      expect(box.w, closeTo(2.734375, _epsilon));
      expect(box.h, closeTo(1.640625, _epsilon));
    });

    test('hitboxFor drops item planes below the scaled anchor', () {
      final HuiRect box = hitboxFor(
        component: _component(0, 1),
        uiScale: 2,
        shape: const IconShape.item(),
      );
      expect(box.y, closeTo(2 - 0.1, _epsilon));
      expect(box.w, closeTo(1.5, _epsilon));
    });

    test('button custom hitbox overrides scaled dimensions only', () {
      final HuiComponent component = HuiComponent(
        'button',
        Vec3(0, 1, 0),
        HuiButtonData(0.05, const [], null, HuiHitbox(1.25, 0.35)),
      );
      final HuiRect box = hitboxFor(
        component: component,
        uiScale: 2,
        shape: const IconShape.text(lines: 1, maxLineChars: 4),
      );
      expect(box.y, closeTo(2 - huiTextTrueRenderBias * 2, _epsilon));
      expect(box.w, closeTo(2.5, _epsilon));
      expect(box.h, closeTo(0.7, _epsilon));
    });

    test('button anchor applies a scaled offset from the icon plane', () {
      final HuiComponent component = HuiComponent(
        'button',
        Vec3(1, 2, 3),
        HuiButtonData(
          0.05,
          const [],
          null,
          HuiHitbox(null, null, Vec3(0.5, -0.25, 0.75)),
        ),
      );
      final HuiRect box = hitboxFor(
        component: component,
        uiScale: 2,
        shape: const IconShape.text(lines: 1, maxLineChars: 4),
        menuOffset: Vec3(10, 20, 30),
      );
      expect(box.x, closeTo(13, _epsilon));
      expect(box.y, closeTo(23.5 - huiTextTrueRenderBias * 2, _epsilon));
      expect(
        hitboxDepthFor(
          component: component,
          uiScale: 2,
          menuOffset: Vec3(10, 20, 30),
        ),
        closeTo(37.5, _epsilon),
      );
    });

    test('menu anchor ignores component movement', () {
      HuiComponent component(double x, double y, double z) => HuiComponent(
        'button',
        Vec3(x, y, z),
        HuiButtonData(
          0.05,
          const [],
          null,
          HuiHitbox(null, null, Vec3(0.5, -0.25, 0.75), HuiHitboxAnchor.menu),
        ),
      );
      final Vec3 menuOffset = Vec3(10, 20, 30);
      final HuiRect first = hitboxFor(
        component: component(1, 2, 3),
        uiScale: 2,
        shape: const IconShape.text(lines: 1, maxLineChars: 4),
        menuOffset: menuOffset,
      );
      final HuiRect moved = hitboxFor(
        component: component(8, -4, 9),
        uiScale: 2,
        shape: const IconShape.text(lines: 1, maxLineChars: 4),
        menuOffset: menuOffset,
      );
      expect(first, moved);
      expect(first.x, closeTo(11, _epsilon));
      expect(first.y, closeTo(19.5, _epsilon));
      expect(
        hitboxDepthFor(
          component: component(8, -4, 9),
          uiScale: 2,
          menuOffset: menuOffset,
        ),
        closeTo(31.5, _epsilon),
      );
    });

    test('menu anchor stays aligned in the authoring projection', () {
      final HuiComponent component = HuiComponent(
        'button',
        Vec3(0, 0.5, 0),
        HuiButtonData(
          0.05,
          const [],
          null,
          HuiHitbox(null, null, Vec3(0, 0.175, 0), HuiHitboxAnchor.menu),
        ),
      );
      final Vec3 menuOffset = Vec3(0, 1.7, 2.5);
      final HuiRect authoring = hitboxFor(
        component: component,
        uiScale: 1,
        shape: const IconShape.text(lines: 1, maxLineChars: 10),
        menuOffset: menuOffset,
        trueRender: false,
      );
      final HuiRect runtime = hitboxFor(
        component: component,
        uiScale: 1,
        shape: const IconShape.text(lines: 1, maxLineChars: 10),
        menuOffset: menuOffset,
        trueRender: true,
      );
      expect(authoring.y, closeTo(2.2, _epsilon));
      expect(runtime.y, closeTo(1.875, _epsilon));
    });

    test('visualBoundsFor carries the true-render bias off the anchor', () {
      final HuiComponent c = _component(0, 1);
      final HuiRect preview = visualBoundsFor(
        component: c,
        uiScale: 2,
        shape: const IconShape.text(lines: 2, maxLineChars: 6),
      );
      final HuiRect real = visualBoundsFor(
        component: c,
        uiScale: 2,
        shape: const IconShape.text(lines: 2, maxLineChars: 6),
        trueRender: true,
      );
      expect(preview.y, closeTo(2, _epsilon));
      expect(real.y, closeTo(2 - 0.65, _epsilon));
      expect(real.w, preview.w);
    });

    test('two components can be tested for hitbox overlap', () {
      final HuiRect a = hitboxFor(
        component: _component(0, 0),
        uiScale: 1,
        shape: const IconShape.text(lines: 3, maxLineChars: 10),
      );
      final HuiRect near = hitboxFor(
        component: _component(0.5, 0),
        uiScale: 1,
        shape: const IconShape.text(lines: 3, maxLineChars: 10),
      );
      final HuiRect far = hitboxFor(
        component: _component(3, 0),
        uiScale: 1,
        shape: const IconShape.text(lines: 3, maxLineChars: 10),
      );
      expect(a.overlaps(near), isTrue);
      expect(a.overlaps(far), isFalse);
      expect(a.contains(0.5, -0.3), isTrue);
    });
  });

  group('degenerate shapes', () {
    test(
      'non-uniform icon scale changes automatic planes and visual bounds',
      () {
        const IconShape shape = IconShape.text(lines: 2, maxLineChars: 8);
        final HuiRect plane = hitboxAt(
          anchorX: 0,
          anchorY: 0,
          uiScale: 1,
          shape: shape,
          scaleX: 2,
          scaleY: 0.5,
        );
        final HuiRect visual = visualBoundsAt(
          anchorX: 0,
          anchorY: 0,
          uiScale: 1,
          shape: shape,
          trueRender: true,
          scaleX: 2,
          scaleY: 0.5,
        );

        expect(plane.w, closeTo(8 * huiLineHeight, _epsilon));
        expect(plane.h, closeTo(huiLineHeight, _epsilon));
        expect(plane.y, closeTo(-huiTextTrueRenderBias * 0.5, _epsilon));
        expect(visual.w, closeTo(8 * huiTextCharWidth * 2, _epsilon));
        expect(visual.h, closeTo(2 * huiLineHeight * 0.5, _epsilon));
      },
    );

    test('non-uniform item scale expands its automatic click plane', () {
      final HuiRect plane = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 2,
        shape: const IconShape.item(),
        scaleX: 1.5,
        scaleY: 0.25,
      );
      expect(plane.w, closeTo(huiItemSize * 3, _epsilon));
      expect(plane.h, closeTo(huiItemSize * 0.5, _epsilon));
    });

    test('never produce negative extents', () {
      final HuiRect emptyText = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.text(lines: 0, maxLineChars: 0),
      );
      expect(emptyText.w, 0.0);
      expect(emptyText.h, 0.0);

      final HuiRect emptyImage = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: const IconShape.image(rows: 0, columns: 0),
      );
      expect(emptyImage.w, 0.0);
      expect(emptyImage.h, 0.0);
    });

    test('a non-positive uiScale collapses to zero rather than inverting', () {
      final HuiRect box = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 0,
        shape: const IconShape.text(lines: 3, maxLineChars: 10),
      );
      expect(box.w, 0.0);
      expect(box.h, 0.0);
    });
  });
}
