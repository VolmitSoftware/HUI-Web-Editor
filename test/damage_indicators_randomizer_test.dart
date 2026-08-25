import 'dart:convert';
import 'dart:math' as math;

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/logic/damage_indicator_preview.dart';
import 'package:gloss_editor/logic/damage_indicator_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:test/test.dart';

void main() {
  test('same seed generates byte-identical complete JSON', () {
    final GlossDamageIndicatorsDoc current =
        buildDefaultGlossDamageIndicators();
    final GlossDamageIndicatorsDoc first = buildRandomDamageIndicatorsShowcase(
      current,
      math.Random(81),
    );
    final GlossDamageIndicatorsDoc repeated =
        buildRandomDamageIndicatorsShowcase(current, math.Random(81));
    final GlossDamageIndicatorsDoc different =
        buildRandomDamageIndicatorsShowcase(current, math.Random(82));
    final String firstJson = encodeGlossDamageIndicatorsDoc(first);

    expect(encodeGlossDamageIndicatorsDoc(repeated), firstJson);
    expect(encodeGlossDamageIndicatorsDoc(different), isNot(firstJson));
    expect(jsonDecode(firstJson), <String, Object?>{
      'schemaVersion': glossDamageIndicatorsCurrentSchemaVersion,
      'revision': current.revision,
      'limits': first.limits.toJson(),
      'damage': first.damage.toJson(),
      'healing': first.healing.toJson(),
      'audience': first.audience.toJson(),
    });
    expect(
      encodeGlossDamageIndicatorsDoc(decodeGlossDamageIndicatorsDoc(firstJson)),
      firstJson,
    );
  });

  test('generated profiles remain valid and inside practical safe bands', () {
    final GlossDamageIndicatorsDoc current = buildDefaultGlossDamageIndicators()
      ..revision = 19;
    for (int seed = 0; seed < 512; seed++) {
      final GlossDamageIndicatorsDoc doc = buildRandomDamageIndicatorsShowcase(
        current,
        math.Random(seed),
      );
      final List<HuiIssue> issues = validateDamageIndicatorsDoc(doc);

      expect(issues, isEmpty, reason: 'seed $seed');
      expect(doc.schemaVersion, glossDamageIndicatorsCurrentSchemaVersion);
      expect(doc.revision, current.revision);
      expect(doc.limits.maxPerSecond, inInclusiveRange(16, 120));
      expect(doc.limits.lifetimeMs, inInclusiveRange(750, 4500));
      expect(doc.limits.minimumDelta, inInclusiveRange(0, 1));
      expect(doc.limits.decimals, inInclusiveRange(0, 4));
      _expectSafeStyle(doc.damage, healing: false, seed: seed);
      _expectSafeStyle(doc.healing, healing: true, seed: seed);
      expect(doc.audience.when, isNotEmpty);
      final ({bool matches, String? error}) audience = glossConditionMatches(
        doc.audience.when,
        buildDamageIndicatorPreviewConditionContext(
          kind: DamageIndicatorPreviewKind.damage,
          amount: 7,
          includeViewer: true,
        ),
      );
      expect(audience.error, isNull, reason: 'seed $seed');
      expect(audience.matches, isTrue, reason: 'seed $seed');
    }
  });

  test('generation varies every settings group across seeds', () {
    final GlossDamageIndicatorsDoc current =
        buildDefaultGlossDamageIndicators();
    final Set<int> admissionLimits = <int>{};
    final Set<int> lifetimes = <int>{};
    final Set<double> minimumDeltas = <double>{};
    final Set<int> decimalCounts = <int>{};
    final Set<String> damageFormats = <String>{};
    final Set<String> healingFormats = <String>{};
    final Set<String> damageOffsets = <String>{};
    final Set<String> healingOffsets = <String>{};
    final Set<String> damageMotion = <String>{};
    final Set<String> healingMotion = <String>{};
    final Set<String> damagePresentation = <String>{};
    final Set<String> healingPresentation = <String>{};
    final Set<String> audiences = <String>{};
    final Set<String> documents = <String>{};

    for (int seed = 0; seed < 256; seed++) {
      final GlossDamageIndicatorsDoc doc = buildRandomDamageIndicatorsShowcase(
        current,
        math.Random(seed),
      );
      admissionLimits.add(doc.limits.maxPerSecond);
      lifetimes.add(doc.limits.lifetimeMs);
      minimumDeltas.add(doc.limits.minimumDelta);
      decimalCounts.add(doc.limits.decimals);
      damageFormats.add(doc.damage.presentation.format);
      healingFormats.add(doc.healing.presentation.format);
      damageOffsets.add(jsonEncode(doc.damage.presentation.offset.toJson()));
      healingOffsets.add(jsonEncode(doc.healing.presentation.offset.toJson()));
      damageMotion.add(jsonEncode(doc.damage.presentation.motion.toJson()));
      healingMotion.add(jsonEncode(doc.healing.presentation.motion.toJson()));
      damagePresentation.add(jsonEncode(doc.damage.presentation.toJson()));
      healingPresentation.add(jsonEncode(doc.healing.presentation.toJson()));
      audiences.add(doc.audience.when);
      documents.add(encodeGlossDamageIndicatorsDoc(doc));
    }

    expect(admissionLimits.length, greaterThan(70));
    expect(lifetimes.length, greaterThan(60));
    expect(minimumDeltas.length, greaterThan(7));
    expect(decimalCounts, <int>{0, 1, 2, 3, 4});
    expect(damageFormats.length, greaterThan(5));
    expect(healingFormats.length, greaterThan(5));
    expect(damageOffsets.length, greaterThan(240));
    expect(healingOffsets.length, greaterThan(240));
    expect(damageMotion.length, greaterThan(240));
    expect(healingMotion.length, greaterThan(240));
    expect(damagePresentation.length, greaterThan(240));
    expect(healingPresentation.length, greaterThan(240));
    expect(audiences.length, greaterThanOrEqualTo(3));
    expect(documents.length, greaterThan(250));
  });
}

void _expectSafeStyle(
  GlossDamageIndicatorStyle style, {
  required bool healing,
  required int seed,
}) {
  final GlossDamageIndicatorPresentation presentation = style.presentation;
  expect(
    style.when,
    healing ? 'event.healing' : 'event.damage',
    reason: 'seed $seed',
  );
  expect(
    presentation.format,
    contains(glossDamageAmountToken),
    reason: 'seed $seed',
  );
  expect(presentation.offset.x, inInclusiveRange(-0.45, 0.45));
  expect(
    presentation.offset.y,
    healing ? inInclusiveRange(-0.25, 0.9) : inInclusiveRange(0.35, 1.4),
  );
  expect(presentation.offset.z, inInclusiveRange(-0.45, 0.45));
  expect(
    presentation.motion.horizontalSpeed,
    healing ? inInclusiveRange(0.15, 1.8) : inInclusiveRange(0.35, 2.4),
  );
  expect(
    presentation.motion.verticalSpeed,
    healing ? inInclusiveRange(0.25, 2.4) : inInclusiveRange(0.7, 3.4),
  );
  expect(
    presentation.motion.verticalAcceleration,
    healing ? inInclusiveRange(-1.5, 1) : inInclusiveRange(-4, -0.25),
  );
  expect(presentation.motion.spinDegreesPerSecond, inInclusiveRange(-360, 360));
  expect(presentation.transform.startScale, inInclusiveRange(0.65, 1.8));
  expect(presentation.transform.endScale, inInclusiveRange(0.4, 2.49));
  expect(
    presentation.transform.fadeStartFraction,
    inInclusiveRange(0.42, 0.86),
  );
  expect(style.variants, hasLength(1), reason: 'seed $seed');
  final GlossDamageIndicatorVariant variant = style.variants.single;
  expect(variant.id, healing ? 'large-heal' : 'critical-hit');
  expect(
    variant.when,
    healing ? 'event.amount >= 8' : 'event.criticalKnown && event.critical',
  );
  expect(variant.presentation.format, contains(glossDamageAmountToken));
  expect(variant.presentation.offset.x, inInclusiveRange(-0.45, 0.45));
  expect(variant.presentation.offset.y, inInclusiveRange(-0.13, 1.52));
  expect(variant.presentation.offset.z, inInclusiveRange(-0.45, 0.45));
  expect(
    variant.presentation.motion.horizontalSpeed,
    inInclusiveRange(0.18, 2.88),
  );
  expect(
    variant.presentation.motion.verticalSpeed,
    inInclusiveRange(0.29, 3.91),
  );
  expect(
    variant.presentation.motion.spinDegreesPerSecond,
    anyOf(-360, -240, 240, 360),
  );
  expect(
    variant.presentation.transform.startScale,
    inInclusiveRange(0.81, 2.25),
  );
  expect(variant.presentation.transform.endScale, inInclusiveRange(0.46, 2.8));
  expect(
    variant.presentation.transform.fadeStartFraction,
    inInclusiveRange(0.5, 0.86),
  );
}
