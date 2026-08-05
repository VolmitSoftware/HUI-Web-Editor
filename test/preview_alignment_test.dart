/// Vertical alignment: where an icon's collision plane sits, where its glyphs
/// are drawn, and where the bitmap that carries those glyphs has to be pinned.
///
/// Text display entities retain their below-anchor bias, and their collision
/// planes follow the resulting visible glyph centre.
///
/// The 2D canvas and the 3D preview both read these numbers, so an assertion
/// here is what keeps the two views from disagreeing about the same document.
library;

import 'dart:math' as math;

import 'package:holoui_editor/logic/canvas_scene.dart';
import 'package:holoui_editor/logic/hui_geometry.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/preview/preview_scene.dart';
import 'package:holoui_editor/preview/preview_types.dart';
import 'package:test/test.dart';

HuiComponent _button(String id, HuiIcon icon) =>
    HuiComponent(id, Vec3(0, 0, 0), HuiButtonData(0, <HuiAction>[], icon));

CanvasScene _scene(List<HuiComponent> components, {double uiScale = 1}) =>
    buildCanvasScene(
      menu: HuiMenu(offset: Vec3(0, 0, 0), components: components),
      uiScale: uiScale,
      // The preview never renders any other way; the canvas toolbar's switch
      // only decides whether the AUTHORING view reproduces the same drop.
      trueRender: true,
      togglePreview: (String _) => true,
      textCache: McTextCache(),
    );

CanvasItem _only(HuiIcon icon, {double uiScale = 1}) =>
    _scene(<HuiComponent>[_button('a', icon)], uiScale: uiScale).items.single;

/// Blocks the plane centre sits below the anchor. Positive is down.
double _planeDrop(CanvasItem item) => item.anchor.y - item.hitbox.y;

/// Blocks the drawn icon's centre sits below the anchor. Positive is down.
double _visualDrop(CanvasItem item) => item.anchor.y - item.visual.y;

void main() {
  group('true-render constants match the Java', () {
    test('one line is NAMETAG_SIZE blocks', () {
      // `MenuIcon.NAMETAG_SIZE = 1 / 16F * 3.5F` (MenuIcon.java:46).
      expect(huiLineHeight, closeTo(3.5 / 16, 1e-12));
    });

    test('text drops two nametags less the display baseline', () {
      // `MenuIcon.spawn` -1 nametag (MenuIcon.java:129) and
      // `TextMenuIcon.createDisplayEntities` -1 more (TextMenuIcon.java:58),
      // calibrated back up by the text display's own 4.5 px baseline.
      expect(
        huiTextTrueRenderBias,
        closeTo(2 * huiLineHeight - 4.5 / 40, 1e-12),
      );
    });

    test('a loose item drops a nametag plus ITEM_OFFSET plus the single-count '
        'nudge, a block-like one only BLOCK_OFFSET', () {
      expect(
        itemTrueRenderBias(count: 1, isBlockItem: false),
        closeTo(
          huiLineHeight + huiItemDisplayOffset + huiSingleItemCountOffset,
          1e-12,
        ),
      );
      expect(
        itemTrueRenderBias(count: 4, isBlockItem: false),
        closeTo(huiLineHeight + huiItemDisplayOffset, 1e-12),
      );
      expect(
        itemTrueRenderBias(count: 1, isBlockItem: true),
        closeTo(huiBlockDisplayOffset, 1e-12),
      );
    });
  });

  group('anchor to plane and anchor to visual', () {
    test('single-line text plants the plane on the visible glyphs', () {
      final CanvasItem item = _only(HuiTextIcon('ONE'));
      expect(_planeDrop(item), closeTo(huiTextTrueRenderBias, 1e-12));
      expect(_visualDrop(item), closeTo(huiTextTrueRenderBias, 1e-12));
      expect(item.hitbox.y, closeTo(item.visual.y, 1e-12));
      expect(item.hitbox.h, closeTo(huiLineHeight, 1e-12));
      expect(item.visual.h, closeTo(huiLineHeight, 1e-12));
    });

    test('multi-line text keeps the same drop and grows both boxes', () {
      final CanvasItem item = _only(HuiTextIcon('AA\nBB\nCC'));
      expect(_planeDrop(item), closeTo(huiTextTrueRenderBias, 1e-12));
      expect(_visualDrop(item), closeTo(huiTextTrueRenderBias, 1e-12));
      expect(item.hitbox.y, closeTo(item.visual.y, 1e-12));
      expect(item.hitbox.h, closeTo(3 * huiLineHeight, 1e-12));
      expect(item.visual.h, closeTo(3 * huiLineHeight, 1e-12));
    });

    test('an image uses the text bias', () {
      // No image library, so the icon resolves to the 8x8 missing placeholder,
      // which is the image geometry path.
      final CanvasItem item = _only(HuiTextImageIcon('nope.png'));
      expect(item.shape.kind, IconShapeKind.image);
      expect(_planeDrop(item), closeTo(huiTextTrueRenderBias, 1e-12));
      expect(_visualDrop(item), closeTo(huiTextTrueRenderBias, 1e-12));
    });

    test('a plain item drops the item bias and its plane drops 0.05', () {
      final CanvasItem item = _only(HuiItemIcon('diamond_sword'));
      expect(item.shape.isBlockItem, isFalse);
      expect(_planeDrop(item), closeTo(huiItemHitboxDrop, 1e-12));
      expect(
        _visualDrop(item),
        closeTo(itemTrueRenderBias(count: 1, isBlockItem: false), 1e-12),
      );
    });

    test('a stack of more than one loses the single-count nudge', () {
      final CanvasItem item = _only(HuiItemIcon('diamond_sword', 12));
      expect(
        _visualDrop(item),
        closeTo(itemTrueRenderBias(count: 12, isBlockItem: false), 1e-12),
      );
      expect(_planeDrop(item), closeTo(huiItemHitboxDrop, 1e-12));
    });

    test('a block-like item hangs less far down', () {
      final CanvasItem item = _only(HuiItemIcon('stone', 12));
      expect(item.shape.isBlockItem, isTrue);
      expect(_visualDrop(item), closeTo(huiBlockDisplayOffset, 1e-12));
    });

    test('uiScale multiplies every drop', () {
      final CanvasItem item = _only(HuiTextIcon('ONE'), uiScale: 2);
      expect(_planeDrop(item), closeTo(huiTextTrueRenderBias * 2, 1e-12));
      expect(_visualDrop(item), closeTo(huiTextTrueRenderBias * 2, 1e-12));
    });

    test(
      'custom size changes dimensions without separating text and plane',
      () {
        final HuiComponent button = HuiComponent(
          'a',
          Vec3(0, 0, 0),
          HuiButtonData(
            0,
            <HuiAction>[],
            HuiTextIcon('ONE'),
            HuiHitbox(1.25, 0.35),
          ),
        );
        final CanvasItem item = _scene(<HuiComponent>[
          button,
        ], uiScale: 2).items.single;
        expect(item.hitbox.w, closeTo(2.5, 1e-12));
        expect(item.hitbox.h, closeTo(0.7, 1e-12));
        expect(item.hitbox.y, closeTo(item.visual.y, 1e-12));
      },
    );
  });

  group('the drawn stack agrees with the visual box', () {
    // The 2D painter draws each line at `textLineCenterY`; the sprite the 3D
    // stage blits is a viewport centred on `visual`. If the centroid of the
    // one is not the centre of the other the two views disagree about the
    // same document.
    for (final int lines in <int>[1, 2, 3, 8]) {
      test('$lines line(s) centre on the visual box', () {
        double sum = 0;
        for (int i = 0; i < lines; i++) {
          sum += textLineCenterY(
            anchorY: 4,
            uiScale: 1.5,
            lineIndex: i,
            lineCount: lines,
            trueRender: true,
          );
        }
        expect(
          sum / lines,
          closeTo(
            visualBoundsAt(
              anchorX: 0,
              anchorY: 4,
              uiScale: 1.5,
              shape: IconShape.text(lines: lines, maxLineChars: 3),
              trueRender: true,
            ).y,
            1e-12,
          ),
        );
      });
    }
  });

  group('spriteExtentFor', () {
    test(
      'is relative to the anchor, so a shared bitmap carries no position',
      () {
        final CanvasScene scene = _scene(<HuiComponent>[
          HuiComponent(
            'left',
            Vec3(-2, 1, 0),
            HuiButtonData(0, <HuiAction>[], HuiTextIcon('SAME')),
          ),
          HuiComponent(
            'right',
            Vec3(3, -1, 0),
            HuiButtonData(0, <HuiAction>[], HuiTextIcon('SAME')),
          ),
        ]);
        final HuiRect a = spriteExtentFor(
          scene.items[0],
          uiScale: 1,
          trueRender: true,
        );
        final HuiRect b = spriteExtentFor(
          scene.items[1],
          uiScale: 1,
          trueRender: true,
        );
        expect(a.x, closeTo(b.x, 1e-12));
        expect(a.y, closeTo(b.y, 1e-12));
        expect(a.w, closeTo(b.w, 1e-12));
        expect(a.h, closeTo(b.h, 1e-12));
      },
    );

    test('centres on the drawn box and only pads around it', () {
      final CanvasItem item = _only(HuiTextIcon('ONE'));
      final HuiRect extent = spriteExtentFor(
        item,
        uiScale: 1,
        trueRender: true,
      );
      expect(extent.x, closeTo(item.visual.x - item.anchor.x, 1e-12));
      expect(extent.y, closeTo(item.visual.y - item.anchor.y, 1e-12));
      expect(
        extent.w,
        closeTo(
          item.visual.w * (1 + 2 * huiSpritePadFractionX) +
              2 * huiSpritePadBlocks,
          1e-12,
        ),
      );
      expect(
        extent.h,
        closeTo(
          item.visual.h * (1 + 2 * huiSpritePadFractionY) +
              2 * huiSpritePadBlocks,
          1e-12,
        ),
      );
    });

    test('a stack of more than one grows down to swallow the count label', () {
      // `ItemMenuIcon` spawns a second text display under a stack of more than
      // one (`ItemMenuIcon.java:91-94,142-149`), so the bitmap is the UNION of
      // the icon and that label — which is deliberately not the visual centre.
      final CanvasItem item = _only(HuiItemIcon('stone', 12));
      final HuiRect label = HuiRect(
        x: 0,
        y: itemCountLabelY(anchorY: 0, uiScale: 1),
        w: 0,
        h: huiLineHeight * 2,
      );
      final double top = math.max(item.visual.top - item.anchor.y, label.top);
      final double bottom = math.min(
        item.visual.bottom - item.anchor.y,
        label.bottom,
      );
      final double padY =
          (top - bottom) * huiSpritePadFractionY + huiSpritePadBlocks;
      final HuiRect extent = spriteExtentFor(
        item,
        uiScale: 1,
        trueRender: true,
      );
      expect(extent.y, closeTo((top + bottom) / 2, 1e-12));
      expect(extent.h, closeTo(top - bottom + 2 * padY, 1e-12));
      // Sanity: the label really does move the centre off the icon's own.
      expect(extent.y, isNot(closeTo(item.visual.y - item.anchor.y, 1e-3)));
    });

    test('a single item is not grown at all', () {
      final CanvasItem item = _only(HuiItemIcon('stone'));
      final HuiRect extent = spriteExtentFor(
        item,
        uiScale: 1,
        trueRender: true,
      );
      expect(extent.y, closeTo(item.visual.y - item.anchor.y, 1e-12));
    });

    test('an icon that draws nothing gets no bitmap', () {
      // An empty text icon parses to a zero-width stack and its plane is zero
      // width too, so there is nothing to rasterize and nothing to place.
      final CanvasItem item = _only(HuiTextIcon(''));
      expect(item.outline.w, 0);
      expect(spriteExtentFor(item, uiScale: 1, trueRender: true), HuiRect.zero);
    });
  });

  group('the 3D scene reports the same relationship the canvas measured', () {
    test(
      'every quad carries its item\'s own anchor, plane and visual gaps',
      () {
        final HuiMenu menu = HuiMenu(
          offset: Vec3(0, 1.5, 2.5),
          components: <HuiComponent>[
            _button('text', HuiTextIcon('ONE')),
            HuiComponent(
              'item',
              Vec3(1, 0, 0),
              HuiButtonData(0, <HuiAction>[], HuiItemIcon('diamond_sword')),
            ),
          ],
        );
        final CanvasScene canvas = buildCanvasScene(
          menu: menu,
          uiScale: 1,
          trueRender: true,
          togglePreview: (String _) => true,
          textCache: McTextCache(),
        );
        final PreviewScene preview = buildPreviewScene(
          menu: menu,
          uiScale: 1,
          openFeet: PVec3.zero,
          openYawDeg: 0,
          canvas: canvas,
        );

        for (int i = 0; i < canvas.items.length; i++) {
          final CanvasItem item = canvas.items[i];
          final PreviewQuad quad = preview.quads[i];
          expect(
            quad.anchor.y - quad.planeCenter.y,
            closeTo(_planeDrop(item), 1e-12),
          );
          expect(
            quad.anchor.y - quad.visualCenter.y,
            closeTo(_visualDrop(item), 1e-12),
          );
        }
      },
    );
  });
}
