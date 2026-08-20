library;

import '../model/model.dart' show looksLikePreviewDoc;
import '../state/workspace.dart';
import 'animation_document_type.dart';
import 'bubble_style_document_type.dart';
import 'container_preview_document_type.dart';
import 'document_type.dart';
import 'emoji_document_type.dart';
import 'gloss_document_type.dart';
import 'hologram_document_type.dart';
import 'menu_document_type.dart';
import 'motd_document_type.dart';
import 'panel_document_type.dart';
import 'real_drop_document_type.dart';
import 'scoreboard_document_type.dart';
import 'tablist_document_type.dart';

/// The const adapter instances, one per [WorkspaceDocKind].
abstract final class DocumentTypes {
  static const MenuDocumentType menu = MenuDocumentType();
  static const ContainerPreviewDocumentType containerPreview =
      ContainerPreviewDocumentType();
  static const PanelDocumentType panel = PanelDocumentType();
  static const HologramDocumentType hologram = HologramDocumentType();
  static const AnimationDocumentType animation = AnimationDocumentType();
  static const ScoreboardDocumentType scoreboard = ScoreboardDocumentType();
  static const MotdDocumentType motd = MotdDocumentType();
  static const EmojiDocumentType emoji = EmojiDocumentType();
  static const BubbleStyleDocumentType bubbleStyle = BubbleStyleDocumentType();
  static const TablistDocumentType tablist = TablistDocumentType();
  static const RealDropDocumentType realDrops = RealDropDocumentType();
}

/// The closed set of adapters.
abstract final class DocumentTypeRegistry {
  /// Kind to adapter, const-initialized. `doctype_guard_test.dart` pins full
  /// coverage so a new enum value cannot ship without an adapter.
  static const Map<WorkspaceDocKind, DocumentTypeAdapter> _byKind =
      <WorkspaceDocKind, DocumentTypeAdapter>{
        WorkspaceDocKind.menu: DocumentTypes.menu,
        WorkspaceDocKind.containerPreview: DocumentTypes.containerPreview,
        WorkspaceDocKind.panel: DocumentTypes.panel,
        WorkspaceDocKind.hologram: DocumentTypes.hologram,
        WorkspaceDocKind.animation: DocumentTypes.animation,
        WorkspaceDocKind.scoreboard: DocumentTypes.scoreboard,
        WorkspaceDocKind.motd: DocumentTypes.motd,
        WorkspaceDocKind.emoji: DocumentTypes.emoji,
        WorkspaceDocKind.bubbleStyle: DocumentTypes.bubbleStyle,
        WorkspaceDocKind.tablist: DocumentTypes.tablist,
        WorkspaceDocKind.realDrops: DocumentTypes.realDrops,
      };

  /// Every adapter, in workspace-rail order.
  static const List<DocumentTypeAdapter> all = <DocumentTypeAdapter>[
    DocumentTypes.menu,
    DocumentTypes.containerPreview,
    DocumentTypes.panel,
    DocumentTypes.hologram,
    DocumentTypes.animation,
    DocumentTypes.scoreboard,
    DocumentTypes.motd,
    DocumentTypes.emoji,
    DocumentTypes.bubbleStyle,
    DocumentTypes.tablist,
    DocumentTypes.realDrops,
  ];

  /// Every adapter in mode-tab order, which is [DocumentTypeAdapter.tabOrder]
  /// rather than declaration order: the tab strip, the library's create row
  /// and the scoped headings all read from this one sequence.
  static List<DocumentTypeAdapter> get tabs {
    final List<DocumentTypeAdapter> ordered = List<DocumentTypeAdapter>.of(all)
      ..sort(
        (DocumentTypeAdapter a, DocumentTypeAdapter b) =>
            a.tabOrder.compareTo(b.tabOrder),
      );
    return ordered;
  }

  /// The adapter whose kind is stored under [name], or null. The name is the
  /// enum's own slug, which is what preferences and tab values carry.
  static DocumentTypeAdapter? byKindName(Object? name) {
    final WorkspaceDocKind? kind = WorkspaceDocKind.fromName(name);
    return kind == null ? null : of(kind);
  }

  static DocumentTypeAdapter of(WorkspaceDocKind kind) {
    final DocumentTypeAdapter? adapter = _byKind[kind];
    if (adapter == null) {
      throw StateError('No document type adapter is registered for $kind.');
    }
    return adapter;
  }

  /// The adapter that syncs as wire kind slug [wireKind], or null when this
  /// editor build has no codec for that kind.
  static DocumentTypeAdapter? byWireKind(String wireKind) {
    for (final DocumentTypeAdapter adapter in all) {
      if (adapter.syncWireKind == wireKind) return adapter;
    }
    return null;
  }

  /// Detects the transferable runtime document represented by decoded JSON.
  ///
  /// Container previews and Gloss envelope documents have identifying shape
  /// keys. Menus are the deliberately lenient fallback because their runtime
  /// format has no envelope or discriminator.
  static DocumentTypeAdapter detectTransferable(Object? decoded) {
    if (looksLikePreviewDoc(decoded)) return DocumentTypes.containerPreview;
    for (final DocumentTypeAdapter adapter in all) {
      if (adapter is GlossDocumentTypeAdapter && adapter.looksLike(decoded)) {
        return adapter;
      }
    }
    return DocumentTypes.menu;
  }
}
