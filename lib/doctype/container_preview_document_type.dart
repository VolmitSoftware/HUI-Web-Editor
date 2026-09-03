library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../config/defaults.dart';
import '../config/preview_templates.dart';
import '../logic/preview_doc_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../services/showcase_randomizer.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';

/// The pixel-space container-preview card document.
final class ContainerPreviewDocumentType extends DocumentTypeAdapter {
  const ContainerPreviewDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.containerPreview;

  @override
  String get noun => huiText('preview');

  @override
  String get createLabel => huiText('New preview document');

  @override
  String get pluralLabel => huiText('Previews');

  @override
  int get tabOrder => 20;

  @override
  DocumentSurface get surface => DocumentSurface.previewCard;

  @override
  String get surfaceLabel => huiText('Card');

  @override
  String? get contentsTabLabel => huiText('Elements');

  @override
  bool get hasRuntimeId => true;

  @override
  bool get transferable => true;

  @override
  bool get undoable => true;

  @override
  bool get sourcePreserving => false;

  @override
  String? get syncWireKind => 'container-preview';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.layoutGrid(size: IconSize.sm);

  @override
  void createNew(EditorStore store, {String? folderId, String? runtimeId}) =>
      store.newPreviewDocument(
        name: huiText('New preview'),
        folderId: folderId,
      );

  @override
  AdoptedDocument adopt(WorkspaceDoc doc) {
    final String editorId = sanitizeMenuId(doc.runtimeId!);
    try {
      return AdoptedDocument(
        editorId: editorId,
        model: decodeHuiPreviewDoc(doc.json),
      );
    } on HuiFormatException catch (e) {
      return AdoptedDocument(
        editorId: editorId,
        model: HuiPreviewDoc(),
        failureResolver: () => huiText(
          'The saved document "{title}" was unreadable ({error}) and was replaced with a blank preview document.',
          <String, Object?>{'title': doc.title, 'error': e.message},
        ),
      );
    } catch (_) {
      return AdoptedDocument(
        editorId: editorId,
        model: HuiPreviewDoc(),
        failureResolver: () => huiText(
          'The saved document "{title}" was unreadable and was replaced with a blank preview document.',
          <String, Object?>{'title': doc.title},
        ),
      );
    }
  }

  @override
  Object decodeSnapshot(String snapshot) => decodeHuiPreviewDoc(snapshot);

  @override
  String snapshot(DocumentStateView state) =>
      encodeHuiPreviewDoc(state.previewDoc!);

  @override
  String exportJson(DocumentStateView state) => snapshot(state);

  @override
  String formattedJson(DocumentStateView state) => snapshot(state);

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final HuiPreviewDoc? doc = state.previewDoc;
    if (doc == null) return const <HuiIssue>[];
    return validatePreviewDoc(
      doc,
      knownMaterials: state.catalogs.loaded
          ? state.catalogs.materialKeys
          : null,
    );
  }

  @override
  MenuRenameRewrite rewriteForMenuRename(
    WorkspaceDoc doc,
    String previous,
    String next,
  ) => MenuRenameRewrite.none;

  @override
  String? get templatesTabLabel => 'Container preview';

  @override
  String get templatesNote =>
      'On the server are the thirteen cards the plugin extracts '
      'into plugins/Gloss/previews/, byte for byte. Starters '
      'are teaching documents the jar does not ship. Every '
      'template opens as a new document, so your current one '
      'is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          title: 'On the server',
          note: 'These are the cards Gloss already draws in game.',
          templates: _templates(inGame: true),
        ),
        DocumentTemplateSection(
          title: 'Starters',
          note: 'Teaching documents. They are not extracted by the plugin.',
          templates: _templates(inGame: false),
        ),
      ];

  List<DocumentTemplate> _templates({
    required bool inGame,
  }) => <DocumentTemplate>[
    if (!inGame)
      DocumentTemplate(
        id: 'all-elements',
        name: 'Furnace expression lab',
        description:
            'A working furnace, blast-furnace, and smoker card demonstrating '
            'live timers, inventory functions, variants, repeat, math, '
            'localization, and animated colour expressions.',
        highlights: const <String>[
          'All 4 element types',
          'Furnace variables',
          'Live expression animation',
        ],
        create: (EditorStore store) => store.createDocumentFromPreview(
          'all-elements',
          buildRandomPreviewFurnaceLab(math.Random(20260819)),
        ),
      ),
    for (final HuiPreviewTemplate template in huiPreviewTemplates)
      if (template.inGame == inGame)
        DocumentTemplate(
          id: template.id,
          name: template.name,
          description: template.description,
          highlights: template.highlights,
          create: (EditorStore store) =>
              store.createDocumentFromPreview(template.id, template.build()),
        ),
  ];
}
