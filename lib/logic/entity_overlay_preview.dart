library;

import 'gloss_show.dart';
import 'dart:math' as math;

import '../l10n/hui_localizations.dart';
import '../model/gloss_entity_overlays.dart';
import '../model/preview_doc.dart';
import 'gloss_particle_text.dart';
import 'gloss_text.dart';
import 'mc_text.dart';
import 'preview_expr.dart';

const List<String> entityOverlayVariables = <String>[
  'entity.health',
  'entity.maxHealth',
  'entity.healthPercent',
  'entity.name',
  'entity.named',
  'entity.type',
  'entity.damage',
  'entity.damaged',
  'entity.attack',
  'entity.armor',
  'entity.stackCount',
  'entity.distance',
  'insight.active',
];

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
    this.insightDetails,
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
  final List<String>? insightDetails;
}

final class EntityOverlayPreview {
  const EntityOverlayPreview({
    required this.rows,
    this.hiddenReason,
    this.errors = const <String>[],
  });

  final List<GlossLineRender> rows;
  final String? hiddenReason;
  final List<String> errors;
  List<String> get lines => <String>[
    for (final GlossLineRender row in rows) row.plainText,
  ];
  bool get visible => hiddenReason == null;

  GlossParticleTextRendered get particleText {
    final StringBuffer text = StringBuffer();
    final List<GlossParticleTextSpan> spans = <GlossParticleTextSpan>[];
    for (int index = 0; index < rows.length; index++) {
      final GlossLineRender row = rows[index];
      if (index > 0) text.write('\n');
      final int offset = text.length;
      text.write(row.plainText);
      spans.addAll(<GlossParticleTextSpan>[
        for (final GlossParticleTextSpan span in row.particleSpans)
          GlossParticleTextSpan(
            name: span.name,
            start: span.start + offset,
            end: span.end + offset,
          ),
      ]);
    }
    return GlossParticleTextRendered(text: text.toString(), spans: spans);
  }
}

GlossTextExpressionSamples entityOverlayExpressionSamples(
  GlossEntityOverlaysDoc doc,
  EntityOverlaySample sample,
) {
  final bool hit =
      sample.damage > 0 &&
      sample.sinceHitMs < doc.hitHighlightMs.clamp(0, 10000);
  return GlossTextExpressionSamples(
    values: <String, Object>{
      'entity.health': sample.health.clamp(0, sample.maxHealth),
      'entity.maxHealth': sample.maxHealth,
      'entity.healthPercent': (sample.health / sample.maxHealth * 100).clamp(
        0,
        100,
      ),
      'entity.name': sample.name,
      'entity.named': sample.name.trim().isNotEmpty,
      'entity.type': sample.entityType.toLowerCase(),
      'entity.damage': hit ? sample.damage : 0.0,
      'entity.damaged': hit,
      'entity.attack': sample.attack,
      'entity.armor': sample.armor,
      'entity.stackCount': sample.react
          ? sample.stackCount.clamp(1, 2147483647).toDouble()
          : 1.0,
      'entity.distance': sample.distance,
      'world.name': sample.world,
      'world.time': 6000.0,
      'insight.active':
          sample.adapt &&
          sample.insight &&
          (sample.insightDetails == null || sample.insightDetails!.isNotEmpty),
    },
  );
}

EntityOverlayPreview resolveEntityOverlayPreview(
  GlossEntityOverlaysDoc doc,
  EntityOverlaySample sample, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
}) {
  final String? hidden = _hiddenReason(doc, sample);
  if (hidden != null) {
    return EntityOverlayPreview(
      rows: const <GlossLineRender>[],
      hiddenReason: hidden,
    );
  }
  final GlossTextExpressionSamples samples = entityOverlayExpressionSamples(
    doc,
    sample,
  );
  final GlossTextExpressionScope scope = GlossTextExpressionScope(
    nowMs,
    samples,
  );
  final List<String> errors = <String>[];
  if (!_shown(doc.show, scope, errors)) {
    return EntityOverlayPreview(
      rows: const <GlossLineRender>[],
      hiddenReason: huiText('The pane visibility expression is false.'),
      errors: errors,
    );
  }
  final bool hit = samples.values['entity.damaged']! as bool;
  final Map<String, String> tokens = <String, String>{
    'bar': _bar(doc, sample, hit),
    'health': _number(sample.health.clamp(0, sample.maxHealth)),
    'max_health': _number(sample.maxHealth),
    'count': _number(samples.values['entity.stackCount']! as double),
    'attack': _number(sample.attack),
    'armor': _number(sample.armor),
    'damage': _number(hit ? sample.damage : 0),
    'type': sample.entityType.toLowerCase(),
    'distance': _number(sample.distance),
  };
  final List<String> details = sample.adapt && sample.insight
      ? sample.insightDetails ??
            <String>[
              '&b${sample.player ? 'Player' : sample.entityType.toLowerCase().split('_').map((String part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ')}',
              '&7Speed &f0.23 &8| &7Jump &f0.42',
              '&7Toughness &f0 &8| &7Knockback resistance &f0 &8| &7Detection range &f35',
            ]
      : const <String>[];
  final List<GlossLineRender> rows = <GlossLineRender>[];
  for (final GlossEntityOverlayLine line in doc.lines) {
    if (!_shown(line.show, scope, errors)) continue;
    if (line.type == 'spacer') {
      rows.add(renderGlossLine(' '));
      continue;
    }
    final List<String> values = line.type == 'insight'
        ? details
        : const <String>[''];
    for (final String detail in values) {
      final Map<String, String> literals = <String, String>{};
      final Map<String, String> markers = <String, String>{};
      final String template = _format(line.text, <String, String>{
        ...tokens,
        'name': _protectLiteral(sample.name, literals, markers),
        'insight': _protectLiteral(detail, literals, markers),
      });
      final GlossLineRender pipeline = renderGlossLine(
        template,
        animations: animations,
        emoji: emoji,
        nowMs: nowMs,
        expressionSamples: samples,
        expressionLiteralEncoder: (String value) =>
            _protectLiteral(value, literals, markers),
      );
      errors.addAll(pipeline.expressionErrors);
      if (pipeline.particleSpanError != null) {
        errors.add(pipeline.particleSpanError!);
      }
      final GlossLineRender result = _richLine(pipeline, literals);
      rows.add(result);
    }
  }
  if (rows.isEmpty ||
      rows.every((GlossLineRender row) => row.plainText.trim().isEmpty)) {
    return EntityOverlayPreview(
      rows: rows,
      hiddenReason: huiText('No lines are visible for this sample.'),
      errors: errors,
    );
  }
  return EntityOverlayPreview(rows: rows, errors: errors);
}

bool _shown(Object? raw, PExprScope scope, List<String> errors) {
  if (raw == null) return true;
  if (raw is bool) return raw;
  if (raw is! String) {
    errors.add('Expected a boolean or expression string');
    return false;
  }
  try {
    return evalBool(
      parsePreviewExpr(previewShowExpression(raw)! as String),
      GlossShowScope(scope: scope),
    );
  } on PExprException catch (error) {
    errors.add(error.message);
    return false;
  }
}

String _protectLiteral(
  String raw,
  Map<String, String> literals,
  Map<String, String> markers,
) {
  final StringBuffer output = StringBuffer();
  String formatting = '';
  int index = 0;
  final RegExp code = RegExp(
    r'(?:[&§]x(?:[&§][0-9a-fA-F]){6}|[&§][0-9a-fA-Fk-oK-OrR]|\[[0-9a-fA-F]{6}\])',
  );
  while (index < raw.length) {
    final Match? color = code.matchAsPrefix(raw, index);
    if (color != null) {
      final String source = color.group(0)!;
      if (source.startsWith('[') ||
          '0123456789abcdefrx'.contains(source[1].toLowerCase())) {
        formatting = source;
      } else {
        formatting += source;
      }
      index = color.end;
      continue;
    }
    final bool pair =
        raw.codeUnitAt(index) >= 0xD800 &&
        raw.codeUnitAt(index) <= 0xDBFF &&
        index + 1 < raw.length;
    final int length = pair ? 2 : 1;
    final String character = raw.substring(index, index + length);
    final String value = '$formatting$character';
    final String marker = markers.putIfAbsent(value, () {
      final String next = String.fromCharCode(0xE000 + markers.length);
      literals[next] = value;
      return next;
    });
    output.write(marker);
    index += length;
  }
  return output.toString();
}

GlossLineRender _richLine(
  GlossLineRender pipeline,
  Map<String, String> literals,
) {
  final McTextResult parsed = parseMcText(pipeline.renderedText);
  final List<GlossTextPiece> pieces = <GlossTextPiece>[];
  for (int row = 0; row < parsed.lines.length; row++) {
    if (row > 0) pieces.add(const GlossTextRun(McSpan(text: '\n')));
    for (final McSpan span in parsed.lines[row]) {
      int offset = 0;
      final RegExp markers = RegExp('[\uE000-\uEFFF]');
      for (final Match match in markers.allMatches(span.text)) {
        if (match.start > offset) {
          pieces.add(
            GlossTextRun(
              span.withText(span.text.substring(offset, match.start)),
            ),
          );
        }
        pieces.addAll(<GlossTextPiece>[
          for (final McSpan literal in renderGlossLiteralSpans(
            literals[match.group(0)] ?? '',
            initial: span,
          ))
            GlossTextRun(literal),
        ]);
        offset = match.end;
      }
      if (offset < span.text.length) {
        pieces.add(GlossTextRun(span.withText(span.text.substring(offset))));
      }
    }
  }
  String plainPrefix(int end) {
    String source = pipeline.renderedText.substring(
      0,
      end.clamp(0, pipeline.renderedText.length),
    );
    final String plain = parseMcText(source).plainText;
    return literals.entries.fold(
      plain,
      (String value, MapEntry<String, String> literal) => value.replaceAll(
        literal.key,
        renderGlossLiteralSpans(
          literal.value,
        ).map((McSpan span) => span.text).join(),
      ),
    );
  }

  final String plain = pieces
      .whereType<GlossTextRun>()
      .map((GlossTextRun run) => run.span.text)
      .join();
  return GlossLineRender(
    pieces: pieces,
    usedAnimations: pipeline.usedAnimations,
    missingAnimations: pipeline.missingAnimations,
    placeholders: pipeline.placeholders,
    metrics: pipeline.metrics,
    expressions: pipeline.expressions,
    expressionErrors: <String>[
      ...pipeline.expressionErrors,
      ...parsed.warnings,
    ],
    renderedText: plain,
    particleSpans: <GlossParticleTextSpan>[
      for (final GlossParticleTextSpan span in pipeline.particleSpans)
        GlossParticleTextSpan(
          name: span.name,
          start: plainPrefix(span.start).length,
          end: plainPrefix(span.end).length,
        ),
    ],
    particleSpanError: pipeline.particleSpanError,
  );
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
      RegExp(r'(?<!\{)\{([a-z_]+)\}(?!\})'),
      (Match match) => tokens[match.group(1)] ?? match.group(0)!,
    );

String _number(double value) =>
    value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
