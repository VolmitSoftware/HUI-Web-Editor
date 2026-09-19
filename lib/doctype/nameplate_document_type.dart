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

final class NameplateDocumentType extends GlossDocumentTypeAdapter {
  const NameplateDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.nameplate;

  @override
  String get noun => huiText('nameplate');

  @override
  String get createLabel => huiText('New nameplate');

  @override
  String get pluralLabel => huiText('Nameplates');

  @override
  int get tabOrder => 125;

  @override
  DocumentSurface get surface => DocumentSurface.nameplate;

  @override
  String get surfaceLabel => huiText('Over player');

  @override
  String? get syncWireKind => 'nameplate';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.user(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossNameplateDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossNameplateDoc(doc as GlossNameplateDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossNameplate();

  @override
  bool looksLike(Object? decoded) => looksLikeNameplateDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a nameplate document: it needs "schemaVersion" plus a '
      'presentation with lines, offset, hideSneaking or relations.';

  @override
  String get defaultDocumentName => 'default';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossNameplateDoc) return const <HuiIssue>[];
    return validateNameplateDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Nameplate';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'nameplate-default',
              name: 'Default nameplate',
              description:
                  'Shipped default',
              highlights: const <String>['Shipped default', 'Health bar'],
              create: (EditorStore store) {
                final String runtimeId = 'default';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildDefaultGlossNameplate(),
                );
              },
            ),
          ],
        ),
      ];
}
