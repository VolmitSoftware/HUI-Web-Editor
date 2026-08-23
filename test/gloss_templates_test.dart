/// Gloss-kind starter templates: shipped copies stay byte-identical to the
/// plugin resources (the same bar `preview_templates_test.dart` holds the
/// thirteen preview cards to), and every template builds clean.
library;

import 'dart:io';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/animation_validation.dart';
import 'package:gloss_editor/logic/bubble_validation.dart';
import 'package:gloss_editor/logic/emoji_validation.dart';
import 'package:gloss_editor/logic/hologram_validation.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/mc_text.dart';
import 'package:gloss_editor/logic/motd_validation.dart';
import 'package:gloss_editor/logic/scoreboard_validation.dart';
import 'package:gloss_editor/logic/tablist_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

final class _Animations implements GlossAnimationResolver {
  final GlossAnimationDoc rainbow = buildRainbowGlossAnimation();

  @override
  List<String> get ids => <String>['rainbow'];

  @override
  GlossAnimationDoc? byId(String id) => id == 'rainbow' ? rainbow : null;
}

void main() {
  group('hologram blank stays the plugin baseline', () {
    test('embedded copy matches the fixture and the plugin resource', () {
      final String fixture = File(
        'test/fixtures/gloss/hologram.json',
      ).readAsStringSync();
      expect(kGlossHologramBaselineJson, fixture);
      final File plugin = File(
        glossRepositoryFilePath('src/main/resources/baselines/hologram.json'),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossHologramBaselineJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean', () {
      final GlossHologramDoc first = buildBlankGlossHologram();
      final GlossHologramDoc second = buildBlankGlossHologram();
      expect(identical(first, second), isFalse);
      expect(first.revision, 1);
      expect(first.anchor.world, 'world');
      expect(first.lines, <String>['&dNew hologram']);
      expect(first.seeThrough, isTrue);
      expect(validateHologramDoc(first), isEmpty);
    });
  });

  group('real drops stay the shipped default', () {
    test('embedded copy matches the plugin resource', () {
      final File plugin = File(
        glossRepositoryFilePath(
          'src/main/resources/defaults/real-drops/default.json',
        ),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossRealDropsDefaultJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean', () {
      final GlossRealDropSettingsDoc first = buildDefaultGlossRealDrops();
      final GlossRealDropSettingsDoc second = buildDefaultGlossRealDrops();
      expect(identical(first, second), isFalse);
      expect(first.motion.speedMultiplier, 1.35);
      expect(first.labels.seeThrough, isTrue);
      expect(first.limits.updateIntervalTicks, 2);
      expect(first.filters.materialBlacklist, <String>['BEDROCK', 'BARRIER']);
    });
  });

  group('animation rainbow stays the shipped default', () {
    test('embedded copy matches the fixture and the plugin resource', () {
      final String fixture = File(
        'test/fixtures/gloss/rainbow.json',
      ).readAsStringSync();
      expect(kGlossAnimationRainbowJson, fixture);
      final File plugin = File(
        glossRepositoryFilePath(
          'src/main/resources/defaults/animations/rainbow.json',
        ),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossAnimationRainbowJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean', () {
      final GlossAnimationDoc first = buildRainbowGlossAnimation();
      final GlossAnimationDoc second = buildRainbowGlossAnimation();
      expect(identical(first, second), isFalse);
      expect(first.mode, 'ascend');
      expect(first.frameIntervalMs, 53);
      expect(first.frames, hasLength(60));
      expect(first.frames.toSet(), hasLength(60));
      for (int index = 0; index < first.frames.length; index++) {
        final int current = int.parse(
          first.frames[index].substring(1, 7),
          radix: 16,
        );
        final int next = int.parse(
          first.frames[(index + 1) % first.frames.length].substring(1, 7),
          radix: 16,
        );
        for (final int shift in <int>[16, 8, 0]) {
          final int delta =
              (((current >> shift) & 0xFF) - ((next >> shift) & 0xFF)).abs();
          expect(delta, lessThanOrEqualTo(26));
        }
      }
      expect(validateAnimationDoc(first), isEmpty);
    });
  });

  test('effect animation templates match every shipped plugin document', () {
    for (final MapEntry<String, GlossAnimationDoc Function()> entry
        in shippedGlossAnimationBuilders.entries.where(
          (MapEntry<String, GlossAnimationDoc Function()> entry) =>
              entry.key != 'rainbow',
        )) {
      final File plugin = File(
        glossRepositoryFilePath(
          'src/main/resources/defaults/animations/${entry.key}.json',
        ),
      );
      expect(plugin.existsSync(), isTrue, reason: entry.key);
      final GlossAnimationDoc shipped = decodeGlossAnimationDoc(
        plugin.readAsStringSync(),
      );
      final GlossAnimationDoc built = entry.value();
      expect(built.toJson(), shipped.toJson(), reason: entry.key);
      expect(validateAnimationDoc(built), isEmpty, reason: entry.key);
      final List<GlossLineRender> renders = <GlossLineRender>[
        for (final int nowMs in <int>[0, 2000, 4000])
          renderGlossAnimationFramePreview(built.frames.single, nowMs: nowMs),
      ];
      for (final GlossLineRender render in renders) {
        expect(render.plainText, isNot(contains('{{')), reason: entry.key);
      }
      expect(
        renders.map(_renderSignature).toSet(),
        hasLength(greaterThan(1)),
        reason: entry.key,
      );
    }
  });

  test('the blank animation is the smallest file Gloss accepts', () {
    final GlossAnimationDoc doc = buildBlankGlossAnimation();
    expect(doc.frames, hasLength(1));
    expect(validateAnimationDoc(doc), isEmpty);
  });

  test('the showcase builds without errors', () {
    final GlossHologramDoc doc = buildShowcaseGlossHologram();
    expect(doc.lines, hasLength(6));
    expect(doc.lines.join('\n'), contains('{{ player.name }}'));
    expect(doc.lines.join('\n'), contains('server.tps'));
    expect(doc.lines.join('\n'), contains("papi('vault_prefix',"));
    final List<HuiIssue> issues = validateHologramDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
    // The |animation.rainbow| line warns until the workspace has that
    // animation document — deliberate: the template teaches the reference.
    expect(
      issues.any(
        (HuiIssue issue) => issue.message.contains('animation.rainbow'),
      ),
      isTrue,
    );
  });

  group('scoreboard default stays the shipped default', () {
    test('embedded copy matches the fixture and the plugin resource', () {
      final String fixture = File(
        'test/fixtures/gloss/board-default.json',
      ).readAsStringSync();
      expect(kGlossScoreboardDefaultJson, fixture);
      final File plugin = File(
        glossRepositoryFilePath(
          'src/main/resources/defaults/boards/default.json',
        ),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossScoreboardDefaultJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean', () {
      final GlossScoreboardDoc first = buildDefaultGlossScoreboard();
      final GlossScoreboardDoc second = buildDefaultGlossScoreboard();
      expect(identical(first, second), isFalse);
      expect(first.title, '&d&lGloss');
      expect(first.lines, hasLength(3));
      expect(
        first.primary,
        isFalse,
        reason: 'the shipped default never forces a sidebar',
      );
      expect(first.permission, 'default');
      expect(validateScoreboardDoc(first), isEmpty);
      for (final String line in first.lines) {
        expect(
          measureGlossScoreboardLine(line, _Animations()).truncated,
          isFalse,
          reason: line,
        );
      }
    });
  });

  group('motd default stays the shipped default', () {
    test('embedded copy matches the fixture and the plugin resource', () {
      final String fixture = File(
        'test/fixtures/gloss/motd.json',
      ).readAsStringSync();
      expect(kGlossMotdDefaultJson, fixture);
      final File plugin = File(
        glossRepositoryFilePath('src/main/resources/defaults/motd/motd.json'),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossMotdDefaultJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean', () {
      final GlossMotdDoc first = buildDefaultGlossMotd();
      final GlossMotdDoc second = buildDefaultGlossMotd();
      expect(identical(first, second), isFalse);
      expect(first.revision, 1);
      expect(first.entries, hasLength(1));
      expect(first.entries.single.lines, <String>['&dA glossy server']);
      expect(validateMotdDoc(first), isEmpty);
    });
  });

  test('the motd showcase builds without errors', () {
    final GlossMotdDoc doc = buildShowcaseGlossMotd();
    expect(doc.entries, hasLength(4));
    expect(
      doc.entries.first.lines.any(
        (String line) => renderGlossLine(line).isAnimated,
      ),
      isTrue,
      reason: 'the initially previewed entry should demonstrate animation',
    );
    final List<HuiIssue> issues = validateMotdDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
    // Same teaching reference as the hologram and scoreboard showcases.
    expect(
      issues.any(
        (HuiIssue issue) => issue.message.contains('animation.rainbow'),
      ),
      isTrue,
    );
  });

  group('emoji heart stays the shipped default', () {
    test('embedded copy matches the fixture and the plugin resource', () {
      final String fixture = File(
        'test/fixtures/gloss/emoji-heart.json',
      ).readAsStringSync();
      expect(kGlossEmojiHeartJson, fixture);
      final File plugin = File(
        glossRepositoryFilePath('src/main/resources/defaults/emoji/heart.json'),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossEmojiHeartJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean', () {
      final GlossEmojiDoc first = buildHeartGlossEmoji();
      final GlossEmojiDoc second = buildHeartGlossEmoji();
      expect(identical(first, second), isFalse);
      expect(first.trigger, '<3');
      expect(first.emoji, 'U+2764;');
      expect(first.resolvedGlyph, '❤');
      expect(first.enabled, isTrue);
      expect(validateEmojiDoc(first), isEmpty);
    });
  });

  test('the blank emoji opens valid — an empty value would be rejected', () {
    final GlossEmojiDoc doc = buildBlankGlossEmoji();
    expect(doc.trigger, isEmpty);
    expect(doc.resolvedGlyph, '✨');
    expect(validateEmojiDoc(doc), isEmpty);
  });

  group('bubble default stays the shipped default', () {
    test('embedded copy matches the fixture and the plugin resource', () {
      final String fixture = File(
        'test/fixtures/gloss/bubbles-default.json',
      ).readAsStringSync();
      expect(kGlossBubbleDefaultJson, fixture);
      final File plugin = File(
        glossRepositoryFilePath(
          'src/main/resources/defaults/bubbles/default.json',
        ),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossBubbleDefaultJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean but for the '
        'no-select note', () {
      final GlossBubbleStyleDoc first = buildDefaultGlossBubbleStyle();
      final GlossBubbleStyleDoc second = buildDefaultGlossBubbleStyle();
      expect(identical(first, second), isFalse);
      expect(first.prefix, '&7');
      expect(first.offset, <double>[0, 0.3, 0]);
      expect(first.effectiveWordWrapChars, 32);
      expect(first.schemaVersion, glossBubbleCurrentSchemaVersion);
      expect(first.motion.translation.x, '0');
      expect(first.motion.translation.y, glossBubbleLegacyFlyAwayExpression);
      expect(first.motion.opacity, '1');
      expect(first.shimmer.spawn, isTrue);
      expect(first.shimmer.flyAway, isTrue);
      expect(first.shimmer.color, '#ffffff');
      expect(first.shimmer.width, 3);
      expect(first.shimmer.durationMs, glossBubbleShimmerDefaultDurationMs);
      expect(first.shimmer.spawnDelayMs, glossBubbleShimmerDefaultSpawnDelayMs);
      expect(
        first.shimmer.flyAwayLeadMs,
        glossBubbleShimmerDefaultFlyAwayLeadMs,
      );
      final List<HuiIssue> issues = validateBubbleStyleDoc(first);
      // The shipped default HAS no select — it is the fallback by name.
      expect(issues.single.severity, HuiSeverity.info);
      expect(issues.single.path, r'$.select');
    });
  });

  test('the bubble showcase builds without errors', () {
    final GlossBubbleStyleDoc doc = buildShowcaseGlossBubbleStyle();
    expect(doc.select, isNotNull);
    expect(doc.select!.priority, 10);
    expect(doc.shimmer.color, '#ff88ff');
    expect(doc.shimmer.width, 5);
    expect(
      validateBubbleStyleDoc(
        doc,
      ).where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
  });

  group('tablist default stays the shipped default', () {
    test('embedded copy matches the fixture and the plugin resource', () {
      final String fixture = File(
        'test/fixtures/gloss/tablist.json',
      ).readAsStringSync();
      expect(kGlossTablistDefaultJson, fixture);
      final File plugin = File(
        glossRepositoryFilePath(
          'src/main/resources/defaults/tablist/tablist.json',
        ),
      );
      expect(plugin.existsSync(), isTrue);
      expect(kGlossTablistDefaultJson, plugin.readAsStringSync());
    });

    test('builds a fresh model each time and validates clean', () {
      final GlossTablistDoc first = buildDefaultGlossTablist();
      final GlossTablistDoc second = buildDefaultGlossTablist();
      expect(identical(first, second), isFalse);
      expect(first.useHeaderFooter, isTrue);
      expect(first.header, '&d&lGloss');
      expect(first.footer, '&7VolmitSoftware.com');
      expect(first.groupListNames, isTrue);
      expect(first.nameFormats, <String, String>{
        'default': r'$player',
        '_op': r'&6$player',
      });
      expect(validateTablistDoc(first), isEmpty);
    });
  });

  test('the tablist showcase builds without errors', () {
    final GlossTablistDoc doc = buildShowcaseGlossTablist();
    expect(doc.nameFormats, hasLength(3));
    expect(doc.header, contains('{{ player.name }}'));
    expect(doc.footer, contains('server.tps'));
    expect(doc.header, contains("papi('vault_prefix',"));
    final List<HuiIssue> issues = validateTablistDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
    // Same teaching reference as the other showcases.
    expect(
      issues.any(
        (HuiIssue issue) => issue.message.contains('animation.rainbow'),
      ),
      isTrue,
    );
  });

  test('the scoreboard showcase builds without errors', () {
    final GlossScoreboardDoc doc = buildShowcaseGlossScoreboard();
    final _Animations animations = _Animations();
    expect(doc.lines, hasLength(13));
    expect(doc.primary, isTrue);
    expect(doc.hideNumbers, isTrue);
    expect(doc.permissionGated, isTrue);
    expect(doc.lines.join('\n'), contains('{{ player.name }}'));
    expect(doc.lines.join('\n'), contains('server.tps'));
    expect(doc.lines.join('\n'), contains("papi('vault_prefix',"));
    expect(doc.lines.join('\n'), contains("metric('react.tick-ms',"));
    final String ticker = doc.lines.singleWhere(
      (String line) => line.contains('LIVE EVENT'),
    );
    expect(ticker, contains('floor(time.seconds)'));
    expect(ticker, isNot(contains('time.seconds *')));
    const int epochMs = 1787426000000;
    expect(
      renderGlossLine(ticker, nowMs: epochMs).plainText,
      isNot(renderGlossLine(ticker, nowMs: epochMs + 1000).plainText),
    );
    final List<HuiIssue> issues = validateScoreboardDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.severity == HuiSeverity.error),
      isEmpty,
    );
    expect(
      issues.any(
        (HuiIssue issue) => issue.message.contains('animation.rainbow'),
      ),
      isFalse,
      reason:
          'scoreboard uses a compact spinner that fits the 16+16 wire budget',
    );
    for (int index = 0; index < doc.lines.length; index++) {
      final String line = doc.lines[index];
      final GlossScoreboardLineMeasure measure = measureGlossScoreboardLine(
        line,
        animations,
      );
      expect(
        measure.truncated,
        isFalse,
        reason:
            'line $index: $line rendered ${measure.visibleLength} visible '
            'characters from ${measure.encodedLength} encoded characters',
      );
    }
  });
}

String _renderSignature(GlossLineRender render) => <String>[
  for (final GlossTextPiece piece in render.pieces)
    switch (piece) {
      GlossTextRun(:final McSpan span) =>
        '${span.text}:${span.color}:${span.bold}:${span.italic}:'
            '${span.underlined}:${span.strikethrough}:${span.obfuscated}',
      GlossPlaceholderChip(:final String token) => token,
      GlossMetricChip(:final String token) => token,
    },
].join('|');
