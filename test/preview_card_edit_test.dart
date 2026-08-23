/// The DOM-free half of the pixel-space card editor: the screen mapping, the
/// hit model, and every write the pointer is allowed to make.
///
/// Everything the canvas surface does that does NOT need a `<canvas>` lives in
/// `lib/logic/preview_card_edit.dart` and is exercised here on the VM. The
/// imperative surface itself is browser-verified in E9.
library;

import 'dart:io';

import 'package:gloss_editor/logic/mc_text.dart';
import 'package:gloss_editor/logic/preview_card_edit.dart';
import 'package:gloss_editor/logic/preview_card_scene.dart';
import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

PreviewCardScene _build(HuiPreviewDoc doc, [String category = 'statics']) =>
    buildCardScene(doc, PreviewSim(category));

HuiPreviewElement _cell(Object? x, Object? y, Object? size) =>
    HuiPreviewElement('cell', x: x, y: y, size: size, color: '#FF00FF00');

void main() {
  group('scene provenance', () {
    test('every item names the element that emitted it', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          _cell(0, 0, 8),
          HuiPreviewElement(
            'cell',
            x: 'i * 10',
            y: 20,
            size: 6,
            color: '#FFFFFFFF',
            repeat: HuiPreviewRepeat(count: 3),
          ),
        ],
      );
      final PreviewCardScene scene = _build(doc);
      expect(scene.sources, <int>[0, 1, 1, 1]);
      expect(scene.sources.length, scene.items.length);
    });

    test('card chrome is not owned by any element', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(),
        elements: <HuiPreviewElement>[_cell(0, 0, 8)],
      );
      final PreviewCardScene scene = _build(doc);
      // frame, panel, tray, title bar, title label, then the cell.
      expect(scene.sources, <int>[-1, -1, -1, -1, -1, 0]);
      expect(previewElementIndexOf(scene, 0), -1);
      expect(previewElementIndexOf(scene, 5), 0);
    });

    test('an element that fails to build claims no items', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          _cell(0, 0, null), // size is required
          _cell(4, 4, 8),
        ],
      );
      final PreviewCardScene scene = _build(doc);
      expect(scene.items, hasLength(1));
      expect(scene.sources, <int>[1]);
    });

    test('all instances of one repeat resolve back to the template', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            x: 'i * 10',
            y: 0,
            size: 6,
            color: '#FFFFFFFF',
            repeat: HuiPreviewRepeat(count: 4),
          ),
        ],
      );
      final PreviewCardScene scene = _build(doc);
      expect(previewItemsForElement(scene, 0), <int>[0, 1, 2, 3]);
    });
  });

  group('PreviewCardView', () {
    const PreviewCardView view = PreviewCardView(
      widthPx: 400,
      heightPx: 200,
      zoom: 4,
    );

    test('maps the card origin to the centre of the surface', () {
      expect(view.toScreenX(0), 200);
      expect(view.toScreenY(0), 100);
    });

    test('card y grows upwards while screen y grows down', () {
      expect(view.toScreenY(10), 60);
      expect(view.toCardY(60), 10);
    });

    test('screen and card coordinates round-trip', () {
      expect(view.toCardX(view.toScreenX(-13)), closeTo(-13, 1e-9));
      expect(view.toCardY(view.toScreenY(27)), closeTo(27, 1e-9));
    });

    test('panning moves the origin in screen pixels', () {
      final PreviewCardView panned = view.pannedBy(30, -10);
      expect(panned.toScreenX(0), 230);
      expect(panned.toScreenY(0), 90);
    });

    test('zooming at a point keeps that point under the pointer', () {
      final PreviewCardView zoomed = view.zoomedAt(
        8,
        screenX: 310,
        screenY: 40,
      );
      expect(zoomed.zoom, 8);
      expect(zoomed.toCardX(310), closeTo(view.toCardX(310), 1e-9));
      expect(zoomed.toCardY(40), closeTo(view.toCardY(40), 1e-9));
    });

    test('zoom steps walk the integer stops and stop at the ends', () {
      expect(previewZoomIn(4), 6);
      expect(previewZoomOut(4), 3);
      expect(previewZoomIn(previewZoomStops.last), previewZoomStops.last);
      expect(previewZoomOut(previewZoomStops.first), previewZoomStops.first);
      expect(previewClampZoom(0), previewZoomStops.first);
      expect(previewClampZoom(9999), previewZoomStops.last);
    });

    test('a fit frames the content and centres it', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[_cell(0, 0, 20)],
      );
      final PreviewCardScene scene = _build(doc);
      final PreviewBox bounds = previewSceneBounds(scene)!;
      expect(bounds.width, 20);
      final PreviewCardView fitted = view.fittedTo(bounds, paddingPx: 20);
      // 20 card px into 160 usable px is 8x; the 12x stop would overflow.
      expect(fitted.zoom, 8);
      expect(fitted.toScreenX(bounds.centerX), closeTo(200, 1e-9));
      expect(fitted.toScreenY(bounds.centerY), closeTo(100, 1e-9));
    });

    test('a fit with nothing to frame keeps the surface at rest', () {
      final PreviewCardView fitted = view.fittedTo(null);
      expect(fitted.zoom, previewDefaultZoom);
      expect(fitted.panX, 0);
      expect(fitted.panY, 0);
    });
  });

  group('item boxes', () {
    test('a cell is its size, centred on its position', () {
      final PreviewBox box = previewItemBox(const CardCell(4, -6, 4, 8, 0));
      expect(box.left, 0);
      expect(box.right, 8);
      expect(box.bottom, -10);
      expect(box.top, -2);
    });

    test('a panel is its width and height', () {
      final PreviewBox box = previewItemBox(
        const CardPanel(0, 0, 1, 100, 40, 0),
      );
      expect(box.width, 100);
      expect(box.height, 40);
    });

    test('a label is measured from its runs when nothing measured it', () {
      final PreviewBox box = previewItemBox(
        const CardLabel(0, 0, 6, <McSpan>[McSpan(text: 'abcd')], 0),
      );
      expect(box.width, 4 * previewGlyphAdvancePx);
      expect(box.height, previewLabelLineHeightPx);
    });

    test('a bold run is one pixel wider per glyph, like the font', () {
      final PreviewBox box = previewItemBox(
        const CardLabel(0, 0, 6, <McSpan>[McSpan(text: 'ab', bold: true)], 0),
      );
      expect(box.width, 2 * (previewGlyphAdvancePx + 1));
    });

    test('a measured width wins over the nominal one', () {
      final PreviewBox box = previewItemBox(
        const CardLabel(0, 0, 6, <McSpan>[McSpan(text: 'abcd')], 0),
        labelWidth: 51,
      );
      expect(box.width, 51);
    });

    test('an empty label still has a grabbable width', () {
      final PreviewBox box = previewItemBox(
        const CardLabel(0, 0, 6, <McSpan>[], 0),
      );
      expect(box.width, previewGlyphAdvancePx);
    });
  });

  group('hit testing', () {
    test('the topmost item by z wins, not the last declared', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            x: 0,
            y: 0,
            z: 9,
            size: 20,
            color: '#FF00FF00',
          ),
          HuiPreviewElement(
            'cell',
            x: 0,
            y: 0,
            z: 2,
            size: 20,
            color: '#FFFF0000',
          ),
        ],
      );
      final PreviewCardScene scene = _build(doc);
      expect(previewHitTestItem(scene, 0, 0), 0);
    });

    test('a miss returns null', () {
      final PreviewCardScene scene = _build(
        HuiPreviewDoc(elements: <HuiPreviewElement>[_cell(0, 0, 8)]),
      );
      expect(previewHitTestItem(scene, 40, 40), isNull);
    });

    test('card chrome is not selectable', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(),
        elements: <HuiPreviewElement>[_cell(0, 0, 8)],
      );
      final PreviewCardScene scene = _build(doc);
      // Well inside the panel, well outside the one cell.
      expect(previewHitTestItem(scene, 60, 0), isNull);
      expect(previewHitTestItem(scene, 0, 0), 5);
    });

    test('a click resolves to the element that owns the item', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          _cell(-20, 0, 8),
          HuiPreviewElement(
            'cell',
            x: 'i * 12',
            y: 0,
            size: 8,
            color: '#FFFFFFFF',
            repeat: HuiPreviewRepeat(count: 3),
          ),
        ],
      );
      final PreviewCardScene scene = _build(doc);
      final int? hit = previewHitTestItem(scene, 12, 0);
      expect(hit, isNotNull);
      expect(previewElementIndexOf(scene, hit!), 1);
    });
  });

  group('move writes', () {
    test('constant and absent coordinates may be dragged', () {
      expect(previewMoveRefusal(_cell(3, 4, 8)), isNull);
      expect(previewMoveRefusal(_cell(null, null, 8)), isNull);
    });

    test('an expression-positioned element refuses the drag', () {
      expect(
        previewMoveRefusal(_cell('i * 10', 0, 8)),
        previewExpressionMoveHint,
      );
      expect(
        previewMoveRefusal(_cell(0, 'time', 8)),
        previewExpressionMoveHint,
      );
    });

    test('a move lands on whole pixels', () {
      final PreviewPoint moved = previewMoveTarget(
        _cell(10, -4, 8),
        dxCard: 3.4,
        dyCard: -2.6,
      );
      expect(moved.x, 13);
      expect(moved.y, -7);
    });

    test('an absent coordinate moves from the format default of zero', () {
      final PreviewPoint moved = previewMoveTarget(
        _cell(null, null, 8),
        dxCard: -5.2,
        dyCard: 9.7,
      );
      expect(moved.x, -5);
      expect(moved.y, 10);
    });

    test('a pointer drag resolves the whole travel from where it started', () {
      const PreviewPoint start = PreviewPoint(10, 10);
      // Ten frames of a third of a pixel each: measured from the start this is
      // one clean move, where per-frame deltas would round to nothing ten
      // times over.
      expect(
        previewMoveFrom(start, dxCard: 3.3, dyCard: -3.3),
        const PreviewPoint(13, 7),
      );
    });

    test('a nudge is a move by whole pixels', () {
      final PreviewPoint nudged = previewMoveTarget(
        _cell(2, 2, 8),
        dxCard: -1,
        dyCard: 0,
      );
      expect(nudged.x, 1);
      expect(nudged.y, 2);
    });
  });

  group('resize writes', () {
    test('a constant-size cell may be resized', () {
      expect(previewResizeRefusal(_cell(0, 0, 8)), isNull);
    });

    test('an expression size refuses', () {
      expect(
        previewResizeRefusal(_cell(0, 0, 'vars.size')),
        previewExpressionResizeHint,
      );
    });

    test('a label has no resizable extent', () {
      expect(
        previewResizeRefusal(HuiPreviewElement('label', text: "'hi'")),
        previewNoResizeHint,
      );
    });

    test('a panel resizes from the corner opposite the handle', () {
      final HuiPreviewElement panel = HuiPreviewElement(
        'panel',
        x: 0,
        y: 0,
        width: 40,
        height: 20,
        color: '#FF000000',
      );
      final PreviewResize? resized = previewResizeTarget(
        element: panel,
        box: const PreviewBox(left: -20, bottom: -10, right: 20, top: 10),
        handle: PreviewHandle.topRight,
        cardX: 30,
        cardY: 16,
      );
      expect(resized, isNotNull);
      // The bottom-left corner (-20, -10) is pinned.
      expect(resized!.width, 50);
      expect(resized.height, 26);
      expect(resized.x, 5);
      expect(resized.y, 3);
      expect(resized.size, isNull);
    });

    test('a cell stays square and takes the larger of the two deltas', () {
      final PreviewResize? resized = previewResizeTarget(
        element: _cell(0, 0, 8),
        box: const PreviewBox(left: -4, bottom: -4, right: 4, top: 4),
        handle: PreviewHandle.bottomLeft,
        cardX: -10,
        cardY: -6,
      );
      expect(resized!.size, 14);
      expect(resized.width, isNull);
      // The top-right corner (4, 4) is pinned.
      expect(resized.x, -3);
      expect(resized.y, -3);
    });

    test('a resize never collapses below one pixel', () {
      final PreviewResize? resized = previewResizeTarget(
        element: _cell(0, 0, 8),
        box: const PreviewBox(left: -4, bottom: -4, right: 4, top: 4),
        handle: PreviewHandle.topLeft,
        cardX: 4,
        cardY: -4,
      );
      expect(resized!.size, 1);
    });

    test('a refused element resolves to no resize at all', () {
      expect(
        previewResizeTarget(
          element: _cell(0, 0, 'vars.size'),
          box: const PreviewBox(left: -4, bottom: -4, right: 4, top: 4),
          handle: PreviewHandle.topLeft,
          cardX: 10,
          cardY: 10,
        ),
        isNull,
      );
    });

    test('handles sit on the corners of the box', () {
      final List<PreviewHandleSpot> spots = previewHandleSpots(
        const PreviewBox(left: -4, bottom: -6, right: 4, top: 6),
      );
      expect(spots, hasLength(4));
      final PreviewHandleSpot topLeft = spots.firstWhere(
        (PreviewHandleSpot s) => s.handle == PreviewHandle.topLeft,
      );
      expect(topLeft.x, -4);
      expect(topLeft.y, 6);
    });
  });

  group('the animation gate', () {
    test('a document of constants is not animated', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(title: "'&fChest'"),
        elements: <HuiPreviewElement>[
          _cell(0, 0, 8),
          HuiPreviewElement(
            'label',
            x: 0,
            y: -20,
            text: "'&7' + inventory.occupied + ' full'",
          ),
        ],
      );
      expect(previewDocIsAnimated(doc), isFalse);
    });

    test('a cell colour driven by the clock is animated', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            x: 0,
            y: 0,
            size: 8,
            color: 'mod(floor(time / 20), 2) == 0 ? #FF00FF00 : #FF008800',
          ),
        ],
      );
      expect(previewDocIsAnimated(doc), isTrue);
    });

    test('a total that never moves does not start the clock', () {
      // `cookTimeTotal` is fixed for the category, and matching it as a whole
      // word is what keeps `time` and `cookTime` from firing inside it.
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            x: 0,
            y: 0,
            size: 'cookTimeTotal / 20',
            color: '#FF00FF00',
          ),
        ],
      );
      expect(previewDocIsAnimated(doc), isFalse);
    });

    test('a repeat count and a card field are both scanned', () {
      expect(
        previewDocIsAnimated(
          HuiPreviewDoc(
            elements: <HuiPreviewElement>[
              HuiPreviewElement(
                'cell',
                x: 0,
                y: 0,
                size: 4,
                color: '#FF00FF00',
                repeat: HuiPreviewRepeat(count: 'floor(burnTime / 100)'),
              ),
            ],
          ),
        ),
        isTrue,
      );
      expect(
        previewDocIsAnimated(
          HuiPreviewDoc(
            card: HuiPreviewCard(title: "'up ' + round(time) + 's'"),
          ),
        ),
        isTrue,
      );
    });

    test('the shipped furnace document animates', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(
        File('test/fixtures/previews/furnace.json').readAsStringSync(),
      );
      expect(previewDocIsAnimated(doc), isTrue);
    });

    test('the shipped locked document does not', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc(
        File('test/fixtures/previews/locked.json').readAsStringSync(),
      );
      expect(previewDocIsAnimated(doc), isFalse);
    });
  });

  group('simulated category for a document', () {
    test('a furnace document simulates a furnace', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(
          blocks: <String>['FURNACE', 'BLAST_FURNACE', 'SMOKER'],
        ),
      );
      expect(previewAutoSimCategory(doc), 'furnace');
    });

    test('a locked document has no target at all', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(special: 'locked'),
      );
      expect(previewAutoSimCategory(doc), 'statics');
    });

    test('an ender-chest document simulates the viewer inventory', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(
          blocks: <String>['ENDER_CHEST'],
          special: 'enderChest',
        ),
      );
      expect(previewAutoSimCategory(doc), 'enderChest');
    });

    test('an any-inventory-holder document simulates an entity', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(
          entities: <String>['CHEST_MINECART'],
          special: 'anyInventoryHolder',
        ),
      );
      expect(previewAutoSimCategory(doc), 'entity');
    });

    test('an entity document simulates an entity', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(entities: <String>['HOPPER_MINECART']),
      );
      expect(previewAutoSimCategory(doc), 'entity');
    });

    test('a furnace minecart document uses its powered simulation', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(entities: <String>['FURNACE_MINECART']),
      );
      expect(previewAutoSimCategory(doc), 'poweredMinecart');
    });

    test('a plain container falls back to a chest', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(blocks: <String>['BARREL']),
      );
      expect(previewAutoSimCategory(doc), 'chest');
    });

    test('a bare document with no match is static', () {
      expect(previewAutoSimCategory(HuiPreviewDoc()), 'statics');
    });

    test('every mapped category is one the simulation actually publishes', () {
      for (final String blocks in <String>[
        'FURNACE',
        'BREWING_STAND',
        'BEEHIVE',
        'WATER_CAULDRON',
        'JUKEBOX',
        'ENDER_CHEST',
        'BARREL',
      ]) {
        final HuiPreviewDoc doc = HuiPreviewDoc(
          match: HuiPreviewMatch(blocks: <String>[blocks]),
        );
        expect(previewSimCategories, contains(previewAutoSimCategory(doc)));
      }
    });
  });
}
