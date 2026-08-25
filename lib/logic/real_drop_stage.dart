/// The drop stage's timeline: one dropped stack, from the moment it is thrown
/// to the moment it settles, driven entirely by the settings document.
///
/// The plugin never simulates the item — Minecraft's own `Item` entity falls
/// and bounces, and Gloss reacts to `isOnGround`, `getVelocity` and the
/// distance moved. So the ballistics here are the stage's own, deliberately
/// simple and documented as such: a stack is thrown forward toward the camera
/// the way `Player.drop` throws one, arcs, bounces and settles nearer the
/// viewer than it started. Everything the *document* controls is the
/// plugin's, taken from `real_drop_model.dart`:
///
///  * how many models the stack grows, and where each one sits,
///  * which scale family the material draws at and how far off the ground,
///  * the tumble, accumulated one `updateIntervalTicks` step at a time and
///    re-drawn on a bounce when `changeOnBounce` is set,
///  * the settled pose, and the interpolation window the client eases over.
///
/// The `physics` block reaches the arc. It has to: those four numbers move the
/// real entity in game, so a stage that ignored them would show nothing when
/// somebody turned them on. They are applied to the stage's own trajectory with
/// the plugin's own constants — 0.04 blocks per tick of gravity, 0.02 per point
/// of buoyancy, drag compounded per tick — but on the stage's arc, at the
/// stage's spawn height, over the stage's throw. Turning gravity up really does
/// make the stack fall harder here; the number of ticks it takes is not the
/// number of ticks it would take in a world.
///
/// The `script` block is evaluated per display per frame through
/// `real_drop_script.dart` and composed onto the result: `offset` adds to the
/// model offset, `rotation` composes onto the pose *before* the resting-height
/// correction is recomputed, `scale` multiplies the family scale per axis, and
/// `glow` and `visible` are handed to the view. Four of the variables the
/// server publishes cannot be observed on a stage with no world, and this file
/// supplies them rather than inventing them silently — see
/// [DropStageEnvironment].
///
/// Frames are pure functions of a millisecond, so pausing the stage holds an
/// instant instead of freezing a mutable simulation, and a test can assert any
/// moment of the cycle without a clock. The flight depends on the document's
/// physics block and on the stage's water toggle and on nothing else, so every
/// stack under one document shares one cycle length — which is what
/// [dropStageRotationDrop] counts to change the stack on show.
library;

import 'dart:math' as math;

import '../config/showcase_flavor.dart';
import '../model/gloss_real_drop_animation.dart';
import '../model/gloss_real_drops.dart';
import 'real_drop_animation.dart';
import 'real_drop_model.dart';
import 'real_drop_script.dart';

/// Ticks per second, for turning configured tick counts into stage time.
const double glossTicksPerSecond = 20;

/// Stage ballistics, in blocks and ticks. Not the plugin's — Minecraft's
/// `Item` entity owns the real ones, and the stage only has to put the model
/// in the air long enough to show the tumble and the settle.
const double _spawnHeight = 2.6;
const double _spawnVelocity = 0.30;

/// `RealDropService.VANILLA_ITEM_GRAVITY`: blocks per tick per tick. The one
/// stage constant that is also the plugin's, which is what lets
/// `physics.gravityMultiplier` scale it and mean the same thing.
const double _gravity = 0.04;

/// What one ground contact gives back, with the physics block off.
///
/// Vanilla items do not bounce at all, and neither does the plugin until
/// `physics.bounce` is set. The stage keeps a bounce anyway when physics is off
/// because ground contacts are the only way to *show* `motion.changeOnBounce`,
/// which is a field of the document a viewer is entitled to see working. Turn
/// physics on and `physics.bounce` replaces this outright, so a bounce of 0
/// really does land and stick.
const double _restitution = 0.4;

/// Blocks the stack ends up nearer the camera than the hand that threw it.
///
/// `Player.drop` shoves a stack along the look vector at about 0.3 blocks a
/// tick and `ItemEntity` bleeds that off slowly, which is why a dropped stack
/// in game lands a few blocks in front of you. Over this stage's twenty-one
/// tick fall those numbers played straight carry the stack five blocks — through
/// the camera and out of frame. So the stage keeps the *shape* of the throw —
/// one shove, drag bleeding it off, a bite taken out of it at every bounce —
/// and scales the whole arc down to land here.
const double dropStageThrowBlocks = 1.15;

/// `ItemEntity`'s own horizontal drag, per tick. The curve of the slowdown is
/// the part worth borrowing; [dropStageThrowBlocks] sets its size.
const double _horizontalDrag = 0.98;

/// What one ground contact takes out of the forward velocity. `ItemEntity`
/// multiplies by the block's slipperiness; the stage has one ground and so one
/// number for it.
const double _bounceFriction = 0.72;

/// Ticks the stack rests, fully settled, before the cycle restarts.
const double _restTicks = 50;

/// Ground contacts the stage draws before it calls the stack settled, and the
/// upward velocity under which a contact is a settle rather than a bounce.
const int _maxContacts = 3;
const double _settleVelocity = 0.03;
const double _settledHorizontalSpeed = 0.001;

/// The cap on a flight that never comes to rest — a floating stack, or one with
/// its gravity cleared. Six seconds is long enough to read the motion and short
/// enough that the rotation still changes stacks.
const double _hangTicks = 120;

/// `RealDropService.WATER_BUOYANCY_STEP`: blocks per tick per point of
/// `physics.waterBuoyancy`.
const double _buoyancyStep = 0.02;

/// The stage's stand-in for what water already does to an item before Gloss
/// touches it.
///
/// `physics.waterBuoyancy` is documented as adding lift *on top of whatever
/// vanilla already does*, and what vanilla already does is float a dropped
/// stack up to the surface and bob it there. Without that baseline the
/// document's buoyancy would be one seventh of gravity and a stack would sink
/// with the setting turned up, which is the opposite of what a server shows. So
/// the stage lifts a submerged stack slightly harder than gravity pulls it and
/// damps the result, which floats it, and the document's buoyancy adds to that.
/// The number is the stage's own; the behaviour it reproduces is Minecraft's.
const double _vanillaWaterLift = 0.045;

/// Per-tick damping on a submerged stack, before `physics.waterDrag`. It is
/// what bounds the rise to a terminal speed instead of accelerating the stack
/// out of the water like a cork from a bottle.
const double _waterDamping = 0.9;

/// Where the stage's water surface sits when the water toggle is on, in blocks
/// above the floor. High enough that a buoyant stack floats in frame, low
/// enough that the throw still starts in air.
const double dropStageWaterLevel = 1.15;

/// The one flight a document with no physics block takes.
///
/// Built once and shared, which is what makes [dropStageCycleMs] a constant the
/// unattended rotation can count in.
final _Flight _neutralFlight = _buildFlight(null, water: false);

/// Milliseconds one throw-to-settle-to-respawn cycle takes with the physics
/// block off, which is every document that has not opted into it.
final int dropStageCycleMs = _neutralFlight.cycleMs;

/// The cycle length for [doc] under the stage's current water setting.
///
/// The view needs this before it has a timeline: which stack is on the stage is
/// a function of how many cycles have finished, and the physics block can move
/// the cycle.
int dropStageCycleMsFor(GlossRealDropSettingsDoc doc, {bool water = false}) =>
    _flightFor(doc, water: water).cycleMs;

/// The stacks the stage shows on rotation while nobody has picked one.
///
/// One material per family in [realDropModelKind], because the family is what
/// decides a drop's scale, its clearance off the ground and the pose it settles
/// into — somebody who watches three cycles has seen every shape the plugin
/// draws. Every entry names a row of `showcaseDrops`, so the sample table's own
/// tests cover them.
const List<String> dropStageRotation = <String>[
  'cobblestone',
  'diamond_pickaxe',
  'oak_slab',
];

/// Which of [dropStageRotation] belongs on the stage after [cycle] completed
/// drops.
ShowcaseDrop dropStageRotationDrop(int cycle) {
  final String material = dropStageRotation[cycle % dropStageRotation.length];
  return showcaseDrops.firstWhere(
    (ShowcaseDrop drop) => drop.material == material,
  );
}

/// What the stage supplies for the four script variables a preview cannot
/// observe, because there is no world under it.
///
/// The server reads `inWater` off `Item.isInWater()`, `inLava` off the block at
/// the item's position, and the two light levels off the chunk. None of those
/// exist here. Rather than quietly feeding zeros — which would make a perfectly
/// correct buoyancy script look broken — the stage states its values and names
/// them as simulated in the readout and in this doc:
///
///  * `inWater` is the stage's water toggle, true while the stack is below
///    [dropStageWaterLevel]. It is the one of the four that is controllable,
///    because it is the one a script is most likely to branch on.
///  * `inLava` is always false. The stage has no lava and no control for it;
///    an expression that only fires in lava will not fire here.
///  * `blockLight` and `skyLight` are both 15. The stage is lit as open ground
///    at noon, so a script that dims in the dark shows its bright branch.
///
/// `height` and the velocities are *not* in this list: the stage genuinely
/// knows them, because it owns the arc that produces them.
final class DropStageEnvironment {
  const DropStageEnvironment({
    this.water = false,
    this.useItemDisplayNames = false,
  });

  /// Whether the stage is flooded to [dropStageWaterLevel].
  final bool water;

  final bool useItemDisplayNames;

  /// Block light level fed to the script. Full, and simulated.
  static const int blockLight = 15;

  /// Sky light level fed to the script. Full, and simulated.
  static const int skyLight = 15;

  /// Lava is never simulated: the stage has no control for it and no world to
  /// read it from.
  static const bool inLava = false;

  /// The names this stage supplies rather than observes, for the readout.
  static const List<String> simulatedVariables = <String>[
    'inWater',
    'inLava',
    'blockLight',
    'skyLight',
  ];
}

/// One item display in one frame, script already composed onto it.
final class DropStageVisual {
  const DropStageVisual({
    required this.index,
    required this.x,
    required this.y,
    required this.z,
    required this.rotation,
    required this.scale,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.glowArgb,
    required this.visible,
  });

  /// Its place in the stack, which is also its offset-table row.
  final int index;

  /// Blocks, relative to the carrier: `RealDropModel.offset` plus, on Y, the
  /// authored lift `RealDropModel.yOffset` returns, plus `script.offset`.
  final double x;
  final double y;
  final double z;

  /// The pose: stack yaw and index rotation already applied, then
  /// `script.rotation` composed onto it in X, Y, Z order.
  final DropRotation rotation;

  /// Edge length in blocks — the model's configured scale family, before the
  /// script's per-axis multipliers.
  final double scale;

  /// `script.scale`, per axis. All 1 with no script.
  final double scaleX;
  final double scaleY;
  final double scaleZ;

  /// `script.glow` as unsigned 32-bit ARGB. Exactly 0 means no outline.
  final int glowArgb;

  /// False when `script.visible` said so. The plugin drives the display's view
  /// range to zero; the item entity is untouched and still pickupable.
  final bool visible;
}

enum DropAnimationPhase {
  airborne,
  rebounding,
  rolling,
  settling,
  settled,
  submerged;

  String get label => switch (this) {
    DropAnimationPhase.airborne => 'airborne',
    DropAnimationPhase.rebounding => 'rebounding',
    DropAnimationPhase.rolling => 'rolling',
    DropAnimationPhase.settling => 'settling',
    DropAnimationPhase.settled => 'settled',
    DropAnimationPhase.submerged => 'submerged',
  };
}

/// The whole stage at one millisecond.
final class DropStageFrame {
  const DropStageFrame({
    required this.visuals,
    required this.carrierY,
    required this.carrierZ,
    required this.grounded,
    required this.settled,
    required this.phase,
    required this.phaseTimeTicks,
    required this.submerged,
    required this.bounces,
    required this.interpolationTicks,
    required this.bounceRevision,
    required this.label,
    required this.labelY,
    required this.modelKind,
    required this.modelScale,
    required this.scriptActive,
    required this.scriptFailures,
    required this.animationProfileId,
    required this.animationPhysics,
    required this.animationLightLevel,
  });

  final List<DropStageVisual> visuals;

  /// Blocks above the ground plane.
  final double carrierY;

  /// Blocks toward the camera from where the stack was thrown, which is the
  /// stage's own arc and not the plugin's — see [dropStageThrowBlocks].
  final double carrierZ;

  final bool grounded;
  final bool settled;
  final DropAnimationPhase phase;
  final double phaseTimeTicks;

  /// Below the stage's water surface, which is what `inWater` reads.
  final bool submerged;

  /// Ground contacts so far, counted the way the script variable `bounces` is —
  /// whether or not `motion.changeOnBounce` is on.
  final int bounces;

  /// What the client is told to ease this pose over — `updateIntervalTicks`
  /// in flight, `landing.transitionTicks` on the settle.
  final int interpolationTicks;

  /// How many times the stack has bounced *for tumble purposes*, which is what
  /// re-draws the spin when `motion.changeOnBounce` is set. Zero all cycle when
  /// that switch is off, which is why it is not the same as [bounces].
  final int bounceRevision;

  /// The name the plugin writes, already formatted and coloured.
  final String label;

  /// Blocks above the carrier.
  final double labelY;

  final DropModelKind modelKind;
  final double modelScale;

  /// Whether the script block ran for this frame at all.
  final bool scriptActive;

  /// Script fields that threw this frame and took their neutral fallback, in
  /// the server's own field spelling.
  final Set<String> scriptFailures;
  final String animationProfileId;
  final bool animationPhysics;
  final int animationLightLevel;
}

/// The stage for one settings document and one sample stack.
final class DropStageTimeline {
  DropStageTimeline(
    this.doc,
    this.drop, {
    this.environment = const DropStageEnvironment(),
  }) : modelKind = realDropModelKind(drop.registryName, block: drop.block),
       _spin = <DropAngles>[] {
    _flight = _flightFor(doc, water: environment.water);
    _scale = realDropScale(modelKind, doc.presentation.scale);
    _visualCount = realDropVisualCount(
      drop.amount,
      drop.maxStackSize,
      doc.presentation.limits.maxVisualsPerStack,
    );
    for (int revision = 0; revision <= _flight.bounces.length; revision++) {
      _spin.add(
        realDropSpin(
          doc.presentation.motion,
          (
            x: _unit(revision * 3 + 1),
            y: _unit(revision * 3 + 2),
            z: _unit(revision * 3 + 3),
          ),
          (
            x: _unit(revision * 7 + 11) < 0,
            y: _unit(revision * 7 + 13) < 0,
            z: _unit(revision * 7 + 17) < 0,
          ),
        ),
      );
    }
    _landing = realDropLandingRotation(modelKind, doc.presentation.landing, (
      yaw: _unit(101),
      tiltX: _unit(103),
      tiltZ: _unit(107),
    ));
    final GlossRealDropScript? script = doc.presentation.script;
    _plan = script == null || !script.enabled
        ? RealDropScriptPlan.empty
        : RealDropScriptPlan.compile(script);
    _animationPlan = RealDropAnimationPlan(doc.presentation.animation);
    _poses = _buildPoses();
    _carrierClock = _buildCarrierClock();
  }

  final GlossRealDropSettingsDoc doc;
  final ShowcaseDrop drop;
  final DropModelKind modelKind;

  /// What the stage supplies for the variables it cannot observe.
  final DropStageEnvironment environment;

  late final double _scale;
  late final int _visualCount;
  late final _Flight _flight;
  final List<DropAngles> _spin;
  late final DropRotation _landing;
  late final RealDropScriptPlan _plan;
  late final RealDropAnimationPlan _animationPlan;
  late final List<_DropPose> _poses;
  late final List<double> _carrierClock;

  /// Blocks per model edge, the configured scale family.
  double get modelScale => _scale;

  int get visualCount => _visualCount;

  /// Milliseconds one throw-to-settle-to-respawn cycle takes.
  int get cycleMs => _flight.cycleMs;

  /// Whether the document's script block is on and compiled to something.
  bool get scriptActive => _plan.isValid && _plan != RealDropScriptPlan.empty;

  /// `random` for this stack: a value in `[0, 1)` fixed for its lifetime, the
  /// way the plugin derives one from the item's UUID. There is no UUID on a
  /// stage, so the material name stands in — which keeps the same property
  /// that matters, that nothing built on it flickers between frames.
  double get random => (_unit(drop.registryName.hashCode) + 1) / 2;

  String get displayType => environment.useItemDisplayNames
      ? drop.displayName
      : drop.registryName.toLowerCase().replaceAll('_', ' ');

  /// The label the plugin's default `drops.name-format` writes for this stack.
  String get label =>
      drop.amount == 1 ? '&7$displayType' : '&7${drop.amount}x $displayType';

  DropStageFrame frameAt(int ms) {
    final double tick = (ms % cycleMs) / 50.0;
    final double carrierTick = _carrierTickAt(tick);
    final _DropPose pose = _poseAt(carrierTick);
    final bool settled = pose.phase == DropAnimationPhase.settled;
    final double height = _flight.heightAt(carrierTick);
    final double forward = _flight.forwardAt(carrierTick);
    final bool grounded = settled || height <= 0.001;
    final int bounces = settled
        ? _flight.bounces.length
        : _flight.bouncesBefore(carrierTick);

    final DropRotation rotation = pose.rotation;
    final int bounceRevision = doc.presentation.motion.changeOnBounce
        ? bounces
        : 0;

    final bool submerged = environment.water && height < dropStageWaterLevel;
    final RealDropAnimationSample animation = _animationPlan.sample(
      drop.registryName,
      _activeAnimationClips(tick, carrierTick, pose),
    );
    final Set<String> failures = <String>{};
    final List<DropStageVisual> visuals = <DropStageVisual>[
      for (int index = 0; index < _visualCount; index++)
        _visual(
          index,
          rotation,
          grounded,
          animation,
          _sample(
            index: index,
            tick: tick,
            carrierTick: carrierTick,
            height: height,
            grounded: grounded,
            settled: settled,
            phase: pose.phase,
            phaseTimeTicks: pose.phaseTimeTicks,
            submerged: submerged,
            bounces: bounces,
            failures: failures,
          ),
        ),
    ];

    return DropStageFrame(
      visuals: visuals,
      carrierY: height,
      carrierZ: forward,
      grounded: grounded,
      settled: settled,
      phase: pose.phase,
      phaseTimeTicks: pose.phaseTimeTicks,
      submerged: submerged,
      bounces: bounces,
      interpolationTicks: settled
          ? doc.presentation.landing.transitionTicks
          : doc.presentation.limits.updateIntervalTicks,
      bounceRevision: bounceRevision,
      label: label,
      labelY: doc.presentation.labels.yOffset,
      modelKind: modelKind,
      modelScale: _scale,
      scriptActive: scriptActive,
      scriptFailures: failures,
      animationProfileId: animation.profileId,
      animationPhysics: animation.physics,
      animationLightLevel: animation.lightLevel,
    );
  }

  List<RealDropActiveAnimationClip> _activeAnimationClips(
    double animationTick,
    double carrierTick,
    _DropPose pose,
  ) {
    if (!_animationPlan.enabled) return const <RealDropActiveAnimationClip>[];
    final List<RealDropActiveAnimationClip> clips =
        <RealDropActiveAnimationClip>[
          RealDropActiveAnimationClip(
            GlossRealDropAnimationTrigger.spawn,
            animationTick,
          ),
          RealDropActiveAnimationClip(
            _phaseTrigger(pose.phase),
            pose.phaseTimeTicks,
          ),
        ];
    for (final GlossRealDropAnimationTrigger trigger
        in const <GlossRealDropAnimationTrigger>[
          GlossRealDropAnimationTrigger.impact,
          GlossRealDropAnimationTrigger.bounce,
          GlossRealDropAnimationTrigger.enterFluid,
          GlossRealDropAnimationTrigger.exitFluid,
          GlossRealDropAnimationTrigger.startRoll,
          GlossRealDropAnimationTrigger.settle,
          GlossRealDropAnimationTrigger.wake,
        ]) {
      final double? eventTick = _latestEventTick(trigger, carrierTick);
      if (eventTick != null) {
        clips.add(
          RealDropActiveAnimationClip(trigger, carrierTick - eventTick),
        );
      }
    }
    return clips;
  }

  List<double> _buildCarrierClock() {
    final int lastTick = (_flight.cycleMs / 50).ceil();
    final List<double> carrierTicks = <double>[0];
    double carrierTick = 0;
    for (int animationTick = 0; animationTick < lastTick; animationTick++) {
      final _DropPose pose = _poseAt(carrierTick);
      final RealDropAnimationSample animation = _animationPlan.sample(
        drop.registryName,
        _activeAnimationClips(animationTick.toDouble(), carrierTick, pose),
      );
      if (animation.physics) carrierTick += 1;
      carrierTicks.add(carrierTick);
    }
    return carrierTicks;
  }

  double _carrierTickAt(double animationTick) {
    if (animationTick <= 0) return 0;
    final int index = animationTick.floor();
    if (index >= _carrierClock.length - 1) return _carrierClock.last;
    final double fraction = animationTick - index;
    return _carrierClock[index] +
        (_carrierClock[index + 1] - _carrierClock[index]) * fraction;
  }

  GlossRealDropAnimationTrigger _phaseTrigger(DropAnimationPhase phase) =>
      switch (phase) {
        DropAnimationPhase.airborne => GlossRealDropAnimationTrigger.airborne,
        DropAnimationPhase.rebounding =>
          GlossRealDropAnimationTrigger.rebounding,
        DropAnimationPhase.rolling => GlossRealDropAnimationTrigger.rolling,
        DropAnimationPhase.settling => GlossRealDropAnimationTrigger.settling,
        DropAnimationPhase.settled => GlossRealDropAnimationTrigger.settled,
        DropAnimationPhase.submerged => GlossRealDropAnimationTrigger.submerged,
      };

  double? _latestEventTick(
    GlossRealDropAnimationTrigger trigger,
    double untilTick,
  ) {
    double? latest;
    final int last = math.min(untilTick.floor(), _poses.length - 1);
    for (int tick = 1; tick <= last; tick++) {
      final DropAnimationPhase previous = _poses[tick - 1].phase;
      final DropAnimationPhase current = _poses[tick].phase;
      final double previousHeight = _flight.heightAt((tick - 1).toDouble());
      final double currentHeight = _flight.heightAt(tick.toDouble());
      final bool event = switch (trigger) {
        GlossRealDropAnimationTrigger.impact =>
          previousHeight > 0.001 && currentHeight <= 0.001,
        GlossRealDropAnimationTrigger.bounce => _flight.bounces.contains(
          tick.toDouble(),
        ),
        GlossRealDropAnimationTrigger.enterFluid =>
          environment.water &&
              previousHeight >= dropStageWaterLevel &&
              currentHeight < dropStageWaterLevel,
        GlossRealDropAnimationTrigger.exitFluid =>
          environment.water &&
              previousHeight < dropStageWaterLevel &&
              currentHeight >= dropStageWaterLevel,
        GlossRealDropAnimationTrigger.startRoll =>
          current == DropAnimationPhase.rolling && previous != current,
        GlossRealDropAnimationTrigger.settle =>
          current == DropAnimationPhase.settled && previous != current,
        GlossRealDropAnimationTrigger.wake =>
          previous == DropAnimationPhase.settled && current != previous,
        _ => false,
      };
      if (event) latest = tick.toDouble();
    }
    return latest;
  }

  List<_DropPose> _buildPoses() {
    final int lastTick = (cycleMs / 50).ceil();
    final int requiredStableTicks = math.max(
      math.max(1, doc.presentation.limits.updateIntervalTicks),
      doc.presentation.landing.settleDelayTicks,
    );
    final List<_DropPose> poses = <_DropPose>[];
    DropRotation rotation = realDropBaseRotation(modelKind);
    DropAnimationPhase phase = DropAnimationPhase.airborne;
    int phaseTicks = 0;
    int stableTicks = 0;
    poses.add(
      _DropPose(
        rotation: rotation,
        phase: phase,
        phaseTimeTicks: phaseTicks.toDouble(),
      ),
    );

    for (int tick = 1; tick <= lastTick; tick++) {
      final double height = _flight.heightAt(tick.toDouble());
      final bool submerged = environment.water && height < dropStageWaterLevel;
      final bool grounded = height <= 0.001;
      final double previousForward = _flight.forwardAt((tick - 1).toDouble());
      final double forward = _flight.forwardAt(tick.toDouble());
      final double deltaZ = forward - previousForward;
      final double speed = _flight.velocityZAt(tick.toDouble()).abs();
      DropAnimationPhase nextPhase;

      if (submerged) {
        rotation = _advanceTumble(
          rotation,
          tick,
          doc.presentation.motion.submergedSpinMultiplier,
        );
        stableTicks = 0;
        nextPhase = DropAnimationPhase.submerged;
      } else if (!grounded) {
        rotation = _advanceTumble(rotation, tick, 1);
        stableTicks = 0;
        nextPhase = _flight.reboundingAt(tick.toDouble())
            ? DropAnimationPhase.rebounding
            : DropAnimationPhase.airborne;
      } else {
        final bool moving = speed > _settledHorizontalSpeed;
        bool aligned;
        if (modelKind != DropModelKind.flat &&
            doc.presentation.landing.mode.toUpperCase() == 'NATURAL') {
          final ({DropRotation rotation, bool aligned}) roll =
              realDropGroundedBlockRotation(
                rotation,
                0,
                deltaZ,
                speed,
                _scale,
                doc.presentation.motion.groundRollMultiplier,
                doc.presentation.landing.faceAttraction,
                doc.presentation.landing.movingFaceAttraction,
                doc.presentation.landing.alignmentDegrees * _degToRad,
              );
          rotation = roll.rotation;
          aligned = roll.aligned;
        } else {
          final DropRotation target = modelKind == DropModelKind.flat
              ? realDropBroadFaceAlignedRotation(rotation)
              : _landing;
          final double difference = rotation.difference(target);
          aligned =
              difference <=
              doc.presentation.landing.alignmentDegrees * _degToRad;
          if (aligned) {
            rotation = target;
          } else {
            final double speedReference = math.max(0.02, _scale * 0.25);
            final double motionRatio = math.min(1, speed / speedReference);
            final double attraction =
                doc.presentation.landing.faceAttraction -
                (doc.presentation.landing.faceAttraction -
                        doc.presentation.landing.movingFaceAttraction) *
                    motionRatio;
            rotation = rotation.slerp(target, attraction);
          }
        }

        if (moving) {
          stableTicks = 0;
          nextPhase = DropAnimationPhase.rolling;
        } else if (!aligned) {
          stableTicks = 0;
          nextPhase = DropAnimationPhase.settling;
        } else {
          stableTicks++;
          nextPhase = stableTicks >= requiredStableTicks
              ? DropAnimationPhase.settled
              : DropAnimationPhase.settling;
        }
      }

      if (phase == nextPhase) {
        phaseTicks++;
      } else {
        phase = nextPhase;
        phaseTicks = 0;
      }
      poses.add(
        _DropPose(
          rotation: rotation,
          phase: phase,
          phaseTimeTicks: phaseTicks.toDouble(),
        ),
      );
    }
    return poses;
  }

  DropRotation _advanceTumble(
    DropRotation rotation,
    int tick,
    double mediumMultiplier,
  ) {
    if (!doc.presentation.motion.tumble) return rotation;
    int revision = _flight.bouncesBefore(tick.toDouble());
    if (!doc.presentation.motion.changeOnBounce) revision = 0;
    final DropAngles spin = _spin[math.min(revision, _spin.length - 1)];
    const double seconds = 1 / glossTicksPerSecond;
    final double velocityY = _flight.velocityYAt(tick.toDouble());
    final double velocityZ = _flight.velocityZAt(tick.toDouble());
    final double speed = math.sqrt(
      velocityY * velocityY + velocityZ * velocityZ,
    );
    final double momentumMultiplier =
        1 + math.min(2, speed * doc.presentation.motion.velocityInfluence);
    return rotation
        .rotateX(
          spin.x * seconds * mediumMultiplier * momentumMultiplier * _degToRad,
        )
        .rotateY(
          spin.y * seconds * mediumMultiplier * momentumMultiplier * _degToRad,
        )
        .rotateZ(
          spin.z * seconds * mediumMultiplier * momentumMultiplier * _degToRad,
        );
  }

  _DropPose _poseAt(double tick) {
    final int index = tick.floor().clamp(0, _poses.length - 1);
    final _DropPose current = _poses[index];
    if (index >= _poses.length - 1) return current;
    final double fraction = tick - index;
    final _DropPose next = _poses[index + 1];
    return _DropPose(
      rotation: current.rotation.slerp(next.rotation, fraction),
      phase: current.phase,
      phaseTimeTicks: current.phase == next.phase
          ? current.phaseTimeTicks + fraction
          : current.phaseTimeTicks,
    );
  }

  /// One script evaluation, for one display in one frame.
  ///
  /// `t` and `age` both count from the throw: the stage's stack is born when it
  /// is thrown, so it has no history the way an item that lay on the ground
  /// before Gloss picked it up would. Everything else here the stage genuinely
  /// knows, bar the four names [DropStageEnvironment] supplies.
  RealDropScriptSample _sample({
    required int index,
    required double tick,
    required double carrierTick,
    required double height,
    required bool grounded,
    required bool settled,
    required DropAnimationPhase phase,
    required double phaseTimeTicks,
    required bool submerged,
    required int bounces,
    required Set<String> failures,
  }) {
    if (!scriptActive) return RealDropScriptSample.neutral;
    final RealDropScriptSample sample = _plan.sample(
      RealDropScriptContext(
        t: tick / glossTicksPerSecond,
        age: tick.floor(),
        index: index,
        count: _visualCount,
        amount: drop.amount,
        onGround: grounded,
        settled: settled,
        phase: phase.name.toUpperCase(),
        stateTime: phaseTimeTicks / glossTicksPerSecond,
        impactSpeed: bounces <= 0
            ? 0
            : _flight
                  .velocityYAt(
                    math.max(0, _flight.bounces[bounces - 1] - 0.001),
                  )
                  .abs(),
        inWater: submerged,
        inLava: DropStageEnvironment.inLava,
        bounces: bounces,
        velocityX: 0,
        velocityY: settled ? 0 : _flight.velocityYAt(carrierTick),
        velocityZ: settled ? 0 : _flight.velocityZAt(carrierTick),
        height: settled ? 0 : height,
        blockLight: DropStageEnvironment.blockLight,
        skyLight: DropStageEnvironment.skyLight,
        random: random,
        material: drop.registryName,
        kind: modelKind,
      ),
    );
    failures.addAll(sample.failed);
    return sample;
  }

  DropStageVisual _visual(
    int index,
    DropRotation rotation,
    bool grounded,
    RealDropAnimationSample animation,
    RealDropScriptSample sample,
  ) {
    final ({double x, double y, double z}) offset = realDropOffset(
      index,
      doc.presentation.limits.spread,
    );
    // Script rotation composes onto the pose *before* the clearance is worked
    // out, which is what stops a scripted tilt sinking a block into the floor —
    // section 3 of DROP_SCRIPT_FORMAT.md is explicit that the correction is
    // recomputed from the final pose.
    final DropRotation indexed = _compose(
      realDropIndexedRotation(rotation, index),
      sample,
      animation,
    );
    return DropStageVisual(
      index: index,
      x: offset.x + sample.offsetX + animation.offsetX,
      y:
          offset.y +
          realDropYOffset(
            drop.registryName,
            modelKind,
            _scale,
            indexed,
            grounded: grounded,
          ) +
          sample.offsetY +
          animation.offsetY,
      z: offset.z + sample.offsetZ + animation.offsetZ,
      rotation: indexed,
      scale: _scale,
      scaleX: sample.scaleX * animation.scaleX,
      scaleY: sample.scaleY * animation.scaleY,
      scaleZ: sample.scaleZ * animation.scaleZ,
      glowArgb: animation.glowArgb == 0 ? sample.glowArgb : animation.glowArgb,
      visible: sample.visible && animation.visible,
    );
  }

  /// `script.rotation` applied in X then Y then Z order, as the plugin applies
  /// it. Degrees in the document, radians in the matrix.
  DropRotation _compose(
    DropRotation pose,
    RealDropScriptSample sample,
    RealDropAnimationSample animation,
  ) {
    final double x = sample.rotationX + animation.rotationX;
    final double y = sample.rotationY + animation.rotationY;
    final double z = sample.rotationZ + animation.rotationZ;
    if (x == 0 && y == 0 && z == 0) {
      return pose;
    }
    return pose
        .rotateX(x * _degToRad)
        .rotateY(y * _degToRad)
        .rotateZ(z * _degToRad);
  }
}

/// Flights, keyed by the physics that shape them. A document is re-read on
/// every keystroke in the inspector, and integrating a trajectory per frame
/// would be work for nothing when four numbers and a toggle decide all of it.
final Map<String, _Flight> _flights = <String, _Flight>{};

_Flight _flightFor(GlossRealDropSettingsDoc doc, {required bool water}) {
  final GlossRealDropPhysics? physics = doc.presentation.physics;
  if (physics == null || !physics.enabled) {
    return water
        ? _flights.putIfAbsent('water', () => _buildFlight(null, water: true))
        : _neutralFlight;
  }
  final String key =
      '${physics.gravityMultiplier}/${physics.bounce}/'
      '${physics.waterBuoyancy}/${physics.waterDrag}/$water';
  return _flights.putIfAbsent(key, () => _buildFlight(physics, water: water));
}

/// The stage's arc, integrated one tick at a time.
///
/// A tick loop rather than the closed form the stage used before the physics
/// block existed, because buoyancy and drag are per-tick multiplications with
/// no closed form worth writing — and because a per-tick loop is exactly the
/// shape of `RealDropService.applyPhysics`, which is the thing the numbers came
/// from. The result is a table, so a frame is still a pure function of its
/// millisecond.
///
/// The forward half is integrated at a unit launch speed and scaled at the end,
/// so [dropStageThrowBlocks] states a distance the whole throw actually lands
/// on rather than a velocity somebody has to integrate to picture. Travel is
/// linear in the launch speed, so the scaling is exact.
_Flight _buildFlight(GlossRealDropPhysics? physics, {required bool water}) {
  final double gravity = physics == null
      ? _gravity
      : _gravity * physics.gravityMultiplier;
  final double restitution = physics == null ? _restitution : physics.bounce;
  final double buoyancy = physics == null ? 0 : physics.waterBuoyancy;
  final double drag = physics == null ? 0 : physics.waterDrag;
  // Exactly zero clears the entity's gravity flag in game and the item hangs
  // where it is; on the stage that is a stack that never falls and never
  // settles, which the cap below turns into a loop.
  final bool hanging = gravity <= 0;

  final List<double> heights = <double>[_spawnHeight];
  final List<double> forwards = <double>[0];
  final List<double> velocityY = <double>[hanging ? 0 : _spawnVelocity];
  final List<double> velocityZ = <double>[1];
  final List<double> bounces = <double>[];

  double height = _spawnHeight;
  double forward = 0;
  double vy = hanging ? 0 : _spawnVelocity;
  double vz = 1;
  int contacts = 0;
  double restTick = _hangTicks;
  bool settles = false;
  bool supported = false;

  for (int tick = 1; tick <= _hangTicks; tick++) {
    final bool submerged = water && height < dropStageWaterLevel;
    if (supported && !submerged) {
      height = 0;
      vy = 0;
      forward += vz;
      vz *= _bounceFriction;
      heights.add(height);
      forwards.add(forward);
      velocityY.add(vy);
      velocityZ.add(vz);
      if (vz.abs() <= _settledHorizontalSpeed) {
        restTick = tick.toDouble();
        settles = true;
        break;
      }
      continue;
    }
    if (!hanging) vy -= gravity;
    if (submerged) {
      vy += _vanillaWaterLift + _buoyancyStep * buoyancy;
      vy *= _waterDamping;
      vz *= _waterDamping;
      if (drag > 0) {
        final double retained = 1 - drag;
        vy *= retained;
        vz *= retained;
      }
    }
    height += vy;
    forward += vz;
    vz *= _horizontalDrag;

    if (height <= 0) {
      height = 0;
      final double rebound = vy.abs() * restitution;
      if (rebound < _settleVelocity || contacts >= _maxContacts) {
        vy = 0;
        // Underwater the stack rests on the floor but the loop keeps running:
        // the water may lift it off again, and the plugin does not let a
        // submerged item settle either — it holds the fast polling interval
        // because a buoyant item is never really at rest.
        if (!submerged) {
          supported = true;
          vz *= _bounceFriction;
        }
      } else {
        contacts++;
        vz *= _bounceFriction;
        vy = rebound;
        bounces.add(tick.toDouble());
      }
    }

    heights.add(height);
    forwards.add(forward);
    velocityY.add(vy);
    velocityZ.add(vz);
  }

  final double travelled = forwards.last;
  final double toThrow = travelled > 0 ? dropStageThrowBlocks / travelled : 0;
  return _Flight(
    heights: heights,
    forwards: <double>[for (final double value in forwards) value * toThrow],
    velocityY: velocityY,
    velocityZ: <double>[for (final double value in velocityZ) value * toThrow],
    bounces: bounces,
    restTick: restTick,
    settles: settles,
  );
}

final class _Flight {
  const _Flight({
    required this.heights,
    required this.forwards,
    required this.velocityY,
    required this.velocityZ,
    required this.bounces,
    required this.restTick,
    required this.settles,
  });

  /// Blocks above the floor at each whole tick, from the throw.
  final List<double> heights;

  /// Blocks toward the camera at each whole tick, already scaled so the last
  /// entry is [dropStageThrowBlocks].
  final List<double> forwards;

  /// Blocks per tick at each whole tick. Negative Y is falling.
  final List<double> velocityY;
  final List<double> velocityZ;

  /// Ticks at which the stack hit the ground and came back up.
  final List<double> bounces;

  /// The tick the stack stops moving for good, or [_hangTicks] when it never
  /// does.
  final double restTick;

  /// False for a flight that never comes to rest — gravity cleared, or a
  /// buoyant stack in water.
  final bool settles;

  int get cycleMs => ((restTick + (settles ? _restTicks : 0)) * 50).round();

  double heightAt(double tick) => _lerp(heights, tick);

  /// Blocks toward the camera at [tick]. Past the last entry the stack has
  /// stopped, and it has covered the whole throw.
  double forwardAt(double tick) => _lerp(forwards, tick);

  double velocityYAt(double tick) => _at(velocityY, tick);

  double velocityZAt(double tick) => _at(velocityZ, tick);

  int bouncesBefore(double tick) {
    int count = 0;
    for (final double bounce in bounces) {
      if (tick >= bounce) count++;
    }
    return count;
  }

  bool reboundingAt(double tick) {
    for (final double bounce in bounces) {
      if (tick > bounce && tick <= bounce + 1) return true;
    }
    return false;
  }

  /// A position between two whole ticks. The client interpolates the same way
  /// between the poses Gloss hands it, so a straight line is the right shape.
  static double _lerp(List<double> table, double tick) {
    if (tick <= 0) return table.first;
    final int index = tick.floor();
    if (index >= table.length - 1) return table.last;
    final double fraction = tick - index;
    return table[index] + (table[index + 1] - table[index]) * fraction;
  }

  /// A per-tick quantity, taken whole. Velocity is constant across a tick in
  /// the plugin's own model, so there is nothing here to interpolate.
  static double _at(List<double> table, double tick) {
    if (tick <= 0) return table.first;
    final int index = tick.floor();
    return index >= table.length ? table.last : table[index];
  }
}

final class _DropPose {
  const _DropPose({
    required this.rotation,
    required this.phase,
    required this.phaseTimeTicks,
  });

  final DropRotation rotation;
  final DropAnimationPhase phase;
  final double phaseTimeTicks;
}

const double _degToRad = math.pi / 180;

/// A deterministic value in `-1..1` for the stage's draws.
///
/// The plugin mixes an item UUID through a 64-bit SplitMix step, which web
/// `int` cannot hold — it is a double there — and a preview has no UUID to mix
/// anyway. This is the stand-in: a 32-bit avalanche done in 16-bit halves so
/// every intermediate stays well inside 2^53 and the browser agrees with the
/// VM, which is what lets a test assert a frame.
double _unit(int seed) {
  final int mixed = _mix32(seed) & 0x7FFFFFFF;
  return mixed / 0x3FFFFFFF - 1;
}

int _mix32(int seed) {
  int value = seed & 0xFFFFFFFF;
  value ^= value >> 16;
  value = _mulLow32(value, 0x7FEB352D);
  value ^= value >> 15;
  value = _mulLow32(value, 0x846CA68B);
  value ^= value >> 16;
  return value & 0xFFFFFFFF;
}

/// The low 32 bits of `a * b`, split so no intermediate exceeds 2^53.
int _mulLow32(int a, int b) {
  final int aLow = a & 0xFFFF;
  final int aHigh = (a >> 16) & 0xFFFF;
  final int bLow = b & 0xFFFF;
  final int bHigh = (b >> 16) & 0xFFFF;
  final int low = aLow * bLow;
  final int mid = (aLow * bHigh + aHigh * bLow) & 0xFFFF;
  return (mid * 0x10000 + low) & 0xFFFFFFFF;
}
