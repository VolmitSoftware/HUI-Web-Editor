import 'dart:math' as math;

import 'package:gloss_editor/logic/viewport_math.dart';
import 'package:test/test.dart';

const double _epsilon = 1e-9;

HuiViewport _viewport({
  double width = 800,
  double height = 600,
  double dpr = 1,
  double base = 100,
  CanvasTransform transform = CanvasTransform.identity,
}) {
  return HuiViewport(
    widthPx: width,
    heightPx: height,
    devicePixelRatio: dpr,
    basePixelsPerBlock: base,
    transform: transform,
  );
}

void main() {
  group('CanvasTransform', () {
    test('identity is zoom 1 with no pan', () {
      const CanvasTransform t = CanvasTransform.identity;
      expect(t.zoom, 1.0);
      expect(t.panX, 0.0);
      expect(t.panY, 0.0);
    });

    test('panBy adds screen pixel deltas', () {
      const CanvasTransform t = CanvasTransform(zoom: 2, panX: 10, panY: -4);
      final CanvasTransform moved = t.panBy(5, 9);
      expect(moved.zoom, 2.0);
      expect(moved.panX, 15.0);
      expect(moved.panY, 5.0);
    });

    test('clamp bounds the zoom into the allowed range', () {
      expect(const CanvasTransform(zoom: 1000).clamp().zoom, huiMaxZoom);
      expect(const CanvasTransform(zoom: 0.0001).clamp().zoom, huiMinZoom);
      expect(const CanvasTransform(zoom: 2).clamp().zoom, 2.0);
    });

    test('clamp bounds the pan symmetrically', () {
      const CanvasTransform t = CanvasTransform(panX: 900, panY: -900);
      final CanvasTransform clamped = t.clamp(maxPanX: 50, maxPanY: 25);
      expect(clamped.panX, 50.0);
      expect(clamped.panY, -25.0);
    });

    test('zoomAtPoint keeps the anchored point stationary in screen space', () {
      const CanvasTransform start = CanvasTransform(
        zoom: 1.5,
        panX: 40,
        panY: -18,
      );
      const double anchorX = 120;
      const double anchorY = -75;
      const double base = 100;
      final double worldBefore = (anchorX - start.panX) / (base * start.zoom);
      final double worldBeforeY = (anchorY - start.panY) / (base * start.zoom);

      final CanvasTransform zoomed = start.zoomAtPoint(
        requestedZoom: 4.25,
        anchorX: anchorX,
        anchorY: anchorY,
      );

      final double worldAfter = (anchorX - zoomed.panX) / (base * zoomed.zoom);
      final double worldAfterY = (anchorY - zoomed.panY) / (base * zoomed.zoom);
      expect(zoomed.zoom, closeTo(4.25, _epsilon));
      expect(worldAfter, closeTo(worldBefore, _epsilon));
      expect(worldAfterY, closeTo(worldBeforeY, _epsilon));
    });

    test('zoomAtPoint clamps the requested zoom', () {
      const CanvasTransform start = CanvasTransform();
      expect(
        start.zoomAtPoint(requestedZoom: 1e9, anchorX: 10, anchorY: 10).zoom,
        huiMaxZoom,
      );
      expect(
        start.zoomAtPoint(requestedZoom: -3, anchorX: 10, anchorY: 10).zoom,
        huiMinZoom,
      );
    });

    test(
      'zoomAtPoint on the centre anchor leaves pan untouched at pan zero',
      () {
        const CanvasTransform start = CanvasTransform(zoom: 1);
        final CanvasTransform zoomed = start.zoomAtPoint(
          requestedZoom: 3,
          anchorX: 0,
          anchorY: 0,
        );
        expect(zoomed.panX, 0.0);
        expect(zoomed.panY, 0.0);
        expect(zoomed.zoom, 3.0);
      },
    );

    test('zoomByAtPoint multiplies the current zoom', () {
      const CanvasTransform start = CanvasTransform(zoom: 2);
      final CanvasTransform zoomed = start.zoomByAtPoint(
        factor: 1.25,
        anchorX: 0,
        anchorY: 0,
      );
      expect(zoomed.zoom, closeTo(2.5, _epsilon));
    });

    test('equality is by value', () {
      expect(
        const CanvasTransform(zoom: 2, panX: 3, panY: 4),
        const CanvasTransform(zoom: 2, panX: 3, panY: 4),
      );
      expect(
        const CanvasTransform(zoom: 2, panX: 3, panY: 4).hashCode,
        const CanvasTransform(zoom: 2, panX: 3, panY: 4).hashCode,
      );
    });
  });

  group('wheelZoomFactor', () {
    test('scrolling up zooms in and down zooms out', () {
      expect(wheelZoomFactor(-100), greaterThan(1));
      expect(wheelZoomFactor(100), lessThan(1));
      expect(wheelZoomFactor(0), 1.0);
    });

    test('is the exponential curve exp(-delta * 0.0015)', () {
      expect(wheelZoomFactor(-120), closeTo(math.exp(0.18), _epsilon));
      expect(huiWheelZoomSensitivity, 0.0015);
    });

    test('normalises line and page delta modes', () {
      expect(
        wheelZoomFactor(-3, deltaMode: 1),
        closeTo(wheelZoomFactor(-48), _epsilon),
      );
      expect(
        wheelZoomFactor(-2, deltaMode: 2, pagePixels: 600),
        closeTo(wheelZoomFactor(-1200), _epsilon),
      );
    });

    test('opposite scrolls compose back to unity', () {
      expect(
        wheelZoomFactor(-90) * wheelZoomFactor(90),
        closeTo(1.0, _epsilon),
      );
    });
  });

  group('HuiViewport mapping', () {
    test('the world origin lands on the canvas centre when untransformed', () {
      final HuiViewport v = _viewport();
      final ScreenPoint p = v.worldToScreen(0, 0);
      expect(p.x, 400.0);
      expect(p.y, 300.0);
    });

    test('y is flipped: world up is screen up', () {
      final HuiViewport v = _viewport();
      expect(v.worldToScreenY(1), 200.0);
      expect(v.worldToScreenY(-1), 400.0);
      expect(v.worldToScreenX(2), 600.0);
    });

    test('zoom and pan scale and translate the mapping', () {
      final HuiViewport v = _viewport(
        transform: const CanvasTransform(zoom: 2, panX: 30, panY: -10),
      );
      expect(v.pixelsPerBlock, 200.0);
      expect(v.worldToScreenX(1), 400 + 30 + 200);
      expect(v.worldToScreenY(1), 300 - 10 - 200);
    });

    test('screenToWorld is the exact inverse of worldToScreen', () {
      final List<HuiViewport> viewports = <HuiViewport>[
        _viewport(),
        _viewport(
          transform: const CanvasTransform(zoom: 3.75, panX: -220, panY: 61.5),
        ),
        _viewport(
          width: 1237,
          height: 719,
          dpr: 2,
          base: 96.5,
          transform: const CanvasTransform(zoom: 0.42, panX: 13.25, panY: -7.5),
        ),
        _viewport(
          width: 320,
          height: 240,
          dpr: 3,
          base: 40,
          transform: const CanvasTransform(zoom: huiMaxZoom, panX: 9, panY: 9),
        ),
      ];
      const List<List<double>> points = <List<double>>[
        <double>[0, 0],
        <double>[1.7, 2.5],
        <double>[-3.125, 0.85],
        <double>[12.5, -44.0],
        <double>[0.21875, 0.75],
      ];
      for (final HuiViewport v in viewports) {
        for (final List<double> point in points) {
          final ScreenPoint screen = v.worldToScreen(point[0], point[1]);
          final WorldPoint back = v.screenToWorld(screen.x, screen.y);
          expect(back.x, closeTo(point[0], _epsilon));
          expect(back.y, closeTo(point[1], _epsilon));
        }
      }
    });

    test('worldToScreen is the exact inverse of screenToWorld', () {
      final HuiViewport v = _viewport(
        width: 911,
        height: 507,
        base: 133.5,
        transform: const CanvasTransform(zoom: 2.75, panX: -61, panY: 42),
      );
      const List<List<double>> pixels = <List<double>>[
        <double>[0, 0],
        <double>[911, 507],
        <double>[455.5, 253.5],
        <double>[123.75, 480.25],
      ];
      for (final List<double> px in pixels) {
        final WorldPoint world = v.screenToWorld(px[0], px[1]);
        final ScreenPoint back = v.worldToScreen(world.x, world.y);
        expect(back.x, closeTo(px[0], 1e-7));
        expect(back.y, closeTo(px[1], 1e-7));
      }
    });

    test('device pixel ratio only affects the backing store mapping', () {
      final HuiViewport v = _viewport(dpr: 2.5);
      expect(v.backingWidthPx, 2000.0);
      expect(v.backingHeightPx, 1500.0);
      expect(v.devicePixelsPerBlock, 250.0);
      final ScreenPoint css = v.worldToScreen(1, 1);
      final ScreenPoint device = v.worldToDevice(1, 1);
      expect(css.x, 500.0);
      expect(device.x, closeTo(css.x * 2.5, _epsilon));
      expect(device.y, closeTo(css.y * 2.5, _epsilon));
      // The CSS-pixel mapping must not shift when the ratio changes.
      final HuiViewport plain = _viewport();
      expect(v.worldToScreen(2, -1).x, plain.worldToScreen(2, -1).x);
      expect(v.worldToScreen(2, -1).y, plain.worldToScreen(2, -1).y);
    });

    test('blocks and pixels convert both ways', () {
      final HuiViewport v = _viewport(
        transform: const CanvasTransform(zoom: 2),
      );
      expect(v.blocksToPixels(0.5), 100.0);
      expect(v.pixelsToBlocks(100), 0.5);
    });

    test('visibleWorld reports the world rectangle under the canvas', () {
      final HuiViewport v = _viewport();
      final WorldBounds b = v.visibleWorld;
      expect(b.minX, closeTo(-4, _epsilon));
      expect(b.maxX, closeTo(4, _epsilon));
      expect(b.minY, closeTo(-3, _epsilon));
      expect(b.maxY, closeTo(3, _epsilon));
      expect(b.width, closeTo(8, _epsilon));
      expect(b.height, closeTo(6, _epsilon));
      expect(b.centerX, closeTo(0, _epsilon));
      expect(b.centerY, closeTo(0, _epsilon));
    });
  });

  group('HuiViewport interaction', () {
    test('zoomAtScreenPoint keeps the world point under the cursor', () {
      final HuiViewport v = _viewport(
        transform: const CanvasTransform(zoom: 1.25, panX: -30, panY: 12),
      );
      const double cursorX = 617.5;
      const double cursorY = 142.25;
      final WorldPoint before = v.screenToWorld(cursorX, cursorY);
      final HuiViewport zoomed = v.zoomAtScreenPoint(
        requestedZoom: 6,
        screenX: cursorX,
        screenY: cursorY,
      );
      final WorldPoint after = zoomed.screenToWorld(cursorX, cursorY);
      expect(zoomed.zoom, closeTo(6, _epsilon));
      expect(after.x, closeTo(before.x, 1e-9));
      expect(after.y, closeTo(before.y, 1e-9));
    });

    test('a wheel zoom round trip returns to the starting transform', () {
      final HuiViewport v = _viewport(
        transform: const CanvasTransform(zoom: 2, panX: 17, panY: -23),
      );
      const double cursorX = 511;
      const double cursorY = 96;
      final HuiViewport zoomIn = v.zoomByAtScreenPoint(
        factor: wheelZoomFactor(-140),
        screenX: cursorX,
        screenY: cursorY,
      );
      final HuiViewport zoomOut = zoomIn.zoomByAtScreenPoint(
        factor: wheelZoomFactor(140),
        screenX: cursorX,
        screenY: cursorY,
      );
      expect(zoomOut.zoom, closeTo(v.zoom, 1e-9));
      expect(zoomOut.transform.panX, closeTo(v.transform.panX, 1e-7));
      expect(zoomOut.transform.panY, closeTo(v.transform.panY, 1e-7));
    });

    test(
      'zooming out past the minimum clamps without moving the anchor twice',
      () {
        final HuiViewport v = _viewport(
          transform: const CanvasTransform(zoom: huiMinZoom),
        );
        final HuiViewport zoomed = v.zoomByAtScreenPoint(
          factor: 0.1,
          screenX: 700,
          screenY: 50,
        );
        expect(zoomed.zoom, huiMinZoom);
        expect(zoomed.transform.panX, v.transform.panX);
        expect(zoomed.transform.panY, v.transform.panY);
      },
    );

    test('panByPixels translates and clamps to the world pan limit', () {
      final HuiViewport v = _viewport();
      final HuiViewport panned = v.panByPixels(25, -40);
      expect(panned.transform.panX, 25.0);
      expect(panned.transform.panY, -40.0);

      final HuiViewport slammed = v.panByPixels(1e9, -1e9);
      expect(slammed.transform.panX, huiPanLimitBlocks * 100);
      expect(slammed.transform.panY, -huiPanLimitBlocks * 100);
    });

    test('reset restores the identity transform', () {
      final HuiViewport v = _viewport(
        transform: const CanvasTransform(zoom: 7, panX: 100, panY: 100),
      );
      expect(v.reset().transform, CanvasTransform.identity);
    });

    test('resized keeps the transform and swaps the canvas size', () {
      final HuiViewport v = _viewport(
        transform: const CanvasTransform(zoom: 3, panX: 5, panY: 6),
      );
      final HuiViewport r = v.resized(
        widthPx: 1024,
        heightPx: 768,
        devicePixelRatio: 2,
      );
      expect(r.widthPx, 1024.0);
      expect(r.heightPx, 768.0);
      expect(r.devicePixelRatio, 2.0);
      expect(r.transform, v.transform);
      expect(r.basePixelsPerBlock, v.basePixelsPerBlock);
    });

    test('zoomToFit centres the bounds and honours padding', () {
      final HuiViewport v = _viewport();
      const WorldBounds bounds = WorldBounds(
        minX: 1,
        minY: 2,
        maxX: 3,
        maxY: 4,
      );
      final HuiViewport fitted = v.zoomToFit(bounds, paddingPx: 20);
      expect(fitted.zoom, closeTo(2.8, _epsilon));
      final ScreenPoint centre = fitted.worldToScreen(2, 3);
      expect(centre.x, closeTo(400, 1e-7));
      expect(centre.y, closeTo(300, 1e-7));
      final ScreenPoint corner = fitted.worldToScreen(bounds.minX, bounds.maxY);
      expect(corner.x, greaterThanOrEqualTo(0));
      expect(corner.y, greaterThanOrEqualTo(20 - 1e-7));
    });

    test('zoomToFit clamps degenerate bounds instead of dividing by zero', () {
      final HuiViewport v = _viewport();
      const WorldBounds point = WorldBounds(minX: 2, minY: 2, maxX: 2, maxY: 2);
      final HuiViewport fitted = v.zoomToFit(point);
      expect(fitted.zoom, lessThanOrEqualTo(huiMaxZoom));
      expect(fitted.zoom, greaterThanOrEqualTo(huiMinZoom));
      expect(fitted.zoom.isFinite, isTrue);
      final ScreenPoint centre = fitted.worldToScreen(2, 2);
      expect(centre.x, closeTo(400, 1e-7));
      expect(centre.y, closeTo(300, 1e-7));
    });

    test('a zero-sized canvas never produces NaN', () {
      final HuiViewport v = _viewport(width: 0, height: 0);
      final ScreenPoint p = v.worldToScreen(1, 1);
      expect(p.x.isFinite, isTrue);
      expect(p.y.isFinite, isTrue);
      final WorldPoint w = v.screenToWorld(0, 0);
      expect(w.x.isFinite, isTrue);
      expect(w.y.isFinite, isTrue);
      expect(
        v
            .zoomToFit(const WorldBounds(minX: 0, minY: 0, maxX: 1, maxY: 1))
            .zoom
            .isFinite,
        isTrue,
      );
    });
  });
}
