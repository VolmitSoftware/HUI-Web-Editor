library;

import 'dart:math' as math;

import '../l10n/hui_localizations.dart';
import '../model/gloss_entity_overlays.dart';

final class EntityOverlaySample {
  const EntityOverlaySample({
    this.name = 'Sample sentinel',
    this.entityType = 'ZOMBIE',
    this.world = 'world',
    this.health = 14,
    this.maxHealth = 20,
    this.attack = 3,
    this.armor = 2,
    this.distance = 6,
    this.damage = 0,
    this.sinceHitMs = 0,
    this.player = false,
    this.react = false,
    this.stackCount = 4,
    this.adapt = false,
    this.insight = false,
    this.adaptExclusive = false,
  });

  final String name;
  final String entityType;
  final String world;
  final double health;
  final double maxHealth;
  final double attack;
  final double armor;
  final double distance;
  final double damage;
  final int sinceHitMs;
  final bool player;
  final bool react;
  final int stackCount;
  final bool adapt;
  final bool insight;
  final bool adaptExclusive;
}

final class EntityOverlayPreview {
  const EntityOverlayPreview({required this.lines, this.hiddenReason});

  final List<String> lines;
  final String? hiddenReason;
  bool get visible => hiddenReason == null;
}

EntityOverlayPreview resolveEntityOverlayPreview(
  GlossEntityOverlaysDoc doc,
  EntityOverlaySample sample,
) {
  final String? hiddenReason = _hiddenReason(doc, sample);
  if (hiddenReason != null) {
    return EntityOverlayPreview(
      lines: const <String>[],
      hiddenReason: hiddenReason,
    );
  }
  final bool hit =
      sample.damage > 0 &&
      sample.sinceHitMs < doc.hitHighlightMs.clamp(0, 10000);
  final Map<String, String> tokens = <String, String>{
    'name': sample.name,
    'bar': _bar(doc, sample, hit),
    'health': _number(sample.health.clamp(0, sample.maxHealth)),
    'max_health': _number(sample.maxHealth),
    'count': sample.stackCount.clamp(1, 2147483647).toString(),
    'attack': _number(sample.attack),
    'armor': _number(sample.armor),
    'damage': _number(sample.damage),
  };
  final String stack = sample.react && sample.stackCount > 1
      ? _format(doc.stackFormat, tokens)
      : '';
  final bool named = doc.showNames && sample.name.trim().isNotEmpty;
  final List<String> lines = <String>[
    if (named) '${_format(doc.nameFormat, tokens)}$stack',
    '${doc.showHealthNumbers ? _format(doc.healthFormat, tokens) : tokens['bar']}${named ? '' : stack}',
    if (hit && doc.damageFormat.trim().isNotEmpty)
      _format(doc.damageFormat, tokens),
    if (sample.adapt && sample.insight) ...<String>[
      '&b${sample.player ? 'Player' : 'Zombie'}',
      '&7Speed &f0.23 &8| &7Jump &f0.42',
      '&7Toughness &f0 &8| &7Knockback resistance &f0 &8| &7Detection range &f35',
    ],
    if (doc.showCombatStats && doc.statsFormat.trim().isNotEmpty)
      _format(doc.statsFormat, tokens),
  ];
  return EntityOverlayPreview(lines: lines);
}

String? _hiddenReason(GlossEntityOverlaysDoc doc, EntityOverlaySample sample) {
  if (!doc.enabled) return huiText('Entity overlays are disabled.');
  if (!sample.maxHealth.isFinite ||
      sample.maxHealth <= 0 ||
      !sample.health.isFinite ||
      sample.health <= 0) {
    return huiText('The sample entity is no longer alive.');
  }
  if (sample.distance > doc.range.clamp(1, 64) &&
      !(sample.adapt && sample.insight)) {
    return huiText('The sample entity is outside the display range.');
  }
  if (sample.player && !doc.includePlayers) {
    return huiText('Player overlays are disabled.');
  }
  if (doc.blacklistWorlds.contains(sample.world)) {
    return huiText('The sample world is excluded.');
  }
  if (doc.excludedEntityTypes.any(
    (String type) => type.toUpperCase() == sample.entityType.toUpperCase(),
  )) {
    return huiText('The sample entity type is excluded.');
  }
  if (sample.adapt && sample.adaptExclusive && !sample.insight) {
    return huiText('Adapt exclusive mode requires an active Insight target.');
  }
  return null;
}

String _bar(GlossEntityOverlaysDoc doc, EntityOverlaySample sample, bool hit) {
  final int segments = doc.healthSegments.clamp(1, 40);
  final double ratio = (sample.health / sample.maxHealth).clamp(0, 1);
  final int filled = (ratio * segments).ceil();
  final int previous = hit
      ? math.min(
          segments,
          ((sample.health + sample.damage) / sample.maxHealth * segments)
              .ceil(),
        )
      : filled;
  final String color = ratio >= 0.5
      ? '&a'
      : ratio >= 0.25
      ? '&e'
      : '&c';
  return '$color${'|' * filled}&c${'|' * math.max(0, previous - filled)}&8${'|' * (segments - math.max(filled, previous))}';
}

String _format(String source, Map<String, String> tokens) =>
    source.replaceAllMapped(
      RegExp(r'\{([a-z_]+)\}'),
      (Match match) => tokens[match.group(1)] ?? match.group(0)!,
    );

String _number(double value) =>
    value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
