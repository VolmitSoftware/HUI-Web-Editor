import 'hui_actions.dart';
import 'hui_icons.dart';
import 'json_codec.dart';
import 'vec3.dart';

/// The three component types, case-sensitive.
const List<String> huiComponentTypes = <String>[
  'button',
  'decoration',
  'toggle',
];

sealed class HuiComponentData {
  Map<String, dynamic> extras = <String, dynamic>{};

  String get type;

  Map<String, dynamic> toJson();

  HuiComponentData copy();

  static HuiComponentData fromJson(Object? raw, {String path = 'data'}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final String type = huiReadTypeTag(map, path);
    switch (type) {
      case 'button':
        return HuiButtonData.fromMap(map, path);
      case 'decoration':
        return HuiDecorationData.fromMap(map, path);
      case 'toggle':
        return HuiToggleData.fromMap(map, path);
      default:
        huiUnknownType(type, path);
    }
  }
}

enum HuiHitboxAnchor { button, menu }

class HuiHitbox {
  double? width;
  double? height;
  Vec3 offset;
  HuiHitboxAnchor anchor;
  Map<String, dynamic> extras = <String, dynamic>{};

  HuiHitbox([
    this.width,
    this.height,
    Vec3? offset,
    this.anchor = HuiHitboxAnchor.button,
  ]) : offset = offset ?? Vec3.zero();

  bool get hasCustomSize => width != null && height != null;

  bool get isDefault =>
      !hasCustomSize &&
      offset == Vec3.zero() &&
      anchor == HuiHitboxAnchor.button;

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (offset != Vec3.zero()) 'offset': offset.toJson(),
    if (anchor != HuiHitboxAnchor.button) 'anchor': anchor.name,
  }, extras);

  HuiHitbox copy() =>
      HuiHitbox(width, height, offset.copy(), anchor)
        ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'width',
    'height',
    'offset',
    'anchor',
  };

  static HuiHitbox? fromJsonOrNull(Object? raw, {required String path}) {
    if (raw == null) return null;
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final String anchor = huiReadString(map, 'anchor', fallback: 'button');
    return HuiHitbox(
      huiReadDoubleOrNull(map, 'width'),
      huiReadDoubleOrNull(map, 'height'),
      Vec3.fromJson(map['offset'], path: '$path.offset'),
      anchor == 'menu' ? HuiHitboxAnchor.menu : HuiHitboxAnchor.button,
    )..extras = huiCollectExtras(map, _known);
  }
}

class HuiButtonData extends HuiComponentData {
  /// Blocks the icon leans toward the player while highlighted. Unclamped in
  /// JSON; the Java API clamps to 0..1.
  double highlightModifier;
  List<HuiAction> actions;
  HuiIcon? icon;
  HuiHitbox? hitbox;

  HuiButtonData([
    this.highlightModifier = 0.05,
    List<HuiAction>? actions,
    this.icon,
    this.hitbox,
  ]) : actions = actions ?? <HuiAction>[];

  @override
  String get type => 'button';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'button',
    'highlightModifier': highlightModifier,
    if (hitbox != null) 'hitbox': hitbox!.toJson(),
    'icon': icon?.toJson(),
    'actions': HuiAction.listToJson(actions),
  }, extras);

  @override
  HuiButtonData copy() => HuiButtonData(
    highlightModifier,
    actions.map((HuiAction a) => a.copy()).toList(),
    icon?.copy(),
    hitbox?.copy(),
  )..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'highlightModifier',
    'hitbox',
    'icon',
    'actions',
  };

  static HuiButtonData fromMap(Map<String, dynamic> map, String path) =>
      HuiButtonData(
        huiReadDouble(map, 'highlightModifier'),
        HuiAction.listFromJson(map['actions'], '$path.actions'),
        HuiIcon.fromJsonOrNull(map['icon'], path: '$path.icon'),
        HuiHitbox.fromJsonOrNull(map['hitbox'], path: '$path.hitbox'),
      )..extras = huiCollectExtras(map, _known);
}

class HuiDecorationData extends HuiComponentData {
  HuiIcon? icon;

  HuiDecorationData([this.icon]);

  @override
  String get type => 'decoration';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'decoration',
    'icon': icon?.toJson(),
  }, extras);

  @override
  HuiDecorationData copy() =>
      HuiDecorationData(icon?.copy())..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'icon'};

  static HuiDecorationData fromMap(Map<String, dynamic> map, String path) =>
      HuiDecorationData(HuiIcon.fromJsonOrNull(map['icon'], path: '$path.icon'))
        ..extras = huiCollectExtras(map, _known);
}

class HuiToggleData extends HuiComponentData {
  double highlightModifier;

  /// PlaceholderAPI-expanded once at menu open, then compared
  /// `equalsIgnoreCase` against [expectedValue]. Never re-evaluated.
  String condition;
  String expectedValue;
  List<HuiAction> trueActions;
  List<HuiAction> falseActions;
  HuiIcon? trueIcon;
  HuiIcon? falseIcon;

  HuiToggleData([
    this.highlightModifier = 0.05,
    this.condition = '',
    this.expectedValue = '',
    List<HuiAction>? trueActions,
    List<HuiAction>? falseActions,
    this.trueIcon,
    this.falseIcon,
  ]) : trueActions = trueActions ?? <HuiAction>[],
       falseActions = falseActions ?? <HuiAction>[];

  @override
  String get type => 'toggle';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': 'toggle',
    'highlightModifier': highlightModifier,
    'condition': condition,
    'expectedValue': expectedValue,
    'trueIcon': trueIcon?.toJson(),
    'falseIcon': falseIcon?.toJson(),
    'trueActions': HuiAction.listToJson(trueActions),
    'falseActions': HuiAction.listToJson(falseActions),
  }, extras);

  @override
  HuiToggleData copy() => HuiToggleData(
    highlightModifier,
    condition,
    expectedValue,
    trueActions.map((HuiAction a) => a.copy()).toList(),
    falseActions.map((HuiAction a) => a.copy()).toList(),
    trueIcon?.copy(),
    falseIcon?.copy(),
  )..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'highlightModifier',
    'condition',
    'expectedValue',
    'trueIcon',
    'falseIcon',
    'trueActions',
    'falseActions',
  };

  static HuiToggleData fromMap(Map<String, dynamic> map, String path) =>
      HuiToggleData(
        huiReadDouble(map, 'highlightModifier'),
        huiReadString(map, 'condition'),
        huiReadString(map, 'expectedValue'),
        HuiAction.listFromJson(map['trueActions'], '$path.trueActions'),
        HuiAction.listFromJson(map['falseActions'], '$path.falseActions'),
        HuiIcon.fromJsonOrNull(map['trueIcon'], path: '$path.trueIcon'),
        HuiIcon.fromJsonOrNull(map['falseIcon'], path: '$path.falseIcon'),
      )..extras = huiCollectExtras(map, _known);
}

class HuiComponent {
  /// Addresses the component in the Java API. The first duplicate id wins;
  /// later duplicates do not render, tick or click.
  String id;

  /// Relative to the menu centre, multiplied by the server's `uiScale`.
  Vec3 offset;
  HuiComponentData data;
  Map<String, dynamic> extras = <String, dynamic>{};

  /// Hard-required keys that were absent from the decoded JSON and had to be
  /// defaulted; see [HuiMenu.absentKeys]. Never serialized.
  Set<String> absentKeys = <String>{};

  HuiComponent(this.id, this.offset, this.data);

  HuiComponent copy() =>
      HuiComponent(id, offset.copy(), data.copy())
        ..extras = huiDeepCopyMap(extras);

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'offset': offset.toJson(),
    'data': data.toJson(),
  }, extras);

  static const Set<String> _known = <String>{'id', 'offset', 'data'};

  static HuiComponent fromJson(Object? raw, {String path = 'component'}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return HuiComponent(
        huiReadString(map, 'id'),
        Vec3.fromJson(map['offset'], path: '$path.offset'),
        HuiComponentData.fromJson(map['data'], path: '$path.data'),
      )
      ..extras = huiCollectExtras(map, _known)
      ..absentKeys = <String>{if (map['offset'] == null) 'offset'};
  }
}
