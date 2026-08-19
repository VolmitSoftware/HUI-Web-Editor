import 'package:gloss_editor/components/shell/pane_layout.dart';
import 'package:gloss_editor/services/storage_service.dart';
import 'package:test/test.dart';

void main() {
  group('PaneLayout defaults', () {
    test('ship 240 rail and 320 inspector', () {
      const PaneLayout layout = PaneLayout.defaults;
      expect(layout.railWidth, 240);
      expect(layout.inspectorWidth, 320);
    });

    test('expose the css custom property each pane track reads', () {
      expect(PaneLayout.variableOf(PaneSide.rail), '--hui-rail-width');
      expect(
        PaneLayout.variableOf(PaneSide.inspector),
        '--hui-inspector-width',
      );
    });
  });

  group('PaneLayout.clampWidth', () {
    test('holds the rail inside 200-420', () {
      const PaneLayout layout = PaneLayout.defaults;
      expect(layout.clampWidth(PaneSide.rail, 120), 200);
      expect(layout.clampWidth(PaneSide.rail, 999), 420);
      expect(layout.clampWidth(PaneSide.rail, 312), 312);
    });

    test('holds the inspector inside 280-520', () {
      const PaneLayout layout = PaneLayout.defaults;
      expect(layout.clampWidth(PaneSide.inspector, 10), 280);
      expect(layout.clampWidth(PaneSide.inspector, 999), 520);
      expect(layout.clampWidth(PaneSide.inspector, 401), 401);
    });

    test('refuses to squeeze the canvas below its floor', () {
      const PaneLayout layout = PaneLayout.defaults;
      // 1280 - 320 inspector - 420 canvas - 12 handles = 528 of room, so the
      // hard 420 maximum still wins.
      expect(layout.clampWidth(PaneSide.rail, 999, viewportWidth: 1280), 420);
      // 1024 - 320 - 420 - 12 leaves 272 of room, so the canvas floor bites
      // before the hard maximum does.
      expect(layout.clampWidth(PaneSide.rail, 999, viewportWidth: 1024), 272);
      // 900 leaves 148, below the rail minimum: the minimum wins so the pane
      // never collapses to nothing.
      expect(layout.clampWidth(PaneSide.rail, 999, viewportWidth: 900), 200);
    });

    test('leaves the pane alone for a non-finite request', () {
      const PaneLayout layout = PaneLayout(railWidth: 300);
      expect(layout.clampWidth(PaneSide.rail, double.nan), 300);
    });
  });

  group('PaneLayout.widthForEdge', () {
    test('reads the rail straight off the handle edge', () {
      expect(PaneLayout.widthForEdge(PaneSide.rail, 264, 1440), 264);
    });

    test('measures the inspector back from the viewport edge', () {
      // 1440 - 1100 edge - 6 handle.
      expect(PaneLayout.widthForEdge(PaneSide.inspector, 1100, 1440), 334);
    });
  });

  group('PaneLayout mutation', () {
    test('withWidth only moves the requested side', () {
      final PaneLayout next = PaneLayout.defaults.withWidth(PaneSide.rail, 300);
      expect(next.railWidth, 300);
      expect(next.inspectorWidth, PaneLayout.defaultInspectorWidth);
    });

    test('nudged steps from the current width and clamps', () {
      const PaneLayout layout = PaneLayout(railWidth: 205);
      expect(layout.nudged(PaneSide.rail, PaneLayout.keyStep).railWidth, 213);
      expect(layout.nudged(PaneSide.rail, -PaneLayout.keyStep).railWidth, 200);
    });

    test('resetSide returns that pane to its default', () {
      const PaneLayout layout = PaneLayout(railWidth: 410, inspectorWidth: 500);
      final PaneLayout next = layout.resetSide(PaneSide.inspector);
      expect(next.inspectorWidth, PaneLayout.defaultInspectorWidth);
      expect(next.railWidth, 410);
    });
  });

  group('PaneLayout persistence', () {
    test('round-trips through the storage key', () {
      const PaneLayout layout = PaneLayout(railWidth: 288, inspectorWidth: 416);
      expect(layout.persist(), isTrue);
      expect(StorageService.read(PaneLayout.storageKey), isNotNull);
      expect(PaneLayout.load(), layout);
      StorageService.remove(PaneLayout.storageKey);
    });

    test('decodes a missing or corrupt value to the defaults', () {
      expect(PaneLayout.decode(null), PaneLayout.defaults);
      expect(PaneLayout.decode(''), PaneLayout.defaults);
      expect(PaneLayout.decode('not json'), PaneLayout.defaults);
      expect(PaneLayout.decode('[1,2]'), PaneLayout.defaults);
      expect(PaneLayout.decode('{"rail":"wide"}'), PaneLayout.defaults);
    });

    test('clamps a stored value that is out of range', () {
      expect(
        PaneLayout.decode('{"rail":9000,"inspector":1}'),
        const PaneLayout(railWidth: 420, inspectorWidth: 280),
      );
    });

    test('uses the versioned key so a format change cannot be misread', () {
      expect(PaneLayout.storageKey, 'gloss.panes.v1');
      expect(
        PaneLayout.storageKey.startsWith(StorageService.keyPrefix),
        isTrue,
      );
    });
  });
}
