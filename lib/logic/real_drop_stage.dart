/// The drop stage's timeline: one dropped stack, from the moment it is thrown
/// to the moment it settles, driven entirely by the settings document.
///
/// The plugin never simulates the item — Minecraft's own `Item` entity falls
/// and bounces, and Gloss reacts to `isOnGround`, `getVelocity` and the
/// distance moved. So the ballistics here are the stage's own, deliberately
/// simple and documented as such; everything the *document* controls is the
/// plugin's, taken from `real_drop_model.dart`:
///
///  * how many models the stack grows, and where each one sits,
///  * which scale family the material draws at and how far off the ground,
///  * the tumble, accumulated one `updateIntervalTicks` step at a time and
///    re-drawn on a bounce when `changeOnBounce` is set,
///  * the settled pose, and the interpolation window the client eases over.
///
/// Frames are pure functions of a millisecond, so pausing the stage holds an
/// instant instead of freezing a mutable simulation, and a test can assert any
/// moment of the cycle without a clock.
library;

import 'dart:math' as math;

import '../config/showcase_flavor.dart';
import '../model/gloss_real_drops.dart';
import 'real_drop_model.dart';

/// Ticks per second, for turning configured tick counts into stage time.
const double glossTicksPerSecond = 20;

/// Stage ballistics, in blocks and ticks. Not the plugin's — Minecraft's
/// `Item` entity owns the real ones, and the stage only has to put the model
/// in the air long enough to show the tumble and the settle.
const double _spawnHeight = 2.6;
const double _spawnVelocity = 0.30;
const double _gravity = 0.04;
const double _restitution = 0.4;

/// Ticks the stack rests, fully settled, before the cycle restarts.
const double _restTicks = 50;

/// One item display in one frame.
final class DropStageVisual {
  const DropStageVisual({
    required this.index,
    required this.x,
    required this.y,
    required this.z,
    required this.rotation,
    required this.scale,
  });

  /// Its place in the stack, which is also its offset-table row.
  final int index;

  /// Blocks, relative to the carrier: `RealDropModel.offset` plus, on Y, the
  /// authored lift `RealDropModel.yOffset` returns.
  final double x;
  final double y;
  final double z;

  /// The pose, stack yaw already applied.
  final DropRotation rotation;

  /// Edge length in blocks — the model's configured scale family.
  final double scale;
}

/// The whole stage at one millisecond.
final class DropStageFrame {
  const DropStageFrame({
    required this.visuals,
    required this.carrierY,
    required this.grounded,
    required this.settled,
    required this.interpolationTicks,
    required this.bounceRevision,
    required this.label,
    required this.labelY,
    required this.modelKind,
    required this.modelScale,
  });

  final List<DropStageVisual> visuals;

  /// Blocks above the ground plane.
  final double carrierY;

  final bool grounded;
  final bool settled;

  /// What the client is told to ease this pose over — `updateIntervalTicks`
  /// in flight, `landing.transitionTicks` on the settle.
  final int interpolationTicks;

  /// How many times the stack has bounced, which is what re-draws the spin
  /// when `motion.changeOnBounce` is set.
  final int bounceRevision;

  /// The name the plugin writes, already formatted and coloured.
  final String label;

  /// Blocks above the carrier.
  final double labelY;

  final DropModelKind modelKind;
  final double modelScale;
}

/// The stage for one settings document and one sample stack.
final class DropStageTimeline {
  DropStageTimeline(this.doc, this.drop)
    : modelKind = realDropModelKind(drop.registryName, block: drop.block),
      _spin = <DropAngles>[] {
    _scale = realDropScale(modelKind, doc.scale);
    _visualCount = realDropVisualCount(
      drop.amount,
      drop.maxStackSize,
      doc.limits.maxVisualsPerStack,
    );
    _flight = _buildFlight();
    for (int revision = 0; revision <= _flight.bounces.length; revision++) {
      _spin.add(
        realDropSpin(
          doc.motion,
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
    _landing = realDropLandingRotation(modelKind, doc.landing, (
      yaw: _unit(101),
      tiltX: _unit(103),
      tiltZ: _unit(107),
    ));
  }

  final GlossRealDropSettingsDoc doc;
  final ShowcaseDrop drop;
  final DropModelKind modelKind;

  late final double _scale;
  late final int _visualCount;
  late final _Flight _flight;
  final List<DropAngles> _spin;
  late final DropRotation _landing;

  /// Blocks per model edge, the configured scale family.
  double get modelScale => _scale;

  int get visualCount => _visualCount;

  /// Milliseconds one throw-to-settle-to-respawn cycle takes.
  int get cycleMs => ((_flight.restTick + _restTicks) * 50).round();

  /// The label the plugin's default `drops.name-format` writes for this stack,
  /// with `drops.useItemDisplayNames` on, which is the shipped default.
  String get label => '&7${drop.amount}x ${drop.displayName}';

  DropStageFrame frameAt(int ms) {
    final double tick = (ms % cycleMs) / 50.0;
    final int step = math.max(1, doc.limits.updateIntervalTicks);
    final bool settled = tick >= _flight.restTick;
    final double height = settled ? 0 : _flight.heightAt(tick);
    final bool grounded = settled || height <= 0.001;

    DropRotation rotation = realDropBaseRotation(modelKind);
    int bounceRevision = 0;
    if (settled) {
      rotation = _landing;
      bounceRevision = _flight.bounces.length;
    } else if (doc.motion.tumble) {
      final double seconds = step / glossTicksPerSecond;
      for (double at = 0; at < tick; at += step) {
        bounceRevision = _flight.bouncesBefore(at);
        if (!doc.motion.changeOnBounce) bounceRevision = 0;
        final DropAngles spin = _spin[math.min(bounceRevision, _spin.length - 1)];
        rotation = rotation
            .rotateX(spin.x * seconds * _degToRad)
            .rotateY(spin.y * seconds * _degToRad)
            .rotateZ(spin.z * seconds * _degToRad);
      }
    }

    final List<DropStageVisual> visuals = <DropStageVisual>[
      for (int index = 0; index < _visualCount; index++)
        _visual(index, rotation, grounded),
    ];

    return DropStageFrame(
      visuals: visuals,
      carrierY: height,
      grounded: grounded,
      settled: settled,
      interpolationTicks: settled
          ? doc.landing.transitionTicks
          : doc.limits.updateIntervalTicks,
      bounceRevision: bounceRevision,
      label: label,
      labelY: doc.labels.yOffset,
      modelKind: modelKind,
      modelScale: _scale,
    );
  }

  DropStageVisual _visual(int index, DropRotation rotation, bool grounded) {
    final ({double x, double y, double z}) offset = realDropOffset(
      index,
      doc.limits.spread,
    );
    final DropRotation indexed = realDropIndexedRotation(rotation, index);
    return DropStageVisual(
      index: index,
      x: offset.x,
      y:
          offset.y +
          realDropYOffset(
            drop.registryName,
            modelKind,
            _scale,
            indexed,
            grounded: grounded,
          ),
      z: offset.z,
      rotation: indexed,
      scale: _scale,
    );
  }

  _Flight _buildFlight() {
    final List<double> bounces = <double>[];
    double height = _spawnHeight;
    double velocity = _spawnVelocity;
    double tick = 0;
    final List<_Arc> arcs = <_Arc>[];
    for (int bounce = 0; bounce < 3; bounce++) {
      // Time to reach the ground from (height, velocity) under gravity.
      final double discriminant = velocity * velocity + 2 * _gravity * height;
      final double duration =
          (velocity + math.sqrt(discriminant)) / _gravity;
      arcs.add(_Arc(start: tick, duration: duration, height: height, velocity: velocity));
      tick += duration;
      bounces.add(tick);
      velocity = (velocity - _gravity * duration).abs() * _restitution;
      height = 0;
      if (velocity < 0.03) break;
    }
    bounces.removeLast();
    return _Flight(arcs: arcs, bounces: bounces, restTick: tick);
  }
}

final class _Arc {
  const _Arc({
    required this.start,
    required this.duration,
    required this.height,
    required this.velocity,
  });

  final double start;
  final double duration;
  final double height;
  final double velocity;
}

final class _Flight {
  const _Flight({
    required this.arcs,
    required this.bounces,
    required this.restTick,
  });

  final List<_Arc> arcs;

  /// Ticks at which the stack hit the ground and came back up.
  final List<double> bounces;

  /// The tick the stack stops moving for good.
  final double restTick;

  double heightAt(double tick) {
    for (final _Arc arc in arcs) {
      if (tick < arc.start || tick > arc.start + arc.duration) continue;
      final double local = tick - arc.start;
      final double height =
          arc.height + arc.velocity * local - 0.5 * _gravity * local * local;
      return height < 0 ? 0 : height;
    }
    return 0;
  }

  int bouncesBefore(double tick) {
    int count = 0;
    for (final double bounce in bounces) {
      if (tick >= bounce) count++;
    }
    return count;
  }
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
