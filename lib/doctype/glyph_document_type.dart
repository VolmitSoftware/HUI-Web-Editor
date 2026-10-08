import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;
import '../l10n/hui_localizations.dart';
import '../logic/glyph_validation.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../state/workspace.dart';
import '../state/editor_store.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class GlyphDocumentType extends GlossDocumentTypeAdapter {
  const GlyphDocumentType();
  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.glyph;
  @override
  String get noun => huiText('Glyphs');
  @override
  String get createLabel => huiText('Glyphs');
  @override
  String get pluralLabel => huiText('Glyphs');
  @override
  int get tabOrder => 195;
  @override
  DocumentSurface get surface => DocumentSurface.glyph;
  @override
  String get surfaceLabel => huiText('Glyphs');
  @override
  bool get hasRuntimePreview => false;
  @override
  String get syncWireKind => 'glyph';
  @override
  String get defaultDocumentName => 'new-glyphs';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.image(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossGlyphDoc(json);
  @override
  String encodeDoc(GlossDoc doc) => encodeGlossGlyphDoc(doc as GlossGlyphDoc);
  @override
  GlossDoc newBlank() => GlossGlyphDoc();
  @override
  bool looksLike(Object? decoded) => looksLikeGlyphDoc(decoded);
  @override
  String get codeShapeError =>
      'A glyph document needs schemaVersion and glyphs, waypointStyles, or namespace and font.';
  @override
  List<HuiIssue> validate(DocumentStateView state) =>
      state.glossDoc is GlossGlyphDoc
      ? validateGlyphDoc(state.glossDoc! as GlossGlyphDoc)
      : const <HuiIssue>[];
  @override
  String get templatesTabLabel => huiText('Glyphs');
  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'glyph-default',
              name: huiText('Glyphs'),
              description: huiText('Empty font collection'),
              highlights: const <String>[],
              create: (EditorStore store) => store.newGlossDocument(this),
            ),
          ],
        ),
      ];
}
