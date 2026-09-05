library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneGlyph, ArcaneIcon, IconSize;

import '../l10n/hui_localizations.dart';
import '../logic/entity_overlay_validation.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';
import 'gloss_document_type.dart';

final class EntityOverlaysDocumentType extends GlossDocumentTypeAdapter {
  const EntityOverlaysDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.entityOverlays;
  @override
  String get noun => huiText('entity-overlay settings');
  @override
  String get createLabel => huiText('Entity overlays');
  @override
  String get pluralLabel => huiText('Entity overlays');
  @override
  int get tabOrder => 96;
  @override
  DocumentSurface get surface => DocumentSurface.entityOverlays;
  @override
  String get surfaceLabel => huiText('Entity stage');
  @override
  String get syncWireKind => 'entity-overlays';
  @override
  ArcaneGlyph railIcon() => ArcaneIcon.heart(size: IconSize.sm);
  @override
  GlossDoc decodeDoc(String json) => decodeGlossEntityOverlaysDoc(json);
  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossEntityOverlaysDoc(doc as GlossEntityOverlaysDoc);
  @override
  GlossDoc newBlank() => GlossEntityOverlaysDoc();
  @override
  bool looksLike(Object? decoded) => looksLikeEntityOverlaysDoc(decoded);
  @override
  String get codeShapeError =>
      'That is not an entity-overlays document: it needs "schemaVersion" and "healthSegments".';
  @override
  String get defaultDocumentName => glossEntityOverlaysDefaultId;

  @override
  String get fixedRuntimeId => glossEntityOverlaysDefaultId;
  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    return doc is GlossEntityOverlaysDoc
        ? validateEntityOverlaysDoc(doc)
        : const <HuiIssue>[];
  }

  @override
  String get templatesTabLabel => huiText('Entity overlays');
  @override
  String get templatesNote => huiText(
    'The singleton entity-overlays/default.json file controls nearby entity labels, segmented health, combat stats and hit feedback.',
  );
  @override
  List<DocumentTemplateSection>
  get templateSections => <DocumentTemplateSection>[
    DocumentTemplateSection(
      templates: <DocumentTemplate>[
        DocumentTemplate(
          id: 'entity-overlays-default',
          name: huiText('Nearby entity health'),
          description: huiText(
            'Gloss defaults with names, ten health segments, damage feedback and attack/armor stats. React adds stack counts; Adapt Insight adds details.',
          ),
          highlights: <String>[
            huiText('Plugin default'),
            huiText('Segmented health'),
            huiText('React and Adapt'),
          ],
          create: (EditorStore store) => store.newGlossDocument(this),
        ),
      ],
    ),
  ];
}
