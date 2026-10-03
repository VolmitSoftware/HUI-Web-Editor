import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/canvas_scene.dart';
import 'package:gloss_editor/logic/channel_preview.dart';
import 'package:gloss_editor/logic/channel_validation.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/motd_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('channel filter replacement expands Java capture groups', () {
    final GlossChannelDoc doc = GlossChannelDoc(
      format: '{{ message }}',
      filters: <GlossChannelFilter>[
        GlossChannelFilter(
          match: r'hello (?<name>\w+)',
          replace: r'Hi ${name}, $1',
        ),
      ],
    );
    expect(
      channelPreview(doc, message: 'hello Alex').render.plainText,
      'Hi Alex, Alex',
    );
  });

  test('channel variants preserve empty overrides and optional blocks', () {
    final GlossChannelDoc doc = decodeGlossChannelDoc('''{
      "schemaVersion":1,"revision":1,"channel":{"name":"global"},"format":"{{ message }}",
      "card":["base"],"filters":[{"match":"old","replace":"new"}],
      "variants":[{"id":"plain","when":"true","card":[],"filters":[],
        "items":{"enabled":false,"custom":7},"links":{"enabled":false},
        "throttle":{"minIntervalTicks":25}}]}''');
    final GlossChannelDoc copy = decodeGlossChannelDoc(
      encodeGlossChannelDoc(doc),
    );
    final GlossChannelVariant variant = copy.variants.single;
    expect(variant.format, isNull);
    expect(variant.card, isEmpty);
    expect(variant.filters, isEmpty);
    expect(variant.items!.extras['custom'], 7);
    expect(variant.throttle!.minIntervalTicks, 25);
    expect(variant.apply(copy).format, '{{ message }}');
    expect(variant.apply(copy).card, isEmpty);
    expect(validateChannelDoc(copy), isEmpty);
    expect(glossJsonSchemaFor('channel'), isNotNull);
  });

  test(
    'channel filtering selects sender while presentation selects recipient',
    () {
      final GlossChannelDoc doc = GlossChannelDoc(
        format: '{{ message }}',
        mentions: GlossChannelMentions(enabled: false),
        variants: <GlossChannelVariant>[
          GlossChannelVariant(
            id: 'sender',
            when: "viewer.name == 'Alex'",
            filters: <GlossChannelFilter>[
              GlossChannelFilter(match: 'old', replace: 'sent'),
            ],
          ),
          GlossChannelVariant(
            id: 'recipient',
            when: "viewer.name == 'Steve'",
            format: 'Received {{ message }}',
            card: <String>['Recipient card'],
            filters: <GlossChannelFilter>[
              GlossChannelFilter(match: 'sent', replace: 'wrong'),
            ],
          ),
        ],
      );
      final ChannelPreview preview = channelPreview(doc, message: 'old');
      expect(preview.render.plainText, 'Received sent');
      expect(preview.hoverText, 'Recipient card');
    },
  );

  test('channel variants render authored item and link templates', () {
    final GlossChannelDoc doc = GlossChannelDoc(
      format: '{{ message }}',
      variants: <GlossChannelVariant>[
        GlossChannelVariant(
          id: 'styled',
          when: 'true',
          items: GlossChannelItems(render: 'Held {{ item.name }}'),
          links: GlossChannelLinks(render: 'Visit {{ link.host }}'),
        ),
      ],
    );
    final ChannelPreview preview = channelPreview(
      doc,
      message: '[item] https://example.test/path',
    );
    expect(preview.render.plainText, 'Held Diamond Visit example.test');
    expect(preview.render.expressionErrors, isEmpty);
    doc.variants.single.items!.enabled = false;
    doc.variants.single.links!.enabled = false;
    expect(
      channelPreview(
        doc,
        message: '[item] https://example.test/path',
      ).render.plainText,
      '[item] https://example.test/path',
    );
  });

  test(
    'menu variants use session declarations and preserve explicit empty layers',
    () {
      final HuiMenu menu = HuiMenu(
        components: <HuiComponent>[
          HuiComponent('base', Vec3.zero(), HuiButtonData()),
        ],
        variants: <HuiMenuVariant>[
          HuiMenuVariant(
            id: 'selected',
            priority: 10,
            when: 'session.active',
            components: <HuiComponent>[
              HuiComponent('replacement', Vec3.zero(), HuiButtonData()),
            ],
            particleLayers: <GlossParticleLayer>[],
          ),
          HuiMenuVariant(
            id: 'empty',
            when: 'true',
            components: <HuiComponent>[],
          ),
        ],
      )..extras['vars'] = <String, String>{'active': 'true'};
      final HuiMenu copy = menu.copy();
      expect(copy.variants.first.particleLayers, isEmpty);
      expect(copy.variants.last.particleLayers, isNull);
      CanvasScene render({
        bool trueRender = true,
        Map<String, Object> values = const <String, Object>{},
      }) => buildCanvasScene(
        menu: copy,
        uiScale: 1,
        trueRender: trueRender,
        togglePreview: (String _) => false,
        textCache: McTextCache(),
        expressionSamples: GlossTextExpressionSamples(values: values),
      );
      expect(render().items.single.component.id, 'replacement');
      expect(
        render(values: <String, Object>{'session.active': false}).items,
        isEmpty,
      );
      expect(render(trueRender: false).items.single.component.id, 'base');
    },
  );

  test('MOTD entry visibility and weight survive edits and validate', () {
    final GlossMotdDoc doc = decodeGlossMotdDoc(
      '{"schemaVersion":1,"revision":1,"entries":[{"lines":["Hello"],"show":"server.online > 0","weight":7}]}',
    );
    final GlossMotdDoc copy = decodeGlossMotdDoc(encodeGlossMotdDoc(doc));
    expect(copy.entries.single.show, 'server.online > 0');
    expect(copy.entries.single.weight, 7);
    copy.entries.single.weight = 0;
    expect(
      validateMotdDoc(
        copy,
      ).any((HuiIssue issue) => issue.path.endsWith('.weight')),
      isTrue,
    );
  });

  test('first join is independently editable and absent by default', () {
    final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(
      '{"schemaVersion":1,"revision":1,"firstJoin":{"presentation":{"text":"Welcome"}}}',
    );
    expect(doc.join.present, isFalse);
    expect(doc.firstJoin.enabled, isTrue);
    expect(
      decodeGlossConnectionsDoc(
        encodeGlossConnectionsDoc(doc),
      ).section('firstJoin').presentation.text,
      'Welcome',
    );
    expect(GlossConnectionsDoc().firstJoin.present, isFalse);
  });
}
