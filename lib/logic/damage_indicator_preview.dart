library;

import 'dart:math' as math;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_damage_indicators.dart';

enum DamageIndicatorPreviewKind { damage, healing }

GlossConditionContext buildDamageIndicatorPreviewConditionContext({
  required DamageIndicatorPreviewKind kind,
  required double amount,
  bool critical = false,
  bool includeViewer = false,
}) {
  final bool damage = kind == DamageIndicatorPreviewKind.damage;
  final Map<String, Object?> variables = <String, Object?>{
    'event.type': damage ? 'damage' : 'healing',
    'event.cause': damage ? 'entity_attack' : 'magic',
    'event.amount': amount,
    'event.reportedAmount': amount,
    'event.damage': damage,
    'event.healing': !damage,
    'event.directSourceType': damage ? 'player' : '',
    'event.critical': damage && critical,
    'event.criticalKnown': true,
    'world.name': 'world',
    'world.environment': 'normal',
    'world.difficulty': 'normal',
    'world.time': 6000.0,
    'world.fullTime': 6000.0,
    'world.storm': false,
    'world.thundering': false,
    'world.pvp': true,
    'world.players': 12.0,
    'server.online': 12.0,
    'server.maxPlayers': 100.0,
    'server.tps': 20.0,
  };
  _putPreviewEntity(
    variables,
    'subject.',
    name: 'Training Dummy',
    type: 'armor_stand',
    health: 12,
    player: false,
  );
  _putPreviewEntity(
    variables,
    'source.',
    name: damage ? 'Cyberpwn' : '',
    type: damage ? 'player' : '',
    health: damage ? 20 : 0,
    player: damage,
    present: damage,
  );
  if (includeViewer) {
    _putPreviewEntity(
      variables,
      'viewer.',
      name: 'Cyberpwn',
      type: 'player',
      health: 20,
      player: true,
    );
    for (final MapEntry<String, Object?> entry in variables.entries.toList()) {
      if (entry.key.startsWith('viewer.')) {
        variables['player.${entry.key.substring('viewer.'.length)}'] =
            entry.value;
      }
    }
  }
  return GlossConditionContext(
    variables: variables,
    permissions: <String>{'gloss.indicators.show'},
    groups: <String>{'player'},
    metrics: <String, double>{'react.tick-ms': 50},
  );
}

void _putPreviewEntity(
  Map<String, Object?> variables,
  String prefix, {
  required String name,
  required String type,
  required double health,
  required bool player,
  bool present = true,
}) {
  final double maxHealth = health > 0 ? 20 : 0;
  variables.addAll(<String, Object?>{
    '${prefix}present': present,
    '${prefix}uuid': present ? '00000000-0000-0000-0000-000000000001' : '',
    '${prefix}name': name,
    '${prefix}type': type,
    '${prefix}world': present ? 'world' : '',
    '${prefix}x': 0.0,
    '${prefix}y': 64.0,
    '${prefix}z': 0.0,
    '${prefix}blockX': 0.0,
    '${prefix}blockY': 64.0,
    '${prefix}blockZ': 0.0,
    '${prefix}yaw': 0.0,
    '${prefix}pitch': 0.0,
    '${prefix}dead': false,
    '${prefix}onGround': true,
    '${prefix}inWater': false,
    '${prefix}fireTicks': 0.0,
    '${prefix}freezeTicks': 0.0,
    '${prefix}ticksLived': 1200.0,
    '${prefix}health': health,
    '${prefix}maxHealth': maxHealth,
    '${prefix}healthPercent': maxHealth == 0 ? 0.0 : health * 100 / maxHealth,
    '${prefix}absorption': 0.0,
    '${prefix}ai': true,
    '${prefix}gliding': false,
    '${prefix}swimming': false,
    '${prefix}invisible': false,
    '${prefix}player': player,
    '${prefix}op': false,
    '${prefix}online': player,
    '${prefix}food': player ? 20.0 : 0.0,
    '${prefix}saturation': player ? 5.0 : 0.0,
    '${prefix}level': player ? 12.0 : 0.0,
    '${prefix}experience': player ? 0.5 : 0.0,
    '${prefix}totalExperience': player ? 320.0 : 0.0,
    '${prefix}ping': player ? 42.0 : 0.0,
    '${prefix}clientViewDistance': player ? 12.0 : 0.0,
    '${prefix}gameMode': player ? 'survival' : '',
    '${prefix}locale': player ? 'en_us' : '',
    '${prefix}sneaking': false,
    '${prefix}sprinting': false,
    '${prefix}flying': false,
    '${prefix}allowFlight': false,
    '${prefix}group': player ? 'player' : '',
  });
}

final class DamageIndicatorPreviewCycle {
  const DamageIndicatorPreviewCycle({
    required this.elapsedMs,
    required this.cycleIndex,
    required this.seed,
  });

  final int elapsedMs;
  final int cycleIndex;
  final int seed;
}

final class DamageIndicatorPreviewFrame {
  const DamageIndicatorPreviewFrame({
    required this.x,
    required this.y,
    required this.z,
    required this.scale,
    required this.opacity,
    required this.rollDegrees,
    required this.progress,
    required this.visible,
  });

  final double x;
  final double y;
  final double z;
  final double scale;
  final double opacity;
  final double rollDegrees;
  final double progress;
  final bool visible;
}

DamageIndicatorPreviewCycle resolveDamageIndicatorPreviewCycle({
  required int lifetimeMs,
  required int totalElapsedMs,
  required int baseSeed,
}) {
  final int safeLifetime = math.max(1, lifetimeMs);
  final int safeTotalElapsed = math.max(0, totalElapsedMs);
  final int cycleIndex = safeTotalElapsed ~/ safeLifetime;
  return DamageIndicatorPreviewCycle(
    elapsedMs: safeTotalElapsed % safeLifetime,
    cycleIndex: cycleIndex,
    seed: (baseSeed + cycleIndex) & 0x7fffffff,
  );
}

String formatDamageIndicatorAmount(double amount, int decimals) {
  final int places = decimals.clamp(0, 4);
  if (places == 0) return amount.round().toString();
  return amount.toStringAsFixed(places);
}

String renderDamageIndicatorText(
  GlossDamageIndicatorPresentation presentation,
  double amount,
  int decimals,
) => presentation.format.replaceAll(
  glossDamageAmountToken,
  formatDamageIndicatorAmount(amount, decimals),
);

DamageIndicatorPreviewFrame resolveDamageIndicatorFrame({
  required GlossDamageIndicatorPresentation presentation,
  required int lifetimeMs,
  required int elapsedMs,
  required int seed,
}) {
  final int safeLifetime = math.max(1, lifetimeMs);
  final int safeElapsed = elapsedMs.clamp(0, safeLifetime);
  final double seconds = safeElapsed / 1000;
  final double progress = safeElapsed / safeLifetime;
  final double angle = _seedUnit(seed) * math.pi * 2;
  final double distance = presentation.motion.horizontalSpeed * seconds;
  final double x = presentation.offset.x + math.cos(angle) * distance;
  final double z = presentation.offset.z + math.sin(angle) * distance;
  final double y =
      presentation.offset.y +
      presentation.motion.verticalSpeed * seconds +
      0.5 * presentation.motion.verticalAcceleration * seconds * seconds;
  final double scale = _lerp(
    presentation.transform.startScale,
    presentation.transform.endScale,
    progress,
  );
  final double fadeStart = presentation.transform.fadeStartFraction.clamp(0, 1);
  final double opacity = progress <= fadeStart
      ? 1
      : fadeStart >= 1
      ? 1
      : ((1 - progress) / (1 - fadeStart)).clamp(0, 1);
  return DamageIndicatorPreviewFrame(
    x: x,
    y: y,
    z: z,
    scale: scale,
    opacity: opacity,
    rollDegrees: presentation.motion.spinDegreesPerSecond * seconds,
    progress: progress,
    visible: safeElapsed < safeLifetime,
  );
}

GlossDamageIndicatorPresentation? resolveDamageIndicatorPresentation(
  GlossDamageIndicatorStyle style,
  GlossConditionContext context,
) {
  if (!glossConditionMatches(style.when, context).matches) return null;
  final List<GlossDamageIndicatorVariant> matches =
      <GlossDamageIndicatorVariant>[
        for (final GlossDamageIndicatorVariant variant in style.variants)
          if (glossConditionMatches(variant.when, context).matches) variant,
      ]..sort((
        GlossDamageIndicatorVariant first,
        GlossDamageIndicatorVariant second,
      ) {
        final int priority = second.priority.compareTo(first.priority);
        return priority != 0 ? priority : first.id.compareTo(second.id);
      });
  return matches.isEmpty ? style.presentation : matches.first.presentation;
}

double _seedUnit(int seed) {
  int value = seed & 0x7fffffff;
  value = (value * 1103515245 + 12345) & 0x7fffffff;
  return value / 0x80000000;
}

double _lerp(double first, double second, double t) =>
    first + (second - first) * t;
