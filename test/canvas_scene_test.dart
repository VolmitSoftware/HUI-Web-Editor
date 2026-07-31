/// VM coverage for the DOM-free half of the canvas: how an image's collision
/// plane is measured, and which component a click resolves to.
library;

import 'package:holoui_editor/components/canvas/canvas_scene.dart';
import 'package:holoui_editor/logic/hui_geometry.dart';
import 'package:holoui_editor/logic/viewport_math.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/services/catalogs.dart';
import 'package:holoui_editor/services/image_library.dart';
import 'package:test/test.dart';

/// [rows] is one string per pixel row: `#` opaque, `.` fully transparent,
/// `~` half transparent (which the plugin also blanks).
ImagePixels _pixels(List<String> rows) => ImagePixels(
      width: rows.isEmpty ? 0 : rows.first.length,
      height: rows.length,
      rows: <List<int>>[
        for (final String row in rows)
          <int>[
            for (int x = 0; x < row.length; x++)
              switch (row[x]) {
                '#' => 0xFFFF0000,
                '~' => 0x80FF0000,
                _ => 0x00000000,
              },
          ],
      ],
    );

CanvasItem _item({
  required String id,
  required int index,
  required HuiRect hitbox,
  required HuiRect visual,
}) =>
    CanvasItem(
      component: HuiComponent(id, Vec3(0, 0, 0), HuiButtonData()),
      index: index,
      kind: CanvasIconKind.text,
      shape: const IconShape.text(lines: 1, maxLineChars: 4),
      anchor: WorldPoint(hitbox.x, hitbox.y),
      depth: 0,
      hitbox: hitbox,
      visual: visual,
      clickable: true,
      isToggle: false,
      toggleShowsTrue: false,
    );

CanvasScene _scene(List<CanvasItem> items) => CanvasScene(
      items: items,
      // Equal depth, so the draw order is declaration order.
      drawOrder: List<CanvasItem>.of(items),
      overlaps: const <CanvasOverlap>[],
      menuOffset: Vec3(0, 0, 0),
      uiScale: 1,
      trueRender: true,
    );

void main() {
  group('imageRowChars', () {
    test('counts one character per opaque pixel', () {
      expect(imageRowChars(_pixels(<String>['####'])), 4);
    });

    test('counts two characters per fully transparent pixel', () {
      // The plugin emits a bold space AND a space, and TextUtils.content
      // concatenates both children.
      expect(imageRowChars(_pixels(<String>['....'])), 8);
    });

    test('counts a partially transparent pixel as transparent', () {
      expect(imageRowChars(_pixels(<String>['~~~~'])), 8);
    });

    test('takes the widest row of a mixed image', () {
      expect(
        imageRowChars(_pixels(<String>['####', '##..', '....'])),
        8,
      );
    });

    test('measures an eight opaque plus eight transparent row as 24', () {
      expect(imageRowChars(_pixels(<String>['########........'])), 24);
    });

    test('is zero for an empty grid', () {
      expect(imageRowChars(_pixels(const <String>[])), 0);
    });
  });

  group('image collision plane width', () {
    test('is char count times half a line height, not pixel count', () {
      const double lineHeight = huiLineHeight;
      final int chars = imageRowChars(_pixels(<String>['########........']));
      final HuiRect plane = hitboxAt(
        anchorX: 0,
        anchorY: 0,
        uiScale: 1,
        shape: IconShape.image(rows: 1, columns: chars),
      );
      expect(plane.w, closeTo(24 * lineHeight / 2, 1e-9));
      // The pixel-width reading it replaces was 33% too narrow.
      expect(plane.w, greaterThan(16 * lineHeight / 2));
    });

    test('doubles for a fully transparent row', () {
      final int chars = imageRowChars(_pixels(<String>['........']));
      expect(chars, 16);
    });
  });

  group('ImageCharCache', () {
    test('returns the same count on a repeat lookup', () {
      final ImageCharCache cache = ImageCharCache();
      final ImagePixels pixels = _pixels(<String>['##..']);
      expect(cache.maxRowChars('a.png', pixels), 6);
      expect(cache.maxRowChars('a.png', pixels), 6);
    });

    test('keys on the grid size so a resized upload is re-measured', () {
      final ImageCharCache cache = ImageCharCache();
      expect(cache.maxRowChars('a.png', _pixels(<String>['##'])), 2);
      expect(cache.maxRowChars('a.png', _pixels(<String>['....'])), 8);
    });

    test('forgets everything after a clear', () {
      final ImageCharCache cache = ImageCharCache();
      expect(cache.maxRowChars('a.png', _pixels(<String>['##'])), 2);
      cache.clear();
      expect(cache.maxRowChars('a.png', _pixels(<String>['##'])), 2);
    });
  });

  group('CanvasScene.hitTest', () {
    test('picks the component whose drawn icon is under the cursor', () {
      // True-render geometry: each plane sits on the anchor while the icon
      // draws a block below it, so the two union regions overlap heavily.
      final CanvasItem above = _item(
        id: 'above',
        index: 0,
        hitbox: const HuiRect(x: 0, y: 1.45, w: 0.5, h: 0.75),
        visual: const HuiRect(x: 0, y: 0.19, w: 0.5, h: 0.75),
      );
      final CanvasItem below = _item(
        id: 'below',
        index: 1,
        hitbox: const HuiRect(x: 0, y: 0.95, w: 0.5, h: 0.75),
        visual: const HuiRect(x: 0, y: -0.31, w: 0.5, h: 0.75),
      );
      final CanvasScene scene = _scene(<CanvasItem>[above, below]);

      // Dead centre of the first component's drawn sprite. The union regions
      // of both components contain it; only one was actually drawn there.
      expect(scene.hitTest(0, 0.19)?.id, 'above');
      expect(scene.hitTest(0, -0.31)?.id, 'below');
    });

    test('falls back to the collision plane when nothing was drawn there', () {
      final CanvasItem item = _item(
        id: 'only',
        index: 0,
        hitbox: const HuiRect(x: 0, y: 1.45, w: 0.5, h: 0.75),
        visual: const HuiRect(x: 0, y: 0.19, w: 0.5, h: 0.75),
      );
      final CanvasScene scene = _scene(<CanvasItem>[item]);
      // On the plane, well above the drawn icon.
      expect(scene.hitTest(0, 1.45)?.id, 'only');
      // In the gap between the two.
      expect(scene.hitTest(0, 0.8)?.id, 'only');
    });

    test('breaks a tie on the drawn icon toward the last declared', () {
      const HuiRect box = HuiRect(x: 0, y: 0, w: 1, h: 1);
      final CanvasScene scene = _scene(<CanvasItem>[
        _item(id: 'first', index: 0, hitbox: box, visual: box),
        _item(id: 'second', index: 1, hitbox: box, visual: box),
      ]);
      expect(scene.hitTest(0, 0)?.id, 'second');
    });

    test('returns null outside everything', () {
      final CanvasScene scene = _scene(<CanvasItem>[
        _item(
          id: 'only',
          index: 0,
          hitbox: const HuiRect(x: 0, y: 0, w: 1, h: 1),
          visual: const HuiRect(x: 0, y: 0, w: 1, h: 1),
        ),
      ]);
      expect(scene.hitTest(9, 9), isNull);
    });
  });

  group('custom item icons', () {
    final HuiCatalogs catalogs = HuiCatalogs.build(
      materials: const <MaterialEntry>[
        MaterialEntry('diamond', 'data:image/png;base64,ZGlhbW9uZA=='),
      ],
      sounds: const <String>[],
      loaded: true,
      customItems: HuiCustomItemCatalog.parse(
        '{"items":[{"provider":"itemsadder","id":"myitems:ruby",'
        '"name":"Ruby","material":"diamond"},'
        '{"provider":"mmoitems","id":"SWORD:CUTLASS"}]}',
      ),
    );

    CanvasItem build(HuiIcon icon, {HuiCatalogs? withCatalogs}) =>
        buildCanvasScene(
          menu: HuiMenu(
            offset: Vec3(0, 1.7, 2.5),
            components: <HuiComponent>[
              HuiComponent('a', Vec3(0, 0, 0), HuiDecorationData(icon)),
            ],
          ),
          uiScale: 1,
          trueRender: true,
          togglePreview: (String _) => true,
          textCache: McTextCache(),
          catalogs: withCatalogs,
        ).items.single;

    test('measures exactly like the vanilla item icon it mirrors', () {
      final CanvasItem custom = build(
        HuiCustomItemIcon('itemsadder', 'myitems:ruby', 3),
        withCatalogs: catalogs,
      );
      final CanvasItem vanilla = build(
        HuiItemIcon('diamond', 3, 0),
        withCatalogs: catalogs,
      );
      expect(custom.kind, CanvasIconKind.customItem);
      expect(custom.shape, vanilla.shape);
      expect(custom.hitbox, vanilla.hitbox);
      expect(custom.visual, vanilla.visual);
      expect(custom.itemCount, 3);
    });

    test('draws the catalog material sprite when the id is known', () {
      final CanvasItem item = build(
        HuiCustomItemIcon('itemsadder', 'myitems:ruby', 1),
        withCatalogs: catalogs,
      );
      expect(item.itemTexture, 'data:image/png;base64,ZGlhbW9uZA==');
      expect(item.itemKey, 'myitems:ruby');
      expect(item.itemProvider, 'itemsadder');
    });

    test('falls back to a labelled placeholder for an unknown id', () {
      final CanvasItem item = build(
        HuiCustomItemIcon('nexo', 'ruby_sword', 1),
        withCatalogs: catalogs,
      );
      expect(item.kind, CanvasIconKind.customItem);
      expect(item.itemTexture, isNull);
      // The label is the id, verbatim: it is what the user typed.
      expect(item.itemKey, 'ruby_sword');
      expect(item.itemProvider, 'nexo');
    });

    test('keeps the id case a case-sensitive provider needs', () {
      final CanvasItem item = build(
        HuiCustomItemIcon('mmoitems', 'SWORD:CUTLASS', 1),
        withCatalogs: catalogs,
      );
      expect(item.itemKey, 'SWORD:CUTLASS');
    });

    test('renders without a catalog at all', () {
      final CanvasItem item =
          build(HuiCustomItemIcon('auto', 'myitems:ruby', 1));
      expect(item.kind, CanvasIconKind.customItem);
      expect(item.itemTexture, isNull);
    });

    test('a blank id falls back to the missing-icon placeholder', () {
      final CanvasItem item = build(HuiCustomItemIcon('auto', '  ', 1));
      expect(item.kind, CanvasIconKind.missing);
    });
  });
}
