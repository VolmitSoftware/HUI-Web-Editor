import 'json_codec.dart';

/// The five JSON-authorable icon types. `fontImage` and `itemStack` exist in
/// the plugin enum but map to a null class, so they are unparseable.
const List<String> huiIconTypes = <String>[
  'text',
  'textImage',
  'animatedTextImage',
  'item',
  'customItem',
];

/// Provider ids the plugin ships adapters for, in registration order — which is
/// also the order `auto` probes them in. These strings are part of the file
/// format, not a UI list.
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

/// Sentinel `provider`: try every ready provider in registration order.
const String huiAutoItemProvider = 'auto';

sealed class HuiIcon {
  Map<String, dynamic> extras = <String, dynamic>{};

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
      case 'customItem':
        return HuiCustomItemIcon.fromMap(map);
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

  HuiTextIcon([this.text = '']);

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
        <String, dynamic>{'type': 'text', 'text': text},
        extras,
      );

  @override
  HuiTextIcon copy() => HuiTextIcon(text)..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'text'};

  static HuiTextIcon fromMap(Map<String, dynamic> map) =>
      HuiTextIcon(huiReadString(map, 'text'))
        ..extras = huiCollectExtras(map, _known);
}

class HuiTextImageIcon extends HuiIcon {
  String path;

  HuiTextImageIcon([this.path = '']);

  @override
  String get type => 'textImage';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
        <String, dynamic>{'type': 'textImage', 'path': path},
        extras,
      );

  @override
  HuiTextImageIcon copy() =>
      HuiTextImageIcon(path)..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'path'};

  static HuiTextImageIcon fromMap(Map<String, dynamic> map) =>
      HuiTextImageIcon(huiReadString(map, 'path'))
        ..extras = huiCollectExtras(map, _known);
}

class HuiAnimatedImageIcon extends HuiIcon {
  List<String> source;

  /// Ticks per frame (20 ticks = 1 s). Anything below 1 advances every tick.
  int speed;

  HuiAnimatedImageIcon([List<String>? source, this.speed = 1])
      : source = source ?? <String>[];

  @override
  String get type => 'animatedTextImage';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
        <String, dynamic>{
          'type': 'animatedTextImage',
          'source': List<String>.from(source),
          'speed': speed,
        },
        extras,
      );

  @override
  HuiAnimatedImageIcon copy() =>
      HuiAnimatedImageIcon(List<String>.from(source), speed)
        ..extras = huiDeepCopyMap(extras);

  // `path` is consumed, not preserved: the stale shipped schema names the frame
  // list `path`, which Gson ignores. Importing migrates it onto `source` rather
  // than exporting a file that carries both.
  static const Set<String> _known = <String>{'type', 'source', 'speed', 'path'};

  static HuiAnimatedImageIcon fromMap(Map<String, dynamic> map) =>
      HuiAnimatedImageIcon(
        huiReadStringList(map['source'] ?? map['path']),
        huiReadInt(map, 'speed'),
      )..extras = huiCollectExtras(map, _known);
}

class HuiItemIcon extends HuiIcon {
  /// Lowercase namespaced registry key; uppercase keys parse to null in-game.
  String item;
  int count;

  /// The record field has no `@SerializedName`, so the JSON key is literally
  /// `customModelValue` (the shipped schema's `customModelData` is ignored).
  int customModelValue;

  HuiItemIcon([this.item = '', this.count = 1, this.customModelValue = 0]);

  @override
  String get type => 'item';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
        <String, dynamic>{
          'type': 'item',
          'item': item,
          'count': count,
          'customModelValue': customModelValue,
        },
        extras,
      );

  @override
  HuiItemIcon copy() => HuiItemIcon(item, count, customModelValue)
    ..extras = huiDeepCopyMap(extras);

  // `customModelData` is consumed, not preserved: the stale shipped schema and
  // the old editor wrote that key, which Gson ignores. Importing migrates the
  // value onto the key the plugin actually reads instead of exporting both.
  static const Set<String> _known = <String>{
    'type',
    'item',
    'count',
    'customModelValue',
    'customModelData',
  };

  static HuiItemIcon fromMap(Map<String, dynamic> map) => HuiItemIcon(
        huiReadString(map, 'item'),
        huiReadInt(map, 'count'),
        huiReadInt(
          map,
          map['customModelValue'] == null
              ? 'customModelData'
              : 'customModelValue',
        ),
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
  ]);

  @override
  String get type => 'customItem';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
        <String, dynamic>{
          'type': 'customItem',
          'provider': provider,
          'item': item,
          'count': count,
        },
        extras,
      );

  @override
  HuiCustomItemIcon copy() => HuiCustomItemIcon(provider, item, count)
    ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'provider',
    'item',
    'count',
  };

  static HuiCustomItemIcon fromMap(Map<String, dynamic> map) {
    // Both defaults mirror the plugin: a blank provider means "try them all",
    // and `setAmount(count > 0 ? count : 1)` makes 0 and 1 the same stack.
    final String provider = huiReadString(map, 'provider').trim();
    final int count = huiReadInt(map, 'count');
    return HuiCustomItemIcon(
      provider.isEmpty ? huiAutoItemProvider : provider,
      huiReadString(map, 'item'),
      count > 0 ? count : 1,
    )..extras = huiCollectExtras(map, _known);
  }
}
