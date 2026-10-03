import 'hui_component.dart';
import 'json_codec.dart';
import 'particle_layer.dart';
import 'vec3.dart';

/// `MenuDefinitionData.MAX_DISTANCE` — the clamp ceiling and the effective
/// default when `maxDistance` is absent.
const double huiMaxDistanceCeiling = 6e7;

class HuiMenu {
  /// Menu centre relative to the player's feet, in blocks (right, up, forward).
  Vec3 offset;
  bool lockPosition;
  bool followPlayer;

  /// Null means "not written" — the plugin then treats it as unlimited (6e7).
  double? maxDistance;
  bool closeOnDeath;
  bool closeOnTeleport;
  List<HuiComponent> components;
  List<HuiMenuVariant> variants;
  List<GlossParticleLayer> particleLayers;
  bool particleLayersPresent = false;
  Map<String, dynamic> extras = <String, dynamic>{};

  /// Hard-required keys that were absent from the decoded JSON and had to be
  /// defaulted. Never serialized: it exists so validation can tell the user the
  /// imported file was missing a field the plugin NPEs on, instead of silently
  /// repairing it. Cleared by any re-decode, since the repaired document does
  /// carry the key.
  Set<String> absentKeys = <String>{};

  HuiMenu({
    Vec3? offset,
    this.lockPosition = false,
    this.followPlayer = false,
    this.maxDistance,
    this.closeOnDeath = false,
    this.closeOnTeleport = false,
    List<HuiComponent>? components,
    List<HuiMenuVariant>? variants,
    List<GlossParticleLayer>? particleLayers,
  }) : offset = offset ?? Vec3.zero(),
       components = components ?? <HuiComponent>[],
       variants = variants ?? <HuiMenuVariant>[],
       particleLayers = particleLayers ?? <GlossParticleLayer>[];

  HuiComponent? componentById(String id) {
    for (final HuiComponent component in components) {
      if (component.id == id) return component;
    }
    return null;
  }

  int indexOfComponent(String id) =>
      components.indexWhere((HuiComponent c) => c.id == id);

  HuiMenu copy() {
    final HuiMenu copied = HuiMenu(
      offset: offset.copy(),
      lockPosition: lockPosition,
      followPlayer: followPlayer,
      maxDistance: maxDistance,
      closeOnDeath: closeOnDeath,
      closeOnTeleport: closeOnTeleport,
      components: components.map((HuiComponent c) => c.copy()).toList(),
      particleLayers: glossCopyParticleLayers(particleLayers),
      variants: <HuiMenuVariant>[
        for (final HuiMenuVariant variant in variants) variant.copy(),
      ],
    );
    copied.extras = huiDeepCopyMap(extras);
    copied.particleLayersPresent = particleLayersPresent;
    return copied;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'offset': offset.toJson(),
      'lockPosition': lockPosition,
      'followPlayer': followPlayer,
    };
    if (maxDistance != null) out['maxDistance'] = maxDistance;
    out['closeOnDeath'] = closeOnDeath;
    out['closeOnTeleport'] = closeOnTeleport;
    out['components'] = components.map((HuiComponent c) => c.toJson()).toList();
    if (variants.isNotEmpty) {
      out['variants'] = <Map<String, Object?>>[
        for (final HuiMenuVariant variant in variants) variant.toJson(),
      ];
    }
    if (particleLayersPresent || particleLayers.isNotEmpty) {
      out['particleLayers'] = glossWriteParticleLayers(particleLayers);
    }
    return huiMergeExtras(out, extras);
  }

  // `id` is consumed and discarded: the plugin overwrites it with the file base
  // name immediately after parsing, so it must never be re-emitted.
  static const Set<String> _known = <String>{
    'offset',
    'lockPosition',
    'followPlayer',
    'maxDistance',
    'closeOnDeath',
    'closeOnTeleport',
    'components',
    'variants',
    'particleLayers',
    'id',
  };

  static HuiMenu fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    final List<Object?> rawComponents = huiReadList(map['components']);
    final List<HuiComponent> components = <HuiComponent>[];
    for (int i = 0; i < rawComponents.length; i++) {
      final Object? entry = rawComponents[i];
      if (entry == null) continue;
      components.add(HuiComponent.fromJson(entry, path: 'components[$i]'));
    }
    final HuiMenu menu = HuiMenu(
      offset: Vec3.fromJson(map['offset']),
      lockPosition: huiReadBool(map, 'lockPosition'),
      followPlayer: huiReadBool(map, 'followPlayer'),
      maxDistance: huiReadDoubleOrNull(map, 'maxDistance'),
      closeOnDeath: huiReadBool(map, 'closeOnDeath'),
      closeOnTeleport: huiReadBool(map, 'closeOnTeleport'),
      components: components,
      variants: <HuiMenuVariant>[
        for (final Object? variant in huiReadList(map['variants']))
          HuiMenuVariant.fromJson(variant),
      ],
      particleLayers: glossReadParticleLayers(map['particleLayers']),
    );
    menu.extras = huiCollectExtras(map, _known);
    menu.absentKeys = <String>{
      if (map['offset'] == null) 'offset',
      if (map['components'] == null) 'components',
    };
    menu.particleLayersPresent = map.containsKey('particleLayers');
    return menu;
  }
}

class HuiMenuVariant {
  HuiMenuVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'true',
    List<HuiComponent>? components,
    this.particleLayers,
    Map<String, Object?>? extras,
  }) : components = components ?? <HuiComponent>[],
       extras = extras ?? <String, Object?>{};
  String id;
  int priority;
  Object? when;
  List<HuiComponent> components;
  List<GlossParticleLayer>? particleLayers;
  Map<String, Object?> extras;

  static HuiMenuVariant fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return HuiMenuVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: map['when'],
      components: <HuiComponent>[
        for (final Object? component in huiReadList(map['components']))
          HuiComponent.fromJson(component),
      ],
      particleLayers: map['particleLayers'] == null
          ? null
          : glossReadParticleLayers(map['particleLayers']),
      extras: huiCollectExtras(map, <String>{
        'id',
        'priority',
        'when',
        'components',
        'particleLayers',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'id': id,
    'priority': priority,
    'when': when,
    'components': <Map<String, Object?>>[
      for (final HuiComponent component in components) component.toJson(),
    ],
    if (particleLayers != null)
      'particleLayers': glossWriteParticleLayers(particleLayers!),
  }, extras);

  HuiMenuVariant copy() => HuiMenuVariant.fromJson(huiDeepCopy(toJson()));
}
