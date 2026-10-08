import 'dart:math';
import 'dart:io';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/channel_preview.dart';
import 'package:gloss_editor/logic/channel_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

void main() {
  test(
    'channels preserve optional blocks and unknown mention fields through export',
    () {
      final GlossChannelDoc doc = decodeGlossChannelDoc(
        '''{"schemaVersion":2,"revision":9,
      "channel":{"name":"global","default":true},"format":"{{ sender.name }}: {{ message }}",
      "mentions":{"enabled":false,"messageFormat":"<green>{{ message }}</green>","custom":7},
      "items":{"enabled":false},"filters":[{"match":"bad","replace":"ok"}],
      "variants":[{"id":"staff","priority":1,"when":"true","format":"staff: {{ message }}"}]}''',
      );
      final GlossChannelDoc copy = decodeGlossChannelDoc(
        encodeGlossChannelDoc(doc),
      );
      expect(copy.revision, 9);
      expect(copy.mentions.enabled, isFalse);
      expect(copy.mentions.extras['custom'], 7);
      expect(copy.extras, doc.extras);
      expect(
        DocumentTypeRegistry.detectTransferable(copy.toJson()),
        DocumentTypes.channel,
      );
      expect(DocumentTypeRegistry.byWireKind('channel'), DocumentTypes.channel);
    },
  );

  test('only a whole recipient mention selects the tagged message style', () {
    final GlossChannelDoc doc = GlossChannelDoc();
    expect(channelPreview(doc, message: 'hello @Steve').mentioned, isTrue);
    expect(
      channelPreview(doc, message: 'hello @Steve', viewer: 'Morgan').mentioned,
      isFalse,
    );
    for (final String message in <String>[
      'name@Steve',
      '@SteveExtra',
      'https://example.test/@Steve',
    ]) {
      expect(channelPreview(doc, message: message).mentioned, isFalse);
    }
    expect(
      channelPreview(
        doc,
        message: '@abcdefghijklmnopq',
        viewer: 'abcdefghijklmnop',
      ).mentioned,
      isFalse,
    );
    expect(
      channelPreview(doc, message: 'hello @Steve', allowed: false).mentioned,
      isFalse,
    );
    doc.mentions.enabled = false;
    expect(channelPreview(doc, message: 'hello @Steve').mentioned, isFalse);
  });

  test('typed chat stays literal while authored mention styles render', () {
    final GlossChannelDoc doc = GlossChannelDoc();
    const String message =
        '<red>&c {{ 1 + 2 }} %player_name% |metric.react.tps| @Steve';
    final ChannelPreview preview = channelPreview(doc, message: message);
    expect(preview.render.plainText, 'Alex: $message');
    expect(preview.render.expressionErrors, isEmpty);
    expect(preview.render.placeholders, isEmpty);
    expect(preview.render.metrics, isEmpty);
    final List<GlossTextRun> runs = preview.render.pieces
        .whereType<GlossTextRun>()
        .toList();
    expect(
      runs
          .where((GlossTextRun run) => run.span.text.contains('<red>'))
          .single
          .span
          .color,
      0xFFFF55,
    );
    expect(
      runs
          .where((GlossTextRun run) => run.span.text.contains('@Steve'))
          .single
          .span
          .bold,
      isTrue,
    );
  });

  test('shipped global channel renders group, player and hover card', () {
    final File source = File(
      glossRepositoryFilePath(
        'src/main/resources/defaults/channels/global.json',
      ),
    );
    final GlossChannelDoc doc = decodeGlossChannelDoc(
      source.readAsStringSync(),
    );
    final ChannelPreview preview = channelPreview(
      doc,
      message: 'Hello',
      viewer: 'Morgan',
    );
    expect(preview.render.plainText, '[Member] Alex: Hello');
    expect(preview.hoverText, contains('Alex'));
    expect(preview.hoverText, contains('World World'));
    expect(preview.render.expressionErrors, isEmpty);
    expect(preview.render.plainText, isNot(contains('<hover')));
  });

  test(
    'imported variants use sender conditions and tagged format takes priority',
    () {
      final GlossChannelDoc doc = GlossChannelDoc(
        variants: <GlossChannelVariant>[
          GlossChannelVariant(
            id: 'z',
            priority: 10,
            when: "hasPermission('sender', 'server.staff')",
            format: 'Staff {{ sender.name }}: {{ message }}',
          ),
          GlossChannelVariant(
            id: 'a',
            priority: 9,
            when: 'true',
            format: 'First {{ sender.name }}: {{ message }}',
          ),
        ],
      );
      expect(
        channelPreview(
          doc,
          message: 'Hello',
          senderPermissions: <String>{'server.staff'},
        ).render.plainText,
        'Staff Alex: Hello',
      );
      expect(
        channelPreview(doc, message: 'Hello').render.plainText,
        'First Alex: Hello',
      );
      expect(
        channelPreview(doc, message: '@Steve').render.plainText,
        'Alex: @Steve',
      );
      doc.show = 'false';
      final ChannelPreview hidden = channelPreview(doc, message: '@Steve');
      expect(hidden.visible, isFalse);
      expect(hidden.mentioned, isFalse);
      expect(hidden.render.plainText, isEmpty);
    },
  );

  test(
    'create, randomize, undo and export keep channel identity and revision',
    () {
      final Map<String, String> saved = <String, String>{};
      final EditorStore store = EditorStore(
        workspace: Workspace(
          read: (String key) => saved[key],
          write: (String key, String value) {
            saved[key] = value;
            return true;
          },
        ),
        autosaveDelay: Duration.zero,
      );
      DocumentTypes.channel.createNew(store);
      final GlossChannelDoc before = store.glossDoc! as GlossChannelDoc;
      store.mutateGloss('revision', (GlossDoc doc) => doc.revision = 5);
      final String original = encodeGlossChannelDoc(before);
      final String id = store.workspace.activeId!;
      expect(randomizeShowcaseDocument(store, id, random: Random(15)), isTrue);
      final GlossChannelDoc generated = store.glossDoc! as GlossChannelDoc;
      expect(validateChannelDoc(generated), isEmpty);
      expect(generated.revision, 5);
      expect(generated.channel.name, 'global');
      expect(generated.mentions.messageFormat, contains('[Mention]'));
      store.performUndo();
      expect(
        encodeGlossChannelDoc(store.glossDoc! as GlossChannelDoc),
        original,
      );
      store.dispose();
    },
  );
}
