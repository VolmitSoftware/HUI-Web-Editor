library;

import 'dart:math' as math;

import '../model/gloss_damage_indicators.dart';

enum DamageIndicatorPreviewKind { damage, healing }

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

String formatDamageIndicatorAmount(double amount, int decimals) {
  final int places = decimals.clamp(0, 4);
  if (places == 0) return amount.round().toString();
  return amount.toStringAsFixed(places);
}

String renderDamageIndicatorText(
  GlossDamageIndicatorStyle style,
  double amount,
  int decimals,
) => style.format.replaceAll(
  glossDamageAmountToken,
  formatDamageIndicatorAmount(amount, decimals),
);

DamageIndicatorPreviewFrame resolveDamageIndicatorFrame({
  required GlossDamageIndicatorStyle style,
  required int lifetimeMs,
  required int elapsedMs,
  required int seed,
}) {
  final int safeLifetime = math.max(1, lifetimeMs);
  final int safeElapsed = elapsedMs.clamp(0, safeLifetime);
  final double seconds = safeElapsed / 1000;
  final double progress = safeElapsed / safeLifetime;
  final double angle = _seedUnit(seed) * math.pi * 2;
  final double distance = style.motion.horizontalSpeed * seconds;
  final double x = style.offset.x + math.cos(angle) * distance;
  final double z = style.offset.z + math.sin(angle) * distance;
  final double y =
      style.offset.y +
      style.motion.verticalSpeed * seconds +
      0.5 * style.motion.verticalAcceleration * seconds * seconds;
  final double scale = _lerp(
    style.presentation.startScale,
    style.presentation.endScale,
    progress,
  );
  final double fadeStart = style.presentation.fadeStartFraction.clamp(0, 1);
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
    rollDegrees: style.motion.spinDegreesPerSecond * seconds,
    progress: progress,
    visible: style.enabled && safeElapsed < safeLifetime,
  );
}

double _seedUnit(int seed) {
  int value = seed & 0x7fffffff;
  value = (value * 1103515245 + 12345) & 0x7fffffff;
  return value / 0x80000000;
}

double _lerp(double first, double second, double t) =>
    first + (second - first) * t;
