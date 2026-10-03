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

final class WaypointDocumentType extends GlossDocumentTypeAdapter {
  const WaypointDocumentType();
  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.waypoint;
  @override
  String get noun => huiText('Waypoints');
  @override
  String get createLabel => huiText('Waypoints');
  @override
  String get pluralLabel => huiText('Waypoints');
  @override
  int get tabOrder => 190;
  @override
  DocumentSurface get surface => DocumentSurface.waypoint;
  @override
  String get surfaceLabel => huiText('Waypoints');
  @override
  bool get hasRuntimePreview => false;
  @override
  String get syncWireKind => 'waypoint';
  @override
  String get defaultDocumentName => 'new-waypoint';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.mapPin(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossWaypointDoc(json);
  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossWaypointDoc(doc as GlossWaypointDoc);
  @override
  GlossDoc newBlank() => GlossWaypointDoc();
  @override
  bool looksLike(Object? decoded) => looksLikeWaypointDoc(decoded);
  @override
  String get codeShapeError =>
      'A waypoint document needs schemaVersion, anchor and range.';
  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    return doc is GlossWaypointDoc
        ? validateWaypointDoc(doc)
        : const <HuiIssue>[];
  }

  @override
  String get templatesTabLabel => huiText('Waypoints');
  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'waypoint-default',
              name: huiText('Waypoints'),
              description: huiText('Plugin default'),
              highlights: const <String>[],
              create: (EditorStore store) => store.newGlossDocument(this),
            ),
          ],
        ),
      ];
}
