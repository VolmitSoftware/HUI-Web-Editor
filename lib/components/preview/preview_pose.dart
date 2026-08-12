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
///  * [PreviewPose] itself notifies for session changes such as a reopen.
///    Camera writes are SILENT (see [PreviewPose.orbit]); a 60 fps
///    orbit drag must never rebuild a Jaspr subtree.
///  * [PreviewPose.live] notifies for per-tick readouts, and only when a value
///    actually changed, so a parked pointer over a static menu notifies nobody.
///  * [PreviewPose.log] notifies only on append or clear.
library;

import 'dart:collection';

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../../preview/action_log.dart';
import '../../preview/preview_types.dart';

/// Entries kept before the oldest is dropped.
const int huiPreviewLogCapacity = 500;

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

  /// Nearest hovered clickable, and the one the HUD names.
  String? get hoveredId => _hoveredId;

  /// How many clickable planes the look ray intersects before nearest-hit
  /// arbitration.
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

  /// The yaw the player had at open, in degrees. Static menus retain it;
  /// `followPlayer` menus replace their current facing as the player looks.
  double get openYawDeg => _openYawDeg;

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
