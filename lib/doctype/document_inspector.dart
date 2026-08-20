/// Per-kind inspector bodies.
///
/// This is the web-only half of the document-type registry: the inspector
/// widgets pull in DOM bridges, so they cannot live on the DOM-free adapters
/// in `document_type.dart` without dragging `package:web` into the store's VM
/// test suite. Only the inspector pane imports this file. A new document kind
/// registers its body here and its adapter in `document_type_registry.dart` —
/// both inside `lib/doctype/`.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart' show ValueKey, Widget;

import '../components/inspector/animation_inspector.dart';
import '../components/inspector/bubble_inspector.dart';
import '../components/inspector/component_inspector.dart';
import '../components/inspector/emoji_inspector.dart';
import '../components/inspector/hologram_inspector.dart';
import '../components/inspector/inspector_session.dart';
import '../components/inspector/menu_inspector.dart';
import '../components/inspector/motd_inspector.dart';
import '../components/inspector/panel_inspector.dart';
import '../components/inspector/preview_element_editor.dart';
import '../components/inspector/scoreboard_inspector.dart';
import '../components/inspector/tablist_inspector.dart';
import '../components/inspector/preview_match_editor.dart';
import '../components/inspector/real_drop_inspector.dart';
import '../components/panels/preview_sim_panel.dart';
import '../model/model.dart';
import '../services/catalogs.dart';
import '../services/image_library.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type_registry.dart';

/// What the inspector pane hands the active kind's body builder.
final class DocumentInspectorScope {
  const DocumentInspectorScope({
    required this.store,
    required this.images,
    required this.session,
    this.bootCatalogs,
  });

  final EditorStore store;
  final ImageLibrary images;

  /// Survives selection changes and type switches for the whole session.
  final InspectorSession session;

  /// Boot snapshot from the shell. `store.catalogs` wins whenever it holds
  /// more; null means the fetch has not settled yet — the only honest signal
  /// for a skeleton.
  final HuiCatalogs? bootCatalogs;
}

typedef DocumentInspectorBuilder =
    List<Widget> Function(DocumentInspectorScope scope);

final Map<WorkspaceDocKind, DocumentInspectorBuilder> _builders =
    <WorkspaceDocKind, DocumentInspectorBuilder>{
      DocumentTypes.menu.kind: _menuBody,
      DocumentTypes.containerPreview.kind: _previewBody,
      DocumentTypes.panel.kind: _panelBody,
      DocumentTypes.hologram.kind: _hologramBody,
      DocumentTypes.animation.kind: _animationBody,
      DocumentTypes.scoreboard.kind: _scoreboardBody,
      DocumentTypes.motd.kind: _motdBody,
      DocumentTypes.emoji.kind: _emojiBody,
      DocumentTypes.bubbleStyle.kind: _bubbleBody,
      DocumentTypes.tablist.kind: _tablistBody,
      DocumentTypes.realDrops.kind: _realDropBody,
    };

/// The inspector body for the active document kind.
List<Widget> buildDocumentInspector(DocumentInspectorScope scope) =>
    _builders[scope.store.docKind]!(scope);

List<Widget> _panelBody(DocumentInspectorScope scope) => <Widget>[
  PanelInspector(store: scope.store),
];

List<Widget> _hologramBody(DocumentInspectorScope scope) => <Widget>[
  HologramInspector(
    store: scope.store,
    catalogs: huiFreshestCatalogs(scope.store.catalogs, scope.bootCatalogs),
  ),
];

List<Widget> _animationBody(DocumentInspectorScope scope) => <Widget>[
  AnimationInspector(store: scope.store),
];

List<Widget> _scoreboardBody(DocumentInspectorScope scope) => <Widget>[
  ScoreboardInspector(
    store: scope.store,
    catalogs: huiFreshestCatalogs(scope.store.catalogs, scope.bootCatalogs),
  ),
];

List<Widget> _motdBody(DocumentInspectorScope scope) => <Widget>[
  MotdInspector(store: scope.store),
];

List<Widget> _emojiBody(DocumentInspectorScope scope) => <Widget>[
  EmojiInspector(store: scope.store),
];

List<Widget> _bubbleBody(DocumentInspectorScope scope) => <Widget>[
  BubbleInspector(store: scope.store),
];

List<Widget> _tablistBody(DocumentInspectorScope scope) => <Widget>[
  TablistInspector(store: scope.store),
];

List<Widget> _realDropBody(DocumentInspectorScope scope) => <Widget>[
  RealDropInspector(store: scope.store),
];

List<Widget> _previewBody(DocumentInspectorScope scope) {
  final EditorStore store = scope.store;
  final List<Widget> body = <Widget>[
    // The simulation panel is the card surface's own HUD-ish chrome (task
    // E8): meaningless in the code view of the same document, where there is
    // nothing to animate. Every other mode has a card on screen.
    if (store.view != EditorView.code)
      PreviewSimPanel(store: store, catalogs: scope.bootCatalogs),
  ];
  final int? index = store.previewSelectedIndex;
  final HuiPreviewElement? element = store.previewSelectedElement;
  if (index == null || element == null) {
    body.add(PreviewMatchEditor(store: store));
  } else {
    // Keyed by index so switching selection rebuilds local draft state
    // instead of carrying the previous element's text across.
    body.add(
      PreviewElementEditor(
        key: ValueKey<int>(index),
        store: store,
        index: index,
        element: element,
      ),
    );
  }
  return body;
}

List<Widget> _menuBody(DocumentInspectorScope scope) {
  final EditorStore store = scope.store;
  final HuiCatalogs catalogs = huiFreshestCatalogs(
    store.catalogs,
    scope.bootCatalogs,
  );
  final HuiComponent? selected = store.selected;
  if (selected == null) return <Widget>[MenuInspector(store: store)];
  return <Widget>[
    ComponentInspector(
      // Keyed by id so switching selection rebuilds the id draft state
      // instead of carrying the previous component's text across.
      key: ValueKey<String>('inspector-${selected.id}'),
      store: store,
      images: scope.images,
      catalogs: catalogs,
      catalogsLoading: scope.bootCatalogs == null && !catalogs.loaded,
      session: scope.session,
      target: selected,
    ),
  ];
}
