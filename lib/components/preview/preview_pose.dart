/// Preview session state that has to outlive the view.
///
/// The preview cell is genuinely unmounted when another view is active, exactly
/// like the code editor, because its rAF loop and its 50 ms simulation timer
/// must die with it. Everything a builder would resent losing across that
/// unmount — where the camera is, which yaw the menu was opened at, what the
/// action log recorded — lives here instead, in a top-level holder
/// ([huiPreviewPose]) that the stage attaches to on mount.
///
/// Three notifiers, deliberately, and the split is load-bearing:
///
///  * [PreviewPose] itself notifies for things a person changed — facing mode,
///    a reopen. Camera writes are SILENT (see [PreviewPose.orbit]); a 60 fps
///    orbit drag must never rebuild a Jaspr subtree.
///  * [PreviewPose.live] notifies for per-tick readouts, and only when a value
///    actually changed, so a parked pointer over a static menu notifies nobody.
///  * [PreviewPose.log] notifies only on append or clear.
library;

import 'dart:collection';

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../../model/model.dart';
import '../../preview/action_log.dart';
import '../../preview/preview_types.dart';

/// Entries kept before the oldest is dropped. A click on a pile of overlapping
/// hitboxes can log a dozen entries at once, so this is a few hundred clicks.
const int huiPreviewLogCapacity = 500;

/// How the preview orients each icon quad.
///
/// The two modes exist because the runtime and the author disagree, and the
/// disagreement is a genuine HoloUi bug rather than a modelling choice.
enum PreviewFacingMode {
  /// What a player actually sees. `billboardMode()` returns FIXED for every
  /// icon type with no overrides (`MenuIcon.java:112-114`), and the only path
  /// that reaches `MenuIcon.rotate` is `MenuSession.rotate`, which **nothing
  /// calls**. So text, image and animated icons spawn at world yaw 0
  /// (`MenuIcon.java:129-131`) and are never turned. Item icons are the lone
  /// exception: `ItemMenuIcon.spawn` yaws them at the player directly
  /// (`ItemMenuIcon.java:117-120`).
  inGame,

  /// What the author is drawing. Component *positions* really are rotated to
  /// sit in front of the player (`MenuComponent.rotateByPlayer`,
  /// `MenuComponent.java:142-144`), so this mode carries that rotation through
  /// to the glyphs as well — the menu the 2D canvas shows, stood up in 3D.
  intent;

  String get label => switch (this) {
    PreviewFacingMode.inGame => 'In-game',
    PreviewFacingMode.intent => 'Intent',
  };

  /// One line for a chip or a tooltip.
  String get summary => switch (this) {
    PreviewFacingMode.inGame =>
      'Text, image and animated icons face world yaw 0. Item icons face '
          'the player.',
    PreviewFacingMode.intent =>
      'Every icon faces the yaw the menu was opened at.',
  };

  /// One line for the in-stage note. Says which mode you are in and that the
  /// result is HoloUi's, not the preview's; the rest is behind the toolbar's
  /// facing help so the stage stays out of the way.
  String get headline => switch (this) {
    PreviewFacingMode.inGame =>
      'Positions follow the player, glyphs do not. A HoloUi quirk, not a '
          'preview artifact.',
    PreviewFacingMode.intent =>
      'Every icon turned to the open yaw. The server will not render text '
          'or images this way.',
  };

  /// The teaching copy. In-game mode has to explain why it looks wrong,
  /// because looking wrong is the correct result.
  String get explanation => switch (this) {
    PreviewFacingMode.inGame =>
      'The layout follows the player but the glyphs do not. HoloUi rotates '
          'every component position by the yaw at open, then spawns text, '
          'image and animated icons at world yaw 0 and never rotates them '
          '(billboard is FIXED and MenuSession.rotate has no caller). Only '
          'item icons are yawed at the player, once, at spawn. So a menu '
          'authored at one yaw reads correctly there and slides toward '
          'edge-on everywhere else. This is a HoloUi bug, not a preview '
          'artifact.',
    PreviewFacingMode.intent =>
      'Every quad is turned to the open yaw — the menu as you are drawing '
          'it. Useful for judging layout, but the server will not render '
          'text, image or animated icons this way. Switch to In-game to '
          'see what a player gets.',
  };
}

/// Imperative commands the preview chrome sends to the stage.
///
/// The chrome (a Jaspr subtree that rebuilds) and the stage (an imperative DOM
/// subtree that must not) are separate files owned by separate tasks, so they
/// meet on this interface rather than on a shared widget tree. The stage
/// registers itself on mount and clears the field on dispose.
abstract interface class PreviewStageController {
  /// Frames the menu from the position the player opened it at.
  void resetCamera();

  /// Re-captures feet and yaw from the current camera, rebuilds the simulation
  /// and clears the log — the runtime has no reopen either, it builds a fresh
  /// `MenuSession`.
  void reopenHere();
}

/// Append-only record of every simulated click.
///
/// The simulation returns entries rather than buffering them
/// (`PreviewSimulation.click`), so ownership of the buffer is here, where it
/// survives the view being unmounted.
class PreviewLogBuffer extends ChangeNotifier {
  final List<ActionLogEntry> _entries = <ActionLogEntry>[];
  int _dropped = 0;

  late final List<ActionLogEntry> entries =
      UnmodifiableListView<ActionLogEntry>(_entries);

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  bool get isNotEmpty => _entries.isNotEmpty;

  /// Entries evicted by [huiPreviewLogCapacity]. Shown rather than hidden: a
  /// silently truncated log would misrepresent a busy menu.
  int get droppedCount => _dropped;

  void addAll(Iterable<ActionLogEntry> added) {
    if (added.isEmpty) return;
    _entries.addAll(added);
    if (_entries.length > huiPreviewLogCapacity) {
      final int excess = _entries.length - huiPreviewLogCapacity;
      _entries.removeRange(0, excess);
      _dropped += excess;
    }
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty && _dropped == 0) return;
    _entries.clear();
    _dropped = 0;
    notifyListeners();
  }
}

/// Per-tick readouts the HUD shows.
///
/// Written by the stage on every simulation tick and notifying only on a real
/// change, which is what keeps a hovered-but-motionless preview from rebuilding
/// the HUD twenty times a second.
class PreviewLiveState extends ChangeNotifier {
  String? _hoveredId;
  int _hoveredIds = 0;
  int _hoverTicks = 0;
  double _hoverPushBlocks = 0;
  double _highlightModifier = 0;
  double _distanceToCenter = 0;
  bool _isOpen = true;
  PreviewCloseReason? _closeReason;
  bool _movementLocked = false;

  /// First hovered clickable in declaration order — the one a click reaches
  /// first, and the one the HUD names.
  String? get hoveredId => _hoveredId;

  /// How many clickables the look ray is inside. More than one means a single
  /// click fires all of them (`SessionHolder.java:145-159`).
  int get hoveredIds => _hoveredIds;

  /// Consecutive ticks [hoveredId] has been held, counting from 1.
  int get hoverTicks => _hoverTicks;

  /// Blocks [hoveredId] is currently displaced toward the eye.
  double get hoverPushBlocks => _hoverPushBlocks;

  /// The authored modifier for [hoveredId], unclamped.
  double get highlightModifier => _highlightModifier;

  /// Player to menu centre, in blocks. Compared against `maxDistance`.
  double get distanceToCenter => _distanceToCenter;

  bool get isOpen => _isOpen;

  /// Non-null once the session closed; the wire name is the runtime's own
  /// token.
  PreviewCloseReason? get closeReason => _closeReason;

  /// True while a `lockPosition` menu is open — the runtime rewrites the move
  /// destination back to its origin (`MenuSessionManager.java:115-127`).
  bool get movementLocked => _movementLocked;

  void update({
    required String? hoveredId,
    required int hoveredIds,
    required int hoverTicks,
    required double hoverPushBlocks,
    required double highlightModifier,
    required double distanceToCenter,
    required bool isOpen,
    required PreviewCloseReason? closeReason,
    required bool movementLocked,
  }) {
    if (hoveredId == _hoveredId &&
        hoveredIds == _hoveredIds &&
        hoverTicks == _hoverTicks &&
        hoverPushBlocks == _hoverPushBlocks &&
        highlightModifier == _highlightModifier &&
        distanceToCenter == _distanceToCenter &&
        isOpen == _isOpen &&
        closeReason == _closeReason &&
        movementLocked == _movementLocked) {
      return;
    }
    _hoveredId = hoveredId;
    _hoveredIds = hoveredIds;
    _hoverTicks = hoverTicks;
    _hoverPushBlocks = hoverPushBlocks;
    _highlightModifier = highlightModifier;
    _distanceToCenter = distanceToCenter;
    _isOpen = isOpen;
    _closeReason = closeReason;
    _movementLocked = movementLocked;
    notifyListeners();
  }

  void reset() => update(
    hoveredId: null,
    hoveredIds: 0,
    hoverTicks: 0,
    hoverPushBlocks: 0,
    highlightModifier: 0,
    distanceToCenter: 0,
    isOpen: true,
    closeReason: null,
    movementLocked: false,
  );
}

/// Everything about one preview session that survives a remount.
class PreviewPose extends ChangeNotifier {
  PreviewPose();

  /// Camera pose per mode, so switching orbit to Player and back does not throw
  /// away where you were standing. Which one is live is `store.previewCameraMode`.
  OrbitCamera orbit = const OrbitCamera(distance: 4.5, pitchDegrees: 4);
  PlayerPose player = const PlayerPose();

  PVec3 _openFeet = PVec3.zero;
  double _openYawDeg = 0;
  PreviewFacingMode _facing = PreviewFacingMode.inGame;
  bool _paused = false;
  int _sessionId = 0;

  /// Registered by the stage on mount, cleared on dispose. Null while the
  /// preview view is not mounted, which is exactly when its commands are
  /// meaningless.
  PreviewStageController? controller;

  final PreviewLogBuffer log = PreviewLogBuffer();
  final PreviewLiveState live = PreviewLiveState();

  /// Where the player stood when the menu opened. The menu anchors on the FEET,
  /// not the eyes (`MenuSession.java:73`).
  PVec3 get openFeet => _openFeet;

  /// The yaw the player had at open, in degrees. The menu's one and only
  /// rotation (`MenuSession.java:119-122`).
  double get openYawDeg => _openYawDeg;

  PreviewFacingMode get facing => _facing;

  /// Stops the preview's 50 ms clock: animated frames stop advancing and
  /// obfuscated glyphs stop scrambling.
  ///
  /// Separate from `store.animationsPlaying`, which is the canvas's own
  /// playback switch — the preview has to be pausable without freezing the 2D
  /// view, and a paused preview must go all the way to zero scheduled frames
  /// rather than merely holding the frame index still.
  bool get paused => _paused;

  /// Bumped by [captureOpen]. A new id means a fresh `MenuSession`.
  int get sessionId => _sessionId;

  set facing(PreviewFacingMode value) {
    if (_facing == value) return;
    _facing = value;
    notifyListeners();
  }

  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    notifyListeners();
  }

  /// Records a new open. Callers rebuild the simulation from this; the log is
  /// theirs to clear, because "reopen" and "keep the history" are both
  /// defensible and the chrome decides.
  void captureOpen({required PVec3 feet, required double yawDeg}) {
    _openFeet = feet;
    _openYawDeg = yawDeg.isFinite ? yawDeg : 0;
    _sessionId++;
    live.reset();
    notifyListeners();
  }
}

/// The one session. Held at top level so unmounting the preview view — which
/// the shell does on every switch away — costs nothing but the DOM.
final PreviewPose huiPreviewPose = PreviewPose();

/// Restores the "source omitted" flag the decoder erases.
///
/// `HuiCommandAction._readSource` normalises both an absent and a blank
/// `source` to `server`, so the model alone cannot tell an omitted key from an
/// explicit console dispatch — and the distinction matters, because omitting
/// the key is the format's sharpest edge (`CommandMenuAction.java:34-40`).
/// T1.4 added `absentKeys` for exactly this; the simulation builds its entries
/// from `HuiAction`s alone and has no menu to consult, so the re-marking
/// happens here, where the menu is at hand.
///
/// Index matching is guarded: an entry whose action count does not line up with
/// the component's list is returned untouched rather than mis-labelled.
List<ActionLogEntry> huiMarkOmittedCommandSources(
  List<ActionLogEntry> entries,
  HuiMenu menu,
) {
  if (entries.isEmpty) return entries;
  return <ActionLogEntry>[
    for (final ActionLogEntry entry in entries)
      _remark(entry, _sourceActions(entry, menu)),
  ];
}

List<HuiAction>? _sourceActions(ActionLogEntry entry, HuiMenu menu) {
  for (final HuiComponent component in menu.components) {
    if (component.id != entry.componentId) continue;
    return switch ((component.data, entry.trigger)) {
      (HuiButtonData data, ActionLogTrigger.button) => data.actions,
      (HuiToggleData data, ActionLogTrigger.toggleToTrue) => data.trueActions,
      (HuiToggleData data, ActionLogTrigger.toggleToFalse) => data.falseActions,
      _ => null,
    };
  }
  return null;
}

ActionLogEntry _remark(ActionLogEntry entry, List<HuiAction>? source) {
  if (source == null || source.length != entry.actions.length) return entry;
  bool changed = false;
  final List<LoggedAction> actions = <LoggedAction>[];
  for (int i = 0; i < source.length; i++) {
    final HuiAction action = source[i];
    if (action is HuiCommandAction &&
        action.absentKeys.contains('source') &&
        entry.actions[i] is LoggedCommand) {
      actions.add(LoggedCommand.from(action, sourceOmitted: true));
      changed = true;
    } else {
      actions.add(entry.actions[i]);
    }
  }
  if (!changed) return entry;
  return ActionLogEntry(
    tick: entry.tick,
    componentId: entry.componentId,
    trigger: entry.trigger,
    actions: List<LoggedAction>.unmodifiable(actions),
  );
}
