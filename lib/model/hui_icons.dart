import 'json_codec.dart';

/// The eight JSON-authorable icon types. `itemStack` exists in the plugin enum
/// but maps to a null class, so it is API-only and unparseable.
const List<String> huiIconTypes = <String>[
  'text',
  'textImage',
  'animatedTextImage',
  'item',
  'block',
  'customItem',
  'entity',
  'playerHead',
];

/// Provider ids the plugin ships adapters for, in declaration order. Runtime
/// `auto` resolution uses the order in which available providers activated.
/// These strings are part of the file format, not a UI list.
const List<String> huiCustomItemProviders = <String>[
  'craftengine',
  'itemsadder',
  'oraxen',
  'nexo',
  'mmoitems',
  'executableitems',
  'ecoitems',
  'slimefun',
  'mythicmobs',
  'headdatabase',
];

/// Sentinel `provider`: try every ready provider in activation order.
const String huiAutoItemProvider = 'auto';

const List<String> huiIconBillboards = <String>[
  'fixed',
  'vertical',
  'horizontal',
  'center',
];

const List<String> huiIconTextAlignments = <String>['center', 'left', 'right'];

const List<String> huiSpawnableLivingEntityTypes = <String>[
  'minecraft:allay',
  'minecraft:armadillo',
  'minecraft:armor_stand',
  'minecraft:axolotl',
  'minecraft:bat',
  'minecraft:bee',
  'minecraft:blaze',
  'minecraft:bogged',
  'minecraft:breeze',
  'minecraft:camel',
  'minecraft:camel_husk',
  'minecraft:cat',
  'minecraft:cave_spider',
  'minecraft:chicken',
  'minecraft:cod',
  'minecraft:copper_golem',
  'minecraft:cow',
  'minecraft:creaking',
  'minecraft:creeper',
  'minecraft:dolphin',
  'minecraft:donkey',
  'minecraft:drowned',
  'minecraft:elder_guardian',
  'minecraft:ender_dragon',
  'minecraft:enderman',
  'minecraft:endermite',
  'minecraft:evoker',
  'minecraft:fox',
  'minecraft:frog',
  'minecraft:ghast',
  'minecraft:giant',
  'minecraft:glow_squid',
  'minecraft:goat',
  'minecraft:guardian',
  'minecraft:happy_ghast',
  'minecraft:hoglin',
  'minecraft:horse',
  'minecraft:husk',
  'minecraft:illusioner',
  'minecraft:iron_golem',
  'minecraft:llama',
  'minecraft:magma_cube',
  'minecraft:mannequin',
  'minecraft:mooshroom',
  'minecraft:mule',
  'minecraft:nautilus',
  'minecraft:ocelot',
  'minecraft:panda',
  'minecraft:parched',
  'minecraft:parrot',
  'minecraft:phantom',
  'minecraft:pig',
  'minecraft:piglin',
  'minecraft:piglin_brute',
  'minecraft:pillager',
  'minecraft:polar_bear',
  'minecraft:pufferfish',
  'minecraft:rabbit',
  'minecraft:ravager',
  'minecraft:salmon',
  'minecraft:sheep',
  'minecraft:shulker',
  'minecraft:silverfish',
  'minecraft:skeleton',
  'minecraft:skeleton_horse',
  'minecraft:slime',
  'minecraft:sniffer',
  'minecraft:snow_golem',
  'minecraft:spider',
  'minecraft:squid',
  'minecraft:stray',
  'minecraft:strider',
  'minecraft:tadpole',
  'minecraft:trader_llama',
  'minecraft:tropical_fish',
  'minecraft:turtle',
  'minecraft:vex',
  'minecraft:villager',
  'minecraft:vindicator',
  'minecraft:wandering_trader',
  'minecraft:warden',
  'minecraft:witch',
  'minecraft:wither',
  'minecraft:wither_skeleton',
  'minecraft:wolf',
  'minecraft:zoglin',
  'minecraft:zombie',
  'minecraft:zombie_horse',
  'minecraft:zombie_nautilus',
  'minecraft:zombie_villager',
  'minecraft:zombified_piglin',
];

class HuiIconStyle {
  String billboard;
  bool shadow;
  bool seeThrough;
  String textAlignment;
  String backgroundArgb;
  int textOpacity;
  int lineWidth;
  int? blockLight;
  int? skyLight;
  double viewRange;
  double shadowRadius;
  double shadowStrength;
  double cullingWidth;
  double cullingHeight;
  String? glowColor;
  double scaleX;
  double scaleY;
  double scaleZ;
  Map<String, dynamic> extras;

  HuiIconStyle({
    this.billboard = 'fixed',
    this.shadow = false,
    this.seeThrough = false,
    this.textAlignment = 'center',
    this.backgroundArgb = '#00000000',
    this.textOpacity = 255,
    this.lineWidth = 2000,
    this.blockLight,
    this.skyLight,
    this.viewRange = 1,
    this.shadowRadius = 0,
    this.shadowStrength = 0,
    this.cullingWidth = 0,
    this.cullingHeight = 0,
    this.glowColor,
    this.scaleX = 1,
    this.scaleY = 1,
    this.scaleZ = 1,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool get hasBrightnessOverride => blockLight != null || skyLight != null;

  HuiIconStyle copy() => HuiIconStyle(
    billboard: billboard,
    shadow: shadow,
    seeThrough: seeThrough,
    textAlignment: textAlignment,
    backgroundArgb: backgroundArgb,
    textOpacity: textOpacity,
    lineWidth: lineWidth,
    blockLight: blockLight,
    skyLight: skyLight,
    viewRange: viewRange,
    shadowRadius: shadowRadius,
    shadowStrength: shadowStrength,
    cullingWidth: cullingWidth,
    cullingHeight: cullingHeight,
    glowColor: glowColor,
    scaleX: scaleX,
    scaleY: scaleY,
    scaleZ: scaleZ,
    extras: huiDeepCopyMap(extras),
  );

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'billboard': billboard,
    'shadow': shadow,
    'seeThrough': seeThrough,
    'textAlignment': textAlignment,
    'backgroundArgb': backgroundArgb,
    'textOpacity': textOpacity,
    'lineWidth': lineWidth,
    if (blockLight != null) 'blockLight': blockLight,
    if (skyLight != null) 'skyLight': skyLight,
    'viewRange': viewRange,
    'shadowRadius': shadowRadius,
    'shadowStrength': shadowStrength,
    'cullingWidth': cullingWidth,
    'cullingHeight': cullingHeight,
    if (glowColor != null) 'glowColor': glowColor,
    'scaleX': scaleX,
    'scaleY': scaleY,
    'scaleZ': scaleZ,
  }, extras);

  static HuiIconStyle? fromJsonOrNull(
    Object? raw, {
    String path = 'icon.style',
  }) {
    if (raw == null) return null;
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return HuiIconStyle(
      billboard: huiReadString(map, 'billboard', fallback: 'fixed'),
      shadow: huiReadBool(map, 'shadow'),
      seeThrough: huiReadBool(map, 'seeThrough'),
      textAlignment: huiReadString(map, 'textAlignment', fallback: 'center'),
      backgroundArgb: huiReadString(
        map,
        'backgroundArgb',
        fallback: '#00000000',
      ),
      textOpacity: huiReadInt(map, 'textOpacity', fallback: 255),
      lineWidth: huiReadInt(map, 'lineWidth', fallback: 2000),
      blockLight: _readOptionalInt(map, 'blockLight'),
      skyLight: _readOptionalInt(map, 'skyLight'),
      viewRange: huiReadDouble(map, 'viewRange', fallback: 1),
      shadowRadius: huiReadDouble(map, 'shadowRadius'),
      shadowStrength: huiReadDouble(map, 'shadowStrength'),
      cullingWidth: huiReadDouble(map, 'cullingWidth'),
      cullingHeight: huiReadDouble(map, 'cullingHeight'),
      glowColor: map['glowColor'] == null
          ? null
          : huiReadString(map, 'glowColor'),
      scaleX: huiReadDouble(map, 'scaleX', fallback: 1),
      scaleY: huiReadDouble(map, 'scaleY', fallback: 1),
      scaleZ: huiReadDouble(map, 'scaleZ', fallback: 1),
      extras: huiCollectExtras(map, _knownStyleKeys),
    );
  }

  static int? _readOptionalInt(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key) || map[key] == null) return null;
    return huiReadInt(map, key);
  }

  static const Set<String> _knownStyleKeys = <String>{
    'billboard',
    'shadow',
    'seeThrough',
    'textAlignment',
    'backgroundArgb',
    'textOpacity',
    'lineWidth',
    'blockLight',
    'skyLight',
    'viewRange',
    'shadowRadius',
    'shadowStrength',
    'cullingWidth',
    'cullingHeight',
    'glowColor',
    'scaleX',
    'scaleY',
    'scaleZ',
  };
}

sealed class HuiIcon {
  Map<String, dynamic> extras = <String, dynamic>{};
  HuiIconStyle? style;

  String get type;

  Map<String, dynamic> toJson();

  HuiIcon copy();

  static HuiIcon fromJson(Object? raw, {String path = 'icon'}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final String type = huiReadTypeTag(map, path);
    switch (type) {
      case 'text':
        return HuiTextIcon.fromMap(map);
      case 'textImage':
        return HuiTextImageIcon.fromMap(map);
      case 'animatedTextImage':
        return HuiAnimatedImageIcon.fromMap(map);
      case 'item':
        return HuiItemIcon.fromMap(map);
      case 'block':
        return HuiBlockIcon.fromMap(map);
      case 'customItem':
        return HuiCustomItemIcon.fromMap(map);
      case 'entity':
        return HuiEntityIcon.fromMap(map);
      case 'playerHead':
        return HuiPlayerHeadIcon.fromMap(map);
      default:
        huiUnknownType(type, path);
    }
  }

  /// `icon` slots are optional everywhere; a null icon renders the built-in
  /// magenta/black placeholder in-game.
  static HuiIcon? fromJsonOrNull(Object? raw, {String path = 'icon'}) =>
      raw == null ? null : HuiIcon.fromJson(raw, path: path);
}

class HuiTextIcon extends HuiIcon {
  String text;
  int? refreshTicks;

  HuiTextIcon([this.text = '', HuiIconStyle? style, this.refreshTicks]) {
    this.style = style;
  }

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'text',
    'text': text,
    if (refreshTicks != null) 'refreshTicks': refreshTicks,
    if (style != null) 'style': style!.toJson(),
  }, extras);

  @override
  HuiTextIcon copy() =>
      HuiTextIcon(text, style?.copy(), refreshTicks)
        ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'text',
    'refreshTicks',
    'style',
  };

  static HuiTextIcon fromMap(Map<String, dynamic> map) => HuiTextIcon(
    huiReadString(map, 'text'),
    HuiIconStyle.fromJsonOrNull(map['style']),
    map.containsKey('refreshTicks') && map['refreshTicks'] != null
        ? huiReadInt(map, 'refreshTicks')
        : null,
  )..extras = huiCollectExtras(map, _known);
}

class HuiTextImageIcon extends HuiIcon {
  String path;

  HuiTextImageIcon([this.path = '', HuiIconStyle? style]) {
    this.style = style;
  }

  @override
  String get type => 'textImage';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'textImage',
    'path': path,
    if (style != null) 'style': style!.toJson(),
  }, extras);

  @override
  HuiTextImageIcon copy() =>
      HuiTextImageIcon(path, style?.copy())..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'path', 'style'};

  static HuiTextImageIcon fromMap(Map<String, dynamic> map) => HuiTextImageIcon(
    huiReadString(map, 'path'),
    HuiIconStyle.fromJsonOrNull(map['style']),
  )..extras = huiCollectExtras(map, _known);
}

class HuiAnimatedImageIcon extends HuiIcon {
  List<String> source;

  /// Ticks per frame (20 ticks = 1 s). The runtime accepts 2 through 1200.
  int speed;

  HuiAnimatedImageIcon([
    List<String>? source,
    this.speed = 2,
    HuiIconStyle? style,
  ]) : source = source ?? <String>[] {
    this.style = style;
  }

  @override
  String get type => 'animatedTextImage';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'animatedTextImage',
    'source': List<String>.from(source),
    'speed': speed,
    if (style != null) 'style': style!.toJson(),
  }, extras);

  @override
  HuiAnimatedImageIcon copy() =>
      HuiAnimatedImageIcon(List<String>.from(source), speed, style?.copy())
        ..extras = huiDeepCopyMap(extras);

  // `path` is consumed, not preserved: the pre-3.0 schema named the frame list
  // `path`, which Gson ignores. Importing migrates it onto `source` rather than
  // exporting a file that carries both.
  static const Set<String> _known = <String>{
    'type',
    'source',
    'speed',
    'path',
    'style',
  };

  static HuiAnimatedImageIcon fromMap(Map<String, dynamic> map) =>
      HuiAnimatedImageIcon(
        huiReadStringList(map['source'] ?? map['path']),
        huiReadInt(map, 'speed'),
        HuiIconStyle.fromJsonOrNull(map['style']),
      )..extras = huiCollectExtras(map, _known);
}

class HuiItemIcon extends HuiIcon {
  /// Lowercase namespaced registry key; uppercase keys parse to null in-game.
  String item;
  int count;

  /// The record field has no `@SerializedName`, so the JSON key is literally
  /// `customModelValue`; the pre-3.0 `customModelData` is ignored by Gson.
  int customModelValue;

  HuiItemIcon([
    this.item = '',
    this.count = 1,
    this.customModelValue = 0,
    HuiIconStyle? style,
  ]) {
    this.style = style;
  }

  @override
  String get type => 'item';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'item',
    'item': item,
    'count': count,
    'customModelValue': customModelValue,
    if (style != null) 'style': style!.toJson(),
  }, extras);

  @override
  HuiItemIcon copy() =>
      HuiItemIcon(item, count, customModelValue, style?.copy())
        ..extras = huiDeepCopyMap(extras);

  // `customModelData` is consumed, not preserved: the old editor and the
  // pre-3.0 schema wrote that key, which Gson ignores. Importing migrates the
  // value onto the key the plugin actually reads instead of exporting both.
  static const Set<String> _known = <String>{
    'type',
    'item',
    'count',
    'customModelValue',
    'customModelData',
    'style',
  };

  static HuiItemIcon fromMap(Map<String, dynamic> map) => HuiItemIcon(
    huiReadString(map, 'item'),
    huiReadInt(map, 'count'),
    huiReadInt(
      map,
      map['customModelValue'] == null ? 'customModelData' : 'customModelValue',
    ),
    HuiIconStyle.fromJsonOrNull(map['style']),
  )..extras = huiCollectExtras(map, _known);
}

class HuiBlockIcon extends HuiIcon {
  String block;

  HuiBlockIcon([this.block = 'minecraft:stone', HuiIconStyle? style]) {
    this.style = style;
  }

  @override
  String get type => 'block';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'block',
    'block': block,
    if (style != null) 'style': style!.toJson(),
  }, extras);

  @override
  HuiBlockIcon copy() =>
      HuiBlockIcon(block, style?.copy())..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'block', 'style'};

  static HuiBlockIcon fromMap(Map<String, dynamic> map) => HuiBlockIcon(
    huiReadString(map, 'block'),
    HuiIconStyle.fromJsonOrNull(map['style']),
  )..extras = huiCollectExtras(map, _known);
}

/// An item owned by a custom-item plugin (ItemsAdder, Oraxen, MMOItems, ...).
///
/// The id is whatever format its provider uses — `ns:id`, a bare yml key,
/// `TYPE:ID`, or a numeric head id — and is written back byte for byte,
/// including case: several providers look ids up in case-sensitive maps. Only
/// the server can say whether an id exists, so the editor never rejects one.
class HuiCustomItemIcon extends HuiIcon {
  /// A provider id from [huiCustomItemProviders], or [huiAutoItemProvider].
  String provider;

  /// The provider's own id, verbatim.
  String item;
  int count;

  HuiCustomItemIcon([
    this.provider = huiAutoItemProvider,
    this.item = '',
    this.count = 1,
    HuiIconStyle? style,
  ]) {
    this.style = style;
  }

  @override
  String get type => 'customItem';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'customItem',
    'provider': provider,
    'item': item,
    'count': count,
    if (style != null) 'style': style!.toJson(),
  }, extras);

  @override
  HuiCustomItemIcon copy() =>
      HuiCustomItemIcon(provider, item, count, style?.copy())
        ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'provider',
    'item',
    'count',
    'style',
  };

  static HuiCustomItemIcon fromMap(Map<String, dynamic> map) {
    // Both defaults mirror the plugin: a blank provider means "try them all",
    // and `setAmount(count > 0 ? count : 1)` makes 0 and 1 the same stack.
    final String provider = huiReadString(map, 'provider').trim().toLowerCase();
    final int count = huiReadInt(map, 'count');
    return HuiCustomItemIcon(
      provider.isEmpty ? huiAutoItemProvider : provider,
      huiReadString(map, 'item'),
      count > 0 ? count : 1,
      HuiIconStyle.fromJsonOrNull(map['style']),
    )..extras = huiCollectExtras(map, _known);
  }
}

class HuiEntityIcon extends HuiIcon {
  String entity;
  double width;
  double height;

  HuiEntityIcon([
    this.entity = 'minecraft:parrot',
    this.width = 1,
    this.height = 1,
  ]);

  @override
  String get type => 'entity';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'entity',
    'entity': entity,
    'width': width,
    'height': height,
  }, extras);

  @override
  HuiEntityIcon copy() =>
      HuiEntityIcon(entity, width, height)..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'entity',
    'width',
    'height',
  };

  static HuiEntityIcon fromMap(Map<String, dynamic> map) => HuiEntityIcon(
    huiReadString(map, 'entity'),
    huiReadDouble(map, 'width', fallback: 1),
    huiReadDouble(map, 'height', fallback: 1),
  )..extras = huiCollectExtras(map, _known);
}

/// A Minecraft account's head, drawn on the item display an `item` icon uses.
///
/// The plugin's `PlayerHeadMenuIcon extends ItemMenuIcon`
/// (`PlayerHeadMenuIcon.java:32`), so the anchor, block offset, click plane and
/// billboard are an item icon's; the only thing the type adds is which stack
/// sits on the display and when it is swapped. There is no `count`: every
/// stack the runtime builds is one head (`PlayerHeadMenuIcon.java:158-164`).
///
/// [player] is written back verbatim. `%player_name%`, `%player%` and
/// `{{player.name}}` are answered by Gloss itself and mean the viewer
/// (`PlayerHeadMenuIcon.java:41`); anything else goes through the text
/// pipeline, so only the server can say what it resolves to.
class HuiPlayerHeadIcon extends HuiIcon {
  /// A literal username, or a placeholder resolved per viewer.
  String player;

  /// Ticks between re-reading the name and the profile cache. Null means the
  /// runtime's own 20 (`PlayerHeadIconData.java:16`), so it is not written.
  int? refreshTicks;

  HuiPlayerHeadIcon([
    this.player = '',
    HuiIconStyle? style,
    this.refreshTicks,
  ]) {
    this.style = style;
  }

  @override
  String get type => 'playerHead';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'playerHead',
    'player': player,
    if (refreshTicks != null) 'refreshTicks': refreshTicks,
    if (style != null) 'style': style!.toJson(),
  }, extras);

  @override
  HuiPlayerHeadIcon copy() =>
      HuiPlayerHeadIcon(player, style?.copy(), refreshTicks)
        ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'player',
    'refreshTicks',
    'style',
  };

  static HuiPlayerHeadIcon fromMap(Map<String, dynamic> map) =>
      HuiPlayerHeadIcon(
        huiReadString(map, 'player'),
        HuiIconStyle.fromJsonOrNull(map['style']),
        map.containsKey('refreshTicks') && map['refreshTicks'] != null
            ? huiReadInt(map, 'refreshTicks')
            : null,
      )..extras = huiCollectExtras(map, _known);
}
