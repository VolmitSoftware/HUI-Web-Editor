/// The preview's runtime state machine and the action-log model it emits.
///
/// Every expectation here is a HoloUi behaviour a reasonable implementation
/// would smooth over: overlapping hitboxes all fire, a wrong-case command
/// source silently becomes a console dispatch, `volume: 0` is the format
/// default and is silent, and the range test is deliberately loosened by the
/// menu offset. Each is cited to the Java that produces it.
library;

import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/preview/action_log.dart';
import 'package:holoui_editor/preview/preview_types.dart';
import 'package:holoui_editor/preview/simulation.dart';
import 'package:test/test.dart';

HuiComponent _button(
  String id, {
  double highlightModifier = 0.05,
  List<HuiAction>? actions,
}) =>
    HuiComponent(
      id,
      Vec3.zero(),
      HuiButtonData(highlightModifier, actions ?? <HuiAction>[]),
    );

HuiComponent _decoration(String id) =>
    HuiComponent(id, Vec3.zero(), HuiDecorationData());

HuiComponent _toggle(
  String id, {
  double highlightModifier = 0.05,
  List<HuiAction>? trueActions,
  List<HuiAction>? falseActions,
}) =>
    HuiComponent(
      id,
      Vec3.zero(),
      HuiToggleData(
        highlightModifier,
        '%player_name%',
        'Steve',
        trueActions ?? <HuiAction>[],
        falseActions ?? <HuiAction>[],
      ),
    );

HuiMenu _menu(
  List<HuiComponent> components, {
  Vec3? offset,
  double? maxDistance,
  bool followPlayer = false,
  bool lockPosition = false,
}) =>
    HuiMenu(
      offset: offset ?? Vec3(0, 1, 2),
      maxDistance: maxDistance,
      followPlayer: followPlayer,
      lockPosition: lockPosition,
      components: components,
    );

PreviewSimulation _sim(
  HuiMenu menu, {
  PVec3 openFeet = PVec3.zero,
  bool Function(String id)? initialToggleState,
}) =>
    PreviewSimulation(
      menu: menu,
      openFeet: openFeet,
      initialToggleState: initialToggleState,
    );

HuiCommandAction _command(String command, [String source = 'player']) =>
    HuiCommandAction(command, source);

void main() {
  group('seeding', () {
    test('collects clickables in declaration order and skips decorations', () {
      // SessionHolder.snapshotClick walks MenuSession's component list, which is
      // built straight from the JSON order (MenuSession.java:74-77).
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _decoration('backdrop'),
        _button('one'),
        _decoration('label'),
        _toggle('two'),
        _button('three'),
      ]));

      expect(
        sim.clickables.map((SimClickable c) => c.id).toList(),
        <String>['one', 'two', 'three'],
      );
      expect(sim.clickables[1].kind, SimClickableKind.toggle);
      expect(sim.clickables[0].kind, SimClickableKind.button);
    });

    test('carries per-clickable highlightModifier verbatim', () {
      // Gson writes the field directly, so the Java API's 0..1 clamp never runs
      // on parsed values (ClickableComponent.java:111-116 uses it raw).
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _button('raw', highlightModifier: 3),
        _toggle('zero', highlightModifier: 0),
      ]));

      expect(sim.highlightModifierFor('raw'), 3);
      expect(sim.highlightModifierFor('zero'), 0);
      expect(sim.highlightModifierFor('missing'), isNull);
    });

    test('centres the menu on the open feet plus the unscaled menu offset', () {
      // MenuSession.java:73 anchors on player.getLocation() — the feet — and the
      // menu offset is never multiplied by uiScale (HuiSettings.java:60-66).
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_button('a')], offset: Vec3(1, 2, 3)),
        openFeet: const PVec3(10, 64, -5),
      );

      expect(sim.center, const PVec3(11, 66, -2));
      expect(sim.menuOffset, const PVec3(1, 2, 3));
    });

    test('toggle state is seeded by the caller, defaulting to true', () {
      // `condition` is a PAPI expression the editor cannot evaluate, so the
      // editor substitutes its own canvas preview choice
      // (ToggleComponent.java:48 samples it once at open).
      final HuiMenu menu = _menu(<HuiComponent>[_toggle('lamp'), _toggle('door')]);

      expect(_sim(menu).toggleStateFor('lamp'), isTrue);
      expect(
        _sim(menu, initialToggleState: (String id) => id == 'door')
            .toggleStateFor('lamp'),
        isFalse,
      );
      expect(_sim(menu).toggleStateFor('nope'), isNull);
    });

    test('a button reports no toggle state', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      expect(sim.toggleStateFor('a'), isNull);
    });

    test('opens with no hover, open, tick zero', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      expect(sim.tickCount, 0);
      expect(sim.isOpen, isTrue);
      expect(sim.closeReason, isNull);
      expect(sim.hoveredIds, isEmpty);
    });
  });

  group('hover ticks', () {
    test('count from one on entry and keep climbing while held', () {
      // Tick 1 pushes by highlightModifier; from tick 2 rotateToFace teleports
      // the icon a full normal — 1.0 block (ClickableComponent.java:111-116).
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));

      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      expect(sim.hoverTicksFor('a'), 1);
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      expect(sim.hoverTicksFor('a'), 2);
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      expect(sim.hoverTicksFor('a'), 3);
    });

    test('reset on exit and start over at one on re-entry', () {
      // Exit teleports the icon back to `location` with no easing
      // (ClickableComponent.java:66-69), so the next entry is a fresh tick 1.
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));

      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      expect(sim.hoverTicksFor('a'), 2);

      sim.tick(hoveredClickableIds: const <String>{}, playerFeet: PVec3.zero);
      expect(sim.hoverTicksFor('a'), 0);

      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      expect(sim.hoverTicksFor('a'), 1);
    });

    test('decorations never hover, so they never accumulate ticks', () {
      // DecoComponent is not a ClickableComponent: no plane, no selection
      // (DecoComponent.java has an empty onTick; MenuComponent.java:62-67 still
      // ticks its icon, which is why animation is unaffected).
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _decoration('backdrop'),
        _button('a'),
      ]));

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: <String>{'backdrop', 'a'},
        playerFeet: PVec3.zero,
      );

      expect(result.hoveredIds, <String>{'a'});
      expect(sim.hoverTicksFor('backdrop'), 0);
    });

    test('unknown hovered ids are dropped', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: <String>{'ghost'},
        playerFeet: PVec3.zero,
      );

      expect(result.hoveredIds, isEmpty);
      expect(result.hoverTicks, isEmpty);
    });

    test('the reported hovered set follows declaration order', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _button('one'),
        _button('two'),
        _button('three'),
      ]));

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: <String>{'three', 'one', 'two'},
        playerFeet: PVec3.zero,
      );

      expect(result.hoveredIds.toList(), <String>['one', 'two', 'three']);
    });

    test('the tick counter starts the first tick at one', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      expect(
        sim
            .tick(hoveredClickableIds: const <String>{}, playerFeet: PVec3.zero)
            .tick,
        1,
      );
      expect(sim.tickCount, 1);
    });
  });

  group('click dispatch', () {
    test('every hovered clickable fires, in declaration order', () {
      // The whole reason the preview exists: MenuSessionManager.dispatchClick
      // walks SessionHolder.snapshotClick's list and calls onClick on EVERY
      // selected component (SessionHolder.java:145-159). Overlapping hitboxes
      // are not deduplicated.
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _button('one', actions: <HuiAction>[_command('say one')]),
        _button('two', actions: <HuiAction>[_command('say two')]),
        _button('three', actions: <HuiAction>[_command('say three')]),
      ]));

      sim.tick(
        hoveredClickableIds: <String>{'three', 'two', 'one'},
        playerFeet: PVec3.zero,
      );
      final List<ActionLogEntry> fired = sim.click();

      expect(
        fired.map((ActionLogEntry e) => e.componentId).toList(),
        <String>['one', 'two', 'three'],
      );
      expect(
        fired
            .map((ActionLogEntry e) => (e.actions.single as LoggedCommand).command)
            .toList(),
        <String>['say one', 'say two', 'say three'],
      );
    });

    test('a duplicate id fires once per component, not once per id', () {
      // MenuSession.java:79 dedupes only the addressing map via putIfAbsent; the
      // component list — which the click snapshot walks — keeps both.
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _button('twin', actions: <HuiAction>[_command('first')]),
        _button('twin', actions: <HuiAction>[_command('second')]),
      ]));

      sim.tick(hoveredClickableIds: <String>{'twin'}, playerFeet: PVec3.zero);
      final List<ActionLogEntry> fired = sim.click();

      expect(fired.length, 2);
      expect(
        fired
            .map((ActionLogEntry e) => (e.actions.single as LoggedCommand).command)
            .toList(),
        <String>['first', 'second'],
      );
    });

    test('decorations never fire even when named as hovered', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _decoration('backdrop'),
        _button('a'),
      ]));

      sim.tick(
        hoveredClickableIds: <String>{'backdrop', 'a'},
        playerFeet: PVec3.zero,
      );

      expect(
        sim.click().map((ActionLogEntry e) => e.componentId).toList(),
        <String>['a'],
      );
    });

    test('nothing fires before the first tick', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _button('a', actions: <HuiAction>[_command('say hi')]),
      ]));
      expect(sim.click(), isEmpty);
    });

    test('a clickable with no actions still logs that it fired', () {
      // The overlap lesson needs the empty entry: it is how the log shows that
      // three hitboxes were hit even when two of them do nothing.
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);

      final List<ActionLogEntry> fired = sim.click();
      expect(fired.single.componentId, 'a');
      expect(fired.single.actions, isEmpty);
      expect(fired.single.trigger, ActionLogTrigger.button);
    });

    test('entries carry the tick they fired on', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);

      expect(sim.click().single.tick, 2);
    });

    test('clicking uses the previous tick\'s hover set, not a live one', () {
      // isSelected() is last tick's state; the click handler only reads it
      // (MenuSessionManager.java:170-183).
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      sim.tick(hoveredClickableIds: const <String>{}, playerFeet: PVec3.zero);

      expect(sim.click(), isEmpty);
    });
  });

  group('toggle transitions', () {
    test('a true toggle clicked fires falseActions and lands on false', () {
      // ToggleComponent.java:52-61: when state is true the click runs
      // falseActions and sets state=false. trueActions fire on the transition
      // INTO true, never on the way out.
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _toggle(
          'lamp',
          trueActions: <HuiAction>[_command('lamp on')],
          falseActions: <HuiAction>[_command('lamp off')],
        ),
      ]));

      sim.tick(hoveredClickableIds: <String>{'lamp'}, playerFeet: PVec3.zero);
      final List<ActionLogEntry> fired = sim.click();

      expect(sim.toggleStateFor('lamp'), isFalse);
      expect(fired.single.trigger, ActionLogTrigger.toggleToFalse);
      expect((fired.single.actions.single as LoggedCommand).command, 'lamp off');
    });

    test('a double click round trips and fires each list once', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _toggle(
            'lamp',
            trueActions: <HuiAction>[_command('lamp on')],
            falseActions: <HuiAction>[_command('lamp off')],
          ),
        ]),
        initialToggleState: (String _) => false,
      );

      sim.tick(hoveredClickableIds: <String>{'lamp'}, playerFeet: PVec3.zero);

      final List<ActionLogEntry> first = sim.click();
      expect(sim.toggleStateFor('lamp'), isTrue);
      expect(first.single.trigger, ActionLogTrigger.toggleToTrue);
      expect((first.single.actions.single as LoggedCommand).command, 'lamp on');

      final List<ActionLogEntry> second = sim.click();
      expect(sim.toggleStateFor('lamp'), isFalse);
      expect(second.single.trigger, ActionLogTrigger.toggleToFalse);
      expect((second.single.actions.single as LoggedCommand).command, 'lamp off');

      final List<ActionLogEntry> third = sim.click();
      expect(sim.toggleStateFor('lamp'), isTrue);
      expect(third.single.trigger, ActionLogTrigger.toggleToTrue);
    });

    test('state only moves on click, never on a tick', () {
      // The condition is sampled once at open (ToggleComponent.java:48) and the
      // per-tick path never touches it again.
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_toggle('lamp')]),
        initialToggleState: (String _) => false,
      );

      for (int i = 0; i < 10; i++) {
        sim.tick(hoveredClickableIds: <String>{'lamp'}, playerFeet: PVec3.zero);
      }

      expect(sim.toggleStateFor('lamp'), isFalse);
    });

    test('two toggles sharing an id keep independent state', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_toggle('twin'), _toggle('twin')]),
        initialToggleState: (String _) => false,
      );

      sim.tick(hoveredClickableIds: <String>{'twin'}, playerFeet: PVec3.zero);
      final List<ActionLogEntry> fired = sim.click();

      expect(fired.length, 2);
      expect(
        fired.map((ActionLogEntry e) => e.trigger).toList(),
        <ActionLogTrigger>[
          ActionLogTrigger.toggleToTrue,
          ActionLogTrigger.toggleToTrue,
        ],
      );
    });
  });

  group('menu centre', () {
    test('a static menu keeps the centre it opened with', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_button('a')], offset: Vec3(0, 1, 2)),
        openFeet: PVec3.zero,
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(3, 0, 0),
      );

      expect(result.center, const PVec3(0, 1, 2));
    });

    test('followPlayer recentres on the walking player', () {
      // MenuSession.move re-anchors centerPoint on the new location
      // (MenuSession.java:103-109), driven from PlayerMoveEvent
      // (MenuSessionManager.java:129-131).
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3(0, 1, 2),
          followPlayer: true,
        ),
        openFeet: PVec3.zero,
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(3, 0, 0),
      );

      expect(result.center, const PVec3(3, 1, 2));
      expect(sim.center, const PVec3(3, 1, 2));
    });

    test('reports the distance from the feet to the centre', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_button('a')], offset: Vec3(0, 0, 3)),
        openFeet: PVec3.zero,
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(0, 0, -1),
      );

      expect(result.distanceToCenter, closeTo(4, 1e-12));
    });
  });

  group('movement lock', () {
    test('lockPosition surfaces as movementLocked while open', () {
      // MenuSessionManager.java:115-127 rewrites the destination back to the
      // origin and zeroes velocity every PlayerMoveEvent.
      final PreviewSimulation locked = _sim(
        _menu(<HuiComponent>[_button('a')], lockPosition: true),
      );
      final PreviewSimulation free = _sim(_menu(<HuiComponent>[_button('a')]));

      expect(locked.movementLocked, isTrue);
      expect(free.movementLocked, isFalse);
      expect(
        locked
            .tick(hoveredClickableIds: const <String>{}, playerFeet: PVec3.zero)
            .movementLocked,
        isTrue,
      );
    });

    test('a closed session stops locking movement', () {
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3.zero(),
          maxDistance: 1,
          lockPosition: true,
        ),
      );

      sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(50, 0, 0),
      );

      expect(sim.isOpen, isFalse);
      expect(sim.movementLocked, isFalse);
    });

    test('lockPosition does not exempt a session from the range test', () {
      // MenuSessionManager.java:104-127 evaluates isValid(e.getTo()) BEFORE the
      // freeze rewrite, so a frozen session can still close on range.
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3.zero(),
          maxDistance: 1,
          lockPosition: true,
        ),
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(0, 0, 9),
      );

      expect(result.closedThisTick, PreviewCloseReason.movedOutOfRange);
    });
  });

  group('range close', () {
    test('uses the offset-loosened threshold, not a bare distance', () {
      // MenuSession.java:147-151 compares centerDistance² against
      // maxDistance² + offset.lengthSquared(), so a menu held further out
      // tolerates a proportionally longer walk.
      final HuiMenu menu = _menu(
        <HuiComponent>[_button('a')],
        offset: Vec3(0, 0, 3),
        maxDistance: 1,
      );

      // centre = (0,0,3); at feet (0,0,-1) the distance is 4 => 16.
      // Bare test: 16 > 1. Loosened test: 16 <= 1 + 9 = 10 is false, so it
      // closes — but only just past the loosened bound.
      final PreviewSimulation far = _sim(menu.copy(), openFeet: PVec3.zero);
      expect(
        far
            .tick(
              hoveredClickableIds: const <String>{},
              playerFeet: const PVec3(0, 0, -1),
            )
            .closedThisTick,
        PreviewCloseReason.movedOutOfRange,
      );

      // distance 3 => 9 <= 10 stays open, though a bare maxDistance test
      // (9 > 1) would have closed it.
      final PreviewSimulation near = _sim(menu.copy(), openFeet: PVec3.zero);
      expect(
        near
            .tick(
              hoveredClickableIds: const <String>{},
              playerFeet: const PVec3(0, 0, 0),
            )
            .closedThisTick,
        isNull,
      );
      expect(near.isOpen, isTrue);
    });

    test('the close reason carries the runtime wire name', () {
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3.zero(),
          maxDistance: 0,
        ),
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(0, 0, 1),
      );

      expect(result.closedThisTick!.wireName, 'MOVED_OUT_OF_RANGE');
      expect(sim.closeReason, PreviewCloseReason.movedOutOfRange);
    });

    test('fires exactly once, then the machine is inert', () {
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[
            _button('a', actions: <HuiAction>[_command('say hi')]),
          ],
          offset: Vec3.zero(),
          maxDistance: 0,
        ),
      );

      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      expect(sim.hoverTicksFor('a'), 1);

      final PreviewTickResult closing = sim.tick(
        hoveredClickableIds: <String>{'a'},
        playerFeet: const PVec3(0, 0, 5),
      );
      expect(closing.closedThisTick, PreviewCloseReason.movedOutOfRange);
      expect(closing.isOpen, isFalse);
      // ClickableComponent.onClose clears selection (`:72-75`).
      expect(closing.hoveredIds, isEmpty);
      expect(sim.hoverTicksFor('a'), 0);

      final PreviewTickResult after = sim.tick(
        hoveredClickableIds: <String>{'a'},
        playerFeet: const PVec3(0, 0, 5),
      );
      expect(after.closedThisTick, isNull);
      expect(after.isOpen, isFalse);
      expect(after.hoveredIds, isEmpty);
      expect(sim.click(), isEmpty);
    });

    test('a closed machine stops advancing its tick counter', () {
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3.zero(),
          maxDistance: 0,
        ),
      );

      sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(0, 0, 5),
      );
      final int atClose = sim.tickCount;
      sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(0, 0, 5),
      );

      expect(sim.tickCount, atClose);
    });

    test('an absent maxDistance means the 6e7 ceiling, so nothing closes', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_button('a')], offset: Vec3.zero()),
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(1000000, 0, 0),
      );

      expect(result.closedThisTick, isNull);
      expect(result.isOpen, isTrue);
    });

    test('followPlayer is tested against the pre-recentre centre', () {
      // The move handler runs isValid(e.getTo()) before MenuSession.move
      // (MenuSessionManager.java:104-131), so a following menu is measured from
      // where it still is — which is why walking never closes one.
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3(0, 0, 2),
          maxDistance: 0,
          followPlayer: true,
        ),
        openFeet: PVec3.zero,
      );

      // Step sideways: centre is still (0,0,2), feet (1,0,0), distance² = 5,
      // threshold = 0 + 4 = 4 => closes. Step along the offset axis instead and
      // the distance shrinks, so it survives.
      final PreviewSimulation along = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3(0, 0, 2),
          maxDistance: 0,
          followPlayer: true,
        ),
        openFeet: PVec3.zero,
      );

      expect(
        sim
            .tick(
              hoveredClickableIds: const <String>{},
              playerFeet: const PVec3(1, 0, 0),
            )
            .closedThisTick,
        PreviewCloseReason.movedOutOfRange,
      );
      final PreviewTickResult ok = along.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(0, 0, 1),
      );
      expect(ok.closedThisTick, isNull);
      expect(ok.center, const PVec3(0, 0, 3));
    });
  });

  group('command dispatch resolution', () {
    test('only the exact token "player" runs as the player', () {
      // CommandMenuAction.java:34-40 tests `data.source() == PLAYER` and falls
      // through to the console for everything else. The enum's JSON spelling is
      // @SerializedName("player") / @SerializedName("server").
      expect(LoggedCommand(command: 'heal', source: 'player').asPlayer, isTrue);
      expect(LoggedCommand(command: 'heal', source: 'server').asPlayer, isFalse);
      expect(LoggedCommand(command: 'heal', source: 'PLAYER').asPlayer, isFalse);
      expect(LoggedCommand(command: 'heal', source: 'Player').asPlayer, isFalse);
      expect(LoggedCommand(command: 'heal', source: 'nonsense').asPlayer, isFalse);
      expect(LoggedCommand(command: 'heal', source: null).asPlayer, isFalse);
      expect(LoggedCommand(command: 'heal', source: '').asPlayer, isFalse);
    });

    test('asConsole is the exact complement of asPlayer', () {
      for (final String? source in <String?>[
        'player',
        'server',
        'PLAYER',
        'nonsense',
        null,
      ]) {
        final LoggedCommand cmd =
            LoggedCommand(command: 'heal', source: source);
        expect(cmd.asConsole, !cmd.asPlayer, reason: 'source=$source');
      }
    });

    test('an absent or blank source reads as omitted', () {
      expect(LoggedCommand(command: 'heal', source: null).sourceOmitted, isTrue);
      expect(LoggedCommand(command: 'heal', source: '  ').sourceOmitted, isTrue);
      expect(
        LoggedCommand(command: 'heal', source: 'server').sourceOmitted,
        isFalse,
      );
    });

    test('only the two format spellings count as recognized', () {
      expect(
        LoggedCommand(command: 'heal', source: 'player').sourceRecognized,
        isTrue,
      );
      expect(
        LoggedCommand(command: 'heal', source: 'server').sourceRecognized,
        isTrue,
      );
      expect(
        LoggedCommand(command: 'heal', source: 'PLAYER').sourceRecognized,
        isFalse,
      );
      expect(
        LoggedCommand(command: 'heal', source: null).sourceRecognized,
        isFalse,
      );
    });

    test('one leading slash is stripped, exactly as the runtime does', () {
      // CommandMenuAction.java:35 strips a single leading '/'.
      expect(LoggedCommand(command: '/heal', source: 'player').command, 'heal');
      expect(LoggedCommand(command: '//heal', source: 'player').command, '/heal');
      expect(LoggedCommand(command: 'heal', source: 'player').command, 'heal');
    });

    test('converting a model action preserves the raw source spelling', () {
      final LoggedCommand cmd =
          LoggedCommand.from(HuiCommandAction('/heal', 'PLAYER'));
      expect(cmd.command, 'heal');
      expect(cmd.rawSource, 'PLAYER');
      expect(cmd.asPlayer, isFalse);
      expect(cmd.sourceOmitted, isFalse);
    });

    test('a converter caller may declare the key was absent in the file', () {
      // The decoder rewrites a blank source to `server`
      // (hui_actions.dart HuiCommandAction._readSource), so absence has to be
      // handed in from outside.
      final LoggedCommand cmd = LoggedCommand.from(
        HuiCommandAction('heal', 'server'),
        sourceOmitted: true,
      );
      expect(cmd.sourceOmitted, isTrue);
      expect(cmd.asConsole, isTrue);
    });

    test('the whole resolution table, end to end through the machine', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _button('probe', actions: <HuiAction>[
          _command('a', 'player'),
          _command('b', 'server'),
          _command('c', 'PLAYER'),
          _command('d', 'garbage'),
          _command('e', ''),
        ]),
      ]));

      sim.tick(hoveredClickableIds: <String>{'probe'}, playerFeet: PVec3.zero);
      final List<LoggedAction> fired = sim.click().single.actions;

      expect(
        fired.map((LoggedAction a) => (a as LoggedCommand).asPlayer).toList(),
        <bool>[true, false, false, false, false],
      );
      expect((fired[4] as LoggedCommand).sourceOmitted, isTrue);
    });
  });

  group('sound logging', () {
    test('volume 0 is flagged inaudible', () {
      // SoundActionData's float default is 0 and the plugin plays it verbatim
      // (SoundMenuAction.java:30-32) — a silent click.
      expect(
        const LoggedSound(
          key: 'ui.button.click',
          category: 'master',
          volume: 0,
          pitch: 1,
        ).inaudible,
        isTrue,
      );
      expect(
        const LoggedSound(
          key: 'ui.button.click',
          category: 'master',
          volume: 0.01,
          pitch: 1,
        ).inaudible,
        isFalse,
      );
    });

    test('a blank category is flagged: a null source NPEs on click', () {
      // SoundMenuAction.java:31 calls data.source().getCategory().
      expect(
        const LoggedSound(key: 's', category: '', volume: 1, pitch: 1)
            .categoryMissing,
        isTrue,
      );
      expect(
        const LoggedSound(key: 's', category: 'master', volume: 1, pitch: 1)
            .categoryMissing,
        isFalse,
      );
    });

    test('converting a model sound action carries every field', () {
      final LoggedSound sound =
          LoggedSound.from(HuiSoundAction('block.note_block.bell', 'block', 0, 2));
      expect(sound.key, 'block.note_block.bell');
      expect(sound.category, 'block');
      expect(sound.volume, 0);
      expect(sound.pitch, 2);
      expect(sound.inaudible, isTrue);
    });

    test('sounds fire through the machine in authored order', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[
        _button('probe', actions: <HuiAction>[
          HuiSoundAction('ui.button.click', 'master', 1, 1),
          _command('say hi', 'player'),
        ]),
      ]));

      sim.tick(hoveredClickableIds: <String>{'probe'}, playerFeet: PVec3.zero);
      final List<LoggedAction> fired = sim.click().single.actions;

      expect(fired[0], isA<LoggedSound>());
      expect(fired[1], isA<LoggedCommand>());
    });
  });

  group('describe', () {
    test('spells out the dispatch target for every source shape', () {
      expect(
        describeLoggedAction(LoggedCommand(command: 'heal', source: 'player')),
        'run "heal" as player',
      );
      expect(
        describeLoggedAction(LoggedCommand(command: 'heal', source: 'server')),
        'run "heal" as console',
      );
      expect(
        describeLoggedAction(LoggedCommand(command: 'heal', source: null)),
        'run "heal" as console (source omitted)',
      );
      expect(
        describeLoggedAction(LoggedCommand(command: 'heal', source: 'PLAYER')),
        'run "heal" as console (source "PLAYER" is not player or server)',
      );
    });

    test('spells out sound volume, pitch and the inaudible flag', () {
      expect(
        describeLoggedAction(const LoggedSound(
          key: 'ui.button.click',
          category: 'master',
          volume: 1,
          pitch: 1.5,
        )),
        'play "ui.button.click" (master) volume 1, pitch 1.5',
      );
      expect(
        describeLoggedAction(const LoggedSound(
          key: 'ui.button.click',
          category: 'master',
          volume: 0,
          pitch: 1,
        )),
        'play "ui.button.click" (master) volume 0, pitch 1 — inaudible',
      );
      expect(
        describeLoggedAction(const LoggedSound(
          key: 'ui.button.click',
          category: '',
          volume: 1,
          pitch: 1,
        )),
        'play "ui.button.click" (source missing) volume 1, pitch 1 '
        '— a null source NPEs on click',
      );
    });

    test('renders an entry with its tick, id and trigger', () {
      expect(
        describeActionLogEntry(ActionLogEntry(
          tick: 7,
          componentId: 'confirm',
          trigger: ActionLogTrigger.button,
          actions: <LoggedAction>[
            LoggedCommand(command: 'heal', source: 'player'),
          ],
        )),
        '#7 confirm (click): run "heal" as player',
      );
      expect(
        describeActionLogEntry(const ActionLogEntry(
          tick: 7,
          componentId: 'lamp',
          trigger: ActionLogTrigger.toggleToTrue,
          actions: <LoggedAction>[],
        )),
        '#7 lamp (toggle → true): no actions',
      );
    });

    test('joins multiple actions in order', () {
      expect(
        describeActionLogEntry(ActionLogEntry(
          tick: 1,
          componentId: 'a',
          trigger: ActionLogTrigger.toggleToFalse,
          actions: <LoggedAction>[
            LoggedCommand(command: 'x', source: 'server'),
            const LoggedSound(
              key: 's',
              category: 'block',
              volume: 1,
              pitch: 1,
            ),
          ],
        )),
        '#1 a (toggle → false): run "x" as console; '
        'play "s" (block) volume 1, pitch 1',
      );
    });
  });
}
