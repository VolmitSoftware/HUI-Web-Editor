/// The drop stage: a dropped stack thrown forward, tumbling, bouncing and
/// settling under the settings the document actually carries.
///
/// What it draws is the plugin's own presentation model — `RealDropModel`,
/// ported in `logic/real_drop_model.dart` and driven by
/// `logic/real_drop_stage.dart`. The number of item displays comes from the
/// stack size, their places from the offset table, their size from the scale
/// family the material belongs to, their pose from the configured tumble
/// rates and the settled landing mode, their lift off the ground from the
/// authored Y offsets, and the label from `drops.name-format` with the
/// shipped `&7{count}x {type}`. Changing any field in the inspector changes
/// the stage the way it changes the server.
///
/// Left alone, the stage rotates through one stack per model family — a cube,
/// a flat item and a slab — changing on every completed drop, so a viewer sees
/// all three shapes without touching anything. The shuffle button steps out of
/// that rotation and through the whole themed sample table instead, and stays
/// on whatever it lands on until it is pressed again.
///
/// The two optional blocks both reach the stage, and the difference between
/// them is the one thing this surface must never blur:
///
///  * **`physics`** moves the item. Its four numbers are applied to the stage's
///    own arc, so gravity, bounce, buoyancy and drag visibly change where the
///    stack goes and when it lands — with the plugin's constants, on the
///    stage's trajectory.
///  * **`script`** moves the picture. `offset` shifts the model, `rotation`
///    composes onto the pose, `scale` squashes it per axis, `glow` traces an
///    outline and `visible` stops drawing it. None of that moves the item: in
///    game the pickup radius stays where Minecraft put it, and a display hidden
///    by `visible` is still a drop a player can walk over.
///
/// Four things are the stage's own and are named as approximations in the
/// readout:
///
///  * **Ballistics.** Minecraft's `Item` entity falls and bounces; Gloss only
///    reacts to it. The arc here is a simple one, sized to show a tumble and a
///    settle, and thrown toward the camera the way `Player.drop` throws a
///    stack — at a distance the stage can frame rather than the five blocks
///    vanilla's own numbers would cover. The `physics` block changes that arc,
///    not the server's.
///  * **Model faces.** Placeable sample blocks use six independently textured
///    faces around their block bounds. Non-block items use the catalog's GUI
///    sprite extruded to item-model depth.
///  * **The environment the script reads.** `inWater` is the stage's water
///    button, `inLava` is always false, and both light levels are 15. There is
///    no world under this stage to read them off — see [DropStageEnvironment],
///    which is where those values are decided and stated.
///  * **The glow outline.** The client draws a real glow as a silhouette
///    outline through blocks; this is a pair of `drop-shadow` filters at the
///    sprite's alpha edge, in the same colour, on the model's two outer slices.
///
/// Pose changes are handed to CSS transitions whose duration is the client's
/// own interpolation window — `limits.updateIntervalTicks` in flight,
/// `landing.transitionTicks` on the settle — so a coarse update interval reads
/// as coarse here too.
///
/// The editor stage carries a free camera: drag orbits, WASD walks, space and
/// shift lift, the wheel dollies, and everything it does is one transform from
/// `drop_stage_camera.dart` on `.hui-real-drops-camera`. It takes the keyboard
/// only while the stage itself has focus, and drops every held key on blur, so
/// typing in the inspector or the code editor is never stolen. The
/// `gameContext` frame deliberately has none of it: that frame stands in for
/// the client's own view, and a player does not get to fly.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;
import 'package:web/web.dart' as web;

import '../../config/showcase_flavor.dart';
import '../../logic/gloss_text.dart';
import '../../logic/gloss_particle_preview.dart';
import '../../logic/gloss_particle_text.dart';
import '../../logic/real_drop_block_geometry.dart';
import '../../logic/real_drop_model.dart';
import '../../logic/real_drop_selection.dart';
import '../../logic/real_drop_stage.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../gloss/gloss_text_line.dart';
import '../scoreboard/scoreboard_selection.dart';
import 'drop_stage_camera.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Pixels one block spans on the stage. Presentation scale only — every
/// distance the document states is in blocks and is converted here.
const double _pixelsPerBlock = 170;

/// A flat item model is one texture pixel thick in game.
const Map<DropModelKind, double> _extrusionDepth = <DropModelKind, double>{
  DropModelKind.flat: 1 / 16,
};

/// Slices per screen pixel of depth. Any sparser and the slices read as a comb
/// along the model's silhouette instead of a solid side.
const double _sliceSpacingPx = 0.8;

/// How often a held movement key is integrated. Short enough to read as
/// continuous; the elapsed time is measured rather than assumed, so a frame the
/// browser skipped costs nothing but smoothness.
const Duration _walkPeriod = Duration(milliseconds: 16);

class RealDropsView extends StatefulWidget {
  const RealDropsView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;

  /// Mounts the stage inside the shared Minecraft game-screen frame instead of
  /// the editor stage. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<RealDropsView> createState() => _RealDropsViewState();
}

class _RealDropsViewState extends State<RealDropsView> {
  static int _instances = 0;
  late final String _sceneId = 'hui-real-drops-scene-${_instances++}';

  Timer? _ticker;

  /// The period [_ticker] is running at, so a document change that moves the
  /// update interval is noticed.
  int _tickerPeriodMs = 0;
  bool _playing = true;

  /// The preview clock: wall time minus this offset. Pausing captures the
  /// instant; resuming re-derives the offset so playback continues from it.
  int _clockOffsetMs = 0;
  int _heldMs = 0;

  /// The sample stack the shuffle button has pinned, or null while the stage
  /// rotates through one stack per model family on its own.
  int? _pinned;

  /// Whether the stage is flooded to [dropStageWaterLevel].
  ///
  /// The one thing on this surface that is not in the document: `inWater` is
  /// read off the world in game and there is no world here, so a script or a
  /// buoyancy setting that only does something underwater would otherwise be
  /// untestable. Off by default, and the readout says so either way.
  bool _water = false;
  bool _itemDisplayNames = false;

  /// Timeline memo, rebuilt when the document, the stack or the water changes.
  DropStageTimeline? _timeline;
  int _timelineRevision = -1;
  ShowcaseDrop? _timelineDrop;
  bool _timelineWater = false;
  bool _timelineItemDisplayNames = false;

  DropStageCamera _camera = DropStageCamera.home;
  bool _dragging = false;
  double _lastPointerX = 0;
  double _lastPointerY = 0;

  /// Movement keys currently down, normalised to one name per direction so a
  /// left and a right shift are one key. Cleared on blur: a key released while
  /// the stage is not focused never reports a keyup, and a stuck key would fly
  /// the camera away on its own.
  final Set<String> _heldKeys = <String>{};
  Timer? _walker;
  int _walkedAtMs = 0;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _clockOffsetMs = DateTime.now().millisecondsSinceEpoch;
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant RealDropsView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _ticker?.cancel();
    _walker?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  int _nowMs() => _playing
      ? DateTime.now().millisecondsSinceEpoch - _clockOffsetMs
      : _heldMs;

  void _togglePlaying() {
    setState(() {
      if (_playing) {
        _heldMs = _nowMs();
        _playing = false;
      } else {
        _clockOffsetMs = DateTime.now().millisecondsSinceEpoch - _heldMs;
        _playing = true;
      }
    });
  }

  /// The stack on the stage at [nowMs].
  ///
  /// Unpinned, that is the model-family rotation, advancing one entry per
  /// completed drop — every stack shares [dropStageCycleMs], so the count of
  /// finished cycles is the whole state the rotation needs.
  ShowcaseDrop _dropAt(int nowMs, int cycleMs) {
    final int? pinned = _pinned;
    if (pinned != null) return showcaseDrops[pinned % showcaseDrops.length];
    return dropStageRotationDrop(nowMs ~/ cycleMs);
  }

  /// Steps the shuffle button: off the rotation onto the first sample, then
  /// through the whole themed table, then back to the rotation.
  ///
  /// It pins rather than showing one cycle and handing back, because a stack
  /// somebody asked to see that vanishes two seconds later cannot be looked at
  /// — and wrapping past the end of the table is what keeps the rotation
  /// reachable again from the same one control.
  void _nextSample() {
    setState(() {
      final int? pinned = _pinned;
      final int next = pinned == null ? 0 : pinned + 1;
      _pinned = next >= showcaseDrops.length ? null : next;
    });
  }

  /// One repaint per server update, so the stage polls exactly as often as the
  /// plugin does and CSS eases between poses the way the client does.
  ///
  /// The period is part of the document, so a changed `updateIntervalTicks`
  /// has to replace the timer rather than keep the old cadence.
  void _syncTicker(GlossRealDropSettingsDoc doc) {
    final int periodMs =
        (doc.presentation.limits.updateIntervalTicks.clamp(1, 20) * 50).toInt();
    if (!_playing) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    if (_ticker != null && _ticker!.isActive && _tickerPeriodMs == periodMs) {
      return;
    }
    _ticker?.cancel();
    _tickerPeriodMs = periodMs;
    _ticker = Timer.periodic(Duration(milliseconds: periodMs), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  DropStageTimeline _timelineFor(
    GlossRealDropSettingsDoc doc,
    ShowcaseDrop drop,
  ) {
    if (_timeline == null ||
        _timelineRevision != _store.glossRevision ||
        !identical(_timelineDrop, drop) ||
        _timelineWater != _water ||
        _timelineItemDisplayNames != _itemDisplayNames) {
      _timeline = DropStageTimeline(
        doc,
        drop,
        environment: DropStageEnvironment(
          water: _water,
          useItemDisplayNames: _itemDisplayNames,
        ),
      );
      _timelineRevision = _store.glossRevision;
      _timelineDrop = drop;
      _timelineWater = _water;
      _timelineItemDisplayNames = _itemDisplayNames;
    }
    return _timeline!;
  }

  // --- camera ---------------------------------------------------------------

  void _onPointerDown(Object? event) {
    _dragging = true;
    _lastPointerX = _eventDouble(event, 'clientX');
    _lastPointerY = _eventDouble(event, 'clientY');
    // Clicking a `tabindex` element focuses it in every browser this editor
    // targets, but the keyboard half of the camera is unusable if one of them
    // disagrees, so the stage takes focus itself.
    (web.document.getElementById(_sceneId) as web.HTMLElement?)?.focus();
  }

  void _onPointerMove(Object? event) {
    if (!_dragging) return;
    final double x = _eventDouble(event, 'clientX');
    final double y = _eventDouble(event, 'clientY');
    final double dx = x - _lastPointerX;
    final double dy = y - _lastPointerY;
    _lastPointerX = x;
    _lastPointerY = y;
    if (dx == 0 && dy == 0) return;
    setState(() => _camera = _camera.orbitBy(dx, dy));
  }

  void _onPointerUp(Object? event) => _dragging = false;

  void _onWheel(Object? event) {
    domPreventDefault(event);
    final double pixels = dropStageWheelPixels(
      _eventDouble(event, 'deltaY'),
      _eventDouble(event, 'deltaMode').round(),
    );
    if (pixels == 0) return;
    setState(() => _camera = _camera.dollyBy(pixels));
  }

  void _onKeyDown(Object? event) {
    // A chord belongs to the shell, not to the camera: nothing here is worth
    // eating a Ctrl-S over.
    if (_eventBool(event, 'ctrlKey') ||
        _eventBool(event, 'metaKey') ||
        _eventBool(event, 'altKey')) {
      return;
    }
    final String? walk = _walkKey(event);
    if (walk == null) return;
    // Space scrolls the page and the shell binds bare letters; the stage has
    // the focus, so it owns both.
    domPreventDefault(event);
    domStopPropagation(event);
    if (!_heldKeys.add(walk)) return;
    _syncWalker();
  }

  void _onKeyUp(Object? event) {
    final String? walk = _walkKey(event);
    if (walk == null) return;
    if (!_heldKeys.remove(walk)) return;
    _syncWalker();
  }

  void _onBlur(Object? event) {
    _dragging = false;
    if (_heldKeys.isEmpty) return;
    _heldKeys.clear();
    _syncWalker();
  }

  void _resetCamera() => setState(() => _camera = DropStageCamera.home);

  /// Which direction a key event drives, or null for a key the stage does not
  /// own. `code` is a physical position, so the layout the author types in does
  /// not move WASD; `key` is the fallback for anything that does not report
  /// one.
  String? _walkKey(Object? event) {
    final String code = _eventString(event, 'code');
    final String name = code.isEmpty
        ? _eventString(event, 'key').toLowerCase()
        : code;
    return switch (name) {
      'KeyW' || 'w' => 'forward',
      'KeyS' || 's' => 'back',
      'KeyA' || 'a' => 'left',
      'KeyD' || 'd' => 'right',
      'Space' || ' ' => 'up',
      'ShiftLeft' || 'ShiftRight' || 'shift' => 'down',
      _ => null,
    };
  }

  void _syncWalker() {
    if (_heldKeys.isEmpty) {
      _walker?.cancel();
      _walker = null;
      return;
    }
    if (_walker != null) return;
    _walkedAtMs = DateTime.now().millisecondsSinceEpoch;
    _walker = Timer.periodic(_walkPeriod, (Timer _) => _walk());
  }

  void _walk() {
    if (!mounted) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    // A tab that was in the background hands back one enormous gap; capping it
    // keeps the camera where it was left instead of hurling it across the box.
    final double seconds = (now - _walkedAtMs).clamp(0, 100) / 1000;
    _walkedAtMs = now;
    final double forward = _axis('forward', 'back');
    final double strafe = _axis('right', 'left');
    final double lift = _axis('up', 'down');
    if (forward == 0 && strafe == 0 && lift == 0) return;
    setState(() {
      _camera = _camera.walkBy(
        seconds: seconds,
        forward: forward,
        strafe: strafe,
        lift: lift,
      );
    });
  }

  double _axis(String positive, String negative) =>
      (_heldKeys.contains(positive) ? 1 : 0) -
      (_heldKeys.contains(negative) ? 1 : 0);

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final GlossRealDropSettingsDoc? doc = _store.realDropSettingsDoc;
    if (doc == null) {
      _ticker?.cancel();
      _ticker = null;
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.world,
          label: huiText('Real drops in game'),
        );
      }
      return const dom.div(
        classes: 'hui-real-drops-stage is-empty',
        <Widget>[],
      );
    }

    final int nowMs = _nowMs();
    final ShowcaseDrop drop = _dropAt(
      nowMs,
      dropStageCycleMsFor(doc, water: _water),
    );
    final GlossConditionContext itemContext = GlossConditionContext(
      variables: <String, Object?>{
        'drop.material': drop.registryName,
        'drop.amount': drop.amount.toDouble(),
        'drop.maxStackSize': drop.maxStackSize.toDouble(),
        'drop.world': 'world',
        'drop.onGround': false,
        'drop.inWater': _water,
        'drop.inLava': false,
        'drop.playerDropped': true,
        'drop.customNamed': _itemDisplayNames,
        'source.present': true,
        'source.type': 'player',
        'subject.world': 'world',
        'world.name': 'world',
        'event.type': 'spawn',
        'event.playerDrop': true,
      },
    );
    final GlossRealDropPresentation selectedPresentation =
        glossResolveRealDropPresentation(doc, itemContext);
    final String? selectedVariantId = glossResolveRealDropVariantId(
      doc,
      itemContext,
    );
    final GlossConditionContext audienceContext = GlossConditionContext(
      variables: <String, Object?>{
        ...itemContext.variables,
        'viewer.world': 'world',
        'viewer.health': 20.0,
        'viewer.maxHealth': 20.0,
        'viewer.healthPercent': 100.0,
        'viewer.gameMode': 'SURVIVAL',
      },
      groups: const <String>{'player'},
    );
    final bool audienceVisible = glossRealDropAudienceVisible(
      doc,
      audienceContext,
    );
    final GlossRealDropSettingsDoc selectedDoc = GlossRealDropSettingsDoc(
      revision: doc.revision,
      presentation: selectedPresentation,
      audience: doc.audience.copy(),
    );
    _syncTicker(selectedDoc);
    final DropStageTimeline timeline = _timelineFor(selectedDoc, drop);
    final DropStageFrame frame = timeline.frameAt(nowMs);
    final Widget scene = _scene(selectedDoc, drop, frame, nowMs);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.world,
        label: huiText('Real drops in game'),
        // No water button in the frame: that frame stands in for the client's
        // own view, and its ground is a photograph with no water plane to
        // raise. The editor stage is where the environment is simulated.
        controls: <Widget>[_playPause(), _sampleButton(drop)],
        child: scene,
      );
    }

    return dom.div(classes: 'hui-real-drops-stage', <Widget>[
      scene,
      dom.div(classes: 'hui-real-drops-controls', <Widget>[
        _playPause(),
        _sampleButton(drop),
        _waterButton(),
        _itemDisplayNameButton(),
        _resetButton(),
        _timelineControl(timeline, frame, nowMs),
        dom.span(classes: 'hui-real-drops-readout-inline', <Widget>[
          Text(
            _readout(
              selectedDoc,
              drop,
              timeline,
              frame,
              selectedVariantId,
              audienceVisible,
            ),
          ),
        ]),
        dom.span(classes: 'hui-real-drops-hint', <Widget>[
          Text(
            huiText(
              'Click the stage: drag orbits, WASD walks, space and shift lift, '
              'wheel dollies',
            ),
          ),
        ]),
      ]),
    ]);
  }

  Widget _playPause() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _togglePlaying,
    attributes: <String, String>{
      'aria-label': _playing ? huiText('Pause') : huiText('Play'),
      'title': _playing ? huiText('Pause') : huiText('Play'),
    },
    child: _playing
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  Widget _sampleButton(ShowcaseDrop drop) => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _nextSample,
    attributes: <String, String>{
      'aria-label': huiText('Next sample stack'),
      'title': _pinned == null
          ? huiText(
              'Drop something else — the stage is rotating through the three '
              'model families ({name})',
              <String, Object?>{'name': huiText(drop.displayName)},
            )
          : huiText('Drop something else ({name})', <String, Object?>{
              'name': huiText(drop.displayName),
            }),
    },
    child: ArcaneIcon.shuffle(size: IconSize.sm),
  );

  /// The stage's own control, not the document's — hence the wording, which
  /// says what it floods rather than implying a setting exists for it.
  Widget _waterButton() => Button(
    variant: _water ? ButtonVariant.secondary : ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: () => setState(() => _water = !_water),
    attributes: <String, String>{
      'aria-label': _water
          ? huiText('Drain the stage')
          : huiText('Flood the stage'),
      'title': _water
          ? huiText('Drain the stage — inWater goes back to false')
          : huiText(
              'Flood the stage to {level} blocks, so inWater, waterBuoyancy '
              'and waterDrag have something to act on',
              <String, Object?>{'level': dropStageWaterLevel},
            ),
    },
    child: ArcaneIcon.droplet(size: IconSize.sm),
  );

  Widget _itemDisplayNameButton() => Button(
    variant: _itemDisplayNames
        ? ButtonVariant.secondary
        : ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: () => setState(() => _itemDisplayNames = !_itemDisplayNames),
    attributes: <String, String>{
      'aria-label': _itemDisplayNames
          ? huiText('Use material names in labels')
          : huiText('Use renamed item names in labels'),
      'title': _itemDisplayNames
          ? huiText(
              'Preview [drops] useItemDisplayNames = true; click for the '
              'default material-name labels',
            )
          : huiText(
              'Preview renamed item labels; [drops] useItemDisplayNames is '
              'false by default',
            ),
    },
    child: ArcaneIcon.typeIcon(size: IconSize.sm),
  );

  Widget _resetButton() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _resetCamera,
    attributes: <String, String>{
      'aria-label': huiText('Reset view'),
      'title': huiText('Reset view'),
    },
    child: ArcaneIcon.maximize(size: IconSize.sm),
  );

  Widget _timelineControl(
    DropStageTimeline timeline,
    DropStageFrame frame,
    int nowMs,
  ) {
    final int localMs = nowMs % timeline.cycleMs;
    return dom.div(classes: 'hui-real-drops-timeline', <Widget>[
      dom.span(
        classes: 'hui-real-drops-phase is-${frame.phase.label}',
        <Widget>[Text(_phaseLabel(frame.phase))],
      ),
      dom.input<num>(
        type: dom.InputType.range,
        classes: 'hui-range hui-real-drops-scrubber',
        value: '$localMs',
        onInput: (num next) => _scrubTo(next.toInt(), nowMs, timeline.cycleMs),
        attributes: <String, String>{
          'min': '0',
          'max': '${math.max(0, timeline.cycleMs - 1)}',
          'step': '25',
          'aria-label': huiText('Scrub the dropped item animation timeline'),
        },
      ),
      dom.span(classes: 'hui-real-drops-time', <Widget>[
        Text(
          huiText("{toStringAsFixed} / {toStringAsFixed2}s", <String, Object?>{
            'toStringAsFixed': (localMs / 1000).toStringAsFixed(2),
            'toStringAsFixed2': (timeline.cycleMs / 1000).toStringAsFixed(2),
          }),
        ),
      ]),
    ]);
  }

  void _scrubTo(int localMs, int nowMs, int cycleMs) {
    final int cycleStart = nowMs ~/ cycleMs * cycleMs;
    setState(() {
      _heldMs = cycleStart + localMs.clamp(0, cycleMs - 1);
      _playing = false;
      _ticker?.cancel();
      _ticker = null;
    });
  }

  Widget _scene(
    GlossRealDropSettingsDoc doc,
    ShowcaseDrop drop,
    DropStageFrame frame,
    int nowMs,
  ) {
    final GlossRealDropLabels labels = doc.presentation.labels;
    final int easeMs = frame.interpolationTicks.clamp(0, 59) * 50;
    final double edgePx = frame.modelScale * _pixelsPerBlock;
    final double forwardPx = frame.carrierZ * _pixelsPerBlock;
    final String? itemTexture = drop.block
        ? null
        : _store.catalogs.textureFor(drop.material);
    final bool free = !component.gameContext;

    // The clipping element cannot also be the 3D context: `overflow: hidden`
    // forces `transform-style: flat`, which would lay the ground plane and the
    // extruded models back down into the page. Nor can the element holding
    // `perspective` carry the camera, because a transform there moves the
    // projected picture rather than the eye — hence three elements: the clip,
    // the projection, and the camera the projection looks through.
    return dom.div(
      id: free ? _sceneId : null,
      classes: 'hui-real-drops-scene',
      attributes: free
          ? <String, String>{
              'tabindex': '0',
              'role': 'application',
              'aria-label': huiText(
                'Drop stage. Drag to orbit, W A S D to walk, space and '
                'shift to change height, scroll to dolly.',
              ),
            }
          : null,
      events: free
          ? <String, EventCallback>{
              'pointerdown': _onPointerDown,
              'pointermove': _onPointerMove,
              'pointerup': _onPointerUp,
              'pointercancel': _onPointerUp,
              'pointerleave': _onPointerUp,
              'wheel': _onWheel,
              'keydown': _onKeyDown,
              'keyup': _onKeyUp,
              'blur': _onBlur,
            }
          : null,
      <Widget>[
        dom.div(classes: 'hui-real-drops-world', <Widget>[
          dom.div(
            classes: 'hui-real-drops-camera',
            styles: dom.Styles(
              raw: <String, String>{
                'transform': free ? _camera.cssTransform : 'none',
              },
            ),
            <Widget>[
              const dom.div(classes: 'hui-real-drops-floor', <Widget>[]),
              if (_water) _waterSurface(),
              dom.div(
                classes: 'hui-real-drops-carrier',
                styles: dom.Styles(
                  raw: <String, String>{
                    'transform':
                        'translate3d(0, '
                        '${(-frame.carrierY * _pixelsPerBlock).toStringAsFixed(2)}px, '
                        '${forwardPx.toStringAsFixed(2)}px)',
                    'transition': 'transform ${easeMs}ms linear',
                  },
                ),
                <Widget>[
                  GlossParticleOverlay(
                    layers: <GlossParticleLayer>[
                      for (final GlossParticleLayer layer
                          in doc.presentation.particleLayers)
                        if (<String>{
                          'projection',
                          'component',
                          'model',
                          'local',
                        }.contains(layer.target.scope))
                          layer,
                    ],
                    pixelsPerBlock: _pixelsPerBlock,
                    tick: nowMs ~/ 50,
                    scopeBounds: <String, List<GlossParticleRect>>{
                      for (final String scope in <String>[
                        'projection',
                        'component',
                        'model',
                      ])
                        scope: <GlossParticleRect>[
                          GlossParticleRect(
                            x: 0,
                            y: 0,
                            z: 0,
                            width: frame.modelScale,
                            height: frame.modelScale,
                            depth: frame.modelScale,
                          ),
                        ],
                    },
                  ),
                  for (final DropStageVisual visual in frame.visuals)
                    if (visual.visible)
                      _model(visual, frame, edgePx, easeMs, drop, itemTexture),
                  if (labels.enabled)
                    _label(
                      labels,
                      frame,
                      nowMs,
                      doc.presentation.particleLayers,
                    ),
                ],
              ),
              dom.div(
                classes: 'hui-real-drops-shadow',
                styles: dom.Styles(
                  raw: <String, String>{
                    'width': '${(edgePx * 1.35).toStringAsFixed(1)}px',
                    'height': '${(edgePx * 1.35).toStringAsFixed(1)}px',
                    'opacity': (0.45 / (1 + frame.carrierY * 1.4))
                        .toStringAsFixed(3),
                    // The centring is the stylesheet's, restated because an
                    // inline transform replaces the rule outright; the Z is the
                    // stack's forward travel, so the shadow stays under it.
                    'transform':
                        'translate(-50%, 50%) '
                        'translate3d(0, 0, ${forwardPx.toStringAsFixed(2)}px) '
                        'rotateX(90deg)',
                    'transition':
                        'opacity ${easeMs}ms linear, '
                        'transform ${easeMs}ms linear',
                  },
                ),
                const <Widget>[],
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _model(
    DropStageVisual visual,
    DropStageFrame frame,
    double edgePx,
    int easeMs,
    ShowcaseDrop drop,
    String? itemTexture,
  ) => realDropUsesBlockGeometry(drop.block)
      ? _blockModel(
          visual,
          edgePx,
          easeMs,
          realDropBlockGeometry(drop.material),
        )
      : _itemModel(visual, frame, edgePx, easeMs, itemTexture);

  Widget _itemModel(
    DropStageVisual visual,
    DropStageFrame frame,
    double edgePx,
    int easeMs,
    String? texture,
  ) {
    final double depth = edgePx * (_extrusionDepth[frame.modelKind] ?? 1 / 8);
    final int slices = (depth / _sliceSpacingPx).round().clamp(2, 24);
    final double spacing = depth / (slices - 1);
    final String? glow = _glowCss(visual.glowArgb, edgePx);
    return dom.div(
      classes: 'hui-real-drops-model',
      styles: dom.Styles(
        raw: <String, String>{
          'width': '${edgePx.toStringAsFixed(1)}px',
          'height': '${edgePx.toStringAsFixed(1)}px',
          // Centred in layout, not in the transform: `transform-origin` is a
          // point in the element's own box, so a `translate(-50%, -50%)` in
          // the list would leave the model rotating about a corner and swing
          // it off the carrier.
          'margin-left': '-${(edgePx / 2).toStringAsFixed(1)}px',
          'margin-top': '-${(edgePx / 2).toStringAsFixed(1)}px',
          // `script.scale` multiplies the family scale per axis, so it goes on
          // the end of the model's own transform rather than into the pixel
          // size: the pose is applied to the unscaled model and the squash
          // rides on top of it, which is the order an ItemDisplay applies its
          // transformation in.
          'transform':
              'translate3d('
              '${(visual.x * _pixelsPerBlock).toStringAsFixed(2)}px, '
              '${(-visual.y * _pixelsPerBlock).toStringAsFixed(2)}px, '
              '${(visual.z * _pixelsPerBlock).toStringAsFixed(2)}px) '
              '${visual.rotation.cssMatrix3d()} '
              'scale3d(${visual.scaleX.toStringAsFixed(4)}, '
              '${visual.scaleY.toStringAsFixed(4)}, '
              '${visual.scaleZ.toStringAsFixed(4)})',
          'transition': 'transform ${easeMs}ms linear',
        },
      ),
      <Widget>[
        for (int layer = 0; layer < slices; layer++)
          if (texture == null)
            dom.div(
              classes: 'hui-real-drops-layer is-missing',
              styles: dom.Styles(
                raw: <String, String>{
                  'transform':
                      'translateZ(${(layer * spacing - depth / 2).toStringAsFixed(2)}px)',
                },
              ),
              const <Widget>[],
            )
          else
            dom.img(
              src: texture,
              alt: '',
              classes: 'hui-real-drops-layer',
              styles: dom.Styles(
                raw: <String, String>{
                  'transform':
                      'translateZ(${(layer * spacing - depth / 2).toStringAsFixed(2)}px)',
                  // Interior slices are the model's own sides, which never
                  // catch as much light as the faces. The glow rides on the two
                  // outer slices only: the client draws one outline around the
                  // whole model, and a halo on all twenty-four slices would be
                  // twenty-four halos and a repaint cost to match.
                  'filter': layer == 0 || layer == slices - 1
                      ? (glow ?? 'none')
                      : 'brightness(0.86)',
                },
              ),
            ),
      ],
    );
  }

  Widget _blockModel(
    DropStageVisual visual,
    double edgePx,
    int easeMs,
    RealDropBlockGeometry geometry,
  ) {
    final double width = edgePx * geometry.width;
    final double height = edgePx * geometry.height;
    final double depth = edgePx * geometry.depth;
    final String? glow = _glowCss(visual.glowArgb, edgePx);
    return dom.div(
      classes: 'hui-real-drops-model is-block',
      styles: dom.Styles(
        raw: <String, String>{
          'width': '0',
          'height': '0',
          'transform':
              'translate3d('
              '${(visual.x * _pixelsPerBlock).toStringAsFixed(2)}px, '
              '${(-visual.y * _pixelsPerBlock).toStringAsFixed(2)}px, '
              '${(visual.z * _pixelsPerBlock).toStringAsFixed(2)}px) '
              '${visual.rotation.cssMatrix3d()} '
              'scale3d(${visual.scaleX.toStringAsFixed(4)}, '
              '${visual.scaleY.toStringAsFixed(4)}, '
              '${visual.scaleZ.toStringAsFixed(4)})',
          'transition': 'transform ${easeMs}ms linear',
        },
      ),
      <Widget>[
        _blockFace(
          face: 'front',
          width: width,
          height: height,
          transform: 'translateZ(${(depth / 2).toStringAsFixed(2)}px)',
          texture: geometry.sideTexture,
          glow: glow,
        ),
        _blockFace(
          face: 'back',
          width: width,
          height: height,
          transform:
              'rotateY(180deg) translateZ(${(depth / 2).toStringAsFixed(2)}px)',
          texture: geometry.sideTexture,
          glow: glow,
        ),
        _blockFace(
          face: 'right',
          width: depth,
          height: height,
          transform:
              'rotateY(90deg) translateZ(${(width / 2).toStringAsFixed(2)}px)',
          texture: geometry.sideTexture,
          glow: glow,
        ),
        _blockFace(
          face: 'left',
          width: depth,
          height: height,
          transform:
              'rotateY(-90deg) translateZ(${(width / 2).toStringAsFixed(2)}px)',
          texture: geometry.sideTexture,
          glow: glow,
        ),
        _blockFace(
          face: 'top',
          width: width,
          height: depth,
          transform:
              'rotateX(90deg) translateZ(${(height / 2).toStringAsFixed(2)}px)',
          texture: geometry.topTexture,
          glow: glow,
        ),
        _blockFace(
          face: 'bottom',
          width: width,
          height: depth,
          transform:
              'rotateX(-90deg) translateZ(${(height / 2).toStringAsFixed(2)}px)',
          texture: geometry.bottomTexture,
          glow: glow,
        ),
      ],
    );
  }

  Widget _blockFace({
    required String face,
    required double width,
    required double height,
    required String transform,
    required String texture,
    required String? glow,
  }) => dom.div(
    classes: 'hui-real-drops-block-face is-$face',
    styles: dom.Styles(
      raw: <String, String>{
        'width': '${width.toStringAsFixed(2)}px',
        'height': '${height.toStringAsFixed(2)}px',
        'margin-left': '-${(width / 2).toStringAsFixed(2)}px',
        'margin-top': '-${(height / 2).toStringAsFixed(2)}px',
        'transform': transform,
        'background-image': "url('$texture')",
        'filter':
            '${_blockFaceBrightness(face)}${glow == null ? '' : ' $glow'}',
      },
    ),
    const <Widget>[],
  );

  String _blockFaceBrightness(String face) => switch (face) {
    'front' => 'brightness(.94)',
    'back' => 'brightness(.72)',
    'right' => 'brightness(.84)',
    'left' => 'brightness(.76)',
    'top' => 'brightness(1.06)',
    _ => 'brightness(.62)',
  };

  /// `script.glow` as a CSS filter, or null for no outline.
  ///
  /// The client draws a real glow as a silhouette outline over everything,
  /// visible through blocks; the nearest thing a browser has is a pair of
  /// `drop-shadow` filters at the sprite's own alpha edge, which traces the
  /// same silhouette. Only the red, green and blue channels are read, exactly
  /// as the plugin discards the alpha before handing the colour to the display.
  String? _glowCss(int argb, double edgePx) {
    if (argb == 0) return null;
    final int red = (argb >> 16) & 0xFF;
    final int green = (argb >> 8) & 0xFF;
    final int blue = argb & 0xFF;
    final String color = 'rgb($red, $green, $blue)';
    final double near = (edgePx * 0.05).clamp(1.5, 6);
    final double far = (edgePx * 0.12).clamp(3, 14);
    return 'drop-shadow(0 0 ${near.toStringAsFixed(1)}px $color) '
        'drop-shadow(0 0 ${far.toStringAsFixed(1)}px $color)';
  }

  /// The stage's water surface, drawn at [dropStageWaterLevel] on the same
  /// plane geometry as the floor. It is a stage prop, not a document setting —
  /// see the water button.
  Widget _waterSurface() => dom.div(
    classes: 'hui-real-drops-water',
    styles: dom.Styles(
      raw: <String, String>{
        'transform':
            'translate3d(0, '
            '${(-dropStageWaterLevel * _pixelsPerBlock).toStringAsFixed(2)}px, '
            '0) rotateX(90deg)',
      },
    ),
    const <Widget>[],
  );

  /// The `TextDisplay` the plugin parents to the carrier: the formatted name,
  /// at `labels.yOffset` blocks, at `labels.scale`, with the configured
  /// background colour and alpha, shadow and see-through depth order.
  Widget _label(
    GlossRealDropLabels labels,
    DropStageFrame frame,
    int nowMs,
    List<GlossParticleLayer> particleLayers,
  ) {
    final double alpha = labels.background ? labels.backgroundAlpha / 255 : 0;
    final GlossLineRender render = renderGlossLine(
      frame.label,
      animations: _store.workspaceAnimations,
      emoji: _store.workspaceEmoji,
      nowMs: nowMs,
    );
    return dom.div(
      classes: labels.seeThrough
          ? 'hui-real-drops-label is-see-through'
          : 'hui-real-drops-label',
      styles: dom.Styles(
        raw: <String, String>{
          'transform':
              'translate(-50%, -100%) translateY('
              '${(-frame.labelY * _pixelsPerBlock).toStringAsFixed(2)}px)',
        },
      ),
      <Widget>[
        // The plate scales separately so `labels.scale` grows the text around
        // the anchor the way a TextDisplay does, instead of dragging it away
        // from the stack.
        dom.div(
          classes: 'hui-real-drops-plate',
          styles: dom.Styles(
            raw: <String, String>{
              'transform':
                  '${_labelBillboard(labels.billboard)}'
                  'scale(${labels.scale.toStringAsFixed(3)})',
              'background':
                  'rgba(${labels.backgroundRed}, ${labels.backgroundGreen}, '
                  '${labels.backgroundBlue}, ${alpha.toStringAsFixed(3)})',
              if (labels.shadow) 'text-shadow': '2px 2px 0 rgba(0, 0, 0, .55)',
            },
          ),
          <Widget>[
            GlossParticleOverlay(
              layers: <GlossParticleLayer>[
                for (final GlossParticleLayer layer in particleLayers)
                  if (<String>{
                    'label',
                    'text',
                    'line',
                    'span',
                  }.contains(layer.target.scope))
                    layer,
              ],
              pixelsPerBlock: _pixelsPerBlock,
              tick: nowMs ~/ 50,
              renderedText: GlossParticleTextRendered(
                text: render.renderedText,
                spans: render.particleSpans,
              ),
            ),
            GlossTextLine(render: render),
          ],
        ),
      ],
    );
  }

  /// A billboard mode can only be shown by the pose it locks the label into.
  /// `CENTER` and `VERTICAL` both face the camera here; `HORIZONTAL` lies down
  /// and `FIXED` keeps the drop's yaw. The editor camera moves and these do
  /// not follow it — a real `CENTER` billboard would turn to face a walking
  /// player, and the stage's plate stays put.
  String _labelBillboard(String billboard) => switch (billboard.toUpperCase()) {
    'HORIZONTAL' => 'rotateX(72deg) ',
    'FIXED' => 'rotateY(-28deg) ',
    _ => '',
  };

  String _readout(
    GlossRealDropSettingsDoc doc,
    ShowcaseDrop drop,
    DropStageTimeline timeline,
    DropStageFrame frame,
    String? selectedVariantId,
    bool audienceVisible,
  ) {
    final String kind = switch (frame.modelKind) {
      DropModelKind.block => huiText('cube'),
      DropModelKind.flat => huiText('flat'),
      DropModelKind.thin => huiText('thin'),
    };
    final GlossRealDropPhysics? physics = doc.presentation.physics;
    final bool physical = physics != null && physics.enabled;
    final int hidden = frame.visuals
        .where((DropStageVisual visual) => !visual.visible)
        .length;
    return <String>[
      huiText('{amount}x {type}', <String, Object?>{
        'amount': drop.amount,
        'type': _displayType(timeline),
      }),
      selectedVariantId == null
          ? huiText('default presentation')
          : huiText('variant {id}', <String, Object?>{'id': selectedVariantId}),
      audienceVisible
          ? huiText('visible to preview viewer')
          : huiText('hidden from preview viewer'),
      huiText('{kind} model at {scale}', <String, Object?>{
        'kind': kind,
        'scale': frame.modelScale.toStringAsFixed(2),
      }),
      huiText('{visible} of {maximum} displays', <String, Object?>{
        'visible': timeline.visualCount,
        'maximum': doc.presentation.limits.maxVisualsPerStack,
      }),
      huiText('{phase} for {ticks} ticks', <String, Object?>{
        'phase': _phaseLabel(frame.phase),
        'ticks': frame.phaseTimeTicks.toStringAsFixed(1),
      }),
      frame.settled
          ? huiText('{mode} landing, {ticks}-tick ease', <String, Object?>{
              'mode': doc.presentation.landing.mode.toLowerCase(),
              'ticks': doc.presentation.landing.transitionTicks,
            })
          : doc.presentation.motion.tumble
          ? huiText('tumbling {speed}x, bounce {bounce}', <String, Object?>{
              'speed': doc.presentation.motion.speedMultiplier.toStringAsFixed(
                2,
              ),
              'bounce': frame.bounceRevision,
            })
          : huiText('no tumble'),
      huiText('{ticks}-tick updates', <String, Object?>{
        'ticks': doc.presentation.limits.updateIntervalTicks,
      }),
      doc.presentation.labels.enabled
          ? huiText('label {billboard}', <String, Object?>{
              'billboard': doc.presentation.labels.billboard.toLowerCase(),
            })
          : huiText('no label'),
      if (physical)
        huiText(
          'physics on: gravity {gravity}x, bounce {bounce} — on the stage\'s '
          'arc, not the server\'s',
          <String, Object?>{
            'gravity': physics.gravityMultiplier.toStringAsFixed(2),
            'bounce': physics.bounce.toStringAsFixed(2),
          },
        ),
      if (timeline.scriptActive) _scriptReadout(frame),
      if (frame.animationProfileId.isNotEmpty)
        huiText('animation {id}: {physics}, light {light}', <String, Object?>{
          'id': frame.animationProfileId,
          'physics': frame.animationPhysics
              ? huiText('physics')
              : huiText('physics held'),
          'light': frame.animationLightLevel,
        }),
      _water
          ? huiText(
              'stage flooded to {level} blocks: inWater is simulated, and so '
              'are inLava, blockLight and skyLight',
              <String, Object?>{'level': dropStageWaterLevel},
            )
          : huiText(
              'no water on the stage: inWater, inLava, blockLight and '
              'skyLight are simulated, not observed',
            ),
      if (hidden > 0)
        huiPlural(
          'real-drops.readout.hidden',
          hidden,
          oneEnglish:
              '{count} display hidden by visible, still pickupable in game',
          otherEnglish:
              '{count} displays hidden by visible, still pickupable in game',
        ),
      huiText('stage toss and GUI-render sides'),
    ].join(' · ');
  }

  /// What the script did this frame, named the way the server names its own
  /// fields so a warning in the console and this line read the same.
  String _scriptReadout(DropStageFrame frame) {
    if (frame.scriptFailures.isNotEmpty) {
      final List<String> failed = frame.scriptFailures.toList()..sort();
      return huiText('script running, {fields} fell back', <String, Object?>{
        'fields': failed.join(', '),
      });
    }
    return huiText('script running on the displays only, not the item');
  }

  String _displayType(DropStageTimeline timeline) =>
      timeline.environment.useItemDisplayNames
      ? huiText(timeline.drop.displayName)
      : timeline.displayType;

  String _phaseLabel(DropAnimationPhase phase) => switch (phase) {
    DropAnimationPhase.airborne => huiText('airborne'),
    DropAnimationPhase.rebounding => huiText('rebounding'),
    DropAnimationPhase.rolling => huiText('rolling'),
    DropAnimationPhase.settling => huiText('settling'),
    DropAnimationPhase.settled => huiText('settled'),
    DropAnimationPhase.submerged => huiText('submerged'),
  };
}

double _eventDouble(Object? event, String property) {
  final JSObject? object = event as JSObject?;
  final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
  return value.isA<JSNumber>() ? (value! as JSNumber).toDartDouble : 0;
}

String _eventString(Object? event, String property) {
  final JSObject? object = event as JSObject?;
  final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
  return value.isA<JSString>() ? (value! as JSString).toDart : '';
}

bool _eventBool(Object? event, String property) {
  final JSObject? object = event as JSObject?;
  final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
  return value.isA<JSBoolean>() && (value! as JSBoolean).toDart;
}
