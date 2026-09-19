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

final class ZoneDocumentType extends GlossDocumentTypeAdapter {
  const ZoneDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.zone;

  @override
  String get noun => huiText('zone');

  @override
  String get createLabel => huiText('New zone');

  @override
  String get pluralLabel => huiText('Zones');

  @override
  int get tabOrder => 150;

  @override
  DocumentSurface get surface => DocumentSurface.zone;

  @override
  String get surfaceLabel => huiText('Volume');

  @override
  String? get syncWireKind => 'zone';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.scan(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossZoneDoc(json);

  @override
  String encodeDoc(GlossDoc doc) => encodeGlossZoneDoc(doc as GlossZoneDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossZone();

  @override
  bool looksLike(Object? decoded) => looksLikeZoneDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a zone document: it needs "schemaVersion" plus a "shape" '
      'with type cuboid, cylinder, polygon or region.';

  @override
  String get defaultDocumentName => 'new-zone';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossZoneDoc) return const <HuiIssue>[];
    return validateZoneDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Zone';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'zone-cuboid',
              name: 'Cuboid',
              description:
                  'Shipped default',
              highlights: const <String>['Cuboid', 'Particles'],
              create: (EditorStore store) {
                final String runtimeId = 'spawn';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildDefaultGlossZone(),
                );
              },
            ),
          ],
        ),
      ];
}
