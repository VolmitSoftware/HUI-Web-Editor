library;

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../config/gloss_templates.dart';
import '../logic/display_lane_validation.dart';
import '../logic/validation.dart' show HuiIssue;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class MarkerDocumentType extends GlossDocumentTypeAdapter {
  const MarkerDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.marker;

  @override
  String get noun => huiText('marker');

  @override
  String get createLabel => huiText('New marker');

  @override
  String get pluralLabel => huiText('Markers');

  @override
  int get tabOrder => 145;

  @override
  DocumentSurface get surface => DocumentSurface.marker;

  @override
  String get surfaceLabel => huiText('World pin');

  @override
  String? get syncWireKind => 'marker';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.mapPin(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossMarkerDoc(json);

  @override
  String encodeDoc(GlossDoc doc) => encodeGlossMarkerDoc(doc as GlossMarkerDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossMarker();

  @override
  bool looksLike(Object? decoded) => looksLikeMarkerDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a marker document: it needs "schemaVersion" plus an '
      '"anchor" with world x y z, an entity, or a player.';

  @override
  String get defaultDocumentName => 'new-marker';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossMarkerDoc) return const <HuiIssue>[];
    return validateMarkerDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Marker';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'marker-pin',
              name: 'World pin',
              description:
                  'Shipped default',
              highlights: const <String>['Position', 'Beam'],
              create: (EditorStore store) {
                final String runtimeId = 'pin';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildDefaultGlossMarker(),
                );
              },
            ),
          ],
        ),
      ];
}
