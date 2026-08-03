import 'json_codec.dart';

/// The only two action types in the format.
const List<String> huiActionTypes = <String>['command', 'sound'];

/// `MenuActionCommandSource` serialized names. A null/unknown source behaves
/// as `server` in-game, so the editor always emits one of these.
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

  String get type;

  Map<String, dynamic> toJson();

  HuiAction copy();

  static HuiAction fromJson(Object? raw, {String path = 'action'}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final String type = huiReadTypeTag(map, path);
    switch (type) {
      case 'command':
        return HuiCommandAction.fromMap(map);
      case 'sound':
        return HuiSoundAction.fromMap(map);
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
}

class HuiCommandAction extends HuiAction {
  /// A leading `/` is optional; the plugin strips it. Never placeholder-expanded.
  String command;
  String source;

  /// Holds `source` when the imported file carried none; see
  /// [HuiMenu.absentKeys]. `_readSource` normalises an absent source to
  /// `server`, which is indistinguishable from an explicit one, so the flag is
  /// the only way validation can tell the user their command was silently
  /// running from the console. Never serialized, and cleared by any re-decode
  /// because the export always writes the key.
  Set<String> absentKeys = <String>{};

  HuiCommandAction([this.command = '', this.source = 'player']);

  @override
  String get type => 'command';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
        <String, dynamic>{
          'type': 'command',
          'source': source,
          'command': command,
        },
        extras,
      );

  @override
  HuiCommandAction copy() =>
      HuiCommandAction(command, source)..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{'type', 'source', 'command'};

  static HuiCommandAction fromMap(Map<String, dynamic> map) => HuiCommandAction(
        huiReadString(map, 'command'),
        _readSource(map),
      )
        ..extras = huiCollectExtras(map, _known)
        ..absentKeys = <String>{
          if (huiReadString(map, 'source').isEmpty) 'source',
        };

  /// An absent or blank source is null to Gson, which runs the command as the
  /// console. Reading it as `server` keeps that behaviour and keeps the export
  /// from carrying an empty string where the format expects an enum token.
  /// Unknown non-empty values are kept verbatim so validation can flag them.
  static String _readSource(Map<String, dynamic> map) {
    final String source = huiReadString(map, 'source');
    return source.isEmpty ? 'server' : source;
  }
}

class HuiSoundAction extends HuiAction {
  /// Lowercase registry key, e.g. `ui.button.click`.
  String sound;

  /// One of [huiSoundSources]; a null source NPEs the menu open.
  String source;
  double volume;
  double pitch;

  HuiSoundAction([
    this.sound = 'ui.button.click',
    this.source = 'master',
    this.volume = 1,
    this.pitch = 1,
  ]);

  @override
  String get type => 'sound';

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(
        <String, dynamic>{
          'type': 'sound',
          'sound': sound,
          'source': source,
          'volume': volume,
          'pitch': pitch,
        },
        extras,
      );

  @override
  HuiSoundAction copy() => HuiSoundAction(sound, source, volume, pitch)
    ..extras = huiDeepCopyMap(extras);

  static const Set<String> _known = <String>{
    'type',
    'sound',
    'source',
    'volume',
    'pitch',
  };

  // Java zero-values (0 volume/pitch) are preserved on import so the round trip
  // stays lossless; validation flags them.
  static HuiSoundAction fromMap(Map<String, dynamic> map) => HuiSoundAction(
        huiReadString(map, 'sound'),
        huiReadString(map, 'source'),
        huiReadDouble(map, 'volume'),
        huiReadDouble(map, 'pitch'),
      )..extras = huiCollectExtras(map, _known);
}
