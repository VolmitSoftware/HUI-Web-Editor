/// Per-kind document behavior behind [EditorStore]'s generic lifecycle.
///
/// [WorkspaceDocKind] stays the identity enum, but everything a kind DOES —
/// codec, validation, views, capabilities, templates, creation — lives on its
/// [DocumentTypeAdapter]. Adding a document kind means one enum value plus one
/// adapter registered in [DocumentTypeRegistry]; consumers go through the
/// registry instead of switching on the enum, which `doctype_guard_test.dart`
/// enforces by failing on new `WorkspaceDocKind.` references outside this
/// directory.
///
/// The adapters here are DOM-free on purpose: [EditorStore] imports this
/// library and the store's whole test suite runs on the VM. Web-only surfaces
/// (the inspector bodies) register in `document_inspector.dart`, which only
/// the inspector pane imports.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart' show Widget;

import '../l10n/hui_localizations.dart';
import '../logic/canvas_scene.dart';
import '../logic/gloss_text.dart'
    show GlossAnimationResolver, GlossEmojiResolver;
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../services/catalogs.dart';
import '../services/image_library.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';

/// Read-only view of the document state an adapter operates on.
///
/// [EditorStore] implements this. Adapters never see the store's private
/// fields; the store hands itself in wherever per-kind work needs the live
/// document.
abstract interface class DocumentStateView {
  /// The menu slot. Always a valid [HuiMenu], but only the live document
  /// while the menu kind is active.
  HuiMenu get menu;

  /// The container-preview slot, or null while another kind is active.
  HuiPreviewDoc? get previewDoc;

  /// The Gloss document slot (hologram, animation or scoreboard model), or
  /// null while another kind is active.
  GlossDoc? get glossDoc;

  /// The workspace's animation documents, for text-pipeline rendering and
  /// reference validation.
  GlossAnimationResolver get workspaceAnimations;

  /// The emoji available to text rendering: the shipped catalog with the
  /// workspace's emoji documents layered over it by id.
  GlossEmojiResolver get workspaceEmoji;

  /// The byte-exact source the active menu document was decoded from, kept
  /// until the first semantic edit. Null for every other kind.
  String? get preservedMenuSource;

  HuiCatalogs get catalogs;

  ImageLibrary? get images;

  /// Resolves the validation-scale canvas scene for the menu slot and caches
  /// it for overlap reporting — the store memoizes text and image decoding
  /// behind this call.
  CanvasScene resolveValidationScene();
}

/// The result of decoding a stored workspace document for adoption.
final class AdoptedDocument {
  const AdoptedDocument({
    required this.editorId,
    this.model,
    this.preservedSource,
    this.failureResolver,
  });

  /// The per-kind model to install, or null for kinds with no in-store model.
  final Object? model;

  /// The id the editor works under: the sanitized runtime id for kinds that
  /// have one, the document title otherwise.
  final String editorId;

  /// Byte-exact source to preserve for round-trips, when the kind keeps one.
  final String? preservedSource;

  /// User-facing message when the stored JSON was unreadable and [model] is a
  /// replacement default instead.
  final String Function()? failureResolver;

  String? get failure => failureResolver?.call();
}

/// What one document contributes to a workspace-wide menu rename.
final class MenuRenameRewrite {
  const MenuRenameRewrite({
    this.json,
    this.navigationLinks = 0,
    this.panelRoots = 0,
    this.failureResolver,
  });

  static const MenuRenameRewrite none = MenuRenameRewrite();

  /// Replacement document JSON, or null when the document does not reference
  /// the renamed menu.
  final String? json;

  /// Rewritten navigation-action targets, for the rename summary.
  final int navigationLinks;

  /// Rewritten world-panel root references, for the rename summary.
  final int panelRoots;

  /// Aborts the whole rename with this message when the document could not be
  /// read safely.
  final String Function()? failureResolver;

  String? get failure => failureResolver?.call();
}

/// A named starter document offered by the templates dialog.
final class DocumentTemplate {
  const DocumentTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.highlights,
    required this.create,
  });

  final String id;
  final String name;
  final String description;
  final List<String> highlights;

  /// Creates a fresh workspace document from this template and adopts it.
  final void Function(EditorStore store) create;
}

/// Which editing surface a kind's [EditorView.visual] mode mounts.
///
/// The centre pane keeps one widget slot per surface; the adapter says which
/// slot its kind draws into, so the shell never switches on the kind itself.
/// [canvas] and [previewCard] are the two surfaces the shell keeps mounted in
/// every view — both carry viewport state that a remount would destroy.
enum DocumentSurface {
  canvas,
  previewCard,
  panel,
  hologram,
  animation,
  scoreboard,
  motd,
  emoji,
  bubble,
  damageIndicators,
  tablist,
  realDrops,
}

/// One heading-plus-grid section of a kind's template tab.
final class DocumentTemplateSection {
  const DocumentTemplateSection({
    this.title,
    this.note,
    required this.templates,
  });

  /// Section heading, or null for a kind with a single unlabelled grid.
  final String? title;
  final String? note;
  final List<DocumentTemplate> templates;
}

/// Everything one [WorkspaceDocKind] knows how to do.
abstract class DocumentTypeAdapter {
  const DocumentTypeAdapter();

  WorkspaceDocKind get kind;

  /// Lowercase noun for user-facing messages ('menu', 'preview', 'flow map').
  String get noun;

  /// Plural, title-case name of the kind, for the top bar's mode tabs and the
  /// library's scoped headings ('Scoreboards').
  String get pluralLabel;

  /// Position in the mode tab strip and the library-rail create row. Spaced by
  /// tens so a new kind can land between two without renumbering the rest.
  int get tabOrder;

  /// Library-rail create-button label.
  String get createLabel;

  /// What this kind's [EditorView.visual] mode draws into.
  DocumentSurface get surface;

  /// Name of that surface, for the view switcher's tooltip ('Sidebar',
  /// 'Stage'). The switcher's own labels stay canonical: the four modes read
  /// the same for every kind, and this says what Visual means for this one.
  String get surfaceLabel;

  /// Whether the kind has an in-game rendering behind [EditorView.preview].
  /// False only for editor-only kinds, which have nothing to render.
  bool get hasRuntimePreview => true;

  /// The rail's contents-tab label for kinds that carry in-document contents
  /// ('Components', 'Elements'), or null for kinds that carry none — those
  /// show the library alone, so a stale list from the previous document can
  /// never be offered.
  String? get contentsTabLabel => null;

  /// Why [view] cannot be entered for this kind, or null when it can.
  ///
  /// Every kind offers the same four modes; a mode a kind genuinely cannot
  /// serve is shown with this sentence rather than hidden, so the switcher's
  /// shape never changes under the user.
  String? unavailableViewReason(EditorView view) => switch (view) {
    EditorView.visual => null,
    EditorView.preview =>
      hasRuntimePreview
          ? null
          : huiText(
              'This document has no in-game rendering, so there is nothing to preview.',
            ),
    EditorView.code || EditorView.split =>
      transferable
          ? null
          : huiText(
              'This document is editor-only, so it has no runtime JSON to edit.',
            ),
  };

  bool supportsView(EditorView view) => unavailableViewReason(view) == null;

  /// The views this kind can actually enter, in switcher order. The first
  /// entry is the kind's default view.
  List<EditorView> get availableViews => <EditorView>[
    for (final EditorView view in EditorView.values)
      if (supportsView(view)) view,
  ];

  /// Whether documents of this kind carry a canonical runtime id.
  bool get hasRuntimeId;

  /// Whether the document is runtime JSON that can be imported, exported and
  /// copied. Editor-only kinds are not.
  bool get transferable;

  /// Whether edits run through the store's snapshot-driven undo stack.
  bool get undoable;

  /// Whether the byte-exact imported source is preserved until the first
  /// semantic edit.
  bool get sourcePreserving;

  String? get syncWireKind;

  /// Library-rail document icon.
  Widget railIcon();

  /// Library-rail create-button icon. Distinct from [railIcon] where the
  /// established chrome differs.
  Widget createIcon() => railIcon();

  /// Mode-tab icon. The document icon by default: the tab and the rows it
  /// scopes the library to must read as the same thing.
  Widget tabIcon() => railIcon();

  /// Creates a fresh document of this kind in [folderId] and adopts it.
  /// A null folder places the document at the workspace root.
  /// [runtimeId] overrides the default id for kinds that have one.
  void createNew(EditorStore store, {String? folderId, String? runtimeId});

  /// Decodes [doc] for adoption. Never throws: an unreadable document comes
  /// back as a default replacement model with [AdoptedDocument.failure] set.
  AdoptedDocument adopt(WorkspaceDoc doc);

  /// Decodes one undo snapshot back into this kind's model. Throws
  /// [HuiFormatException] when the snapshot does not parse.
  Object decodeSnapshot(String snapshot);

  /// The active document encoded for undo snapshots and autosave.
  String snapshot(DocumentStateView state);

  /// The active document's runtime JSON for export, byte-preserved where the
  /// kind supports it. Throws [StateError] for non-[transferable] kinds.
  String exportJson(DocumentStateView state);

  /// The active document canonically re-encoded, discarding preserved
  /// formatting. Throws [StateError] for non-[transferable] kinds.
  String formattedJson(DocumentStateView state);

  /// Validation issues for the active document. Never throws.
  List<HuiIssue> validate(DocumentStateView state);

  /// What [doc] contributes to renaming menu [previous] to [next].
  MenuRenameRewrite rewriteForMenuRename(
    WorkspaceDoc doc,
    String previous,
    String next,
  );

  /// Tab label in the templates dialog, or null when the kind offers none.
  String? get templatesTabLabel => null;

  /// Kind-level paragraph shown above the template grid.
  String get templatesNote => '';

  List<DocumentTemplateSection> get templateSections =>
      const <DocumentTemplateSection>[];
}
