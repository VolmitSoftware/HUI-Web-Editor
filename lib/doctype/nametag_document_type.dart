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

final class NametagDocumentType extends GlossDocumentTypeAdapter {
  const NametagDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.nametag;

  @override
  String get noun => huiText('nametag');

  @override
  String get createLabel => huiText('New nametag');

  @override
  String get pluralLabel => huiText('Nametags');

  @override
  int get tabOrder => 130;

  @override
  DocumentSurface get surface => DocumentSurface.nametag;

  @override
  String get surfaceLabel => huiText('Team tag');

  @override
  String? get syncWireKind => 'nametag';

  @override
  ArcaneGlyph railIcon() => ArcaneIcon.tag(size: IconSize.sm);

  @override
  GlossDoc decodeDoc(String json) => decodeGlossNametagDoc(json);

  @override
  String encodeDoc(GlossDoc doc) =>
      encodeGlossNametagDoc(doc as GlossNametagDoc);

  @override
  GlossDoc newBlank() => buildDefaultGlossNametag();

  @override
  bool looksLike(Object? decoded) => looksLikeNametagDoc(decoded);

  @override
  String get codeShapeError =>
      'That is not a nametag document: it needs "schemaVersion" plus a '
      'presentation with prefix, suffix, nameTagVisibility or collision.';

  @override
  String get defaultDocumentName => 'default';

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final GlossDoc? doc = state.glossDoc;
    if (doc is! GlossNametagDoc) return const <HuiIssue>[];
    return validateNametagDoc(doc);
  }

  @override
  String? get templatesTabLabel => 'Nametag';

  @override
  String get templatesNote =>
      'Every template opens as a new document, so your current one is untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'nametag-default',
              name: 'Default nametag',
              description:
                  'Shipped default',
              highlights: const <String>['Shipped default', 'Staff variant'],
              create: (EditorStore store) {
                final String runtimeId = 'default';
                store.newGlossDocument(
                  this,
                  name: runtimeId,
                  from: buildDefaultGlossNametag(),
                );
              },
            ),
          ],
        ),
      ];
}
