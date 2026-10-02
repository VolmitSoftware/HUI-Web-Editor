import 'package:gloss_editor/logic/bubble_preview.dart';
import 'package:gloss_editor/logic/bubble_validation.dart';
import 'package:gloss_editor/logic/damage_indicator_validation.dart';
import 'package:gloss_editor/logic/particle_layer_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('document settings survive typed copies and serialization', () {
    final GlossBubbleStyleDoc bubbles = GlossBubbleStyleDoc(
      stackDistance: 0.7,
      maxPerSender: 9,
      blacklistWorlds: <String>['lobby'],
      format: '[{message}]',
    ).copy();
    expect(bubbles.toJson(), containsPair('stackDistance', 0.7));
    expect(bubbles.toJson(), containsPair('maxPerSender', 9));
    expect(
      bubbles.toJson(),
      containsPair('blacklistWorlds', <String>['lobby']),
    );
    expect(bubbles.toJson(), containsPair('format', '[{message}]'));
    final GlossHologramDoc hologram = GlossHologramDoc(
      viewDistance: 64,
      refreshTicks: 30,
    ).copy();
    expect(hologram.toJson(), containsPair('viewDistance', 64));
    expect(hologram.toJson(), containsPair('refreshTicks', 30));
    final HuiPreviewDoc preview = HuiPreviewDoc.fromJson(
      HuiPreviewDoc(scale: 1.4, viewDistance: 20).copy().toJson(),
    );
    expect(preview.scale, 1.4);
    expect(preview.viewDistance, 20);
    final GlossDamageIndicatorLimits limits = GlossDamageIndicatorLimits(
      viewRange: 64,
      debounceMs: 400,
    ).copy();
    expect(limits.viewRange, 64);
    expect(limits.debounceMs, 400);
    final GlossRealDropLabels labels = GlossRealDropLabels(
      show: false,
      preserveCustomNames: false,
    ).copy();
    expect(labels.show, false);
    expect(labels.preserveCustomNames, false);
    final GlossParticleLayer layer = GlossParticleLayer(
      id: 'sparkles',
      viewDistance: 64,
      show: 'viewer.health > 10',
      particle: GlossParticleSpec(
        count: 5,
        spread: Vec3(0.1, 0.2, 0.3),
        speed: 0.5,
      ),
    ).copy();
    final GlossParticleLayer decoded = GlossParticleLayer.fromJson(
      layer.toJson(),
      0,
    );
    expect(decoded.viewDistance, 64);
    expect(decoded.show, 'viewer.health > 10');
    expect(decoded.particle.count, 5);
    expect(decoded.particle.spread, Vec3(0.1, 0.2, 0.3));
    expect(decoded.particle.speed, 0.5);
  });

  test('bubble preview uses document cap, spacing and message format', () {
    final GlossBubbleStyleDoc doc = GlossBubbleStyleDoc(
      wordWrapChars: 128,
      maxAliveMs: 60000,
      maxPerSender: 2,
      stackDistance: 0.75,
      format: 'Notice: {message}',
    );
    final List<GlossBubblePreviewBubble> bubbles = GlossBubblePreviewTimeline(
      doc,
    ).bubblesAt(9000);
    expect(bubbles, hasLength(2));
    expect(bubbles.last.text, startsWith('Notice: '));
    expect(bubbles.last.stackY, 0);
    expect(bubbles.first.stackY, bubbles.last.lineCount * 0.75);
  });

  test('invalid settings report their exact document paths', () {
    expect(
      validateBubbleStyleDoc(
        GlossBubbleStyleDoc(stackDistance: 4, maxPerSender: 90),
      ).map((issue) => issue.path),
      containsAll(<String>[r'$.stackDistance', r'$.maxPerSender']),
    );
    expect(
      validateDamageIndicatorsDoc(
        GlossDamageIndicatorsDoc(
          limits: GlossDamageIndicatorLimits(viewRange: 500, debounceMs: -1),
        ),
      ).map((issue) => issue.path),
      containsAll(<String>[r'$.limits.viewRange', r'$.limits.debounceMs']),
    );
    expect(
      validateParticleLayers(<GlossParticleLayer>[
        GlossParticleLayer(
          id: 'test',
          particle: GlossParticleSpec(
            count: 0,
            speed: 11,
            spread: Vec3(-1, 0, 0),
          ),
        ),
      ]).map((issue) => issue.path),
      containsAll(<String>[
        'particleLayers[0].particle.count',
        'particleLayers[0].particle.speed',
        'particleLayers[0].particle.spread[0]',
      ]),
    );
  });
}
