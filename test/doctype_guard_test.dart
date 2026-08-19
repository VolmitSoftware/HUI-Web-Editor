/// Guards the document-type registry refactor.
///
/// Per-kind behavior lives on [DocumentTypeAdapter]s in `lib/doctype/`;
/// adding a document kind must mean one enum value plus one adapter, never a
/// new `WorkspaceDocKind.` branch site scattered through the app. The first
/// test fails the build when one appears outside the allowed files; the rest
/// pin the registry's coverage and the frozen sync-wire mapping.
library;

import 'dart:io';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

/// Files allowed to name `WorkspaceDocKind.` values: the enum's own
/// declaration (identity plus the stored-slug compat mapping) and the doctype
/// layer itself.
const List<String> _allowedPrefixes = <String>[
  'lib/doctype/',
  'lib/state/workspace.dart',
];

void main() {
  test('WorkspaceDocKind values are only named by the doctype layer', () {
    final List<String> offenders = <String>[];
    final List<FileSystemEntity> entries = Directory(
      'lib',
    ).listSync(recursive: true);
    for (final FileSystemEntity entry in entries) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final String path = entry.path.replaceAll('\\', '/');
      if (_allowedPrefixes.any(path.startsWith)) continue;
      final List<String> lines = entry.readAsLinesSync();
      for (int index = 0; index < lines.length; index++) {
        if (lines[index].contains('WorkspaceDocKind.')) {
          offenders.add('$path:${index + 1}: ${lines[index].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Per-kind behavior belongs on a DocumentTypeAdapter in lib/doctype/. '
          'Route these through the registry instead:\n${offenders.join('\n')}',
    );
  });

  test('every document kind has a registered adapter', () {
    for (final WorkspaceDocKind kind in WorkspaceDocKind.values) {
      final DocumentTypeAdapter adapter = DocumentTypeRegistry.of(kind);
      expect(adapter.kind, kind);
      expect(adapter.noun, isNotEmpty);
      expect(adapter.createLabel, isNotEmpty);
      expect(
        adapter.availableViews,
        isNotEmpty,
        reason: 'every kind needs a default view',
      );
    }
    expect(DocumentTypeRegistry.all.length, WorkspaceDocKind.values.length);
  });

  test('sync wire kinds stay on the protocol-v2 slugs', () {
    // Protocol v2 keeps kinds open on the wire, but the slugs this build has
    // codecs for are pinned: menus sync as `menu`, world panels sync as
    // `panel` (the v1 slug `board` died at the v2 cutover), and the Gloss
    // kinds sync under their own names. Renaming a workspace kind must never
    // leak into the wire vocabulary.
    expect(DocumentTypeRegistry.byWireKind('menu'), DocumentTypes.menu);
    expect(DocumentTypeRegistry.byWireKind('panel'), DocumentTypes.panel);
    expect(DocumentTypeRegistry.byWireKind('board'), isNull);
    expect(
      DocumentTypeRegistry.byWireKind('hologram'),
      DocumentTypes.hologram,
    );
    expect(
      DocumentTypeRegistry.byWireKind('animation'),
      DocumentTypes.animation,
    );
    expect(
      DocumentTypeRegistry.byWireKind('scoreboard'),
      DocumentTypes.scoreboard,
    );
    expect(DocumentTypeRegistry.byWireKind('scoreboards'), isNull);
    expect(DocumentTypeRegistry.byWireKind('motd'), DocumentTypes.motd);
    expect(DocumentTypeRegistry.byWireKind('emoji'), DocumentTypes.emoji);
    expect(
      DocumentTypeRegistry.byWireKind('bubble-style'),
      DocumentTypes.bubbleStyle,
    );
    expect(DocumentTypeRegistry.byWireKind('bubbles'), isNull);
    expect(DocumentTypeRegistry.byWireKind('tablist'), DocumentTypes.tablist);
    expect(DocumentTypes.containerPreview.syncWireKind, isNull);
  });

  test('adapter views agree with the store surfaces they gate', () {
    expect(DocumentTypes.menu.availableViews, const <EditorView>[
      EditorView.visual,
      EditorView.preview,
      EditorView.code,
      EditorView.split,
    ]);
    expect(DocumentTypes.containerPreview.availableViews, const <EditorView>[
      EditorView.previewCard,
      EditorView.code,
    ]);
    expect(DocumentTypes.panel.availableViews, const <EditorView>[
      EditorView.panel,
    ]);
    expect(DocumentTypes.hologram.availableViews, const <EditorView>[
      EditorView.hologram,
      EditorView.code,
    ]);
    expect(DocumentTypes.animation.availableViews, const <EditorView>[
      EditorView.animation,
      EditorView.code,
    ]);
    expect(DocumentTypes.scoreboard.availableViews, const <EditorView>[
      EditorView.scoreboard,
      EditorView.code,
    ]);
    expect(DocumentTypes.motd.availableViews, const <EditorView>[
      EditorView.motd,
      EditorView.code,
    ]);
    expect(DocumentTypes.emoji.availableViews, const <EditorView>[
      EditorView.emoji,
      EditorView.code,
    ]);
    expect(DocumentTypes.bubbleStyle.availableViews, const <EditorView>[
      EditorView.bubble,
      EditorView.code,
    ]);
    expect(DocumentTypes.tablist.availableViews, const <EditorView>[
      EditorView.tablist,
      EditorView.code,
    ]);
  });

  test('capabilities carry the per-kind rules the store used to switch on', () {
    expect(DocumentTypes.menu.hasRuntimeId, isTrue);
    expect(DocumentTypes.containerPreview.hasRuntimeId, isTrue);
    expect(DocumentTypes.panel.hasRuntimeId, isFalse);
    for (final WorkspaceDocKind kind in WorkspaceDocKind.values) {
      expect(
        DocumentTypeRegistry.of(kind).hasRuntimeId,
        kind.hasRuntimeId,
        reason: 'adapter and enum must agree for $kind',
      );
    }
    expect(DocumentTypes.menu.sourcePreserving, isTrue);
    expect(DocumentTypes.panel.transferable, isFalse);
    expect(DocumentTypes.panel.undoable, isFalse);
    expect(DocumentTypes.hologram.hasRuntimeId, isTrue);
    expect(DocumentTypes.hologram.transferable, isTrue);
    expect(DocumentTypes.hologram.undoable, isTrue);
    expect(DocumentTypes.hologram.sourcePreserving, isFalse);
    expect(DocumentTypes.animation.hasRuntimeId, isTrue);
    expect(DocumentTypes.animation.transferable, isTrue);
    expect(DocumentTypes.animation.undoable, isTrue);
    expect(DocumentTypes.animation.sourcePreserving, isFalse);
    expect(DocumentTypes.scoreboard.hasRuntimeId, isTrue);
    expect(DocumentTypes.scoreboard.transferable, isTrue);
    expect(DocumentTypes.scoreboard.undoable, isTrue);
    expect(DocumentTypes.scoreboard.sourcePreserving, isFalse);
    expect(DocumentTypes.motd.hasRuntimeId, isTrue);
    expect(DocumentTypes.motd.transferable, isTrue);
    expect(DocumentTypes.motd.undoable, isTrue);
    expect(DocumentTypes.motd.sourcePreserving, isFalse);
    expect(DocumentTypes.emoji.hasRuntimeId, isTrue);
    expect(DocumentTypes.emoji.transferable, isTrue);
    expect(DocumentTypes.emoji.undoable, isTrue);
    expect(DocumentTypes.emoji.sourcePreserving, isFalse);
    expect(DocumentTypes.bubbleStyle.hasRuntimeId, isTrue);
    expect(DocumentTypes.bubbleStyle.transferable, isTrue);
    expect(DocumentTypes.bubbleStyle.undoable, isTrue);
    expect(DocumentTypes.bubbleStyle.sourcePreserving, isFalse);
    expect(DocumentTypes.tablist.hasRuntimeId, isTrue);
    expect(DocumentTypes.tablist.transferable, isTrue);
    expect(DocumentTypes.tablist.undoable, isTrue);
    expect(DocumentTypes.tablist.sourcePreserving, isFalse);
  });
}
