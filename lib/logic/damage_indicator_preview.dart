library;

import 'dart:math' as math;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_damage_indicators.dart';

enum DamageIndicatorPreviewKind { damage, healing }

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
