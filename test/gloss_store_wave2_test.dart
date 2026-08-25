/// [EditorStore] plumbing for the wave-2 Gloss kinds (MOTD, emoji, bubble
/// style, tablist): creation, typed mutators, import auto-detection, and the
/// workspace-scoped emoji resolver with its catalog merge.
library;

import 'dart:convert';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/catalogs.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

class _FakeStorage {
  final Map<String, String> values = <String, String>{};

  String? read(String key) => values[key];

  bool write(String key, String value) {
    values[key] = value;
    return true;
  }
}

EditorStore _store(_FakeStorage storage) => EditorStore(
  workspace: Workspace(read: storage.read, write: storage.write),
  autosaveDelay: Duration.zero,
);

void main() {
  group('motd', () {
    test('newGlossDocument opens the shipped default on the motd view', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.motd);
      expect(store.docKind, WorkspaceDocKind.motd);
      expect(store.motdDoc, isNotNull);
      expect(store.view, EditorView.visual);
      expect(store.workspace.active!.runtimeId, 'motd');
      expect(jsonDecode(store.exportJson()), jsonDecode(kGlossMotdDefaultJson));
    });

    test('mutateMotd is undoable and typed', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.motd);
      store.mutateMotd(
        'add entry',
        (GlossMotdDoc doc) =>
            doc.entries.add(GlossMotdEntry(lines: <String>['&bHi'])),
      );
      expect(store.motdDoc!.entries, hasLength(2));
      expect(store.performUndo(), isTrue);
      expect(store.motdDoc!.entries, hasLength(1));
    });

    test('import auto-detection routes an entries document to the kind', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJsonAsNewDocument('server-motd.json', kGlossMotdDefaultJson);
      expect(store.docKind, WorkspaceDocKind.motd);
      expect(store.motdDoc!.entries, hasLength(1));
    });
  });

  group('emoji', () {
    test('newGlossDocument opens the blank starter on the emoji view', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.emoji);
      expect(store.docKind, WorkspaceDocKind.emoji);
      expect(store.emojiDoc, isNotNull);
      expect(store.view, EditorView.visual);
      expect(store.workspace.active!.runtimeId, 'new-emoji');
      expect(store.emojiDoc!.resolvedGlyph, '✨');
    });

    test('mutateEmoji is undoable and typed', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.emoji);
      store.mutateEmoji(
        'emoji trigger',
        (GlossEmojiDoc doc) => doc.trigger = ':-)',
      );
      expect(store.emojiDoc!.trigger, ':-)');
      expect(store.performUndo(), isTrue);
      expect(store.emojiDoc!.trigger, isEmpty);
    });

    test('import auto-detection routes an emoji document to the kind', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJsonAsNewDocument('heart.json', kGlossEmojiHeartJson);
      expect(store.docKind, WorkspaceDocKind.emoji);
      expect(store.emojiDoc!.trigger, '<3');
    });
  });

  group('bubble style', () {
    test('newGlossDocument opens the shipped default on the bubble view', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.bubbleStyle);
      expect(store.docKind, WorkspaceDocKind.bubbleStyle);
      expect(store.bubbleStyleDoc, isNotNull);
      expect(store.view, EditorView.visual);
      expect(
        jsonDecode(store.exportJson()),
        jsonDecode(kGlossBubbleDefaultJson),
      );
    });

    test('mutateBubbleStyle is undoable and typed', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.bubbleStyle);
      store.mutateBubbleStyle(
        'bubble wrap',
        (GlossBubbleStyleDoc doc) => doc.wordWrapChars = 20,
      );
      expect(store.bubbleStyleDoc!.wordWrapChars, 20);
      expect(store.performUndo(), isTrue);
      expect(store.bubbleStyleDoc!.wordWrapChars, 32);
    });

    test('import auto-detection routes a bubble style to the kind', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJsonAsNewDocument('default.json', kGlossBubbleDefaultJson);
      expect(store.docKind, WorkspaceDocKind.bubbleStyle);
      expect(store.bubbleStyleDoc!.maxAliveMs, 5000);
    });
  });

  group('tablist', () {
    test('newGlossDocument opens the shipped default on the tablist view', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.tablist);
      expect(store.docKind, WorkspaceDocKind.tablist);
      expect(store.tablistDoc, isNotNull);
      expect(store.view, EditorView.visual);
      expect(store.workspace.active!.runtimeId, 'tablist');
      expect(
        jsonDecode(store.exportJson()),
        jsonDecode(kGlossTablistDefaultJson),
      );
    });

    test('mutateTablist is undoable and typed', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.tablist);
      store.mutateTablist(
        'tablist header',
        (GlossTablistDoc doc) =>
            doc.headerFooter.presentation.header = '&bNew header',
      );
      expect(
        store.tablistDoc!.headerFooter.presentation.header,
        '&bNew header',
      );
      expect(store.performUndo(), isTrue);
      expect(store.tablistDoc!.headerFooter.presentation.header, '&d&lGloss');
    });

    test('import auto-detection routes a tablist document to the kind', () {
      final EditorStore store = _store(_FakeStorage());
      store.importJsonAsNewDocument('tablist.json', kGlossTablistDefaultJson);
      expect(store.docKind, WorkspaceDocKind.tablist);
      expect(store.tablistDoc!.listNames.variants, hasLength(1));
    });
  });

  group('workspace emoji resolver', () {
    test('starts from the catalog and stays sorted', () {
      final EditorStore store = _store(_FakeStorage());
      store.setCatalogs(
        HuiCatalogs.build(
          materials: const <MaterialEntry>[],
          sounds: const <String>[],
          loaded: false,
          emoji: const <GlossEmojiEntry>[
            GlossEmojiEntry(id: 'zeta', trigger: '', glyph: 'Z', enabled: true),
            GlossEmojiEntry(
              id: 'alpha',
              trigger: '',
              glyph: 'A',
              enabled: true,
            ),
          ],
        ),
      );
      final List<String> ids = <String>[
        for (final GlossEmojiEntry entry in store.workspaceEmoji.entries)
          entry.id,
      ];
      expect(ids, <String>['alpha', 'zeta']);
      expect(
        store.workspaceEmoji.entries.every(
          (GlossEmojiEntry entry) => !entry.fromWorkspace,
        ),
        isTrue,
      );
    });

    test('a workspace emoji document overrides its catalog entry by id', () {
      final EditorStore store = _store(_FakeStorage());
      store.setCatalogs(
        HuiCatalogs.build(
          materials: const <MaterialEntry>[],
          sounds: const <String>[],
          loaded: false,
          emoji: const <GlossEmojiEntry>[
            GlossEmojiEntry(
              id: 'heart',
              trigger: '<3',
              glyph: '❤',
              enabled: true,
            ),
          ],
        ),
      );
      store.newGlossDocument(DocumentTypes.emoji, name: 'heart');
      store.mutateEmoji('emoji value', (GlossEmojiDoc doc) {
        doc.emoji = 'U+2713;';
        doc.trigger = 'ok';
      });
      final List<GlossEmojiEntry> entries = store.workspaceEmoji.entries;
      expect(entries, hasLength(1));
      expect(entries.single.id, 'heart');
      expect(entries.single.glyph, '✓', reason: 'live model wins');
      expect(entries.single.trigger, 'ok');
      expect(entries.single.fromWorkspace, isTrue);
      // And the substitution stage sees the override.
      expect(glossApplyEmoji('ok :heart:', store.workspaceEmoji), '✓ ✓');
    });

    test('the resolver tracks edits — the memo dies with each change', () {
      final EditorStore store = _store(_FakeStorage());
      store.newGlossDocument(DocumentTypes.emoji, name: 'wave');
      store.mutateEmoji('emoji value', (GlossEmojiDoc doc) => doc.emoji = 'A');
      expect(store.workspaceEmoji.entries.single.glyph, 'A');
      store.mutateEmoji('emoji value', (GlossEmojiDoc doc) => doc.emoji = 'B');
      expect(store.workspaceEmoji.entries.single.glyph, 'B');
    });
  });
}
