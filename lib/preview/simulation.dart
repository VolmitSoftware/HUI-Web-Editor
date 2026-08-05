/// The runtime's per-tick behaviour, as a pure deterministic state machine.
///
/// This is the half of the preview that has no geometry in it. Picking — which
/// planes the look ray currently hits — belongs to `projection.dart`; this
/// machine consumes the answer as a plain `Set<String>` of hovered clickable
/// ids and owns everything that follows from it: hover-tick counters, click
/// dispatch, toggle state, the menu centre and the range close.
///
/// Positions here are unrotated authoring-frame values. The menu's one yaw
/// rotation is frozen at open and applied by `preview_scene.dart`; it turns
/// component locations about the player's own vertical axis
/// (`MenuComponent.java:142-144`), which preserves the distance from the player
/// to the centre, so the range test below is unaffected by it.
library;

import '../model/hui_actions.dart';
import '../model/hui_component.dart';
import '../model/hui_menu.dart';
import 'action_log.dart';
import 'preview_types.dart';

/// The two component types that have a collision plane. `decoration` has none
/// — `DecoComponent` is not a `ClickableComponent`, so it never highlights and
/// never fires, while `MenuComponent.java:62-67` still ticks its icon and its
/// animation keeps running.
enum SimClickableKind { button, toggle }

/// One clickable, flattened out of the document in declaration order.
class SimClickable {
  const SimClickable({
    required this.id,
    required this.kind,
    required this.highlightModifier,
    required this.actions,
    required this.trueActions,
    required this.falseActions,
  });

  final String id;
  final SimClickableKind kind;

  /// Raw, unclamped: Gson writes the field directly, so the Java API's 0..1
  /// clamp never runs on a parsed value and `ClickableComponent.java:63-65`
  /// multiplies the plane normal by whatever the file said.
  final double highlightModifier;

  /// `button` only.
  final List<HuiAction> actions;

  /// `toggle` only — named for the state they lead *into*
  /// (`ToggleComponent.java:52-61`).
  final List<HuiAction> trueActions;
  final List<HuiAction> falseActions;
}

/// The machine's observable state after one tick.
class PreviewTickResult {
  const PreviewTickResult({
    required this.tick,
    required this.center,
    required this.distanceToCenter,
    required this.hoveredIds,
    required this.hoverTicks,
    required this.isOpen,
    required this.closedThisTick,
    required this.movementLocked,
  });

  final int tick;

  /// Menu centre in the authoring frame, before the frozen open-yaw rotation.
  final PVec3 center;
  final double distanceToCenter;

  /// Effective hover, in declaration order: decorations and unknown ids are
  /// dropped from whatever the caller passed in.
  final Set<String> hoveredIds;

  /// Consecutive ticks each hovered id has been held, counting from 1.
  final Map<String, int> hoverTicks;

  final bool isOpen;

  /// Non-null only on the tick the session closed; the reason persists on the
  /// machine afterwards.
  final PreviewCloseReason? closedThisTick;

  final bool movementLocked;
}

/// A single simulated `MenuSession`.
///
/// Seed one per open. There is no reopen: T2.1's "reopen here" builds a new
/// machine, exactly as the runtime builds a new `MenuSession`.
class PreviewSimulation {
  /// [initialToggleState] stands in for `ToggleComponent.java:48`, which
  /// samples `condition == expectedValue` once at open. The condition is a
  /// PlaceholderAPI expression the editor cannot evaluate, so the caller
  /// supplies its own answer — the editor passes `store.togglePreviewFor`.
  /// Absent, every toggle opens true, matching the canvas default.
  PreviewSimulation({
    required HuiMenu menu,
    required this.openFeet,
    bool Function(String componentId)? initialToggleState,
  }) : menuOffset = PVec3(menu.offset.x, menu.offset.y, menu.offset.z),
       maxDistance = menu.maxDistance,
       followPlayer = menu.followPlayer,
       lockPosition = menu.lockPosition,
       _clickables = List<SimClickable>.unmodifiable(_collectClickables(menu)) {
    // MenuSession.java:73 anchors on player.getLocation() — the feet — and the
    // menu offset is the one offset uiScale never touches
    // (HuiSettings.java:60-66).
    _center = openFeet + menuOffset;
    for (final SimClickable clickable in _clickables) {
      _toggleStates.add(
        clickable.kind == SimClickableKind.toggle
            ? (initialToggleState?.call(clickable.id) ?? true)
            : null,
      );
      // MenuSession.java:79 builds the id map with putIfAbsent, so a duplicate
      // id resolves to the first component that claimed it.
      _highlightById.putIfAbsent(
        clickable.id,
        () => clickable.highlightModifier,
      );
    }
  }

  final PVec3 openFeet;

  /// Menu offset in the authoring frame; its squared length loosens the range
  /// test (`MenuSession.java:57-80`).
  final PVec3 menuOffset;

  /// Null means the key was absent, which the plugin reads as the 6e7 ceiling.
  final double? maxDistance;
  final bool followPlayer;
  final bool lockPosition;

  final List<SimClickable> _clickables;
  final List<bool?> _toggleStates = <bool?>[];
  final Map<String, double> _highlightById = <String, double>{};
  final Map<String, int> _hoverTicks = <String, int>{};

  late PVec3 _center;
  Set<String> _hoveredIds = const <String>{};
  int _tickCount = 0;
  bool _open = true;
  PreviewCloseReason? _closeReason;

  /// Clickables in declaration order — the order a click dispatches in.
  List<SimClickable> get clickables => _clickables;

  int get tickCount => _tickCount;

  PVec3 get center => _center;

  bool get isOpen => _open;

  PreviewCloseReason? get closeReason => _closeReason;

  /// `MenuSessionManager.java:115-127` rewrites the move destination back to
  /// its origin and zeroes velocity while a `lockPosition` session is open.
  bool get movementLocked => lockPosition && _open;

  Set<String> get hoveredIds => _hoveredIds;

  int hoverTicksFor(String id) => _hoverTicks[id] ?? 0;

  double? highlightModifierFor(String id) => _highlightById[id];

  /// Null for a decoration, an unknown id, or a button.
  bool? toggleStateFor(String id) {
    for (int i = 0; i < _clickables.length; i++) {
      if (_clickables[i].id == id) return _toggleStates[i];
    }
    return null;
  }

  PreviewTickResult tick({
    required Set<String> hoveredClickableIds,
    required PVec3 playerFeet,
  }) {
    if (!_open) {
      return _result(playerFeet: playerFeet, closedThisTick: null);
    }

    _tickCount++;

    // The runtime hangs the range test off PlayerMoveEvent, which also fires on
    // look-only changes, so it runs effectively every tick. Two orderings from
    // MenuSessionManager.java:104-131 are load-bearing and reproduced here: it
    // is evaluated against the centre the menu STILL has, before followPlayer
    // re-anchors it, and it runs before the lockPosition freeze — a frozen
    // session is not exempt.
    if (!huiWithinMaxDistance(
      playerFeet: playerFeet,
      center: _center,
      maxDistance: maxDistance,
      menuOffset: menuOffset,
    )) {
      _open = false;
      _closeReason = PreviewCloseReason.movedOutOfRange;
      // ClickableComponent.java:72-75 drops selection on close.
      _hoverTicks.clear();
      _hoveredIds = const <String>{};
      return _result(playerFeet: playerFeet, closedThisTick: _closeReason);
    }

    if (followPlayer) {
      // MenuSession.java:103-109 re-anchors the whole session on the new feet.
      _center = playerFeet + menuOffset;
    }

    _advanceHover(hoveredClickableIds);
    return _result(playerFeet: playerFeet, closedThisTick: null);
  }

  /// One left click, dispatched exactly as `MenuSessionManager.dispatchClick`
  /// does it: `SessionHolder.java:145-159` snapshots EVERY component that is
  /// currently selected, in component-list order, and the dispatcher calls
  /// `onClick` on all of them. Overlapping hitboxes are never deduplicated —
  /// teaching that is the point of the preview.
  ///
  /// Selection is last tick's state, so a click resolves against the hover set
  /// the previous [tick] produced.
  List<ActionLogEntry> click() {
    if (!_open) return const <ActionLogEntry>[];

    final List<ActionLogEntry> fired = <ActionLogEntry>[];
    for (int i = 0; i < _clickables.length; i++) {
      final SimClickable clickable = _clickables[i];
      if (!_hoverTicks.containsKey(clickable.id)) continue;

      switch (clickable.kind) {
        case SimClickableKind.button:
          fired.add(
            ActionLogEntry(
              tick: _tickCount,
              componentId: clickable.id,
              trigger: ActionLogTrigger.button,
              actions: loggedActionsFrom(clickable.actions),
            ),
          );
        case SimClickableKind.toggle:
          // ToggleComponent.java:52-61 fires the list named for the state it is
          // moving INTO, then swaps the icon and stores the new state.
          final bool next = !(_toggleStates[i] ?? false);
          _toggleStates[i] = next;
          fired.add(
            ActionLogEntry(
              tick: _tickCount,
              componentId: clickable.id,
              trigger: next
                  ? ActionLogTrigger.toggleToTrue
                  : ActionLogTrigger.toggleToFalse,
              actions: loggedActionsFrom(
                next ? clickable.trueActions : clickable.falseActions,
              ),
            ),
          );
      }
    }
    return fired;
  }

  void _advanceHover(Set<String> requested) {
    final Set<String> next = <String>{};
    for (final SimClickable clickable in _clickables) {
      if (requested.contains(clickable.id)) next.add(clickable.id);
    }
    _hoverTicks.removeWhere((String id, int _) => !next.contains(id));
    for (final String id in next) {
      // Entry is tick 1; a held hover keeps climbing; an exit drops the entry
      // entirely so re-entry starts over (ClickableComponent.java:63-69).
      _hoverTicks[id] = (_hoverTicks[id] ?? 0) + 1;
    }
    _hoveredIds = Set<String>.unmodifiable(next);
  }

  PreviewTickResult _result({
    required PVec3 playerFeet,
    required PreviewCloseReason? closedThisTick,
  }) => PreviewTickResult(
    tick: _tickCount,
    center: _center,
    distanceToCenter: _center.distanceTo(playerFeet),
    hoveredIds: _hoveredIds,
    // Snapshot: a result must not mutate under a caller that holds it.
    hoverTicks: Map<String, int>.unmodifiable(_hoverTicks),
    isOpen: _open,
    closedThisTick: closedThisTick,
    movementLocked: movementLocked,
  );

  static List<SimClickable> _collectClickables(HuiMenu menu) {
    final List<SimClickable> out = <SimClickable>[];
    for (final HuiComponent component in menu.components) {
      switch (component.data) {
        case HuiButtonData(
          :final double highlightModifier,
          :final List<HuiAction> actions,
        ):
          out.add(
            SimClickable(
              id: component.id,
              kind: SimClickableKind.button,
              highlightModifier: highlightModifier,
              actions: List<HuiAction>.unmodifiable(actions),
              trueActions: const <HuiAction>[],
              falseActions: const <HuiAction>[],
            ),
          );
        case HuiToggleData(
          :final double highlightModifier,
          :final List<HuiAction> trueActions,
          :final List<HuiAction> falseActions,
        ):
          out.add(
            SimClickable(
              id: component.id,
              kind: SimClickableKind.toggle,
              highlightModifier: highlightModifier,
              actions: const <HuiAction>[],
              trueActions: List<HuiAction>.unmodifiable(trueActions),
              falseActions: List<HuiAction>.unmodifiable(falseActions),
            ),
          );
        case HuiDecorationData():
          // No plane, no selection, no click. Its icon still ticks, which is
          // why an animated decoration keeps animating.
          break;
      }
    }
    return out;
  }
}
