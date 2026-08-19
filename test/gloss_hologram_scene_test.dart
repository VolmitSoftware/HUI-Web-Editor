/// The hologram stage's DOM-free geometry: billboard projection, ground-grid
/// segments and the animation gate.
library;

import 'package:gloss_editor/logic/gloss_hologram_scene.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/preview/preview_types.dart';
import 'package:gloss_editor/preview/projection.dart';
import 'package:test/test.dart';

final class _Animations implements GlossAnimationResolver {
  _Animations(this.docs);

  final Map<String, GlossAnimationDoc> docs;

  @override
  List<String> get ids => docs.keys.toList()..sort();

  @override
  GlossAnimationDoc? byId(String id) => docs[id];
}

GlossHologramDoc _doc({List<String>? lines}) => GlossHologramDoc(
  anchor: GlossHologramAnchor(world: 'world', positionRaw: <num>[0, 64, 0]),
  lines: lines ?? <String>['&fone', '&7two'],
);

CameraBasis _basis() => CameraBasis.orbit(
  const OrbitCamera(
    target: PVec3(0, 64, 0),
    yawDegrees: 180,
    pitchDegrees: 0,
    distance: 6,
  ),
);

void main() {
  test('the stack metrics are the vanilla TextDisplay constants', () {
    expect(glossTextBlocksPerPixel, 1 / 40);
    expect(glossHologramLineHeightBlocks, 0.25);
    expect(glossHologramViewRangeBaseBlocks, 64);
  });

  group('billboard placement', () {
    test('an anchor dead ahead lands at the viewport centre', () {
      final HologramBillboardPlacement? placement =
          hologramBillboardPlacement(
        basis: _basis(),
        anchor: _doc().anchor,
        viewportWidth: 800,
        viewportHeight: 600,
      );
      expect(placement, isNotNull);
      expect(placement!.x, closeTo(400, 1e-6));
      expect(placement.y, closeTo(300, 1e-6));
      expect(placement.distance, closeTo(6, 1e-9));
      expect(
        placement.pxPerBlock,
        closeTo(huiPreviewPerspectivePx / 6, 1e-9),
      );
    });

    test('an anchor behind the camera projects to null', () {
      final CameraBasis basis = CameraBasis.orbit(
        const OrbitCamera(
          target: PVec3(0, 64, 0),
          yawDegrees: 0,
          distance: 4,
        ),
      );
      // Looking along +z from behind the target: a point far behind the
      // camera position.
      final GlossHologramAnchor behind = GlossHologramAnchor(
        world: 'world',
        positionRaw: <num>[0, 64, -100],
      );
      expect(
        hologramBillboardPlacement(
          basis: basis,
          anchor: behind,
          viewportWidth: 800,
          viewportHeight: 600,
        ),
        isNull,
      );
    });
  });

  group('ground grid', () {
    test('draws both axes over the snapped anchor at the anchor height', () {
      final List<HologramGridSegment> segments = hologramGroundSegments(
        basis: CameraBasis.orbit(
          const OrbitCamera(
            target: PVec3(0, 64, 0),
            yawDegrees: 180,
            pitchDegrees: 45,
            distance: 12,
          ),
        ),
        anchor: _doc().anchor,
        viewportWidth: 800,
        viewportHeight: 600,
      );
      const int expected = (glossHologramGridRadiusBlocks * 2 + 1) * 2;
      expect(segments.length, expected,
          reason: 'every line survives a camera above the plane');
      expect(
        segments.where((HologramGridSegment s) => s.throughAnchor).length,
        2,
      );
    });

    test('drops segments the camera cannot see', () {
      final List<HologramGridSegment> segments = hologramGroundSegments(
        basis: CameraBasis.orbit(
          // Standing almost on the plane looking straight ahead: much of the
          // grid is behind the camera.
          const OrbitCamera(
            target: PVec3(0, 64, 0),
            yawDegrees: 180,
            pitchDegrees: 0,
            distance: 2,
          ),
        ),
        anchor: _doc().anchor,
        viewportWidth: 800,
        viewportHeight: 600,
      );
      const int all = (glossHologramGridRadiusBlocks * 2 + 1) * 2;
      expect(segments.length, lessThan(all));
    });
  });

  group('rendered lines and the animation gate', () {
    test('lines render in document order, top first', () {
      final List<GlossLineRender> lines = hologramRenderedLines(_doc());
      expect(lines, hasLength(2));
      expect(lines[0].plainText, 'one');
      expect(lines[1].plainText, 'two');
    });

    test('the gate trips only on satisfied references', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'x': GlossAnimationDoc(frames: <String>['*']),
      });
      expect(
        hologramIsAnimated(
          _doc(lines: <String>['static', '|animation.x|']),
          animations,
        ),
        isTrue,
      );
      expect(
        hologramIsAnimated(
          _doc(lines: <String>['|animation.unknown|']),
          animations,
        ),
        isFalse,
        reason: 'a dangling reference renders literally and never ticks',
      );
    });
  });

  test('the default camera frames the stack midpoint', () {
    final OrbitCamera camera = hologramDefaultCamera(_doc());
    expect(camera.target.x, 0);
    expect(camera.target.z, 0);
    expect(
      camera.target.y,
      closeTo(64 + glossHologramLineHeightBlocks, 1e-9),
      reason: 'two lines: half the stack above the anchor',
    );
  });
}
