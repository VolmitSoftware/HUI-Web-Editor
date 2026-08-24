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

  test('sync wire kinds stay on the protocol-v3 slugs', () {
    expect(DocumentTypeRegistry.byWireKind('menu'), DocumentTypes.menu);
    expect(DocumentTypeRegistry.byWireKind('panel'), DocumentTypes.panel);
    expect(DocumentTypeRegistry.byWireKind('board'), isNull);
    expect(DocumentTypeRegistry.byWireKind('hologram'), DocumentTypes.hologram);
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
    expect(
      DocumentTypeRegistry.byWireKind('real-drops'),
      DocumentTypes.realDrops,
    );
    expect(
      DocumentTypes.containerPreview.syncWireKind,
      'container-preview',
    );
  });

  test('every kind offers the four modes, or says why not', () {
    for (final DocumentTypeAdapter adapter in DocumentTypeRegistry.all) {
      expect(
        adapter.supportsView(EditorView.visual),
        isTrue,
        reason: '${adapter.noun} must have an editing surface',
      );
      for (final EditorView view in EditorView.values) {
        final String? reason = adapter.unavailableViewReason(view);
        expect(
          adapter.supportsView(view),
          reason == null,
          reason: 'supportsView and the reason must agree for $view',
        );
        if (reason != null) {
          expect(reason, isNotEmpty);
          expect(adapter.availableViews, isNot(contains(view)));
        }
      }
    }
  });

  test('only the editor-only kind loses modes', () {
    expect(DocumentTypes.menu.availableViews, EditorView.values);
    expect(DocumentTypes.containerPreview.availableViews, EditorView.values);
    expect(DocumentTypes.scoreboard.availableViews, EditorView.values);
    expect(DocumentTypes.panel.availableViews, const <EditorView>[
      EditorView.visual,
    ]);
    // A flow map is editor-only and nothing on the server draws it, so both
    // the JSON modes and the preview say so rather than disappearing.
    expect(
      DocumentTypes.panel.unavailableViewReason(EditorView.code),
      contains('editor-only'),
    );
    expect(
      DocumentTypes.panel.unavailableViewReason(EditorView.split),
      contains('editor-only'),
    );
    expect(
      DocumentTypes.panel.unavailableViewReason(EditorView.preview),
      contains('no in-game rendering'),
    );
  });

  test('every kind carries its mode-tab and surface metadata', () {
    final Set<DocumentSurface> surfaces = <DocumentSurface>{};
    final Set<int> orders = <int>{};
    for (final DocumentTypeAdapter adapter in DocumentTypeRegistry.all) {
      expect(adapter.pluralLabel, isNotEmpty);
      expect(adapter.surfaceLabel, isNotEmpty);
      expect(
        surfaces.add(adapter.surface),
        isTrue,
        reason: 'two kinds claim the ${adapter.surface} surface',
      );
      expect(
        orders.add(adapter.tabOrder),
        isTrue,
        reason: 'two kinds claim tab order ${adapter.tabOrder}',
      );
    }
    // Every surface the centre pane knows about is claimed by exactly one
    // kind, so no slot in the shell can go unreachable.
    expect(surfaces.length, DocumentSurface.values.length);
  });

  test('the mode tabs are in tabOrder', () {
    final List<DocumentTypeAdapter> tabs = DocumentTypeRegistry.tabs;
    expect(tabs.length, DocumentTypeRegistry.all.length);
    for (int i = 1; i < tabs.length; i++) {
      expect(tabs[i - 1].tabOrder, lessThan(tabs[i].tabOrder));
    }
    expect(tabs.first, DocumentTypes.menu);
    expect(
      DocumentTypeRegistry.byKindName(DocumentTypes.scoreboard.kind.name),
      DocumentTypes.scoreboard,
    );
    expect(DocumentTypeRegistry.byKindName('not-a-kind'), isNull);
  });

  test('only kinds with in-document contents offer a contents tab', () {
    expect(DocumentTypes.menu.contentsTabLabel, 'Components');
    expect(DocumentTypes.containerPreview.contentsTabLabel, 'Elements');
    expect(DocumentTypes.panel.contentsTabLabel, isNull);
    for (final DocumentTypeAdapter adapter in DocumentTypeRegistry.all) {
      if (adapter is GlossDocumentTypeAdapter) {
        expect(
          adapter.contentsTabLabel,
          isNull,
          reason: 'a ${adapter.noun} has no in-document contents list',
        );
      }
    }
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
