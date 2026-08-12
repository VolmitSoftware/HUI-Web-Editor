/// The preview's runtime state machine and the action-log model it emits.
///
/// Every expectation here is a HoloUi behaviour a reasonable implementation
/// would smooth over: the nearest hitbox wins, command source controls
/// player-versus-console dispatch, an explicit `volume: 0` is silent, and the
/// range test is deliberately loosened by the menu offset. Each is cited to the
/// Java that produces it.
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
}) => HuiComponent(
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
}) => HuiComponent(
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
}) => HuiMenu(
  offset: offset ?? Vec3(0, 1, 2),
  maxDistance: maxDistance,
  followPlayer: followPlayer,
  lockPosition: lockPosition,
  components: components,
);

PreviewSimulation _sim(
  HuiMenu menu, {
  PVec3 openFeet = PVec3.zero,
  double openYawDeg = 0,
  bool Function(String id)? initialToggleState,
}) => PreviewSimulation(
  menu: menu,
  openFeet: openFeet,
  openYawDeg: openYawDeg,
  initialToggleState: initialToggleState,
);

HuiCommandAction _command(String command, [String source = 'player']) =>
    HuiCommandAction(command, source);

void main() {
  group('seeding', () {
    test('collects clickables in declaration order and skips decorations', () {
      // SessionHolder.snapshotClick walks MenuSession's component list, which is
      // built straight from the JSON order (MenuSession.java:74-77).
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _decoration('backdrop'),
          _button('one'),
          _decoration('label'),
          _toggle('two'),
          _button('three'),
        ]),
      );

      expect(sim.clickables.map((SimClickable c) => c.id).toList(), <String>[
        'one',
        'two',
        'three',
      ]);
      expect(sim.clickables[1].kind, SimClickableKind.toggle);
      expect(sim.clickables[0].kind, SimClickableKind.button);
    });

    test('carries per-clickable highlightModifier verbatim', () {
      // Gson writes the field directly, so the Java API's 0..1 clamp never runs
      // on parsed values (ClickableComponent.java:111-116 uses it raw).
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _button('raw', highlightModifier: 3),
          _toggle('zero', highlightModifier: 0),
        ]),
      );

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

    test('the open yaw transforms the menu offset around the player', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_button('a')], offset: Vec3(0, 1, 3)),
        openFeet: const PVec3(10, 64, -5),
        openYawDeg: 90,
      );

      expect(sim.center, const PVec3(13, 65, -5));
      expect(sim.anchorFeet, const PVec3(10, 64, -5));
      expect(sim.facingYawDeg, 90);
    });

    test('toggle state is seeded by the caller, defaulting to true', () {
      // `condition` is a PAPI expression the editor cannot evaluate, so the
      // editor substitutes its own canvas preview choice
      // (ToggleComponent.java:48 samples it once at open).
      final HuiMenu menu = _menu(<HuiComponent>[
        _toggle('lamp'),
        _toggle('door'),
      ]);

      expect(_sim(menu).toggleStateFor('lamp'), isTrue);
      expect(
        _sim(
          menu,
          initialToggleState: (String id) => id == 'door',
        ).toggleStateFor('lamp'),
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
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_decoration('backdrop'), _button('a')]),
      );

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
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_button('one'), _button('two'), _button('three')]),
      );

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
    test('only the nearest event-time target fires', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _button('one', actions: <HuiAction>[_command('say one')]),
          _button('two', actions: <HuiAction>[_command('say two')]),
          _button('three', actions: <HuiAction>[_command('say three')]),
        ]),
      );

      sim.tick(
        hoveredClickableIds: <String>{'three', 'two', 'one'},
        playerFeet: PVec3.zero,
      );
      final List<ActionLogEntry> fired = sim.click(componentId: 'two');

      expect(fired.single.componentId, 'two');
      expect((fired.single.actions.single as LoggedCommand).command, 'say two');
    });

    test('a duplicate id keeps only the first component', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _button('twin', actions: <HuiAction>[_command('first')]),
          _button('twin', actions: <HuiAction>[_command('second')]),
        ]),
      );

      sim.tick(hoveredClickableIds: <String>{'twin'}, playerFeet: PVec3.zero);
      final List<ActionLogEntry> fired = sim.click();

      expect(fired.length, 1);
      expect((fired.single.actions.single as LoggedCommand).command, 'first');
    });

    test('decorations never fire even when named as hovered', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_decoration('backdrop'), _button('a')]),
      );

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
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _button('a', actions: <HuiAction>[_command('say hi')]),
        ]),
      );
      expect(sim.click(), isEmpty);
    });

    test('a clickable with no actions still logs that it fired', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);

      final List<ActionLogEntry> fired = sim.click();
      expect(fired.single.componentId, 'a');
      expect(fired.single.actions, isEmpty);
      expect(fired.single.trigger, ActionLogTrigger.button);
      expect(fired.single.clickTrigger, 'left_click');
    });

    test('each click runs only its exact and any-trigger actions', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _button(
            'bound',
            actions: <HuiAction>[
              HuiCommandAction('say any', 'player', 'any'),
              HuiCommandAction('say left', 'player', 'left_click'),
              HuiCommandAction('say right', 'player', 'right_click'),
              HuiCommandAction(
                'say sneak right',
                'player',
                'shift_right_click',
              ),
            ],
          ),
        ]),
      );
      sim.tick(hoveredClickableIds: <String>{'bound'}, playerFeet: PVec3.zero);

      final ActionLogEntry fired = sim.click(trigger: 'right_click').single;

      expect(fired.clickTrigger, 'right_click');
      expect(
        fired.actions
            .cast<LoggedCommand>()
            .map((LoggedCommand action) => action.command)
            .toList(),
        <String>['say any', 'say right'],
      );
    });

    test('entries carry the tick they fired on', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);

      expect(sim.click().single.tick, 2);
    });

    test('an event-time target does not depend on the prior hover state', () {
      final PreviewSimulation sim = _sim(_menu(<HuiComponent>[_button('a')]));
      sim.tick(hoveredClickableIds: <String>{'a'}, playerFeet: PVec3.zero);
      sim.tick(hoveredClickableIds: const <String>{}, playerFeet: PVec3.zero);

      expect(sim.click(componentId: 'a').single.componentId, 'a');
    });
  });

  group('toggle transitions', () {
    test('a true toggle clicked fires falseActions and lands on false', () {
      // ToggleComponent.java:52-61: when state is true the click runs
      // falseActions and sets state=false. trueActions fire on the transition
      // INTO true, never on the way out.
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _toggle(
            'lamp',
            trueActions: <HuiAction>[_command('lamp on')],
            falseActions: <HuiAction>[_command('lamp off')],
          ),
        ]),
      );

      sim.tick(hoveredClickableIds: <String>{'lamp'}, playerFeet: PVec3.zero);
      final List<ActionLogEntry> fired = sim.click();

      expect(sim.toggleStateFor('lamp'), isFalse);
      expect(fired.single.trigger, ActionLogTrigger.toggleToFalse);
      expect(
        (fired.single.actions.single as LoggedCommand).command,
        'lamp off',
      );
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
      expect(
        (second.single.actions.single as LoggedCommand).command,
        'lamp off',
      );

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

    test('a later toggle sharing an id is ignored', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[_toggle('twin'), _toggle('twin')]),
        initialToggleState: (String _) => false,
      );

      sim.tick(hoveredClickableIds: <String>{'twin'}, playerFeet: PVec3.zero);
      final List<ActionLogEntry> fired = sim.click();

      expect(fired.length, 1);
      expect(fired.single.trigger, ActionLogTrigger.toggleToTrue);
    });

    test('only a matching navigation prevents the toggle transition', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _toggle(
            'lamp',
            trueActions: <HuiAction>[
              HuiNavigateAction('right-menu', 'push', 'right_click'),
              HuiCommandAction('lamp on', 'player', 'left_click'),
            ],
          ),
        ]),
        initialToggleState: (String _) => false,
      );
      sim.tick(hoveredClickableIds: <String>{'lamp'}, playerFeet: PVec3.zero);

      final ActionLogEntry right = sim.click(trigger: 'right_click').single;
      expect(right.actions.single, isA<LoggedNavigation>());
      expect(sim.toggleStateFor('lamp'), isFalse);

      final ActionLogEntry left = sim.click(trigger: 'left_click').single;
      expect((left.actions.single as LoggedCommand).command, 'lamp on');
      expect(sim.toggleStateFor('lamp'), isTrue);
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

    test('followPlayer turns the menu with the current player yaw', () {
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3(0, 1, 2),
          followPlayer: true,
        ),
        openFeet: PVec3.zero,
        openYawDeg: 15,
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(3, 0, 4),
        playerYawDeg: 90,
      );

      expect(sim.anchorFeet, const PVec3(3, 0, 4));
      expect(sim.facingYawDeg, 90);
      expect(result.center, const PVec3(5, 1, 4));
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

    test('lockPosition keeps a proposed move from closing the session', () {
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

      expect(sim.isOpen, isTrue);
      expect(sim.movementLocked, isTrue);
    });

    test('lockPosition freezes before the range test', () {
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

      expect(result.closedThisTick, isNull);
      expect(result.center, PVec3.zero);
    });

    test('lockPosition with followPlayer still turns on a look event', () {
      final PreviewSimulation sim = _sim(
        _menu(
          <HuiComponent>[_button('a')],
          offset: Vec3(0, 0, 2),
          followPlayer: true,
          lockPosition: true,
        ),
        openFeet: const PVec3(4, 0, 5),
      );

      final PreviewTickResult result = sim.tick(
        hoveredClickableIds: const <String>{},
        playerFeet: const PVec3(40, 0, 50),
        playerYawDeg: 90,
      );

      expect(sim.anchorFeet, const PVec3(4, 0, 5));
      expect(sim.facingYawDeg, 90);
      expect(result.center, const PVec3(6, 0, 5));
      expect(result.movementLocked, isTrue);
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
      // The move handler runs isValid(e.getTo()) before MenuSession.follow
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
    test('server and the Java enum name GLOBAL run from the console', () {
      // CommandMenuAction.java:34-40 dispatches from the console only for
      // GLOBAL; every other value, including a null from an absent or unknown
      // spelling, takes the `player` default. The enum's JSON spelling is
      // @SerializedName("player") / @SerializedName("server").
      expect(LoggedCommand(command: 'heal', source: 'player').asPlayer, isTrue);
      expect(
        LoggedCommand(command: 'heal', source: 'server').asPlayer,
        isFalse,
      );
      expect(LoggedCommand(command: 'heal', source: 'PLAYER').asPlayer, isTrue);
      expect(
        LoggedCommand(command: 'heal', source: 'GLOBAL').asPlayer,
        isFalse,
      );
      expect(LoggedCommand(command: 'heal', source: 'Player').asPlayer, isTrue);
      expect(
        LoggedCommand(command: 'heal', source: 'nonsense').asPlayer,
        isTrue,
      );
      expect(LoggedCommand(command: 'heal', source: null).asPlayer, isTrue);
      expect(LoggedCommand(command: 'heal', source: '').asPlayer, isTrue);
    });

    test('asConsole is the exact complement of asPlayer', () {
      for (final String? source in <String?>[
        'player',
        'server',
        'PLAYER',
        'nonsense',
        null,
      ]) {
        final LoggedCommand cmd = LoggedCommand(
          command: 'heal',
          source: source,
        );
        expect(cmd.asConsole, !cmd.asPlayer, reason: 'source=$source');
      }
    });

    test('an absent source keeps an empty raw spelling', () {
      expect(LoggedCommand(command: 'heal', source: null).rawSource, '');
      expect(LoggedCommand(command: 'heal', source: '  ').rawSource, '  ');
      expect(
        LoggedCommand(command: 'heal', source: 'server').rawSource,
        'server',
      );
    });

    test('canonical and Java enum spellings count as recognized', () {
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
        isTrue,
      );
      expect(
        LoggedCommand(command: 'heal', source: 'GLOBAL').sourceRecognized,
        isTrue,
      );
      expect(
        LoggedCommand(command: 'heal', source: null).sourceRecognized,
        isFalse,
      );
    });

    test('one leading slash is stripped, exactly as the runtime does', () {
      // CommandMenuAction trims the declaration and strips one leading '/'.
      expect(LoggedCommand(command: '/heal', source: 'player').command, 'heal');
      expect(
        LoggedCommand(command: '//heal', source: 'player').command,
        '/heal',
      );
      expect(LoggedCommand(command: 'heal', source: 'player').command, 'heal');
      expect(
        LoggedCommand(command: '  /heal  ', source: 'player').command,
        'heal',
      );
    });

    test('invalid command actions are dropped from the runtime log', () {
      final List<LoggedAction> logged = loggedActionsFrom(<HuiAction>[
        HuiCommandAction('', 'player'),
        HuiCommandAction('   ', 'player'),
        HuiCommandAction('/', 'server'),
        HuiCommandAction('/heal', 'player'),
      ]);

      expect(logged.length, 1);
      expect((logged.single as LoggedCommand).command, 'heal');
    });

    test('converting a model action preserves the raw source spelling', () {
      final LoggedCommand cmd = LoggedCommand.from(
        HuiCommandAction('/heal', 'PLAYER'),
      );
      expect(cmd.command, 'heal');
      expect(cmd.rawSource, 'PLAYER');
      expect(cmd.asPlayer, isTrue);
      expect(cmd.sourceRecognized, isTrue);
    });

    test('the whole resolution table, end to end through the machine', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _button(
            'probe',
            actions: <HuiAction>[
              _command('a', 'player'),
              _command('b', 'server'),
              _command('c', 'PLAYER'),
              _command('d', 'garbage'),
              _command('e', ''),
            ],
          ),
        ]),
      );

      sim.tick(hoveredClickableIds: <String>{'probe'}, playerFeet: PVec3.zero);
      final List<LoggedAction> fired = sim.click().single.actions;

      expect(
        fired.map((LoggedAction a) => (a as LoggedCommand).asPlayer).toList(),
        <bool>[true, false, true, true, true],
      );
      expect((fired[4] as LoggedCommand).rawSource, '');
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

    test('a blank logged category is detectable for the master fallback', () {
      expect(
        const LoggedSound(
          key: 's',
          category: '',
          volume: 1,
          pitch: 1,
        ).categoryMissing,
        isTrue,
      );
      expect(
        const LoggedSound(
          key: 's',
          category: 'master',
          volume: 1,
          pitch: 1,
        ).categoryMissing,
        isFalse,
      );
    });

    test('converting a model sound action carries every field', () {
      final LoggedSound sound = LoggedSound.from(
        HuiSoundAction('block.note_block.bell', 'block', 0, 2),
      );
      expect(sound.key, 'block.note_block.bell');
      expect(sound.category, 'block');
      expect(sound.volume, 0);
      expect(sound.pitch, 2);
      expect(sound.inaudible, isTrue);
    });

    test('sounds fire through the machine in authored order', () {
      final PreviewSimulation sim = _sim(
        _menu(<HuiComponent>[
          _button(
            'probe',
            actions: <HuiAction>[
              HuiSoundAction('ui.button.click', 'master', 1, 1),
              _command('say hi', 'player'),
            ],
          ),
        ]),
      );

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
        'run "heal" as player',
      );
      expect(
        describeLoggedAction(LoggedCommand(command: 'heal', source: 'PLAYER')),
        'run "heal" as player',
      );
    });

    test('spells out sound volume, pitch and the inaudible flag', () {
      expect(
        describeLoggedAction(
          const LoggedSound(
            key: 'ui.button.click',
            category: 'master',
            volume: 1,
            pitch: 1.5,
          ),
        ),
        'play "ui.button.click" (master) volume 1, pitch 1.5',
      );
      expect(
        describeLoggedAction(
          const LoggedSound(
            key: 'ui.button.click',
            category: 'master',
            volume: 0,
            pitch: 1,
          ),
        ),
        'play "ui.button.click" (master) volume 0, pitch 1 — inaudible',
      );
      expect(
        describeLoggedAction(
          const LoggedSound(
            key: 'ui.button.click',
            category: '',
            volume: 1,
            pitch: 1,
          ),
        ),
        'play "ui.button.click" (master) volume 1, pitch 1',
      );
    });

    test('renders an entry with its tick, id and trigger', () {
      expect(
        describeActionLogEntry(
          ActionLogEntry(
            tick: 7,
            componentId: 'confirm',
            trigger: ActionLogTrigger.button,
            clickTrigger: 'left_click',
            actions: <LoggedAction>[
              LoggedCommand(command: 'heal', source: 'player'),
            ],
          ),
        ),
        '#7 confirm (click, left click): run "heal" as player',
      );
      expect(
        describeActionLogEntry(
          const ActionLogEntry(
            tick: 7,
            componentId: 'lamp',
            trigger: ActionLogTrigger.toggleToTrue,
            clickTrigger: 'shift_right_click',
            actions: <LoggedAction>[],
          ),
        ),
        '#7 lamp (toggle → true, sneak + right click): no actions',
      );
    });

    test('joins multiple actions in order', () {
      expect(
        describeActionLogEntry(
          ActionLogEntry(
            tick: 1,
            componentId: 'a',
            trigger: ActionLogTrigger.toggleToFalse,
            clickTrigger: 'right_click',
            actions: <LoggedAction>[
              LoggedCommand(command: 'x', source: 'server'),
              const LoggedSound(
                key: 's',
                category: 'block',
                volume: 1,
                pitch: 1,
              ),
            ],
          ),
        ),
        '#1 a (toggle → false, right click): run "x" as console; '
        'play "s" (block) volume 1, pitch 1',
      );
    });

    test('navigation is logged and stops later actions', () {
      final List<LoggedAction> actions = loggedActionsFrom(<HuiAction>[
        HuiSoundAction('ui.button.click', 'master', 1, 1),
        HuiNavigateAction('shops/confirm', 'push'),
        HuiCommandAction('say unreachable', 'server'),
      ]);

      expect(actions.length, 2);
      expect(actions.last, isA<LoggedNavigation>());
      expect(
        describeLoggedAction(actions.last),
        'push navigation to "shops/confirm"',
      );
    });

    test('unmatched navigation does not stop a matching later action', () {
      final List<LoggedAction> actions = loggedActionsFrom(<HuiAction>[
        HuiNavigateAction('right-menu', 'push', 'right_click'),
        HuiCommandAction('say left', 'server', 'left_click'),
      ], clickTrigger: 'left_click');

      expect(actions.single, isA<LoggedCommand>());
      expect((actions.single as LoggedCommand).command, 'say left');
    });

    test('typed player interactions are logged in declaration order', () {
      final List<LoggedAction> actions = loggedActionsFrom(<HuiAction>[
        HuiMessageAction('<green>Hello %player%</green>'),
        HuiTeleportAction('minecraft:overworld', 1, 64, -2, 90, 0),
        HuiConnectAction('lobby-1'),
      ]);

      expect(actions, <Matcher>[
        isA<LoggedMessage>(),
        isA<LoggedTeleport>(),
        isA<LoggedConnect>(),
      ]);
      expect(
        describeLoggedAction(actions[0]),
        'message player "<green>Hello %player%</green>"',
      );
      expect(
        describeLoggedAction(actions[1]),
        'teleport player to minecraft:overworld 1 64 -2 (yaw 90, pitch 0)',
      );
      expect(
        describeLoggedAction(actions[2]),
        'connect player to proxy server "lobby-1"',
      );
    });

    test(
      'runtime-invalid typed interactions are omitted from the preview log',
      () {
        expect(
          loggedActionsFrom(<HuiAction>[
            HuiMessageAction(' '),
            HuiTeleportAction('world', 0, 64, 0, 0, 0),
            HuiConnectAction('bad server'),
          ]),
          isEmpty,
        );
      },
    );
  });
}
