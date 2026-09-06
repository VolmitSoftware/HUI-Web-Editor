import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/logic/bubble_preview.dart';
import 'package:gloss_editor/logic/canvas_scene.dart';
import 'package:gloss_editor/logic/gloss_animation_playback.dart';
import 'package:gloss_editor/logic/gloss_hologram_scene.dart';
import 'package:gloss_editor/logic/gloss_show.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/tablist_selection.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/gloss_hologram_box.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

final class _Animations implements GlossAnimationResolver {
  _Animations(this.doc);
  final GlossAnimationDoc doc;
  @override
  List<String> get ids => <String>['test'];
  @override
  GlossAnimationDoc? byId(String id) => id == 'test' ? doc : null;
}

final class _Emoji implements GlossEmojiResolver {
  _Emoji(this.entries);
  @override
  final List<GlossEmojiEntry> entries;
}

CanvasScene _scene(HuiMenu menu, {bool trueRender = true, int ticks = 0}) =>
    buildCanvasScene(
      menu: menu,
      uiScale: 1,
      trueRender: trueRender,
      togglePreview: (String id) => false,
      textCache: McTextCache(),
      animationTicks: ticks,
    );

void main() {
  test('conditions retain false and reject invalid boolean data', () {
    final Map<String, Object?> fields = <String, Object?>{};
    setGlossShow(fields, false);
    expect(fields['show'], isFalse);
    expect(glossShowMatches(fields['show']), isFalse);
    setGlossShow(fields, null);
    expect(fields.containsKey('show'), isFalse);
    expect(glossShowMatches(null), isTrue);
    for (final Object invalid in <Object>[
      1,
      <String, Object?>{},
      '2 + 3',
      "'text'",
      'viewer.health >',
    ]) {
      expect(
        validateGlossShow(
          invalid,
        ).any((HuiIssue issue) => issue.severity == HuiSeverity.error),
        isTrue,
        reason: '$invalid',
      );
      expect(glossShowMatches(invalid), isFalse);
    }
    expect(validateGlossShow('{{ viewer.health > 0 }}'), isEmpty);
    expect(glossShowMatches('{{ false }}'), isFalse);
  });

  test(
    'viewer roles, time, world, permissions and PAPI use the supplied scope',
    () {
      final GlossConditionContext context = GlossConditionContext(
        variables: <String, Object?>{
          'viewer.world': 'world_nether',
          'viewer.health': 7.0,
        },
        permissions: <String>{'gloss.test'},
        groups: <String>{'vip'},
        regions: <String>{'spawn'},
        placeholders: <String, String>{'player_level': '12'},
      );
      expect(
        glossShowMatches(
          "viewer.world == 'world_nether' && viewer.health < 10 && time.seconds >= 2 && hasPermission('viewer', 'gloss.test') && inGroup('viewer', 'vip') && inRegion('viewer', 'spawn') && papiNumber('viewer', 'player_level', 0) == 12",
          scope: context,
          nowMs: 2000,
        ),
        isTrue,
      );
      expect(glossShowMatches('time.ticks > 10', nowMs: 500), isFalse);
      expect(glossShowMatches('server.online > 0', viewerAware: false), isTrue);
      expect(
        glossShowMatches("viewer.world == 'world'", viewerAware: false),
        isFalse,
      );
    },
  );

  test('all document roots preserve false across direct JSON round trips', () {
    final List<(GlossDoc, GlossDoc Function(Object?))> docs =
        <(GlossDoc, GlossDoc Function(Object?))>[
          (GlossHologramDoc(), GlossHologramDoc.fromJson),
          (GlossAnimationDoc(), GlossAnimationDoc.fromJson),
          (GlossBubbleStyleDoc(), GlossBubbleStyleDoc.fromJson),
          (GlossEmojiDoc(), GlossEmojiDoc.fromJson),
          (GlossMotdDoc(), GlossMotdDoc.fromJson),
          (GlossScoreboardDoc(), GlossScoreboardDoc.fromJson),
          (GlossTablistDoc(), GlossTablistDoc.fromJson),
          (GlossDamageIndicatorsDoc(), GlossDamageIndicatorsDoc.fromJson),
        ];
    for (final (GlossDoc doc, GlossDoc Function(Object?) decode) in docs) {
      final Map<String, Object?> json = doc.toJson()..['show'] = false;
      expect(
        decode(json).toJson()['show'],
        isFalse,
        reason: '${doc.runtimeType}',
      );
    }
  });

  test(
    'menu visibility removes runtime hit targets while editing stays selectable',
    () {
      final HuiMenu menu = HuiMenu(
        components: <HuiComponent>[
          HuiComponent('hidden', Vec3(0, 0, 0), HuiButtonData())
            ..extras['show'] = false,
          HuiComponent('timed', Vec3(1, 0, 0), HuiButtonData())
            ..extras['show'] = 'time.ticks >= 4',
        ],
      );
      expect(_scene(menu).items, isEmpty);
      expect(
        _scene(
          menu,
          ticks: 4,
        ).items.map((CanvasItem item) => item.component.id),
        <String>['timed'],
      );
      expect(_scene(menu, trueRender: false).items, hasLength(2));
      menu.extras['show'] = false;
      expect(_scene(menu, ticks: 4).items, isEmpty);
      expect(menu.copy().toJson()['show'], isFalse);
      expect(menu.copy().components.first.toJson()['show'], isFalse);
    },
  );

  test('header footer and list names evaluate independent conditions', () {
    final GlossTablistDoc doc = GlossTablistDoc();
    final GlossConditionContext context = GlossConditionContext();
    doc.headerFooter.enabled = true;
    doc.listNames.enabled = true;
    doc.headerFooter.extras['show'] = false;
    doc.listNames.extras['show'] = 'time.ticks >= 1';
    expect(glossTablistHeaderFooterVisible(doc, context), isFalse);
    expect(glossTablistListNamesVisible(doc, context), isFalse);
    expect(glossTablistListNamesVisible(doc, context, nowMs: 50), isTrue);
    final GlossTablistDoc copy = doc.copy();
    expect(copy.headerFooter.toJson()['show'], isFalse);
    doc.extras['show'] = false;
    expect(glossTablistListNamesVisible(doc, context, nowMs: 50), isFalse);
  });

  test('hidden boards cannot win selection', () {
    final GlossScoreboardDoc hidden = GlossScoreboardDoc()
      ..extras['show'] = false;
    hidden.select.priority = 100;
    hidden.select.when = 'true';
    final GlossScoreboardDoc visible = GlossScoreboardDoc()
      ..select.when = 'true';
    expect(
      glossSelectBoard(
        boards: <GlossBoardCandidate>[
          GlossBoardCandidate.fromDoc('hidden', hidden),
          GlossBoardCandidate.fromDoc('visible', visible),
        ],
        context: GlossConditionContext(),
      ).boardId,
      'visible',
    );
  });

  test('animation and emoji conditions receive the rendering samples', () {
    final GlossAnimationDoc animation = GlossAnimationDoc(frames: <String>['A'])
      ..extras['show'] = 'viewer.health < 10 && time.ticks >= 2';
    final _Emoji emoji = _Emoji(<GlossEmojiEntry>[
      const GlossEmojiEntry(
        id: 'test',
        trigger: ':)',
        glyph: 'B',
        enabled: true,
        show: 'viewer.health < 10 && time.ticks >= 2',
      ),
    ]);
    const GlossTextExpressionSamples samples = GlossTextExpressionSamples(
      values: <String, Object>{'viewer.health': 7.0},
    );
    expect(
      renderGlossLine(
        '|animation.test|:test:',
        animations: _Animations(animation),
        emoji: emoji,
        nowMs: 100,
        expressionSamples: samples,
      ).renderedText,
      'AB',
    );
    expect(
      renderGlossLine(
        '|animation.test|:test:',
        animations: _Animations(animation),
        emoji: emoji,
        nowMs: 0,
        expressionSamples: samples,
      ).renderedText,
      ':test:',
    );
    animation.extras['show'] = false;
    expect(glossAnimationFrameAt(animation, 'test', 100), isEmpty);
    expect(renderGlossAnimationFramePreview('').renderedText, isEmpty);
  });

  test('hidden holograms and bubbles render no text or spawns', () {
    final GlossHologramDoc hologram = GlossHologramDoc(lines: <String>['test'])
      ..extras['show'] = false;
    expect(hologramRenderedLines(hologram), isEmpty);
    final GlossBubbleStyleDoc bubble = GlossBubbleStyleDoc()
      ..extras['show'] = false;
    expect(GlossBubblePreviewTimeline(bubble).bubblesAt(1000), isEmpty);
  });

  test(
    'shared style and box round trip independently for every presentation',
    () {
      final GlossHologramDoc doc = GlossHologramDoc();
      doc.style.scaleX = 1.5;
      doc.style.scaleY = 0.6;
      doc.style.blockLight = 15;
      doc.style.textAlignment = 'right';
      doc.box = GlossHologramBox(enabled: true, padding: 12, borderWidth: 3);
      final GlossHologramDoc copy = doc.copy();
      expect(copy.style.toJson(), doc.style.toJson());
      expect(copy.box.toJson(), doc.box.toJson());
      copy.box.padding = 8;
      expect(doc.box.padding, 12);
      final GlossBubbleStyleDoc bubble = GlossBubbleStyleDoc(
        style: doc.style.copy(),
        box: doc.box.copy(),
      );
      expect(
        GlossBubbleStyleDoc.fromJson(bubble.toJson()).style.toJson(),
        doc.style.toJson(),
      );
      final GlossDamageIndicatorsDoc indicators = GlossDamageIndicatorsDoc();
      indicators.damage.presentation.style = doc.style.copy();
      indicators.damage.presentation.box = doc.box.copy();
      indicators.damage.presentation.format = 'Critical hit';
      expect(
        GlossDamageIndicatorsDoc.fromJson(
          indicators.toJson(),
        ).damage.presentation.box.toJson(),
        doc.box.toJson(),
      );
      expect(
        GlossHologramDoc.fromJson(<String, Object?>{
          'schemaVersion': 3,
          'revision': 1,
        }).style.billboard,
        'center',
      );
      expect(
        GlossHologramDoc.fromJson(<String, Object?>{
          'schemaVersion': 3,
          'revision': 1,
          'style': <String, Object?>{},
        }).style.billboard,
        'fixed',
      );
    },
  );
}
