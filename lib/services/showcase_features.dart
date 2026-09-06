library;

import 'dart:math' as math;

import '../config/showcase_flavor.dart';
import '../model/model.dart';
import '../model/runtime_panel_definition.dart';
import '../model/gloss_hologram_box.dart';
import 'showcase_effects.dart';

/// A display style a server would actually run: readable opacity, one
/// uniform scale, a line width that fits a sentence, no lighting or culling
/// surprises. Variety comes from the billboard, the plate colour and the
/// scale; the exotic knobs stay at their defaults so a randomized document
/// reads as a finished one rather than a stress test.
HuiIconStyle showcaseDisplayStyle(math.Random random, ShowcaseMood mood) {
  final double scale = _number(random, 0.85, 1.35);
  final int roll = random.nextInt(10);
  final String billboard = roll < 5
      ? 'center'
      : roll < 8
      ? 'vertical'
      : roll < 9
      ? 'fixed'
      : 'horizontal';
  return HuiIconStyle(
    billboard: billboard,
    shadow: random.nextInt(4) != 0,
    seeThrough: random.nextInt(5) == 0,
    textAlignment: random.nextInt(4) == 0
        ? showcasePick(random, huiIconTextAlignments)
        : 'center',
    backgroundArgb: showcasePick(random, <String>[
      '#40000000',
      '#66000000',
      '#80${mood.primary.substring(1)}',
      '#4D${mood.secondary.substring(1)}',
    ]),
    textOpacity: 255,
    lineWidth: showcasePick(random, <int>[200, 240, 320]),
    viewRange: _number(random, 1, 1.5),
    shadowRadius: random.nextInt(3) == 0 ? _number(random, 0.2, 0.6) : 0,
    shadowStrength: _number(random, 0.6, 1),
    cullingWidth: 0,
    cullingHeight: 0,
    glowColor: random.nextInt(6) == 0 ? '#FF${mood.primary.substring(1)}' : null,
    scaleX: scale,
    scaleY: scale,
    scaleZ: scale,
  );
}

String showcaseRichText(math.Random random, ShowcaseMood mood, String text) {
  final String rich = switch (random.nextInt(8)) {
    0 => '<gradient:${mood.primary}:${mood.secondary}>$text</gradient>',
    1 => '<rainbow>$text</rainbow>',
    2 => '<bold><${mood.primary}>$text</${mood.primary}></bold>',
    3 => '<bold><${mood.secondary}>$text</${mood.secondary}></bold>',
    4 => '${showcaseColorEffect(random, mood).text}$text',
    5 => '${mood.legacy}&l$text',
    6 => '${mood.legacy}$text',
    _ => '&f$text',
  };
  return '<particles:highlight>$rich</particles>';
}

List<GlossParticleLayer> showcaseParticleLayers(
  math.Random random,
  ShowcaseMood mood, {
  required List<String> scopes,
  String? componentId,
  String spanName = 'highlight',
  int lineCount = 1,
  int? count,
}) {
  final List<GlossParticleLayer> layers = <GlossParticleLayer>[];
  final int length = count ?? 1 + random.nextInt(4);
  for (int index = 0; index < length; index++) {
    final String scope = showcasePick(random, scopes);
    final bool textGeometry = scope != 'local' && scope != 'model';
    final String geometry = showcasePick(
      random,
      textGeometry
          ? glossParticleGeometryTypes
          : glossParticleGeometryTypes.take(6).toList(),
    );
    final double width = _number(random, 0.25, 2.5);
    final double height = _number(random, 0.15, 1.4);
    final String key = showcasePick(random, <String>[
      'minecraft:dust',
      'minecraft:soul',
      'minecraft:end_rod',
      'minecraft:enchanted_hit',
      'minecraft:portal',
    ]);
    layers.add(
      GlossParticleLayer(
        id: 'particle-${index + 1}',
        target: GlossParticleTarget(
          scope: scope,
          component: scope == 'component' ? componentId : null,
          name: scope == 'span' ? spanName : null,
          line: scope == 'line'
              ? 1 + random.nextInt(math.max(1, lineCount))
              : null,
        ),
        geometry: GlossParticleGeometry(
          type: geometry,
          from: geometry == 'line' || geometry == 'point'
              ? Vec3(-width / 2, -height / 2, 0)
              : null,
          to: geometry == 'line' ? Vec3(width / 2, height / 2, 0) : null,
          points: geometry == 'polyline'
              ? <Vec3>[
                  Vec3(-width / 2, 0, 0),
                  Vec3(0, height / 2, 0),
                  Vec3(width / 2, 0, 0),
                  Vec3(0, -height / 2, 0),
                  Vec3(-width / 2, 0, 0),
                ]
              : null,
          width: scope == 'local' || random.nextBool() ? width : null,
          height: scope == 'local' || random.nextBool() ? height : null,
          depth: geometry == 'cuboid' ? _number(random, 0.1, 1) : null,
          padding: _number(random, 0, 0.2),
          spacing: _number(random, 0.07, 0.3),
        ),
        placement: GlossParticlePlacement(
          layer: showcasePick(random, glossParticlePlacementLayers),
          depth: _number(random, 0, 0.2),
          offset: Vec3(
            _number(random, -0.15, 0.15),
            _number(random, -0.15, 0.15),
            _number(random, -0.15, 0.15),
          ),
        ),
        particle: GlossParticleSpec(
          key: key,
          color: key == 'minecraft:dust'
              ? showcasePick(random, <String>[mood.primary, mood.secondary])
              : null,
          size: key == 'minecraft:dust' ? _number(random, 0.4, 2.4) : null,
        ),
        emission: GlossParticleEmission(
          pattern: showcasePick(random, glossParticleEmissionPatterns),
          intervalTicks: 1 + random.nextInt(6),
          periodTicks: 8 + random.nextInt(73),
          seed: random.nextInt(100000),
        ),
        priority: random.nextInt(21) - 10,
      ),
    );
  }
  return layers;
}

GlossEntityOverlaysDoc buildRandomEntityOverlayShowcase(
  GlossEntityOverlaysDoc current,
  math.Random random,
) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final List<GlossEntityOverlayLine> lines = defaultEntityOverlayLines();
  lines.first.text = showcaseRichText(random, mood, '{name}');
  final List<(String, String, String)> details = <(String, String, String)>[
    ('vitality', '&f{{ fixed(entity.healthPercent, 1) }}% &7vitality', 'true'),
    ('species', '&7{type} &8at &f{distance}m', 'entity.distance >= 0'),
    ('threat', '&cATK {attack} &8/ &bARM {armor}', 'entity.attack >= 0'),
    ('pack', '&6{{ entity.stackCount > 1 ? "PACK" : "SOLO" }}', 'true'),
    ('observer', '&7Observed by &f{{ player.name }}', 'true'),
    ('clock', '&8{{ fixed(time.seconds, 1) }}s', 'true'),
    ('alert', '&cTARGET STRUCK &f-{damage}', 'entity.damaged'),
    ('discovery', '&bDiscovery details available', 'insight.active'),
    ('distance', '&7{{ entity.distance < 8 ? "CLOSE" : "DISTANT" }}', 'true'),
  ]..shuffle(random);
  final int detailCount = 2 + random.nextInt(details.length - 1);
  for (int index = 0; index < detailCount; index++) {
    final (String, String, String) detail = details[index];
    lines.add(
      GlossEntityOverlayLine(
        id: detail.$1,
        text: showcaseRichText(random, mood, detail.$2),
        show: detail.$3,
      ),
    );
  }
  final int spacerCount = 1 + random.nextInt(3);
  for (int index = 0; index < spacerCount; index++) {
    lines.add(GlossEntityOverlayLine(id: 'spacer-$index', type: 'spacer'));
  }
  lines.shuffle(random);
  final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
    revision: current.revision,
    range: (8 + random.nextInt(57)).toDouble(),
    updateIntervalTicks: 1 + random.nextInt(20),
    maxEntitiesPerViewer: 16 + random.nextInt(241),
    includePlayers: random.nextBool(),
    verticalOffset: _number(random, -0.25, 1.5),
    healthSegments: 4 + random.nextInt(37),
    hitHighlightMs: showcasePick(random, <int>[0, 250, 500, 750, 1500, 3000]),
    blacklistWorlds: random.nextBool() ? <String>[] : <String>['quiet_world'],
    excludedEntityTypes: random.nextBool()
        ? <String>['ARMOR_STAND']
        : <String>['ARMOR_STAND', 'BAT'],
    show: showcasePick(random, <String>[
      'true',
      'entity.health > 0',
      'entity.distance <= 32',
      'entity.named || entity.healthPercent < 100',
    ]),
    lines: lines,
    style: showcaseDisplayStyle(random, mood),
    box: showcaseBox(random, mood),
    particleLayers: showcaseParticleLayers(
      random,
      mood,
      scopes: <String>['projection', 'text', 'line', 'span', 'local'],
      lineCount: 1,
    ),
  );
  return doc;
}

double _number(math.Random random, double minimum, double maximum) =>
    ((minimum + random.nextDouble() * (maximum - minimum)) * 100).round() / 100;

GlossHologramBox showcaseBox(math.Random random, ShowcaseMood mood) =>
    GlossHologramBox(
      enabled: random.nextInt(4) != 0,
      padding: random.nextInt(17),
      borderWidth: random.nextInt(5),
      backgroundArgb: showcasePick(random, <String>[
        '#00000000',
        '#E61B1B22',
        '#99${mood.primary.substring(1)}',
      ]),
      borderArgb: showcasePick(random, <String>[
        '#00FFFFFF',
        '#80${mood.secondary.substring(1)}',
        '#FF${mood.primary.substring(1)}',
      ]),
    );

Object showcaseShow(
  math.Random random, {
  bool viewerAware = true,
  bool allowHidden = false,
}) => showcasePick(random, <Object>[
  true,
  if (allowHidden) false,
  'server.online >= 0',
  'time.seconds >= 0',
  if (viewerAware) 'viewer.health > 0',
  if (viewerAware) "viewer.world != 'hidden_world'",
]);

RuntimePanelDefinition buildRandomRuntimePanelShowcase(
  RuntimePanelDefinition current,
  math.Random random,
) {
  final bool permission = random.nextBool();
  return current.copyWith(
    transform: current.transform.copyWith(
      x: current.transform.x.floorToDouble() + _number(random, 0.05, 0.95),
      y: current.transform.y.floorToDouble() + _number(random, 0.05, 0.95),
      z: current.transform.z.floorToDouble() + _number(random, 0.05, 0.95),
      yaw: _number(random, -180, 180),
      pitch: _number(random, -80, 80),
      roll: _number(random, -180, 180),
      scale: _number(random, 0.35, 2.5),
    ),
    follow: RuntimePanelFollow(
      mode: current.follow.targetPlayerUuid == null
          ? RuntimePanelFollowMode.none
          : RuntimePanelFollowMode.player,
      targetPlayerUuid: current.follow.targetPlayerUuid,
      rotation: current.follow.targetPlayerUuid == null
          ? RuntimePanelFollowRotation.fixed
          : showcasePick(random, RuntimePanelFollowRotation.values),
    ),
    visibility: RuntimePanelVisibility(
      mode: permission
          ? RuntimePanelVisibilityMode.permission
          : RuntimePanelVisibilityMode.public,
      viewPermission: permission ? 'gloss.panel.showcase.view' : null,
      interactPermission: random.nextBool() ? 'gloss.panel.showcase.use' : null,
      viewRange: _number(random, 8, 64),
      interactionRange: _number(random, 1, 6),
    ),
    show: showcaseShow(random, allowHidden: true),
  );
}
