import 'json_codec.dart';

const List<String> huiActionTypes = <String>[
  'command',
  'sound',
  'message',
  'teleport',
  'connect',
  'navigate',
];

const List<String> huiActionTriggers = <String>[
  'any',
  'left_click',
  'right_click',
  'shift_left_click',
  'shift_right_click',
];

const List<String> huiNavigationModes = <String>[
  'push',
  'replace',
  'back',
  'home',
  'close',
];

/// `MenuActionCommandSource` serialized names. Gson also accepts the Java enum
/// names `PLAYER` and `GLOBAL`; imports canonicalize those spellings.
const List<String> huiCommandSources = <String>['player', 'server'];

/// `SoundSource` serialized names, in declaration order.
const List<String> huiSoundSources = <String>[
  'master',
  'music',
  'record',
  'weather',
  'block',
  'hostile',
  'neutral',
  'player',
  'ambient',
  'voice',
];

sealed class HuiAction {
  Map<String, dynamic> extras = <String, dynamic>{};
  String trigger;

  HuiAction([this.trigger = 'any']);

  String get type;

  Map<String, dynamic> toJson();

  HuiAction copy();

  Map<String, dynamic> withTrigger(Map<String, dynamic> values) =>
      <String, dynamic>{...values, if (trigger != 'any') 'trigger': trigger};

  static HuiAction fromJson(Object? raw, {String path = 'action'}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final String type = huiReadTypeTag(map, path);
    switch (type) {
      case 'command':
        return HuiCommandAction.fromMap(map);
      case 'sound':
        return HuiSoundAction.fromMap(map);
      case 'message':
        return HuiMessageAction.fromMap(map);
      case 'teleport':
        return HuiTeleportAction.fromMap(map);
      case 'connect':
        return HuiConnectAction.fromMap(map);
      case 'navigate':
        return HuiNavigateAction.fromMap(map);
      default:
        huiUnknownType(type, path);
    }
  }

  static List<HuiAction> listFromJson(Object? raw, String path) {
    final List<Object?> entries = huiReadList(raw);
    final List<HuiAction> out = <HuiAction>[];
    for (int i = 0; i < entries.length; i++) {
      final Object? entry = entries[i];
      if (entry == null) continue;
      out.add(HuiAction.fromJson(entry, path: '$path[$i]'));
    }
    return out;
  }

  static List<Object?> listToJson(List<HuiAction> actions) =>
      actions.map((HuiAction a) => a.toJson()).toList();

  static String readTrigger(Map<String, dynamic> map) {
    if (!map.containsKey('trigger') || map['trigger'] == null) return 'any';
    return huiReadString(map, 'trigger');
  }
}

class HuiCommandAction extends HuiAction {
  /// A leading `/` is optional; the plugin strips it. Never placeholder-expanded.
  String command;
  String source;

  HuiCommandAction([
    this.command = '',
    this.source = 'player',
    super.trigger = 'any',
  ]);

  @override
  String get type => 'command';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
    withTrigger(<String, dynamic>{
      'type': 'command',
      'source': source,
      'command': command,
    }),
    extras,
  );

  @override
  HuiCommandAction copy() =>
      HuiCommandAction(command, source, trigger)
        ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'source',
    'command',
    'trigger',
  };

  static HuiCommandAction fromMap(Map<String, dynamic> map) => HuiCommandAction(
    huiReadString(map, 'command'),
    _readSource(map),
    HuiAction.readTrigger(map),
  )..extras = huiCollectExtras(map, _known);

  /// An absent or blank source is null to Gson, which the plugin defaults to
  /// `player`. Reading it as `player` keeps that behaviour and keeps the export
  /// from carrying an empty string where the format expects an enum token.
  /// Unknown non-empty values are kept verbatim so validation can flag them.
  static String _readSource(Map<String, dynamic> map) {
    final String source = huiReadString(map, 'source');
    return switch (source) {
      '' => 'player',
      'PLAYER' => 'player',
      'GLOBAL' => 'server',
      _ => source,
    };
  }
}

class HuiSoundAction extends HuiAction {
  /// Lowercase registry key, e.g. `ui.button.click`.
  String sound;

  /// One of [huiSoundSources]; an absent or unknown source defaults to
  /// `master`.
  String source;
  double volume;
  double pitch;

  HuiSoundAction([
    this.sound = 'ui.button.click',
    this.source = 'master',
    this.volume = 1,
    this.pitch = 1,
    super.trigger = 'any',
  ]);

  @override
  String get type => 'sound';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
    withTrigger(<String, dynamic>{
      'type': 'sound',
      'sound': sound,
      'source': source,
      'volume': volume,
      'pitch': pitch,
    }),
    extras,
  );

  @override
  HuiSoundAction copy() =>
      HuiSoundAction(sound, source, volume, pitch, trigger)
        ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'sound',
    'source',
    'volume',
    'pitch',
    'trigger',
  };

  // Absent keys take the plugin's defaults - master, 1.0, 1.0 - while an
  // explicit 0 volume or pitch is preserved so the round trip stays lossless;
  // validation flags those.
  static HuiSoundAction fromMap(Map<String, dynamic> map) => HuiSoundAction(
    huiReadString(map, 'sound'),
    _readSource(map),
    huiReadDouble(map, 'volume', fallback: 1),
    huiReadDouble(map, 'pitch', fallback: 1),
    HuiAction.readTrigger(map),
  )..extras = huiCollectExtras(map, _known);

  /// An absent or blank category is null to Gson and the plugin falls back to
  /// `master`. Unknown non-empty values are kept verbatim so validation can
  /// flag the spelling.
  static String _readSource(Map<String, dynamic> map) {
    final String source = huiReadString(map, 'source');
    if (source.isEmpty) return 'master';
    final String lowercase = source.toLowerCase();
    if (source == source.toUpperCase() && huiSoundSources.contains(lowercase)) {
      return lowercase;
    }
    return source;
  }
}

class HuiNavigateAction extends HuiAction {
  String target;
  String mode;

  HuiNavigateAction([
    this.target = '',
    this.mode = 'push',
    super.trigger = 'any',
  ]);

  @override
  String get type => 'navigate';

  bool get requiresTarget => mode == 'push' || mode == 'replace';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
    withTrigger(<String, dynamic>{
      'type': 'navigate',
      if (target.isNotEmpty) 'target': target,
      'mode': mode,
    }),
    extras,
  );

  @override
  HuiNavigateAction copy() =>
      HuiNavigateAction(target, mode, trigger)..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'target',
    'mode',
    'trigger',
  };

  static HuiNavigateAction fromMap(Map<String, dynamic> map) =>
      HuiNavigateAction(
        huiReadString(map, 'target'),
        huiReadString(map, 'mode').isEmpty
            ? 'push'
            : huiReadString(map, 'mode'),
        HuiAction.readTrigger(map),
      )..extras = huiCollectExtras(map, _known);
}

class HuiMessageAction extends HuiAction {
  String message;

  HuiMessageAction([
    this.message = '<gold>Hello %player%</gold>',
    super.trigger = 'any',
  ]);

  @override
  String get type => 'message';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
    withTrigger(<String, dynamic>{'type': 'message', 'message': message}),
    extras,
  );

  @override
  HuiMessageAction copy() =>
      HuiMessageAction(message, trigger)..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'message', 'trigger'};

  static HuiMessageAction fromMap(Map<String, dynamic> map) => HuiMessageAction(
    huiReadString(map, 'message'),
    HuiAction.readTrigger(map),
  )..extras = huiCollectExtras(map, _known);
}

class HuiTeleportAction extends HuiAction {
  String world;
  double x;
  double y;
  double z;
  double yaw;
  double pitch;

  HuiTeleportAction([
    this.world = 'minecraft:overworld',
    this.x = 0,
    this.y = 64,
    this.z = 0,
    this.yaw = 0,
    this.pitch = 0,
    super.trigger = 'any',
  ]);

  @override
  String get type => 'teleport';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
    withTrigger(<String, dynamic>{
      'type': 'teleport',
      'world': world,
      'x': x,
      'y': y,
      'z': z,
      'yaw': yaw,
      'pitch': pitch,
    }),
    extras,
  );

  @override
  HuiTeleportAction copy() =>
      HuiTeleportAction(world, x, y, z, yaw, pitch, trigger)
        ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'world',
    'x',
    'y',
    'z',
    'yaw',
    'pitch',
    'trigger',
  };

  static HuiTeleportAction fromMap(Map<String, dynamic> map) =>
      HuiTeleportAction(
        huiReadString(map, 'world'),
        huiReadDouble(map, 'x'),
        huiReadDouble(map, 'y'),
        huiReadDouble(map, 'z'),
        huiReadDouble(map, 'yaw'),
        huiReadDouble(map, 'pitch'),
        HuiAction.readTrigger(map),
      )..extras = huiCollectExtras(map, _known);
}

class HuiConnectAction extends HuiAction {
  String server;

  HuiConnectAction([this.server = 'lobby', super.trigger = 'any']);

  @override
  String get type => 'connect';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
    withTrigger(<String, dynamic>{'type': 'connect', 'server': server}),
    extras,
  );

  @override
  HuiConnectAction copy() =>
      HuiConnectAction(server, trigger)..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'server', 'trigger'};

  static HuiConnectAction fromMap(Map<String, dynamic> map) =>
      HuiConnectAction(huiReadString(map, 'server'), HuiAction.readTrigger(map))
        ..extras = huiCollectExtras(map, _known);
}
