/// What a simulated click actually does, recorded rather than performed.
///
/// The preview never plays a sound and never runs a command; it logs what the
/// server would have done. That makes the log the place where the format's
/// silent traps become visible: a command whose `source` is the exact token
/// `server` is dispatched from the CONSOLE with no permission check against the
/// clicking player (`CommandMenuAction.java:34-40`), and an explicit
/// `volume: 0` is played inaudibly (`SoundMenuAction.java:30-32`).
///
/// Pure and DOM-free: the log dock renders these, it does not define them.
library;

import '../model/hui_actions.dart';

/// One thing the runtime does when a component is clicked.
sealed class LoggedAction {
  const LoggedAction();
}

/// A `command` action as `CommandMenuAction.execute` would run it.
class LoggedCommand extends LoggedAction {
  LoggedCommand({required String command, required String? source})
    : command = _stripOneLeadingSlash(command),
      rawSource = source ?? '';

  factory LoggedCommand.from(HuiCommandAction action) =>
      LoggedCommand(command: action.command, source: action.source);

  /// The command as dispatched — `CommandMenuAction.java:35` strips exactly one
  /// leading `/`, so `//me` reaches the dispatcher as `/me`.
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
    ActionLogTrigger.button => 'click',
    ActionLogTrigger.toggleToTrue => 'toggle → true',
    ActionLogTrigger.toggleToFalse => 'toggle → false',
  };
}

/// One component firing on one click.
///
/// A single click can produce several of these — every hovered clickable fires
/// (`SessionHolder.java:145-159`) — so the entry names its component and the
/// tick it fired on. [actions] may be empty: that an empty component fired at
/// all is exactly what the overlap lesson needs to show.
class ActionLogEntry {
  const ActionLogEntry({
    required this.tick,
    required this.componentId,
    required this.trigger,
    required this.actions,
  });

  final int tick;
  final String componentId;
  final ActionLogTrigger trigger;
  final List<LoggedAction> actions;
}

LoggedAction loggedActionFrom(HuiAction action) => switch (action) {
  HuiCommandAction() => LoggedCommand.from(action),
  HuiSoundAction() => LoggedSound.from(action),
};

List<LoggedAction> loggedActionsFrom(Iterable<HuiAction> actions) => actions
    .where(
      (HuiAction action) =>
          action is! HuiCommandAction || _hasUsableCommand(action.command),
    )
    .map(loggedActionFrom)
    .toList(growable: false);

bool _hasUsableCommand(String command) {
  final String trimmed = command.trim();
  return trimmed.isNotEmpty && trimmed != '/';
}

String describeLoggedAction(LoggedAction action) => switch (action) {
  LoggedCommand() => _describeCommand(action),
  LoggedSound() => _describeSound(action),
};

String describeActionLogEntry(ActionLogEntry entry) {
  final String body = entry.actions.isEmpty
      ? 'no actions'
      : entry.actions.map(describeLoggedAction).join('; ');
  return '#${entry.tick} ${entry.componentId} (${entry.trigger.label}): $body';
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
