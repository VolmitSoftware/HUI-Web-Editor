import 'package:gloss_editor/logic/gloss_particle_preview.dart';
import 'package:gloss_editor/logic/gloss_particle_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('particle text layout', () {
    test('matches runtime character and line geometry', () {
      final GlossParticleRect text = glossParticleTextBounds('AB\nC', 2);
      final List<GlossParticleRect> lines = glossParticleLineBounds('AB\nC', 2);

      expect(text.width, closeTo(0.4, 1.0E-9));
      expect(text.height, closeTo(1.04, 1.0E-9));
      expect(lines, hasLength(2));
      expect(lines[0].width, closeTo(0.4, 1.0E-9));
      expect(lines[0].y, closeTo(0.26, 1.0E-9));
      expect(lines[1].width, closeTo(0.2, 1.0E-9));
      expect(lines[1].y, closeTo(-0.26, 1.0E-9));
    });

    test('skips legacy formatting while preserving span source indices', () {
      const GlossParticleTextRendered rendered = GlossParticleTextRendered(
        text: 'A§cBC',
        spans: <GlossParticleTextSpan>[
          GlossParticleTextSpan(name: 'green', start: 3, end: 5),
        ],
      );

      final List<GlossParticleRect> grouped = glossParticleSpanBounds(
        rendered,
        'green',
        1,
        perLetter: false,
      );
      final List<GlossParticleRect> letters = glossParticleSpanBounds(
        rendered,
        'green',
        1,
        perLetter: true,
      );

      expect(grouped, hasLength(1));
      expect(grouped.single.width, closeTo(0.2, 1.0E-9));
      expect(grouped.single.x, closeTo(0.05, 1.0E-9));
      expect(letters, hasLength(2));
    });

    test('matches runtime handling of authored ampersand colors', () {
      const GlossParticleTextRendered rendered = GlossParticleTextRendered(
        text: '&4GREEN',
        spans: <GlossParticleTextSpan>[
          GlossParticleTextSpan(name: 'green', start: 0, end: 7),
        ],
      );

      final List<GlossParticleRect> letters = glossParticleSpanBounds(
        rendered,
        'green',
        1,
        perLetter: true,
      );

      expect(letters, hasLength(5));
      expect(
        glossParticleTextBounds(rendered.text, 1).width,
        closeTo(0.5, 1.0E-9),
      );
    });
  });

  group('particle geometry preview', () {
    test('samples outlines with runtime edge de-duplication', () {
      final GlossParticleGeometry geometry = GlossParticleGeometry(
        type: 'outline',
        spacing: 1,
      );
      final List<Vec3> points = glossSampleParticleGeometry(
        geometry,
        const <GlossParticleRect>[GlossParticleRect.plane(2, 2)],
      );

      expect(points, hasLength(9));
      expect(points.first, Vec3(-1, -1, 0));
      expect(points.last, Vec3(-1, -1, 0));
    });

    test('samples explicit lines independently of target bounds', () {
      final GlossParticleGeometry geometry = GlossParticleGeometry(
        type: 'line',
        from: Vec3(0, 0, 0),
        to: Vec3(1, 0, 0),
        spacing: 0.4,
      );

      final List<Vec3> points = glossSampleParticleGeometry(
        geometry,
        const <GlossParticleRect>[],
      );

      expect(points, hasLength(4));
      expect(points[1].x, closeTo(1 / 3, 1.0E-9));
      expect(points.last, Vec3(1, 0, 0));
    });

    test('selects chase, pulse, and corners by runtime phase', () {
      final List<Vec3> samples = <Vec3>[
        for (int index = 0; index < 10; index++) Vec3(index.toDouble(), 0, 0),
      ];

      expect(
        glossSelectParticlePattern(
          samples,
          GlossParticleEmission(pattern: 'chase', periodTicks: 10),
          5,
        ).single.x,
        5,
      );
      expect(
        glossSelectParticlePattern(
          samples,
          GlossParticleEmission(pattern: 'pulse', periodTicks: 10),
          5,
        ),
        isEmpty,
      );
      expect(
        glossSelectParticlePattern(
          samples,
          GlossParticleEmission(pattern: 'corners'),
          0,
        ).map((Vec3 point) => point.x),
        <double>[0, 3, 6, 9],
      );
    });
  });
}
