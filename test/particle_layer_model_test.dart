import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/config/gloss_menu_json_schema.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/logic/particle_layer_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/gloss_bubble_style.dart';
import 'package:gloss_editor/model/gloss_damage_indicators.dart';
import 'package:gloss_editor/model/gloss_hologram.dart';
import 'package:gloss_editor/model/gloss_real_drops.dart';
import 'package:gloss_editor/model/hui_menu.dart';
import 'package:gloss_editor/model/particle_layer.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:gloss_editor/model/vec3.dart';
import 'package:test/test.dart';

GlossParticleLayer _layer() => GlossParticleLayer(
  id: 'green-word',
  target: GlossParticleTarget(scope: 'span', name: 'green'),
  geometry: GlossParticleGeometry(
    type: 'glyphFill',
    points: <Vec3>[Vec3(0, 0, 0), Vec3(1, 1, 0)],
    padding: 0.02,
    spacing: 0.06,
    extras: <String, dynamic>{'geometryFuture': true},
  ),
  placement: GlossParticlePlacement(
    layer: 'behind',
    depth: 0.04,
    offset: Vec3(0, 0, 0.01),
  ),
  particle: GlossParticleSpec(
    key: 'minecraft:dust',
    color: '#00ff00',
    size: 0.7,
  ),
  emission: GlossParticleEmission(
    intervalTicks: 2,
    pattern: 'pulse',
    periodTicks: 30,
    seed: 42,
  ),
  priority: 12,
  extras: <String, dynamic>{
    'future': <String>['kept'],
  },
);

void main() {
  test('particle layer round-trips every canonical field and extras', () {
    final GlossParticleLayer layer = _layer();
    final Map<String, dynamic> json = layer.toJson();
    final GlossParticleLayer decoded = GlossParticleLayer.fromJson(json, 0);

    expect(decoded.toJson(), json);
    expect(decoded.target.name, 'green');
    expect(decoded.geometry.points, <Vec3>[Vec3(0, 0, 0), Vec3(1, 1, 0)]);
    expect(decoded.placement.signedDepth, 0.04);
    expect(decoded.extras['future'], <String>['kept']);

    final GlossParticleLayer copied = decoded.copy();
    copied.geometry.points.first.x = 99;
    (copied.extras['future'] as List<dynamic>).add('changed');
    expect(decoded.geometry.points.first.x, 0);
    expect(decoded.extras['future'], <String>['kept']);
  });

  test('defaults match ParticleLayer Java compact constructors', () {
    final GlossParticleLayer layer = GlossParticleLayer.fromJson(
      <String, dynamic>{
        'id': 'frame',
        'target': <String, dynamic>{'scope': 'projection'},
        'geometry': <String, dynamic>{'type': 'outline'},
        'particle': <String, dynamic>{'key': 'minecraft:dust'},
      },
      0,
    );

    expect(layer.geometry.padding, 0);
    expect(layer.geometry.spacing, 0.15);
    expect(layer.placement.layer, 'behind');
    expect(layer.placement.depth, 0.04);
    expect(layer.placement.offset, Vec3.zero());
    expect(layer.particle.color, '#ffffff');
    expect(layer.particle.size, 1);
    expect(layer.emission.intervalTicks, 4);
    expect(layer.emission.pattern, 'steady');
    expect(layer.emission.periodTicks, 40);
    expect(layer.emission.seed, 0);
  });

  test('all requested in-world document roots own particle layers', () {
    final List<GlossParticleLayer> layers = <GlossParticleLayer>[_layer()];
    final GlossDamageIndicatorPresentation damage =
        GlossDamageIndicatorPresentation.damageDefaults()
          ..particleLayers = glossCopyParticleLayers(layers);
    final List<Map<String, dynamic>> owners = <Map<String, dynamic>>[
      HuiMenu(particleLayers: layers).toJson(),
      GlossHologramDoc(particleLayers: layers).toJson(),
      GlossBubbleStyleDoc(particleLayers: layers).toJson(),
      damage.toJson(),
      GlossRealDropPresentation(particleLayers: layers).toJson(),
      HuiPreviewDoc(particleLayers: layers).toJson(),
    ];

    for (final Map<String, dynamic> owner in owners) {
      expect(owner['particleLayers'], hasLength(1));
    }
  });

  test('validation enforces hard constraints and reports runtime clamps', () {
    final GlossParticleLayer invalid = _layer()
      ..id = 'bad id'
      ..target = GlossParticleTarget(scope: 'line', line: 0)
      ..geometry = GlossParticleGeometry(type: 'polyline')
      ..placement.depth = 17
      ..particle = GlossParticleSpec(
        key: 'minecraft:soul',
        color: '#00ff00',
        size: 1,
      )
      ..emission.intervalTicks = 0
      ..priority = 1001;
    final List<HuiIssue> issues = validateParticleLayers(<GlossParticleLayer>[
      invalid,
    ]);
    final Set<String> errors = <String>{
      for (final HuiIssue issue in issues)
        if (issue.severity == HuiSeverity.error) issue.path,
    };
    final Set<String> warnings = <String>{
      for (final HuiIssue issue in issues)
        if (issue.severity == HuiSeverity.warning) issue.path,
    };

    expect(
      errors,
      containsAll(<String>{
        'particleLayers[0].id',
        'particleLayers[0].target.line',
        'particleLayers[0].geometry.points',
        'particleLayers[0].placement.depth',
        'particleLayers[0].particle.color',
        'particleLayers[0].particle.size',
      }),
    );
    expect(
      warnings,
      containsAll(<String>{
        'particleLayers[0].emission.intervalTicks',
        'particleLayers[0].priority',
      }),
    );
  });

  test('validation detects normalized duplicate ids and the 64-layer cap', () {
    final List<GlossParticleLayer> layers = <GlossParticleLayer>[
      _layer()..id = 'same',
      _layer()..id = ' SAME ',
      for (int index = 2; index < 65; index++) _layer()..id = 'layer-$index',
    ];
    final List<HuiIssue> issues = validateParticleLayers(layers);
    expect(
      issues.where((HuiIssue issue) => issue.path == 'particleLayers'),
      hasLength(1),
    );
    expect(
      issues.where((HuiIssue issue) => issue.path == 'particleLayers[1].id'),
      hasLength(1),
    );
  });

  test(
    'schema descriptors expose particle fields on every code-view owner',
    () {
      for (final GlossJsonObject root in <GlossJsonObject>[
        glossMenuJsonSchema,
        glossHologramJsonSchema,
        glossBubbleStyleJsonSchema,
      ]) {
        expect(
          root.field('particleLayers')?.node,
          same(glossParticleLayersNode),
        );
      }
      expect(
        glossJsonNodeAt(glossRealDropsJsonSchema, const <JsonPathStep>[
          JsonPathStep.key('presentation'),
        ]),
        isA<GlossJsonObject>().having(
          (GlossJsonObject node) => node.field('particleLayers')?.node,
          'particle layers',
          same(glossParticleLayersNode),
        ),
      );
      expect(
        glossJsonNodeAt(glossDamageIndicatorsJsonSchema, const <JsonPathStep>[
          JsonPathStep.key('damage'),
          JsonPathStep.key('presentation'),
        ]),
        isA<GlossJsonObject>().having(
          (GlossJsonObject node) => node.field('particleLayers')?.node,
          'particle layers',
          same(glossParticleLayersNode),
        ),
      );
    },
  );
}
