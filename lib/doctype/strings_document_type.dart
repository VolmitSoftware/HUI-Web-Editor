import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;
import '../l10n/hui_localizations.dart';
import '../logic/catalog_document_validation.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../state/workspace.dart';
import '../state/editor_store.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class StringsDocumentType extends GlossDocumentTypeAdapter {
  const StringsDocumentType();
  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.strings;
  @override
  String get noun => huiText('Strings');
  @override
  String get createLabel => huiText('Strings');
  @override
  String get pluralLabel => huiText('Strings');
  @override
  int get tabOrder => 180;
  @override
  DocumentSurface get surface => DocumentSurface.strings;
  @override
  String get surfaceLabel => huiText('Strings');
  @override
  bool get hasRuntimePreview => false;
  @override
  String get syncWireKind => 'strings';
  @override
  String get defaultDocumentName => 'en_US';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.bookOpen(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossStringsDoc(json);
  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossStringsDoc(doc as GlossStringsDoc);
  @override
  GlossDoc newBlank() => GlossStringsDoc();
  @override
  bool looksLike(Object? decoded) => looksLikeStringsDoc(decoded);
  @override
  String get codeShapeError =>
      'A strings document needs schemaVersion, locale and entries.';
  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    return doc is GlossStringsDoc
        ? validateStringsDoc(doc)
        : const <HuiIssue>[];
  }

  @override
  String get templatesTabLabel => huiText('Strings');
  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'strings-default',
              name: huiText('Strings'),
              description: huiText('Plugin default'),
              highlights: const <String>[],
              create: (EditorStore store) => store.newGlossDocument(this),
            ),
          ],
        ),
      ];
}
