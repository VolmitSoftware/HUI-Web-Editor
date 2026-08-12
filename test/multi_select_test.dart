/// VM coverage for the pure half of canvas multi-select: marquee hit-testing,
/// align, distribute, smart alignment guides and z-order.
///
/// Every expectation here is stated in world blocks and then inverted back
/// through the anchor math, because that inversion is the part that silently
/// breaks: the menu offset is NOT scaled by uiScale while component offsets
/// are (`HuiSettings.java:60-66`, `MenuComponent.java:50-60`).
library;

import 'package:holoui_editor/logic/canvas_scene.dart';
import 'package:holoui_editor/logic/hui_geometry.dart';
import 'package:holoui_editor/logic/multi_select.dart';
import 'package:holoui_editor/logic/viewport_math.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:test/test.dart';

/// A text-icon button. Text icons are the cleanest geometry to assert against:
/// the drawn box is `chars * 0.15 * uiScale` wide and `lines * 0.21875 *
/// uiScale` tall, centred on the anchor.
HuiComponent _text(
  String id,
  double x,
  double y, {
  double z = 0,
  String text = 'AB',
}) => HuiComponent(
  id,
  Vec3(x, y, z),
  HuiButtonData(0.05, <HuiAction>[], HuiTextIcon(text)),
);

CanvasScene _scene(
  List<HuiComponent> components, {
  double uiScale = 1,
  Vec3? menuOffset,
  bool trueRender = false,
}) => buildCanvasScene(
  menu: HuiMenu(offset: menuOffset ?? Vec3.zero(), components: components),
  uiScale: uiScale,
  trueRender: trueRender,
  togglePreview: (String id) => true,
  textCache: McTextCache(),
);

/// A synthetic item with an explicit drawn rect, for the guide and z-order
/// suites where the icon content is irrelevant.
CanvasItem _item({
  required String id,
  required int index,
  required HuiRect visual,
  Vec3? offset,
}) => CanvasItem(
  component: HuiComponent(id, offset ?? Vec3.zero(), HuiButtonData()),
  index: index,
  kind: CanvasIconKind.text,
  shape: const IconShape.text(lines: 1, maxLineChars: 2),
  anchor: WorldPoint(visual.x, visual.y),
  depth: (offset ?? Vec3.zero()).z,
  hitboxDepth: (offset ?? Vec3.zero()).z,
  hitbox: visual,
  visual: visual,
  clickable: true,
  isToggle: false,
  toggleShowsTrue: false,
);

void main() {
  group('idsInMarquee', () {
    test('returns every item the rubber band touches', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 1, 0),
        _text('c', 5, 0),
      ]);
      final Set<String> hit = idsInMarquee(
        scene,
        const HuiRect.fromEdges(left: -1, bottom: -1, right: 2, top: 1),
      );
      expect(hit, <String>{'a', 'b'});
    });

    test('is empty when the band misses everything', () {
      final CanvasScene scene = _scene(<HuiComponent>[_text('a', 0, 0)]);
      expect(
        idsInMarquee(
          scene,
          const HuiRect.fromEdges(left: 10, bottom: 10, right: 12, top: 12),
        ),
        isEmpty,
      );
    });

    test('touching edges count as a hit', () {
      // 'AAAA' at the origin draws across x in [-0.3, 0.3].
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0, text: 'AAAA'),
      ]);
      expect(
        idsInMarquee(
          scene,
          const HuiRect.fromEdges(
            left: 0.3,
            bottom: -0.05,
            right: 0.5,
            top: 0.05,
          ),
        ),
        <String>{'a'},
      );
      expect(
        idsInMarquee(
          scene,
          const HuiRect.fromEdges(
            left: 0.3001,
            bottom: -0.05,
            right: 0.5,
            top: 0.05,
          ),
        ),
        isEmpty,
      );
    });

    test('a zero-area band still picks what it lands on', () {
      final CanvasScene scene = _scene(<HuiComponent>[_text('a', 0, 0)]);
      expect(
        idsInMarquee(
          scene,
          const HuiRect.fromEdges(left: 0, bottom: 0, right: 0, top: 0),
        ),
        <String>{'a'},
      );
    });

    test('tests the drawn outline, not the collision plane', () {
      // 'AAAA' draws to x = 0.3 but its plane only reaches 4 * 0.21875 / 2 / 2
      // = 0.21875, so a band in the gap must still select it.
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0, text: 'AAAA'),
      ]);
      expect(
        idsInMarquee(
          scene,
          const HuiRect.fromEdges(
            left: 0.25,
            bottom: -0.05,
            right: 0.4,
            top: 0.05,
          ),
        ),
        <String>{'a'},
      );
    });
  });

  group('alignOffsets', () {
    // 'AB' spans 0.30 blocks, 'ABCD' spans 0.60, both one line tall.
    List<HuiComponent> pair() => <HuiComponent>[
      _text('a', 0, 0),
      _text('b', 1, 0, z: 0.13, text: 'ABCD'),
    ];

    test('left pulls every outline to the leftmost edge', () {
      final CanvasScene scene = _scene(pair());
      final Map<String, Vec3> out = alignOffsets(
        scene: scene,
        ids: <String>['a', 'b'],
        align: HuiAlign.left,
      );
      // a.left = -0.15 is the target; b is 0.30 wide so its centre lands at
      // -0.15 + 0.30 = 0.15.
      expect(out['a']!.x, closeTo(0, 1e-12));
      expect(out['b']!.x, closeTo(0.15, 1e-12));
    });

    test('right pushes every outline to the rightmost edge', () {
      final Map<String, Vec3> out = alignOffsets(
        scene: _scene(pair()),
        ids: <String>['a', 'b'],
        align: HuiAlign.right,
      );
      expect(out['a']!.x, closeTo(1.15, 1e-12));
      expect(out['b']!.x, closeTo(1, 1e-12));
    });

    test('centreX centres on the group bounding box', () {
      final Map<String, Vec3> out = alignOffsets(
        scene: _scene(pair()),
        ids: <String>['a', 'b'],
        align: HuiAlign.centerX,
      );
      // bbox spans [-0.15, 1.30]; its centre is 0.575.
      expect(out['a']!.x, closeTo(0.575, 1e-12));
      expect(out['b']!.x, closeTo(0.575, 1e-12));
    });

    test('top, middleY and bottom work on differing heights', () {
      final List<HuiComponent> tall = <HuiComponent>[
        _text('a', 0, 0),
        _text('b', 0, 1, text: 'A\nB'),
      ];
      // a: h 0.21875 centred on 0 -> [-0.109375, 0.109375]
      // b: h 0.43750 centred on 1 -> [ 0.781250, 1.218750]
      final Map<String, Vec3> top = alignOffsets(
        scene: _scene(tall),
        ids: <String>['a', 'b'],
        align: HuiAlign.top,
      );
      // 1.109375 rounded to the store's four decimals.
      expect(top['a']!.y, 1.1094);
      expect(top['b']!.y, closeTo(1, 1e-12));

      final Map<String, Vec3> bottom = alignOffsets(
        scene: _scene(tall),
        ids: <String>['a', 'b'],
        align: HuiAlign.bottom,
      );
      expect(bottom['a']!.y, closeTo(0, 1e-12));
      expect(bottom['b']!.y, 0.1094);

      final Map<String, Vec3> middle = alignOffsets(
        scene: _scene(tall),
        ids: <String>['a', 'b'],
        align: HuiAlign.middleY,
      );
      // bbox spans [-0.109375, 1.21875]; centre 0.5546875 -> 0.5547.
      expect(middle['a']!.y, 0.5547);
      expect(middle['b']!.y, 0.5547);
    });

    test('inverts uiScale and an unscaled menu offset', () {
      final CanvasScene scene = _scene(
        pair(),
        uiScale: 2,
        menuOffset: Vec3(0.5, 1, 3),
      );
      // a anchors at x 0.5 (half width 0.30) -> left 0.20.
      // b anchors at x 2.5 (half width 0.60) -> left 1.90.
      final Map<String, Vec3> out = alignOffsets(
        scene: scene,
        ids: <String>['a', 'b'],
        align: HuiAlign.left,
      );
      expect(out['a']!.x, closeTo(0, 1e-12));
      // target centre 0.80 -> (0.80 - 0.50) / 2.
      expect(out['b']!.x, closeTo(0.15, 1e-12));
    });

    test('never touches z, and leaves the off-axis coordinate alone', () {
      final Map<String, Vec3> out = alignOffsets(
        scene: _scene(pair()),
        ids: <String>['a', 'b'],
        align: HuiAlign.left,
      );
      expect(out['b']!.z, 0.13);
      expect(out['b']!.y, 0);
      final Map<String, Vec3> vertical = alignOffsets(
        scene: _scene(pair()),
        ids: <String>['a', 'b'],
        align: HuiAlign.top,
      );
      expect(vertical['b']!.z, 0.13);
      expect(vertical['b']!.x, 1);
    });

    test('aligns what is drawn, not the anchor, under true render', () {
      // Text drops 0.325 below its anchor in true-render mode; a single loose
      // item drops 1.30875. Two different biases, so aligning the anchors and
      // aligning the drawn rects give different answers.
      List<HuiComponent> mixed() => <HuiComponent>[
        _text('a', 0, 0),
        HuiComponent(
          'b',
          Vec3(0, 1, 0),
          HuiButtonData(0.05, <HuiAction>[], HuiItemIcon('stick')),
        ),
      ];
      final Map<String, Vec3> biased = alignOffsets(
        scene: _scene(mixed(), trueRender: true),
        ids: <String>['a', 'b'],
        align: HuiAlign.bottom,
      );
      // Drawn bottoms are -0.434375 (text) and -0.68375 (item); the item is
      // lower, so the text moves down to meet it.
      expect(biased['a']!.y, closeTo(-0.2494, 1e-9));
      expect(biased['b']!.y, closeTo(1, 1e-12));

      final Map<String, Vec3> plain = alignOffsets(
        scene: _scene(mixed()),
        ids: <String>['a', 'b'],
        align: HuiAlign.bottom,
      );
      expect(plain['a']!.y, closeTo(0, 1e-12));
      expect(plain['b']!.y, 0.2656);
    });

    test('is a no-op below two resolved items', () {
      final CanvasScene scene = _scene(pair());
      expect(
        alignOffsets(scene: scene, ids: <String>['a'], align: HuiAlign.left),
        isEmpty,
      );
      expect(
        alignOffsets(
          scene: scene,
          ids: <String>['a', 'nope'],
          align: HuiAlign.left,
        ),
        isEmpty,
      );
      expect(
        alignOffsets(
          scene: scene,
          ids: <String>['a', 'a'],
          align: HuiAlign.left,
        ),
        isEmpty,
      );
      expect(
        alignOffsets(scene: scene, ids: const <String>[], align: HuiAlign.left),
        isEmpty,
      );
    });

    test('drops ids the scene does not know', () {
      final Map<String, Vec3> out = alignOffsets(
        scene: _scene(pair()),
        ids: <String>['a', 'b', 'ghost'],
        align: HuiAlign.left,
      );
      expect(out.keys, <String>['a', 'b']);
    });
  });

  group('distributeOffsets', () {
    test('equalises horizontal gaps and pins the outer two', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 1, 0, text: 'ABCD'),
        _text('c', 3, 0),
      ]);
      final Map<String, Vec3> out = distributeOffsets(
        scene: scene,
        ids: <String>['a', 'b', 'c'],
        axis: HuiAxis.horizontal,
      );
      // span 3.30, content 1.20, so each gap is 1.05: b.left = 0.15 + 1.05.
      expect(out['a']!.x, closeTo(0, 1e-12));
      expect(out['b']!.x, closeTo(1.5, 1e-12));
      expect(out['c']!.x, closeTo(3, 1e-12));
    });

    test('equalises vertical gaps', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 0, 1, text: 'A\nB'),
        _text('c', 0, 3),
      ]);
      final Map<String, Vec3> out = distributeOffsets(
        scene: scene,
        ids: <String>['a', 'b', 'c'],
        axis: HuiAxis.vertical,
      );
      expect(out['a']!.y, closeTo(0, 1e-12));
      expect(out['b']!.y, closeTo(1.5, 1e-12));
      expect(out['c']!.y, closeTo(3, 1e-12));
    });

    test('reads positions in space, not in the order the ids arrive', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 1, 0, text: 'ABCD'),
        _text('c', 3, 0),
      ]);
      final Map<String, Vec3> out = distributeOffsets(
        scene: scene,
        ids: <String>['c', 'a', 'b'],
        axis: HuiAxis.horizontal,
      );
      expect(out['b']!.x, closeTo(1.5, 1e-12));
    });

    test('rounds to four decimals the way the store does', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 0.3, 0),
        _text('c', 0.6, 0),
        _text('d', 1, 0),
      ]);
      final Map<String, Vec3> out = distributeOffsets(
        scene: scene,
        ids: <String>['a', 'b', 'c', 'd'],
        axis: HuiAxis.horizontal,
      );
      // gap = (1.30 - 1.20) / 3 = 0.0333..., so b lands on 1/3 exactly.
      expect(out['b']!.x, 0.3333);
      expect(out['c']!.x, 0.6667);
    });

    test('inverts uiScale and the unscaled menu offset', () {
      final CanvasScene scene = _scene(
        <HuiComponent>[
          _text('a', 0, 0),
          _text('b', 1, 0, text: 'ABCD'),
          _text('c', 3, 0),
        ],
        uiScale: 2,
        menuOffset: Vec3(0.5, 1, 0),
      );
      final Map<String, Vec3> out = distributeOffsets(
        scene: scene,
        ids: <String>['a', 'b', 'c'],
        axis: HuiAxis.horizontal,
      );
      // Everything doubles in world space, so the offsets are unchanged.
      expect(out['a']!.x, closeTo(0, 1e-12));
      expect(out['b']!.x, closeTo(1.5, 1e-12));
      expect(out['c']!.x, closeTo(3, 1e-12));
    });

    test('never touches z or the off-axis coordinate', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 1, 0.7, z: 0.13, text: 'ABCD'),
        _text('c', 3, 0),
      ]);
      final Map<String, Vec3> out = distributeOffsets(
        scene: scene,
        ids: <String>['a', 'b', 'c'],
        axis: HuiAxis.horizontal,
      );
      expect(out['b']!.y, 0.7);
      expect(out['b']!.z, 0.13);
    });

    test('is a no-op below three resolved items', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 1, 0),
        _text('c', 3, 0),
      ]);
      expect(
        distributeOffsets(
          scene: scene,
          ids: <String>['a', 'b'],
          axis: HuiAxis.horizontal,
        ),
        isEmpty,
      );
      expect(
        distributeOffsets(
          scene: scene,
          ids: <String>['a', 'b', 'ghost'],
          axis: HuiAxis.horizontal,
        ),
        isEmpty,
      );
    });
  });

  group('smartGuides', () {
    CanvasItem block(String id, double cx, double cy, {int index = 0}) => _item(
      id: id,
      index: index,
      visual: HuiRect(x: cx, y: cy, w: 2, h: 2),
    );

    test('snaps an edge and reports one vertical guide', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: 1.02, minY: 5, maxX: 3.02, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0)],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, closeTo(-0.02, 1e-12));
      expect(snap.dy, 0);
      expect(snap.guides.length, 1);
      final AlignmentGuide guide = snap.guides.single;
      expect(guide.axis, GuideAxis.vertical);
      expect(guide.match, GuideMatch.edge);
      expect(guide.position, closeTo(1, 1e-12));
      expect(guide.ids, <String>['a']);
      // Spans the matched item and the moved rect.
      expect(guide.start, closeTo(-1, 1e-12));
      expect(guide.end, closeTo(7, 1e-12));
    });

    test('does nothing beyond the threshold', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: 1.2, minY: 5, maxX: 3.2, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0)],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, 0);
      expect(snap.dy, 0);
      expect(snap.isEmpty, isTrue);
    });

    test('a delta exactly on the threshold still snaps', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: 1.05, minY: 5, maxX: 3.05, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0)],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, closeTo(-0.05, 1e-12));
    });

    test('nearest candidate wins', () {
      // Left edge is 0.03 from a's right edge; right edge is 0.01 from b's.
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: 1.03, minY: 5, maxX: 3.01, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0), block('b', 4, 0, index: 1)],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, closeTo(-0.01, 1e-12));
      expect(snap.guides.single.ids, <String>['b']);
      expect(snap.guides.single.position, closeTo(3, 1e-12));
    });

    test('centre matches are flagged as centre', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: -0.98, minY: 5, maxX: 1.02, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0)],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, closeTo(-0.02, 1e-12));
      // Three coincident matches at once: left/left, centre/centre, right/right.
      expect(snap.guides.length, 3);
      expect(
        snap.guides.map((AlignmentGuide g) => g.match).toList(),
        containsAll(<GuideMatch>[GuideMatch.edge, GuideMatch.center]),
      );
      expect(
        snap.guides
            .singleWhere((AlignmentGuide g) => g.match == GuideMatch.center)
            .position,
        closeTo(0, 1e-12),
      );
    });

    test('resolves the two axes independently', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(
          minX: 1.02,
          minY: 3.97,
          maxX: 3.02,
          maxY: 5.97,
        ),
        others: <CanvasItem>[
          block('a', 0, 0),
          // Centre y 4.98 -> the moving centre y 4.97 is 0.01 away.
          block('b', 20, 4.98, index: 1),
        ],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, closeTo(-0.02, 1e-12));
      expect(snap.dy, closeTo(0.01, 1e-12));
      expect(snap.snappedX, isTrue);
      expect(snap.snappedY, isTrue);
      expect(
        snap.guides
            .singleWhere(
              (AlignmentGuide g) =>
                  g.axis == GuideAxis.horizontal &&
                  g.match == GuideMatch.center,
            )
            .position,
        closeTo(4.98, 1e-12),
      );
    });

    test('an exact alignment reports a guide with a zero correction', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: -1, minY: 5, maxX: 1, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0)],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, 0);
      expect(snap.isEmpty, isFalse);
      expect(snap.snappedX, isTrue);
    });

    test('merges every item sitting on the winning line', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: 1.02, minY: 5, maxX: 3.02, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0), block('b', 0, 9, index: 1)],
        thresholdBlocks: 0.05,
      );
      final AlignmentGuide vertical = snap.guides.singleWhere(
        (AlignmentGuide g) => g.axis == GuideAxis.vertical,
      );
      expect(vertical.ids, <String>['a', 'b']);
      expect(vertical.start, closeTo(-1, 1e-12));
      expect(vertical.end, closeTo(10, 1e-12));
    });

    test('no neighbours means no snap', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: 0, minY: 0, maxX: 1, maxY: 1),
        others: const <CanvasItem>[],
        thresholdBlocks: 0.05,
      );
      expect(snap.dx, 0);
      expect(snap.dy, 0);
      expect(snap.guides, isEmpty);
    });

    test('a non-positive threshold disables snapping', () {
      final GuideSnap snap = smartGuides(
        moving: const WorldBounds(minX: 1.02, minY: 5, maxX: 3.02, maxY: 7),
        others: <CanvasItem>[block('a', 0, 0)],
        thresholdBlocks: 0,
      );
      expect(snap.isEmpty, isTrue);
    });
  });

  group('zOrderOffsets', () {
    List<CanvasItem> stack() => <CanvasItem>[
      _item(id: 'a', index: 0, visual: HuiRect.zero, offset: Vec3(0, 0, 1)),
      _item(id: 'b', index: 1, visual: HuiRect.zero, offset: Vec3(0, 0, 2)),
      _item(id: 'c', index: 2, visual: HuiRect.zero, offset: Vec3(0, 0, 3)),
    ];

    test('bring forward subtracts, because larger z paints first', () {
      final Map<String, Vec3> out = zOrderOffsets(
        items: stack(),
        ids: <String>{'c'},
        op: HuiZOrder.forward,
        step: 0.1,
      );
      expect(out['c']!.z, closeTo(2.9, 1e-12));
    });

    test('send back adds', () {
      final Map<String, Vec3> out = zOrderOffsets(
        items: stack(),
        ids: <String>{'a'},
        op: HuiZOrder.backward,
        step: 0.1,
      );
      expect(out['a']!.z, closeTo(1.1, 1e-12));
    });

    test('to front lands one step in front of the nearest unselected', () {
      final Map<String, Vec3> out = zOrderOffsets(
        items: stack(),
        ids: <String>{'c'},
        op: HuiZOrder.toFront,
        step: 0.1,
      );
      // Nearest unselected is a at z 1, so c goes to 0.9.
      expect(out['c']!.z, closeTo(0.9, 1e-12));
    });

    test('to back lands one step behind the farthest unselected', () {
      final Map<String, Vec3> out = zOrderOffsets(
        items: stack(),
        ids: <String>{'a'},
        op: HuiZOrder.toBack,
        step: 0.1,
      );
      expect(out['a']!.z, closeTo(3.1, 1e-12));
    });

    test('to front actually reorders the painted stack', () {
      final List<HuiComponent> components = <HuiComponent>[
        _text('a', 0, 0, z: 1),
        _text('b', 0, 0, z: 2),
        _text('c', 0, 0, z: 3),
      ];
      final CanvasScene before = _scene(components);
      expect(before.drawOrder.last.id, 'a');

      final Map<String, Vec3> out = zOrderOffsets(
        items: before.items,
        ids: <String>{'c'},
        op: HuiZOrder.toFront,
        step: 0.1,
      );
      for (final MapEntry<String, Vec3> entry in out.entries) {
        components.firstWhere((HuiComponent c) => c.id == entry.key).offset =
            entry.value;
      }
      // Painted last == nearest the camera == what a click hits first.
      expect(_scene(components).drawOrder.last.id, 'c');
    });

    test('a multi-selection keeps its internal order and gaps', () {
      final Map<String, Vec3> out = zOrderOffsets(
        items: stack(),
        ids: <String>{'b', 'c'},
        op: HuiZOrder.toFront,
        step: 0.1,
      );
      // Every selected item must clear a (z 1), so the BACK-most selected (c,
      // z 3) lands on 0.9 and b keeps its one-block lead in front of it.
      expect(out['c']!.z, closeTo(0.9, 1e-12));
      expect(out['b']!.z, closeTo(-0.1, 1e-12));
    });

    test('to back keeps a multi-selection ordered too', () {
      final Map<String, Vec3> out = zOrderOffsets(
        items: stack(),
        ids: <String>{'a', 'b'},
        op: HuiZOrder.toBack,
        step: 0.1,
      );
      // Every selected item must fall behind c (z 3), so the front-most
      // selected (a, z 1) lands on 3.1 and b stays one block behind it.
      expect(out['a']!.z, closeTo(3.1, 1e-12));
      expect(out['b']!.z, closeTo(4.1, 1e-12));
    });

    test('duplicate z values survive to-front intact', () {
      final List<CanvasItem> items = <CanvasItem>[
        _item(id: 'a', index: 0, visual: HuiRect.zero, offset: Vec3(0, 0, 2)),
        _item(id: 'b', index: 1, visual: HuiRect.zero, offset: Vec3(0, 0, 2)),
        _item(id: 'c', index: 2, visual: HuiRect.zero, offset: Vec3(0, 0, 5)),
      ];
      final Map<String, Vec3> out = zOrderOffsets(
        items: items,
        ids: <String>{'c'},
        op: HuiZOrder.toFront,
        step: 0.25,
      );
      expect(out['c']!.z, closeTo(1.75, 1e-12));

      final Map<String, Vec3> both = zOrderOffsets(
        items: items,
        ids: <String>{'a', 'b'},
        op: HuiZOrder.toFront,
        step: 0.25,
      );
      expect(both['a']!.z, closeTo(4.75, 1e-12));
      expect(both['b']!.z, closeTo(4.75, 1e-12));
    });

    test('to front and to back are no-ops when everything is selected', () {
      expect(
        zOrderOffsets(
          items: stack(),
          ids: <String>{'a', 'b', 'c'},
          op: HuiZOrder.toFront,
          step: 0.1,
        ),
        isEmpty,
      );
      expect(
        zOrderOffsets(
          items: stack(),
          ids: <String>{'a', 'b', 'c'},
          op: HuiZOrder.toBack,
          step: 0.1,
        ),
        isEmpty,
      );
    });

    test('forward and backward still work on a full selection', () {
      final Map<String, Vec3> out = zOrderOffsets(
        items: stack(),
        ids: <String>{'a', 'b', 'c'},
        op: HuiZOrder.forward,
        step: 0.5,
      );
      expect(out.length, 3);
      expect(out['a']!.z, closeTo(0.5, 1e-12));
      expect(out['c']!.z, closeTo(2.5, 1e-12));
    });

    test('an empty or unknown selection produces nothing', () {
      expect(
        zOrderOffsets(
          items: stack(),
          ids: const <String>{},
          op: HuiZOrder.forward,
          step: 0.1,
        ),
        isEmpty,
      );
      expect(
        zOrderOffsets(
          items: stack(),
          ids: <String>{'ghost'},
          op: HuiZOrder.toFront,
          step: 0.1,
        ),
        isEmpty,
      );
    });

    test('preserves x and y and rounds z to four decimals', () {
      final List<CanvasItem> items = <CanvasItem>[
        _item(
          id: 'a',
          index: 0,
          visual: HuiRect.zero,
          offset: Vec3(1.5, -2.25, 0.123456),
        ),
        _item(id: 'b', index: 1, visual: HuiRect.zero, offset: Vec3(0, 0, 9)),
      ];
      final Map<String, Vec3> out = zOrderOffsets(
        items: items,
        ids: <String>{'a'},
        op: HuiZOrder.forward,
        step: 0.01,
      );
      expect(out['a']!.x, 1.5);
      expect(out['a']!.y, -2.25);
      expect(out['a']!.z, 0.1135);
    });
  });

  group('marqueeRect', () {
    test('normalises whichever way the band was dragged', () {
      const HuiRect expected = HuiRect.fromEdges(
        left: -1,
        bottom: -2,
        right: 3,
        top: 4,
      );
      expect(marqueeRect(-1, -2, 3, 4), expected);
      expect(marqueeRect(3, 4, -1, -2), expected);
      expect(marqueeRect(-1, 4, 3, -2), expected);
    });

    test('a perfectly straight drag keeps its zero extent', () {
      final HuiRect flat = marqueeRect(0, 1, 2, 1);
      expect(flat.h, 0);
      expect(flat.w, 2);
      // Zero height is exactly why idsInMarquee is inclusive.
      expect(flat.bottom, 1);
      expect(flat.top, 1);
    });
  });

  group('outlineBounds', () {
    test('unions the drawn outlines of the resolved ids', () {
      final CanvasScene scene = _scene(<HuiComponent>[
        _text('a', 0, 0),
        _text('b', 1, 0.5),
        _text('c', 9, 9),
      ]);
      final WorldBounds bounds = outlineBounds(scene, <String>['a', 'b'])!;
      // 'AB' is two chars: 0.3 blocks wide, 0.21875 tall, centred on the anchor.
      expect(bounds.minX, closeTo(-0.15, 1e-12));
      expect(bounds.maxX, closeTo(1.15, 1e-12));
      expect(bounds.minY, closeTo(-0.109375, 1e-12));
      expect(bounds.maxY, closeTo(0.609375, 1e-12));
    });

    test('unknown ids are skipped, and an all-unknown list is null', () {
      final CanvasScene scene = _scene(<HuiComponent>[_text('a', 0, 0)]);
      final WorldBounds bounds = outlineBounds(scene, <String>['ghost', 'a'])!;
      expect(bounds.minX, closeTo(-0.15, 1e-12));
      expect(outlineBounds(scene, <String>['ghost']), isNull);
      expect(outlineBounds(scene, const <String>[]), isNull);
    });
  });

  group('shiftOffsets', () {
    test('moves every offset by the same delta', () {
      final Map<String, Vec3> out = shiftOffsets(
        offsets: <String, Vec3>{'a': Vec3(0, 0, 0), 'b': Vec3(1, -2, 0.5)},
        dx: 0.25,
        dy: -0.5,
      );
      expect(out['a'], Vec3(0.25, -0.5, 0));
      expect(out['b'], Vec3(1.25, -2.5, 0.5));
    });

    test('rounds to four decimals like the store does', () {
      final Map<String, Vec3> out = shiftOffsets(
        offsets: <String, Vec3>{'a': Vec3(0, 0, 0)},
        dx: 1 / 3,
        dz: 1 / 7,
      );
      expect(out['a']!.x, 0.3333);
      expect(out['a']!.z, 0.1429);
    });

    test('an untouched axis survives byte-identical, rounding included', () {
      // A z the author typed as 0.123456 must not be rounded away by a drag
      // that never went near it — the same rule editComponent follows.
      final Map<String, Vec3> out = shiftOffsets(
        offsets: <String, Vec3>{'a': Vec3(0.123456, 0.987654, 0.135791)},
        dx: 0.1,
      );
      expect(out['a']!.x, 0.2235);
      expect(out['a']!.y, 0.987654);
      expect(out['a']!.z, 0.135791);
    });
  });

  group('resolveGroupDrag', () {
    CanvasScene groupScene({double uiScale = 1}) => _scene(<HuiComponent>[
      _text('a', 0, 0),
      _text('b', 1, 0, z: 0.13),
      _text('c', 5, 0),
    ], uiScale: uiScale);

    test('applies the grabbed component snapped delta to every member', () {
      final CanvasScene scene = groupScene();
      final GroupDrag drag = resolveGroupDrag(
        scene: scene,
        startOffsets: <String, Vec3>{'a': Vec3(0, 0, 0), 'b': Vec3(1, 0, 0.13)},
        startBounds: outlineBounds(scene, <String>['a', 'b'])!,
        grabbedId: 'a',
        grabbedTarget: Vec3(0.5, 0.25, 0),
        guideThresholdBlocks: 0,
      );
      expect(drag.offsets['a'], Vec3(0.5, 0.25, 0));
      expect(drag.offsets['b'], Vec3(1.5, 0.25, 0.13));
      expect(drag.guides, isEmpty);
    });

    test('a guide correction lands on top of the snapped delta', () {
      final CanvasScene scene = groupScene();
      final GroupDrag drag = resolveGroupDrag(
        scene: scene,
        startOffsets: <String, Vec3>{'a': Vec3(0, 0, 0)},
        startBounds: outlineBounds(scene, <String>['a'])!,
        grabbedId: 'a',
        // The grid snapped this to 0.98; 'b' sits at 1.0 and pulls it flush.
        grabbedTarget: Vec3(0.98, 0, 0),
        guideThresholdBlocks: 0.05,
      );
      expect(drag.offsets['a']!.x, 1);
      expect(
        drag.guides.any((AlignmentGuide g) => g.ids.contains('b')),
        isTrue,
      );
    });

    test('a zero correction still reports its guides', () {
      final CanvasScene scene = groupScene();
      final GroupDrag drag = resolveGroupDrag(
        scene: scene,
        startOffsets: <String, Vec3>{'a': Vec3(0, 0, 0)},
        startBounds: outlineBounds(scene, <String>['a'])!,
        grabbedId: 'a',
        // Already exactly aligned with 'b' on both axes.
        grabbedTarget: Vec3(1, 0, 0),
        guideThresholdBlocks: 0.05,
      );
      expect(drag.offsets['a'], Vec3(1, 0, 0));
      expect(drag.guides, isNotEmpty);
      expect(
        drag.guides.any((AlignmentGuide g) => g.axis == GuideAxis.horizontal),
        isTrue,
      );
    });

    test('the selection never snaps to itself', () {
      final CanvasScene scene = groupScene();
      final GroupDrag drag = resolveGroupDrag(
        scene: scene,
        startOffsets: <String, Vec3>{'a': Vec3(0, 0, 0), 'b': Vec3(1, 0, 0.13)},
        startBounds: outlineBounds(scene, <String>['a', 'b'])!,
        grabbedId: 'a',
        grabbedTarget: Vec3(0.02, 0, 0),
        guideThresholdBlocks: 0.05,
      );
      // 'b' moves with the group, so it cannot be a guide source; 'c' is far
      // away, so only the shared y line survives and x is left alone.
      expect(drag.offsets['a']!.x, 0.02);
      expect(drag.offsets['b']!.x, 1.02);
      expect(
        drag.guides.every((AlignmentGuide g) => !g.ids.contains('b')),
        isTrue,
      );
    });

    test('guide corrections are world blocks, so uiScale divides them out', () {
      final CanvasScene scene = groupScene(uiScale: 2);
      final GroupDrag drag = resolveGroupDrag(
        scene: scene,
        startOffsets: <String, Vec3>{'a': Vec3(0, 0, 0)},
        startBounds: outlineBounds(scene, <String>['a'])!,
        grabbedId: 'a',
        // 'b' draws at world x 2.0; this lands at 1.9, a 0.1-block pull that
        // is only a 0.05 change in authored offset.
        grabbedTarget: Vec3(0.95, 0, 0),
        guideThresholdBlocks: 0.15,
      );
      expect(drag.offsets['a']!.x, 1);
    });

    test('an unknown grab or an uninvertible scale resolves to nothing', () {
      final CanvasScene scene = groupScene();
      expect(
        resolveGroupDrag(
          scene: scene,
          startOffsets: <String, Vec3>{'a': Vec3(0, 0, 0)},
          startBounds: outlineBounds(scene, <String>['a'])!,
          grabbedId: 'ghost',
          grabbedTarget: Vec3(1, 0, 0),
          guideThresholdBlocks: 0.05,
        ).offsets,
        isEmpty,
      );
      final CanvasScene degenerate = groupScene(uiScale: 0);
      expect(
        resolveGroupDrag(
          scene: degenerate,
          startOffsets: <String, Vec3>{'a': Vec3(0, 0, 0)},
          startBounds: const WorldBounds(minX: 0, minY: 0, maxX: 0, maxY: 0),
          grabbedId: 'a',
          grabbedTarget: Vec3(1, 0, 0),
          guideThresholdBlocks: 0.05,
        ).offsets,
        isEmpty,
      );
    });
  });
}
