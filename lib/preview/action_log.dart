/// What a simulated click actually does, recorded rather than performed.
///
/// The preview never executes an action; it logs what the server would have
/// done. That makes the log the place where the format's
/// silent traps become visible: a command whose `source` is the exact token
/// `server` is dispatched from the CONSOLE with no permission check against the
/// clicking player (`CommandMenuAction.java:34-40`), and an explicit
/// `volume: 0` is played inaudibly (`SoundMenuAction.java:30-32`).
///
/// Pure and DOM-free: the log dock renders these, it does not define them.
library;

import '../l10n/hui_localizations.dart';

import '../model/hui_actions.dart';

const String huiPreviewClickerName = 'Steve';

/// One thing the runtime does when a component is clicked.
sealed class LoggedAction {
  const LoggedAction();
}

/// A `command` action as `CommandMenuAction.execute` would run it.
class LoggedCommand extends LoggedAction {
  LoggedCommand({
    required String command,
    required String? source,
    String clickerName = huiPreviewClickerName,
  }) : command = _resolveCommand(command, clickerName),
       rawSource = source ?? '';

  factory LoggedCommand.from(
    HuiCommandAction action, {
    String clickerName = huiPreviewClickerName,
  }) => LoggedCommand(
    command: action.command,
    source: action.source,
    clickerName: clickerName,
  );

  /// The command as dispatched — player tokens resolved and exactly one
  /// leading `/` stripped, so `//me` reaches the dispatcher as `/me`.
  final String command;

  /// The authored spelling, kept verbatim so the log can quote what is wrong.
  final String rawSource;

  /// Canonical editor values are `player` and `server`. Directly constructed
  /// logs also recognize Gson's Java enum spelling `GLOBAL`.
  bool get asPlayer => rawSource != 'server' && rawSource != 'GLOBAL';

  bool get asConsole => !asPlayer;

  /// Whether the spelling is one the format defines at all. An unrecognized
  /// value takes the player default by falling off the end of the enum lookup
  /// rather than by intent, so the log calls it out separately from a
  /// deliberate `player`.
  bool get sourceRecognized =>
      huiCommandSources.contains(rawSource) ||
      rawSource == 'PLAYER' ||
      rawSource == 'GLOBAL';

  static String _stripOneLeadingSlash(String raw) {
    final String trimmed = raw.trim();
    return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  }

  static String _resolveCommand(String raw, String clickerName) =>
      _stripOneLeadingSlash(
        raw
            .replaceAll('%player_name%', clickerName)
            .replaceAll('%player%', clickerName),
      );
}

/// A `sound` action as `SoundMenuAction.execute` would play it.
class LoggedSound extends LoggedAction {
  const LoggedSound({
    required this.key,
    required this.category,
    required this.volume,
    required this.pitch,
  });

  factory LoggedSound.from(HuiSoundAction action) => LoggedSound(
    key: action.sound,
    category: action.source,
    volume: action.volume,
    pitch: action.pitch,
  );

  /// Lowercase namespaced registry key; uppercase enum names parse to null.
  final String key;

  /// `SoundSource` serialized name — the `source` key, not a category name.
  final String category;
  final double volume;
  final double pitch;

  /// An omitted `volume` defaults to 1, so silence only happens when the file
  /// writes 0 itself.
  bool get inaudible => volume == 0;

  /// An absent category defaults to `master`, so this is only ever true for an
  /// action the editor built with an empty one.
  bool get categoryMissing => category.trim().isEmpty;
}

class LoggedMessage extends LoggedAction {
  const LoggedMessage(this.message);

  factory LoggedMessage.from(HuiMessageAction action) =>
      LoggedMessage(action.message);

  final String message;

  bool get hasStrippedInteractions {
    final String lowercase = message.toLowerCase();
    return lowercase.contains('<click:') || lowercase.contains('<insert:');
  }
}

class LoggedTeleport extends LoggedAction {
  const LoggedTeleport({
    required this.world,
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    required this.pitch,
  });

  factory LoggedTeleport.from(HuiTeleportAction action) => LoggedTeleport(
    world: action.world,
    x: action.x,
    y: action.y,
    z: action.z,
    yaw: action.yaw,
    pitch: action.pitch,
  );

  final String world;
  final double x;
  final double y;
  final double z;
  final double yaw;
  final double pitch;
}

class LoggedConnect extends LoggedAction {
  const LoggedConnect(this.server);

  factory LoggedConnect.from(HuiConnectAction action) =>
      LoggedConnect(action.server);

  final String server;
}

class LoggedNavigation extends LoggedAction {
  const LoggedNavigation({required this.mode, required this.target});

  factory LoggedNavigation.from(HuiNavigateAction action) =>
      LoggedNavigation(mode: action.mode, target: action.target);

  final String mode;
  final String target;
}

/// Why a component's actions ran.
///
/// Toggles need the direction spelled out because the lists are named for the
/// state they lead *into*: `ToggleComponent.java:52-61` runs `falseActions` on
/// the way to false and `trueActions` on the way to true.
enum ActionLogTrigger {
  button,
  toggleToTrue,
  toggleToFalse;

  String get label => switch (this) {
    ActionLogTrigger.button => huiText('click'),
    ActionLogTrigger.toggleToTrue => huiText('toggle → true'),
    ActionLogTrigger.toggleToFalse => huiText('toggle → false'),
  };
}

/// One component firing on one click.
///
/// One nearest component fired on one click, named with its component, tick,
/// exact interaction trigger, and filtered action chain.
class ActionLogEntry {
  const ActionLogEntry({
    required this.tick,
    required this.componentId,
    required this.trigger,
    required this.clickTrigger,
    required this.actions,
  });

  final int tick;
  final String componentId;
  final ActionLogTrigger trigger;
  final String clickTrigger;
  final List<LoggedAction> actions;
}

LoggedAction loggedActionFrom(
  HuiAction action, {
  String clickerName = huiPreviewClickerName,
}) => switch (action) {
  HuiCommandAction() => LoggedCommand.from(action, clickerName: clickerName),
  HuiSoundAction() => LoggedSound.from(action),
  HuiMessageAction() => LoggedMessage.from(action),
  HuiTeleportAction() => LoggedTeleport.from(action),
  HuiConnectAction() => LoggedConnect.from(action),
  HuiNavigateAction() => LoggedNavigation.from(action),
};

List<LoggedAction> loggedActionsFrom(
  Iterable<HuiAction> actions, {
  String clickTrigger = 'left_click',
  String clickerName = huiPreviewClickerName,
}) {
  final List<LoggedAction> logged = <LoggedAction>[];
  for (final HuiAction action in actions) {
    if (!_matchesClickTrigger(action.trigger, clickTrigger)) continue;
    if (action is HuiCommandAction && !_hasUsableCommand(action.command)) {
      continue;
    }
    if (action is HuiMessageAction && action.message.trim().isEmpty) {
      continue;
    }
    if (action is HuiTeleportAction && !_hasUsableTeleport(action)) {
      continue;
    }
    if (action is HuiConnectAction && !_hasUsableServer(action.server)) {
      continue;
    }
    logged.add(loggedActionFrom(action, clickerName: clickerName));
    if (action is HuiNavigateAction) break;
  }
  return List<LoggedAction>.unmodifiable(logged);
}

bool _matchesClickTrigger(String binding, String interaction) =>
    binding == 'any' || binding == interaction;

String actionClickTriggerLabel(String trigger) => switch (trigger) {
  'left_click' => huiText('left click'),
  'right_click' => huiText('right click'),
  'shift_left_click' => huiText('sneak + left click'),
  'shift_right_click' => huiText('sneak + right click'),
  'any' => huiText('any click'),
  _ => trigger,
};

bool _hasUsableCommand(String command) {
  final String trimmed = command.trim();
  return trimmed.isNotEmpty && trimmed != '/';
}

final RegExp _loggedWorldKey = RegExp(r'^[a-z0-9._-]+:[a-z0-9/._-]+$');
final RegExp _loggedServerName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

bool _hasUsableTeleport(HuiTeleportAction action) =>
    action.world.length <= 255 &&
    _loggedWorldKey.hasMatch(action.world) &&
    action.x.isFinite &&
    action.y.isFinite &&
    action.z.isFinite &&
    action.yaw.isFinite &&
    action.pitch.isFinite;

bool _hasUsableServer(String server) => _loggedServerName.hasMatch(server);

String describeLoggedAction(LoggedAction action) => switch (action) {
  LoggedCommand() => _describeCommand(action),
  LoggedSound() => _describeSound(action),
  LoggedMessage() =>
    'message player "${action.message}"'
        '${action.hasStrippedInteractions ? " (click and insertion events stripped)" : ""}',
  LoggedTeleport() =>
    'teleport player to ${action.world} '
        '${_number(action.x)} ${_number(action.y)} ${_number(action.z)} '
        '(yaw ${_number(action.yaw)}, pitch ${_number(action.pitch)})',
  LoggedConnect() => 'connect player to proxy server "${action.server}"',
  LoggedNavigation() =>
    action.target.isEmpty
        ? '${action.mode} navigation'
        : '${action.mode} navigation to "${action.target}"',
};

String describeActionLogEntry(ActionLogEntry entry) {
  final String body = entry.actions.isEmpty
      ? 'no actions'
      : entry.actions.map(describeLoggedAction).join('; ');
  return '#${entry.tick} ${entry.componentId} '
      '(${entry.trigger.label}, ${actionClickTriggerLabel(entry.clickTrigger)}): $body';
}

String _describeCommand(LoggedCommand command) {
  final String target = command.asPlayer ? 'player' : 'console';
  final String note = command.rawSource.isEmpty || command.sourceRecognized
      ? ''
      : ' (source "${command.rawSource}" is not player or server)';
  return 'run "${command.command}" as $target$note';
}

String _describeSound(LoggedSound sound) {
  final String source = sound.categoryMissing ? 'master' : sound.category;
  final String note = sound.inaudible ? ' — inaudible' : '';
  return 'play "${sound.key}" ($source) '
      'volume ${_number(sound.volume)}, pitch ${_number(sound.pitch)}$note';
}

/// Whole values read as whole numbers; `1.0` in a log row is noise.
String _number(double value) => value == value.roundToDouble() && value.isFinite
    ? value.toStringAsFixed(0)
    : value.toString();
