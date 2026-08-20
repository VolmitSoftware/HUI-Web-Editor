/// The runtime's per-tick behaviour, as a pure deterministic state machine.
///
/// This is the half of the preview that has no geometry in it. Picking — which
/// planes the look ray currently hits — belongs to `projection.dart`; this
/// machine consumes the answer as a plain `Set<String>` of hovered clickable
/// ids and owns everything that follows from it: hover-tick counters, click
/// dispatch, toggle state, the menu centre and the range close.
///
/// Positions use the same transformed menu origin as the runtime. Static menus
/// keep their open pose; `followPlayer` updates both the anchor and facing yaw
/// from each movement event before the next scene is built.
library;

import '../model/hui_actions.dart';
import '../model/hui_component.dart';
import '../model/hui_menu.dart';
import 'action_log.dart';
import 'preview_types.dart';
import 'projection.dart';

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
    required this.hoverDurationTicks,
    required this.hoverEasing,
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
  final int hoverDurationTicks;
  final HuiHoverEasing hoverEasing;

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

  /// The transformed runtime menu origin.
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
    this.openYawDeg = 0,
    bool Function(String componentId)? initialToggleState,
  }) : menuOffset = PVec3(menu.offset.x, menu.offset.y, menu.offset.z),
       maxDistance = menu.maxDistance,
       followPlayer = menu.followPlayer,
       lockPosition = menu.lockPosition,
       _clickables = List<SimClickable>.unmodifiable(_collectClickables(menu)) {
    _anchorFeet = openFeet;
    _facingYawDeg = openYawDeg.isFinite ? openYawDeg : 0;
    _center = _menuCenter(_anchorFeet, _facingYawDeg);
    for (final SimClickable clickable in _clickables) {
      _toggleStates.add(
        clickable.kind == SimClickableKind.toggle
            ? (initialToggleState?.call(clickable.id) ?? true)
            : null,
      );
      _highlightById.putIfAbsent(
        clickable.id,
        () => clickable.highlightModifier,
      );
    }
  }

  final PVec3 openFeet;
  final double openYawDeg;

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
  late PVec3 _anchorFeet;
  late double _facingYawDeg;
  Set<String> _hoveredIds = const <String>{};
  int _tickCount = 0;
  bool _open = true;
  PreviewCloseReason? _closeReason;

  /// Clickables in declaration order, used for equal-distance fallback ties.
  List<SimClickable> get clickables => _clickables;

  int get tickCount => _tickCount;

  PVec3 get center => _center;

  PVec3 get anchorFeet => _anchorFeet;

  double get facingYawDeg => _facingYawDeg;

  bool get isOpen => _open;

  PreviewCloseReason? get closeReason => _closeReason;

  /// `MenuSessionManager.java:115-127` rewrites the move destination back to
  /// its origin and zeroes velocity while a `lockPosition` session is open.
  bool get movementLocked => lockPosition && _open;

  Set<String> get hoveredIds => _hoveredIds;

  int hoverTicksFor(String id) => _hoverTicks[id] ?? 0;

  double? highlightModifierFor(String id) => _highlightById[id];

  int hoverDurationFor(String id) =>
      _clickableById(id)?.hoverDurationTicks ?? 0;

  HuiHoverEasing hoverEasingFor(String id) =>
      _clickableById(id)?.hoverEasing ?? huiRuntimeDefaultHoverEasing;

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
    double? playerYawDeg,
  }) {
    if (!_open) {
      return _result(playerFeet: playerFeet, closedThisTick: null);
    }

    _tickCount++;

    if (lockPosition) {
      if (followPlayer) {
        _follow(openFeet, playerYawDeg);
      }
      _advanceHover(hoveredClickableIds);
      return _result(playerFeet: openFeet, closedThisTick: null);
    }

    // The runtime hangs the range test off PlayerMoveEvent, which also fires on
    // look-only changes. It is evaluated against the centre the menu still has
    // before followPlayer re-anchors it.
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
      _follow(playerFeet, playerYawDeg);
    }

    _advanceHover(hoveredClickableIds);
    return _result(playerFeet: playerFeet, closedThisTick: null);
  }

  /// One accepted click, dispatched as the nearest event-time intersection.
  /// [componentId] is the
  /// geometry pass's nearest result; pure state-machine callers fall back to
  /// the first hovered component, matching declaration-order tie-breaking.
  List<ActionLogEntry> click({
    String trigger = 'left_click',
    String? componentId,
  }) {
    if (!_open) return const <ActionLogEntry>[];

    String? target = componentId;
    if (target == null) {
      for (final SimClickable clickable in _clickables) {
        if (_hoveredIds.contains(clickable.id)) {
          target = clickable.id;
          break;
        }
      }
    }
    if (target == null) {
      return const <ActionLogEntry>[];
    }

    for (int i = 0; i < _clickables.length; i++) {
      final SimClickable clickable = _clickables[i];
      if (clickable.id != target) continue;

      switch (clickable.kind) {
        case SimClickableKind.button:
          return <ActionLogEntry>[
            ActionLogEntry(
              tick: _tickCount,
              componentId: clickable.id,
              trigger: ActionLogTrigger.button,
              clickTrigger: trigger,
              actions: loggedActionsFrom(
                clickable.actions,
                clickTrigger: trigger,
              ),
            ),
          ];
        case SimClickableKind.toggle:
          // ToggleComponent.java:52-61 fires the list named for the state it is
          // moving INTO, then swaps the icon and stores the new state.
          final bool next = !(_toggleStates[i] ?? false);
          final List<LoggedAction> actions = loggedActionsFrom(
            next ? clickable.trueActions : clickable.falseActions,
            clickTrigger: trigger,
          );
          if (actions.isEmpty || actions.last is! LoggedNavigation) {
            _toggleStates[i] = next;
          }
          return <ActionLogEntry>[
            ActionLogEntry(
              tick: _tickCount,
              componentId: clickable.id,
              trigger: next
                  ? ActionLogTrigger.toggleToTrue
                  : ActionLogTrigger.toggleToFalse,
              clickTrigger: trigger,
              actions: actions,
            ),
          ];
      }
    }
    return const <ActionLogEntry>[];
  }

  void _advanceHover(Set<String> requested) {
    final Set<String> next = <String>{};
    for (final SimClickable clickable in _clickables) {
      if (requested.contains(clickable.id)) next.add(clickable.id);
    }
    for (final SimClickable clickable in _clickables) {
      final String id = clickable.id;
      final int current = _hoverTicks[id] ?? 0;
      final int duration = clickable.hoverDurationTicks;
      final int updated;
      if (duration == 0) {
        updated = next.contains(id) ? 1 : 0;
      } else if (next.contains(id)) {
        updated = current >= duration ? duration : current + 1;
      } else {
        updated = current <= 0 ? 0 : current - 1;
      }
      if (updated == 0) {
        _hoverTicks.remove(id);
      } else {
        _hoverTicks[id] = updated;
      }
    }
    _hoveredIds = Set<String>.unmodifiable(next);
  }

  SimClickable? _clickableById(String id) {
    for (final SimClickable clickable in _clickables) {
      if (clickable.id == id) return clickable;
    }
    return null;
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

  void _follow(PVec3 playerFeet, double? playerYawDeg) {
    _anchorFeet = playerFeet;
    if (playerYawDeg != null && playerYawDeg.isFinite) {
      _facingYawDeg = playerYawDeg;
    }
    _center = _menuCenter(_anchorFeet, _facingYawDeg);
  }

  PVec3 _menuCenter(PVec3 anchor, double yawDegrees) =>
      anchor + huiMenuVector(menuOffset, facingYawDegrees: yawDegrees);

  static List<SimClickable> _collectClickables(HuiMenu menu) {
    final List<SimClickable> out = <SimClickable>[];
    final Set<String> ids = <String>{};
    for (final HuiComponent component in menu.components) {
      if (!ids.add(component.id)) continue;
      switch (component.data) {
        case HuiButtonData(
          :final double highlightModifier,
          :final int hoverDurationTicks,
          :final HuiHoverEasing hoverEasing,
          :final List<HuiAction> actions,
        ):
          out.add(
            SimClickable(
              id: component.id,
              kind: SimClickableKind.button,
              highlightModifier: highlightModifier,
              hoverDurationTicks: hoverDurationTicks,
              hoverEasing: hoverEasing,
              actions: List<HuiAction>.unmodifiable(actions),
              trueActions: const <HuiAction>[],
              falseActions: const <HuiAction>[],
            ),
          );
        case HuiToggleData(
          :final double highlightModifier,
          :final int hoverDurationTicks,
          :final HuiHoverEasing hoverEasing,
          :final List<HuiAction> trueActions,
          :final List<HuiAction> falseActions,
        ):
          out.add(
            SimClickable(
              id: component.id,
              kind: SimClickableKind.toggle,
              highlightModifier: highlightModifier,
              hoverDurationTicks: hoverDurationTicks,
              hoverEasing: hoverEasing,
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
