library;

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/damage_indicator_preview.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('amount formatting and template replacement match the contract', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    expect(formatDamageIndicatorAmount(2.5, 0), '3');
    expect(formatDamageIndicatorAmount(2.5, 1), '2.5');
    expect(formatDamageIndicatorAmount(2.5, 2), '2.50');
    expect(formatDamageIndicatorAmount(1.23456, 4), '1.2346');
    expect(renderDamageIndicatorText(doc.damage, 2.5, 1), '&c&l2.5');
  });

  test('closed-form damage trajectory applies velocity and acceleration', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    final DamageIndicatorPreviewFrame start = resolveDamageIndicatorFrame(
      style: doc.damage,
      lifetimeMs: 3000,
      elapsedMs: 0,
      seed: 7,
    );
    final DamageIndicatorPreviewFrame oneSecond = resolveDamageIndicatorFrame(
      style: doc.damage,
      lifetimeMs: 3000,
      elapsedMs: 1000,
      seed: 7,
    );
    expect(start.y, closeTo(0.7, 1e-9));
    expect(oneSecond.y, closeTo(1.535, 1e-9));
    expect((oneSecond.x - doc.damage.offset.x).abs(), lessThanOrEqualTo(0.8));
    expect(oneSecond.scale, closeTo(0.94, 1e-9));
    expect(oneSecond.opacity, 1);
  });

  test('fade, scale, roll and expiry follow normalized lifetime', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    doc.damage.motion.spinDegreesPerSecond = 90;
    final DamageIndicatorPreviewFrame late = resolveDamageIndicatorFrame(
      style: doc.damage,
      lifetimeMs: 3000,
      elapsedMs: 2400,
      seed: 13,
    );
    final DamageIndicatorPreviewFrame expired = resolveDamageIndicatorFrame(
      style: doc.damage,
      lifetimeMs: 3000,
      elapsedMs: 3000,
      seed: 13,
    );
    expect(late.progress, closeTo(0.8, 1e-9));
    expect(late.opacity, closeTo(0.625, 1e-9));
    expect(late.rollDegrees, closeTo(216, 1e-9));
    expect(expired.visible, isFalse);
  });

  test('seeded horizontal direction is stable and seed-sensitive', () {
    final GlossDamageIndicatorsDoc doc = buildDefaultGlossDamageIndicators();
    final DamageIndicatorPreviewFrame first = resolveDamageIndicatorFrame(
      style: doc.healing,
      lifetimeMs: 3000,
      elapsedMs: 1000,
      seed: 4,
    );
    final DamageIndicatorPreviewFrame repeat = resolveDamageIndicatorFrame(
      style: doc.healing,
      lifetimeMs: 3000,
      elapsedMs: 1000,
      seed: 4,
    );
    final DamageIndicatorPreviewFrame other = resolveDamageIndicatorFrame(
      style: doc.healing,
      lifetimeMs: 3000,
      elapsedMs: 1000,
      seed: 5,
    );
    expect(repeat.x, first.x);
    expect(repeat.z, first.z);
    expect(other.x, isNot(first.x));
  });
}
