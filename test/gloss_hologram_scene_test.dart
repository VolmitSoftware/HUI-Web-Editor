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
      final HologramBillboardPlacement? placement = hologramBillboardPlacement(
        basis: _basis(),
        anchor: _doc().anchor,
        viewportWidth: 800,
        viewportHeight: 600,
      );
      expect(placement, isNotNull);
      expect(placement!.x, closeTo(400, 1e-6));
      expect(placement.y, closeTo(300, 1e-6));
      expect(placement.distance, closeTo(6, 1e-9));
      expect(placement.pxPerBlock, closeTo(huiPreviewPerspectivePx / 6, 1e-9));
    });

    test('an anchor behind the camera projects to null', () {
      final CameraBasis basis = CameraBasis.orbit(
        const OrbitCamera(target: PVec3(0, 64, 0), yawDegrees: 0, distance: 4),
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

  group('billboard orientation', () {
    // The default stage camera: yaw 180 puts it on the +z side of the anchor
    // looking back along -z, which is the reading position for a display at
    // Minecraft yaw 0 (south).
    CameraBasis south({double distance = 6}) => CameraBasis.orbit(
      OrbitCamera(
        target: const PVec3(0, 64, 0),
        yawDegrees: 180,
        pitchDegrees: 0,
        distance: distance,
      ),
    );

    CameraBasis north() => CameraBasis.orbit(
      const OrbitCamera(
        target: PVec3(0, 64, 0),
        yawDegrees: 0,
        pitchDegrees: 0,
        distance: 6,
      ),
    );

    HologramPlaneTransform transformFor(
      GlossHologramDoc doc,
      CameraBasis basis,
    ) {
      final HologramBillboardPlacement? placement = hologramBillboardPlacement(
        basis: basis,
        anchor: doc.anchor,
        viewportWidth: 800,
        viewportHeight: 600,
      );
      expect(placement, isNotNull);
      return hologramPlaneTransform(
        basis: basis,
        doc: doc,
        placement: placement!,
        viewportWidth: 800,
        viewportHeight: 600,
      );
    }

    test('the normal follows Minecraft, not the menu authoring frame', () {
      final PVec3 southFacing = glossDisplayNormal(yawDegrees: 0);
      expect(southFacing.x, closeTo(0, 1e-9));
      expect(southFacing.z, closeTo(1, 1e-9));
      // Yaw 90 is west, which is -x in world coordinates. huiLookDirection
      // would answer +x here because it mirrors for the authoring frame.
      expect(glossDisplayNormal(yawDegrees: 90).x, closeTo(-1, 1e-9));
      expect(glossDisplayNormal(pitchDegrees: 90, yawDegrees: 0).y,
          closeTo(-1, 1e-9));
    });

    test('each mode keeps exactly the axes the client does not solve', () {
      final GlossHologramDoc doc = _doc()
        ..yaw = 30
        ..pitch = 20;

      doc.billboard = 'FIXED';
      HologramFacing facing = hologramFacing(basis: south(), doc: doc);
      expect(facing.tracksYaw, isFalse);
      expect(facing.tracksPitch, isFalse);
      expect(facing.yawDegrees, 30);
      expect(facing.pitchDegrees, 20);

      doc.billboard = 'VERTICAL';
      facing = hologramFacing(basis: south(), doc: doc);
      expect(facing.tracksYaw, isTrue);
      expect(facing.tracksPitch, isFalse);
      expect(facing.pitchDegrees, 20);
      expect(facing.yawDegrees, closeTo(0, 1e-6), reason: 'camera is south');

      doc.billboard = 'HORIZONTAL';
      facing = hologramFacing(basis: south(), doc: doc);
      expect(facing.tracksYaw, isFalse);
      expect(facing.tracksPitch, isTrue);
      expect(facing.yawDegrees, 30);
      expect(facing.pitchDegrees, closeTo(0, 1e-6));

      doc.billboard = 'CENTER';
      facing = hologramFacing(basis: south(), doc: doc);
      expect(facing.tracksYaw, isTrue);
      expect(facing.tracksPitch, isTrue);
    });

    test('CENTER is the identity from anywhere, as it always was', () {
      final GlossHologramDoc doc = _doc();
      for (final CameraBasis basis in <CameraBasis>[
        south(),
        north(),
        CameraBasis.orbit(
          const OrbitCamera(
            target: PVec3(0, 64, 0),
            yawDegrees: 55,
            pitchDegrees: -35,
            distance: 9,
          ),
        ),
      ]) {
        final HologramPlaneTransform plane = transformFor(doc, basis);
        expect(plane.a, closeTo(1, 1e-6));
        expect(plane.b, closeTo(0, 1e-6));
        expect(plane.c, closeTo(0, 1e-6));
        expect(plane.d, closeTo(1, 1e-6));
        expect(plane.isMirrored, isFalse);
      }
    });

    test('FIXED reads forwards from the front and mirrored from behind', () {
      final GlossHologramDoc doc = _doc()
        ..billboard = 'FIXED'
        ..yaw = 0;

      final HologramPlaneTransform front = transformFor(doc, south());
      expect(front.a, closeTo(1, 1e-6));
      expect(front.d, closeTo(1, 1e-6));
      expect(front.isMirrored, isFalse);

      final HologramPlaneTransform back = transformFor(doc, north());
      expect(back.a, closeTo(-1, 1e-6));
      expect(back.d, closeTo(1, 1e-6));
      expect(back.isMirrored, isTrue);
    });

    test('FIXED seen from the side thins out to nothing', () {
      final GlossHologramDoc doc = _doc()
        ..billboard = 'FIXED'
        ..yaw = 90;

      final HologramPlaneTransform edge = transformFor(doc, south());

      expect(edge.faceCoverage, closeTo(0, 1e-6));
      expect(edge.isEdgeOn, isTrue);
      expect(transformFor(_doc(), south()).isEdgeOn, isFalse);
    });

    test('VERTICAL keeps its pitch while CENTER does not', () {
      final GlossHologramDoc doc = _doc()
        ..billboard = 'VERTICAL'
        ..pitch = 45;
      final CameraBasis basis = CameraBasis.orbit(
        const OrbitCamera(
          target: PVec3(0, 64, 0),
          yawDegrees: 180,
          pitchDegrees: 0,
          distance: 6,
        ),
      );

      final HologramPlaneTransform tilted = transformFor(doc, basis);
      expect(tilted.faceCoverage, lessThan(1));
      expect(tilted.a, closeTo(1, 1e-6), reason: 'yaw still tracks the camera');

      doc.billboard = 'CENTER';
      expect(transformFor(doc, basis).faceCoverage, closeTo(1, 1e-6));
    });

    test('the readout names the mode and what one camera cannot show', () {
      expect(hologramBillboardNote('FIXED'), contains('mirrored'));
      expect(
        hologramBillboardNote('VERTICAL'),
        contains('this camera only'),
      );
      expect(
        hologramBillboardNote('HORIZONTAL'),
        contains('this camera only'),
      );
      expect(hologramBillboardNote('CENTER'), contains('every viewer'));
      expect(hologramBillboardNote('SPIN'), contains('not a mode'));
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
      expect(
        segments.length,
        expected,
        reason: 'every line survives a camera above the plane',
      );
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

  test('reframing follows a randomized anchor without losing the orbit', () {
    const OrbitCamera authored = OrbitCamera(
      target: PVec3(2, 65, 1),
      yawDegrees: 137,
      pitchDegrees: -31,
      distance: 9,
    );
    final GlossHologramDoc moved = GlossHologramDoc(
      anchor: GlossHologramAnchor(
        world: 'world',
        positionRaw: <num>[120, 82, -45],
      ),
      lines: <String>['one', 'two', 'three', 'four'],
    );
    final OrbitCamera reframed = reframeHologramCamera(
      authored,
      hologramDefaultCamera(_doc()).target,
      moved,
    );

    expect(reframed.target, const PVec3(122, 83.25, -44));
    expect(reframed.yawDegrees, authored.yawDegrees);
    expect(reframed.pitchDegrees, authored.pitchDegrees);
    expect(reframed.distance, authored.distance);
  });

  test('authored time expressions keep the hologram ticker active', () {
    final GlossHologramDoc doc = GlossHologramDoc(
      lines: <String>["{{ select(['&c', '&b'], time.seconds) }}Live"],
    );
    expect(hologramIsAnimated(doc, const GlossNoAnimations()), isTrue);
  });
}
