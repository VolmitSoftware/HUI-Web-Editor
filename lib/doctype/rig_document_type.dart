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

final class RigDocumentType extends GlossDocumentTypeAdapter {
  const RigDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.rig;

  @override
  String get noun => huiText('rig');

  @override
  String get createLabel => huiText('New rig');

  @override
  String get pluralLabel => huiText('Rigs');

  @override
  int get tabOrder => 140;

  @override
  DocumentSurface get surface => DocumentSurface.rig;

  @override
  String get surfaceLabel => huiText('Bones and parts');

  @override
  String? get syncWireKind => 'rig';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.box(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossRigDoc(json);

  @override
  String encodeDoc(GlossDoc doc) => encodeGlossRigDoc(doc as GlossRigDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossRig();

  @override
  bool looksLike(Object? decoded) => looksLikeRigDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a rig document: it needs "schemaVersion" plus "bones" and '
      '"parts".';

  @override
  String get defaultDocumentName => 'pedestal';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossRigDoc) return const <HuiIssue>[];
    return validateRigDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Rig';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'rig-pedestal',
              name: 'Pedestal',
              description:
                  'Shipped default',
              highlights: const <String>['Shipped default', 'Graph', 'Hitbox'],
              create: (EditorStore store) {
                final String runtimeId = 'pedestal';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildDefaultGlossRig(),
                );
              },
            ),
          ],
        ),
      ];
}
